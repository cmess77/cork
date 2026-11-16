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

final class SettingsStore extends ChangeNotifier {
  SettingsStore._(this._file, this._currency, this._theme);

  static SettingsStore open(String path, {required CurrencyCode fallback}) {
    final file = File(path);
    var currency = fallback;
    var theme = ThemeChoice.system;
    final json = _readJson(file);
    if (json is Map) {
      currency =
          switch (json['currency']) {
            final String s => CurrencyCode.tryParse(s),
            _ => null,
          } ??
          fallback;
      theme = ThemeChoice.values.firstWhere(
        (t) => t.name == json['theme'],
        orElse: () => ThemeChoice.system,
      );
    }
    return SettingsStore._(file, currency, theme);
  }

  static Object? _readJson(File file) {
    try {
      return jsonDecode(file.readAsStringSync());
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
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
