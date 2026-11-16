import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

export 'package:image_picker/image_picker.dart' show ImageSource;

abstract interface class LabelPhotoPicker {
  /// JPEG bytes already bounded to 1600 px, or null when the user cancels.
  /// Throws a `PlatformException` when the camera or gallery is unavailable.
  Future<Uint8List?> pick(ImageSource source);
}

final class SystemLabelPhotoPicker implements LabelPhotoPicker {
  const SystemLabelPhotoPicker();

  @override
  Future<Uint8List?> pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    return file?.readAsBytes();
  }
}

class LabelPhotoPickerScope extends InheritedWidget {
  const LabelPhotoPickerScope({
    super.key,
    required this.picker,
    required super.child,
  });

  final LabelPhotoPicker picker;

  static LabelPhotoPicker of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<LabelPhotoPickerScope>()?.picker ??
      const SystemLabelPhotoPicker();

  @override
  bool updateShouldNotify(LabelPhotoPickerScope old) => old.picker != picker;
}
