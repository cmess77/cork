import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// First 12 hex digits of the SHA-256 of `assets/wine_index.db`.
/// `test/lookup/wine_index_asset_test.dart` fails when the asset changes
/// without this changing, so a rebuilt index always reinstalls on device.
const wineIndexAssetVersion = '9cc1fb509ace';

const wineIndexAssetKey = 'assets/wine_index.db';

/// SQLite cannot open a file inside the APK, so the bundled index is copied to
/// [indexDir] once per asset version. Temp file then rename, so a crash mid-copy
/// never leaves a half-written database under the final name. Returns the path.
Future<String> installWineIndex(
  String indexDir, {
  required Future<ByteData> Function() loadAsset,
}) async {
  final dir = Directory(indexDir);
  await dir.create(recursive: true);
  final name = 'wine_index.$wineIndexAssetVersion.db';
  final target = File(p.join(indexDir, name));

  if (!target.existsSync()) {
    final data = await loadAsset();
    final temp = File('${target.path}.tmp');
    await temp.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    await temp.rename(target.path);
  }

  await for (final entry in dir.list()) {
    if (entry is File && p.basename(entry.path) != name) {
      await entry.delete();
    }
  }
  return target.path;
}
