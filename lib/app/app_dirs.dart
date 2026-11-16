import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where Cork keeps its files, all under the app-support directory.
final class AppDirs {
  const AppDirs(this.root);

  static Future<AppDirs> resolve() async =>
      AppDirs((await getApplicationSupportDirectory()).path);

  final String root;

  String get journalDb => p.join(root, 'journal.db');
  String get indexDir => p.join(root, 'index');
  String get photosDir => p.join(root, 'photos');
  String get exportsDir => p.join(root, 'exports');
  String get settingsFile => p.join(root, 'settings.json');
}
