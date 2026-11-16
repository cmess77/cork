import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/providers.dart';
import '../../app/version.dart';
import '../../data/backup.dart';
import '../../data/settings_store.dart';
import '../../domain/ids.dart';
import '../format.dart';
import '../theme/cork_theme.dart';
import '../widgets/chalk.dart';
import 'file_dialogs.dart';

enum _Export {
  journal(
    'Export journal',
    'Everything: wines, tastings, photos, wishlist',
    'application/zip',
    'Journal exported',
  ),
  journalWithoutPhotos(
    'Export without photos',
    'Wines, tastings and wishlist as one JSON file',
    'application/json',
    'Journal exported',
  ),
  csv(
    'Export tastings as CSV',
    'For spreadsheets',
    'text/csv',
    'Tastings exported',
  );

  const _Export(this.title, this.subtitle, this.mimeType, this.done);
  final String title;
  final String subtitle;
  final String mimeType;
  final String done;

  Future<File> write(Backup backup) => switch (this) {
    _Export.journal => backup.exportCork(),
    _Export.journalWithoutPhotos => backup.exportJson(),
    _Export.csv => backup.exportCsv(),
  };
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  var _busy = false;

  void _say(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  /// Runs [work] with the backup rows disabled and the progress bar showing.
  Future<void> _run(Future<void> Function() work) async {
    setState(() => _busy = true);
    try {
      await work();
    } on FileSystemException catch (e) {
      if (mounted) _say("Couldn't read or write the file: ${_reason(e)}.");
    } on PlatformException catch (e) {
      if (mounted) _say("The file dialog failed: ${e.message ?? e.code}.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export(_Export kind) => _run(() async {
    final dialogs = FileDialogsScope.of(context);
    final file = await kind.write(ref.read(backupProvider));
    final saved = await dialogs.save(
      fileName: p.basename(file.path),
      bytes: await file.readAsBytes(),
      mimeType: kind.mimeType,
    );
    if (saved != null && mounted) _say(kind.done);
  });

  Future<void> _import() => _run(() async {
    final backup = ref.read(backupProvider);
    final path = await FileDialogsScope.of(context).pickPath();
    if (path == null || !mounted) return;
    switch (await backup.preview(path)) {
      case ImportRejected(:final problem):
        if (mounted) _say(problem.message);
      case ImportReady(:final incoming):
        if (!mounted) return;
        // Nothing is running while the owner decides.
        setState(() => _busy = false);
        if (!await _confirmReplace() || !mounted) return;
        setState(() => _busy = true);
        await backup.restore(incoming);
        final n = incoming.journal.tastings.length;
        if (mounted) _say('Imported ${countLabel(n, 'tasting')}');
    }
  });

  Future<bool> _confirmReplace() async {
    final current = ref.read(journalProvider).tastings.length;
    final replace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace your journal with this backup?'),
        content: Text(
          'Your current ${countLabel(current, 'tasting')} will be replaced.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    return replace ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final store = ref.read(settingsStoreProvider);
    final text = Theme.of(context).textTheme;
    final currencies = {...commonCurrencies, settings.currency}.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _busy
              ? const LinearProgressIndicator(semanticsLabel: 'Working')
              : const SizedBox(height: 4),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: CorkSpace.xl),
        children: [
          const BoardHeading('Journal'),
          ListTile(
            title: const Text('Default currency'),
            subtitle: const Text('For new tasting prices'),
            trailing: DropdownButtonHideUnderline(
              child: DropdownButton<CurrencyCode>(
                value: settings.currency,
                style: text.labelLarge,
                items: [
                  for (final c in currencies)
                    DropdownMenuItem(value: c, child: Text(c.code)),
                ],
                onChanged: (c) {
                  if (c != null) store.currency = c;
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CorkSpace.gutter,
              CorkSpace.sm,
              CorkSpace.gutter,
              CorkSpace.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Theme', style: text.titleMedium),
                const SizedBox(height: CorkSpace.sm),
                SegmentedButton<ThemeChoice>(
                  showSelectedIcon: false,
                  segments: [
                    for (final t in ThemeChoice.values)
                      ButtonSegment(value: t, label: Text(t.label)),
                  ],
                  selected: {settings.theme},
                  onSelectionChanged: (s) => store.theme = s.single,
                ),
              ],
            ),
          ),
          const BoardHeading('Backup'),
          _action(_Export.journal),
          _action(_Export.journalWithoutPhotos),
          ListTile(
            enabled: !_busy,
            title: const Text('Import journal'),
            subtitle: const Text('Replaces this journal with a backup'),
            onTap: _import,
          ),
          _action(_Export.csv),
          const BoardHeading('About'),
          ListTile(
            title: const Text('Version'),
            trailing: Text(appVersion, style: text.bodyMedium),
          ),
          for (final line in const [
            'Wine data from X-Wines (CC0)',
            'Online search by Open Food Facts (ODbL)',
            'Your data stays on this phone.',
          ])
            ListTile(title: Text(line), titleTextStyle: text.bodyLarge),
        ],
      ),
    );
  }

  Widget _action(_Export kind) => ListTile(
    enabled: !_busy,
    title: Text(kind.title),
    subtitle: Text(kind.subtitle),
    onTap: () => _export(kind),
  );
}

String _reason(FileSystemException e) => e.osError?.message ?? e.message;
