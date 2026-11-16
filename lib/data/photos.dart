import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../domain/ids.dart';
import '../domain/journal.dart';

/// Content-addressed label photos: each file is named by the SHA-256 of its
/// bytes, so the same photo twice is one file and re-importing is harmless.
/// Images arrive already downscaled by the picker.
final class PhotoStore {
  PhotoStore(this.dir);
  final String dir;

  Future<PhotoRef> add(Uint8List jpegBytes) async {
    final ref = PhotoRef('${sha256.convert(jpegBytes)}.jpg');
    final target = fileFor(ref);
    if (!target.existsSync()) {
      await Directory(dir).create(recursive: true);
      final temp = File('${target.path}.tmp');
      await temp.writeAsBytes(jpegBytes, flush: true);
      await temp.rename(target.path);
    }
    return ref;
  }

  File fileFor(PhotoRef ref) => File(p.join(dir, ref.fileName));

  bool has(PhotoRef ref) => fileFor(ref).existsSync();

  /// Deletes photo files no tasting references, and stray temp files. Run at
  /// launch, before any draft can hold an unsaved ref.
  Future<int> sweep(Journal journal) async {
    final d = Directory(dir);
    if (!d.existsSync()) return 0;
    final keep = {
      for (final t in journal.tastings.values)
        if (t.photo case final ref?) ref.fileName,
    };
    var deleted = 0;
    await for (final entry in d.list()) {
      if (entry is File && !keep.contains(p.basename(entry.path))) {
        await entry.delete();
        deleted++;
      }
    }
    return deleted;
  }
}
