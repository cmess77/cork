import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_store.dart';
import '../ui/shell.dart';
import '../ui/theme/cork_theme.dart';
import 'providers.dart';

class CorkApp extends ConsumerWidget {
  const CorkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(settingsProvider).theme;
    return MaterialApp(
      title: 'Cork',
      debugShowCheckedModeBanner: false,
      theme: CorkTheme.light,
      darkTheme: CorkTheme.dark,
      themeMode: switch (theme) {
        ThemeChoice.system => ThemeMode.system,
        ThemeChoice.light => ThemeMode.light,
        ThemeChoice.dark => ThemeMode.dark,
      },
      home: const Shell(),
    );
  }
}
