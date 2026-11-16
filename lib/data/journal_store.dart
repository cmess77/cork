import 'package:flutter/foundation.dart';

import '../domain/journal.dart';
import 'journal_codec.dart';
import 'journal_db.dart';

final class JournalStore extends ChangeNotifier {
  JournalStore._(this._db, this._journal);

  static JournalStore open(
    String dbPath, {
    required void Function(int fromVersion, RawDocs docs) beforeUpgrade,
  }) {
    final db = JournalDb.open(dbPath);
    final version = db.docVersion;
    final raw = db.readAll();
    final journal = switch (JournalCodec.decode(version, raw)) {
      DecodedJournal(:final journal) => journal,
      NewerDocVersion(:final version) => throw StateError(
        'journal.db holds doc version $version; this Cork reads up to '
        '$currentDocVersion',
      ),
      DecodeFailure() && final f => throw StateError('journal.db: $f'),
    };
    if (version < currentDocVersion) {
      beforeUpgrade(version, raw);
      db.replaceAll(_rowsOf(journal));
    }
    return JournalStore._(db, journal);
  }

  final JournalDb _db;
  Journal _journal;

  Journal get journal => _journal;

  Journal commit(List<JournalChange> changes) {
    final before = _journal;
    final after = before.apply(changes);
    final rows = _diff(before, after);
    if (!rows.isEmpty) _db.write(rows);
    _journal = after;
    notifyListeners();
    return after;
  }

  void replaceAll(Journal next) {
    _db.replaceAll(_rowsOf(next));
    _journal = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }
}

RowChanges _diff(Journal a, Journal b) => RowChanges(
  putWines: [
    for (final w in b.wines.values)
      if (!identical(a.wines[w.id], w))
        (w.id.value, JournalCodec.encodeWine(w)),
  ],
  putTastings: [
    for (final t in b.tastings.values)
      if (!identical(a.tastings[t.id], t))
        (t.id.value, t.wineId.value, JournalCodec.encodeTasting(t)),
  ],
  deleteTastings: [
    for (final id in a.tastings.keys)
      if (!b.tastings.containsKey(id)) id.value,
  ],
  putWishlist: [
    for (final i in b.wishlist.values)
      if (!identical(a.wishlist[i.wineId], i))
        (i.wineId.value, JournalCodec.encodeWishlistItem(i)),
  ],
  deleteWishlist: [
    for (final id in a.wishlist.keys)
      if (!b.wishlist.containsKey(id)) id.value,
  ],
);

RowChanges _rowsOf(Journal j) => _diff(Journal.empty, j);
