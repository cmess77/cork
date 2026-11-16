import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/ids.dart';

enum ThemeChoice {
  system('System'),
  light('Light'),
  dark('Dark');

  const ThemeChoice(this.label);
  final String label;
}

/// App preferences, kept apart from the journal so a backup restore never
/// changes them. One small JSON file, written temp-then-rename.
final class SettingsStore extends ChangeNotifier {
  SettingsStore._(this._file, this._currency, this._theme);

  static SettingsStore open(String path, {required CurrencyCode fallback}) {
    final file = File(path);
    var currency = fallback;
    var theme = ThemeChoice.system;
    try {
      final json = jsonDecode(file.readAsStringSync());
      if (json is Map) {
        currency = CurrencyCode.tryParse('${json['currency']}') ?? fallback;
        theme = ThemeChoice.values.firstWhere(
          (t) => t.name == json['theme'],
          orElse: () => ThemeChoice.system,
        );
      }
    } on FileSystemException {
      // First launch: defaults.
    } on FormatException {
      // A damaged file falls back to defaults and is rewritten on next save.
    }
    return SettingsStore._(file, currency, theme);
  }

  final File _file;
  CurrencyCode _currency;
  ThemeChoice _theme;

  CurrencyCode get currency => _currency;
  ThemeChoice get theme => _theme;

  set currency(CurrencyCode value) {
    _currency = value;
    _save();
  }

  set theme(ThemeChoice value) {
    _theme = value;
    _save();
  }

  void _save() {
    final temp = File('${_file.path}.tmp');
    temp.parent.createSync(recursive: true);
    temp.writeAsStringSync(
      jsonEncode({'currency': _currency.code, 'theme': _theme.name}),
      flush: true,
    );
    temp.renameSync(_file.path);
    notifyListeners();
  }
}
