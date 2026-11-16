import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../domain/ids.dart';
import '../domain/journal.dart';

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
