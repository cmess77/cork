import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../domain/aroma_wheel_data.dart';
import '../domain/ids.dart';
import '../domain/journal.dart';
import 'journal_codec.dart';
import 'journal_store.dart';
import 'photos.dart';

sealed class ImportPreview {
  const ImportPreview();
}

final class ImportReady extends ImportPreview {
  const ImportReady(this.incoming);
  final Incoming incoming;
}

final class ImportRejected extends ImportPreview {
  const ImportRejected(this.problem);
  final ImportProblem problem;
}

final class Incoming {
  const Incoming._(this.journal, this._source, this._zipped);
  final Journal journal;
  final String _source;
  final bool _zipped;
}

sealed class ImportProblem {
  const ImportProblem();

  String get message;
}

final class NotCorkBackup extends ImportProblem {
  const NotCorkBackup();
  @override
  String get message => "That file isn't a Cork backup.";
}

final class BackupTooNew extends ImportProblem {
  const BackupTooNew(this.version);
  final int version;
  @override
  String get message =>
      'That backup is from a newer Cork. Update the app to import it.';
}

final class BackupDamaged extends ImportProblem {
  const BackupDamaged(this.path, this.detail);
  final String path;
  final String detail;
  @override
  String get message => 'That backup is damaged ($path: $detail).';
}

final class Backup {
  Backup({
    required this.store,
    required this.photos,
    required this.exportsDir,
    required this.appVersion,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final JournalStore store;
  final PhotoStore photos;
  final String exportsDir;
  final String appVersion;
  final DateTime Function() _now;

  static const journalEntry = 'journal.json';
  static const photosPrefix = 'photos/';

  Future<File> exportCork({String prefix = 'cork'}) async {
    final file = await _target('$prefix-${_stamp()}.cork');
    final zip = ZipFileEncoder()..create(file.path);
    zip.addArchiveFile(ArchiveFile.string(journalEntry, _journalText()));
    final added = <String>{};
    for (final t in store.journal.tastings.values) {
      final ref = t.photo;
      if (ref == null || !added.add(ref.fileName)) continue;
      final photo = photos.fileFor(ref);
      if (photo.existsSync()) {
        await zip.addFile(photo, '$photosPrefix${ref.fileName}');
      }
    }
    await zip.close();
    return file;
  }

  Future<File> exportJson() async {
    final file = await _target('cork-${_stamp()}.json');
    await file.writeAsString(_journalText(), flush: true);
    return file;
  }

  Future<File> exportCsv() async {
    final file = await _target('cork-tastings-${_stamp()}.csv');
    await file.writeAsString(tastingsCsv(store.journal), flush: true);
    return file;
  }

  Future<ImportPreview> preview(String path) async {
    final Object? json;
    final bool zipped;
    try {
      zipped = await _isZip(path);
      if (zipped) {
        final input = InputFileStream(path);
        try {
          final entry = ZipDecoder().decodeStream(input).findFile(journalEntry);
          if (entry == null) return const ImportRejected(NotCorkBackup());
          json = jsonDecode(utf8.decode(entry.content));
        } finally {
          await input.close();
        }
      } else {
        json = jsonDecode(await File(path).readAsString());
      }
    } on FormatException {
      // Also catches ArchiveException, a FormatException subtype.
      return const ImportRejected(NotCorkBackup());
    } on FileSystemException {
      return const ImportRejected(NotCorkBackup());
    }
    return switch (decodeJournalFile(json)) {
      FileJournal(:final journal) => ImportReady(
        Incoming._(journal, path, zipped),
      ),
      NotACorkFile() => const ImportRejected(NotCorkBackup()),
      FileTooNew(:final version) => ImportRejected(BackupTooNew(version)),
      FileMalformed(:final path, :final message) => ImportRejected(
        BackupDamaged(path, message),
      ),
    };
  }

  Future<File> restore(Incoming incoming) async {
    final safety = await exportCork(prefix: 'pre-import');
    if (incoming._zipped) {
      final wanted = {
        for (final t in incoming.journal.tastings.values)
          if (t.photo case final ref?) ref.fileName,
      };
      final input = InputFileStream(incoming._source);
      try {
        for (final entry in ZipDecoder().decodeStream(input)) {
          if (!entry.isFile || !entry.name.startsWith(photosPrefix)) continue;
          final name = entry.name.substring(photosPrefix.length);
          final ref = PhotoRef.tryParse(name);
          if (ref == null || !wanted.contains(name) || photos.has(ref)) {
            continue;
          }
          await photos.add(entry.content);
          entry.clear();
        }
      } finally {
        await input.close();
      }
    }
    store.replaceAll(incoming.journal);
    return safety;
  }

  String _journalText() => const JsonEncoder.withIndent('  ').convert(
    encodeJournalFile(
      store.journal,
      exportedAt: _now(),
      appVersion: appVersion,
    ),
  );

  Future<File> _target(String name) async {
    await Directory(exportsDir).create(recursive: true);
    return File(p.join(exportsDir, name));
  }

  String _stamp() {
    final t = _now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}-'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }
}

Future<bool> _isZip(String path) async {
  final raf = await File(path).open();
  try {
    final head = await raf.read(4);
    return head.length == 4 &&
        head[0] == 0x50 &&
        head[1] == 0x4B &&
        head[2] == 0x03 &&
        head[3] == 0x04;
  } finally {
    await raf.close();
  }
}

const csvColumns = [
  'tasted_at',
  'wine',
  'winery',
  'type',
  'grapes',
  'region',
  'country',
  'vintage',
  'score',
  'glass',
  'aroma',
  'flavor',
  'finish',
  'finish_length',
  'sweetness',
  'body',
  'acidity',
  'tannin',
  'descriptors',
  'notes',
  'where',
  'price',
  'currency',
];

/// RFC 4180.
String tastingsCsv(Journal journal) {
  final out = StringBuffer()..write('${csvColumns.join(',')}\r\n');
  for (final (:tasting, :wine) in journal.feed) {
    final t = tasting;
    final cells = <Object?>[
      t.tastedAt.toLocal().toIso8601String(),
      wine.name,
      wine.winery,
      wine.type?.label,
      wine.grapes.join('; '),
      wine.region,
      wine.country?.name,
      t.vintage?.format(),
      t.score.format(),
      t.color?.phrase,
      t.aroma?.value,
      t.flavor?.value,
      t.finish?.value,
      t.finishLength?.label,
      t.sweetness?.label,
      t.body?.label,
      t.acidity?.label,
      t.tannin?.label,
      [for (final d in t.descriptors) aromaWheel.resolve(d).label].join('; '),
      t.notes,
      t.place,
      t.price?.formatAmount(),
      t.price?.currency.code,
    ];
    out.write('${cells.map(_csvCell).join(',')}\r\n');
  }
  return out.toString();
}

String _csvCell(Object? value) {
  final s = value?.toString() ?? '';
  if (!s.contains(RegExp('[",\r\n]'))) return s;
  return '"${s.replaceAll('"', '""')}"';
}
