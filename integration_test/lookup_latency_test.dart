import 'package:cork/domain/journal.dart';
import 'package:cork/lookup/wine_index.dart';
import 'package:cork/lookup/wine_lookup.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _typing = [
  'c',
  'ch',
  'cha',
  'chat',
  'chate',
  'chatea',
  'chateau',
  'chateau m',
  'chateau ma',
  'chateau mar',
  'chateau marg',
];
const _rounds = 5;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('suggest answers each keystroke quickly', (tester) async {
    final support = await getApplicationSupportDirectory();
    final lookup = await BundledWineLookup.open(
      indexDir: p.join(support.path, 'index'),
      loadAsset: () => rootBundle.load(wineIndexAssetKey),
      journal: () => Journal.empty,
      appVersion: '0.0.0-latency',
    );
    addTearDown(lookup.close);

    for (final text in _typing) {
      await lookup.suggest(text);
    }

    final samples = <int>[];
    for (var round = 0; round < _rounds; round++) {
      for (final text in _typing) {
        final clock = Stopwatch()..start();
        final hits = await lookup.suggest(text);
        samples.add(clock.elapsedMicroseconds);
        if (text.length > 1) expect(hits, isNotEmpty, reason: text);
      }
    }
    samples.sort();
    String ms(int micros) => (micros / 1000).toStringAsFixed(1);
    int at(double q) => samples[((samples.length - 1) * q).round()];

    final top = (await lookup.suggest('chateau marg')).first;
    expect(top.winery, 'Château Margaux');

    // ignore: avoid_print
    print(
      'SUGGEST_LATENCY p50_ms=${ms(at(0.5))} p95_ms=${ms(at(0.95))} '
      'max_ms=${ms(samples.last)} n=${samples.length}',
    );
    // ignore: avoid_print
    print('SUGGEST_TOP "chateau marg" -> "${top.name} / ${top.winery}"');
  });
}
