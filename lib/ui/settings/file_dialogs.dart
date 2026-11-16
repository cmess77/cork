import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';

abstract interface class FileDialogs {
  /// Null when the user cancels.
  Future<Uri?> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  });

  /// A local path to the picked file, or null when the user cancels.
  Future<String?> pickPath();
}

final class SystemFileDialogs implements FileDialogs {
  const SystemFileDialogs();

  @override
  Future<Uri?> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) =>
      FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: mimeType);

  @override
  Future<String?> pickPath() async => (await FilePicker.pickFile())?.path;
}

class FileDialogsScope extends InheritedWidget {
  const FileDialogsScope({
    super.key,
    required this.dialogs,
    required super.child,
  });

  final FileDialogs dialogs;

  static FileDialogs of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FileDialogsScope>()?.dialogs ??
      const SystemFileDialogs();

  @override
  bool updateShouldNotify(FileDialogsScope old) => old.dialogs != dialogs;
}
