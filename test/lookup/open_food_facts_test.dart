import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cork/domain/ids.dart';
import 'package:cork/domain/wine.dart';
import 'package:cork/lookup/open_food_facts.dart';
import 'package:cork/lookup/wine_lookup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  var now = DateTime.utc(2026, 11, 15, 12);
  final requests = <http.Request>[];

  OpenFoodFacts client(
    FutureOr<http.Response> Function(http.Request) respond, {
    Duration timeout = const Duration(seconds: 10),
  }) => OpenFoodFacts(
    appVersion: '1.2.3',
    now: () => now,
    timeout: timeout,
    client: MockClient((request) async {
      requests.add(request);
      return respond(request);
    }),
  );

  http.Response products(List<Object?> list) => http.Response.bytes(
    utf8.encode(jsonEncode({'count': list.length, 'products': list})),
    200,
    headers: {'content-type': 'application/json'},
  );

  final empty = products(const []);

  setUp(() {
    now = DateTime.utc(2026, 11, 15, 12);
    requests.clear();
  });

  test('sends the Cork User-Agent and the terms to the wine search', () async {
    await client((_) => empty).search('  château margaux ');
    final request = requests.single;
    expect(
      request.headers['User-Agent'],
      'Cork/1.2.3 (https://git.bigpapa.one/cmess/cork)',
    );
    expect(request.method, 'GET');
    expect(request.url.host, 'world.openfoodfacts.org');
    expect(request.url.path, '/cgi/search.pl');
    expect(request.url.queryParameters['search_terms'], 'château margaux');
    expect(request.url.queryParameters['tag_0'], 'en:wines');
  });

  test('blank text returns no hits without a request', () async {
    expect(await client((_) => empty).search('   '), isA<OnlineHits>());
    expect(requests, isEmpty);
  });

  test(
    'the ninth search inside a minute is refused without a request',
    () async {
      final off = client((_) => empty);
      for (var i = 0; i < 8; i++) {
        expect(await off.search('wine $i'), isA<OnlineHits>());
        now = now.add(const Duration(seconds: 5));
      }
      final refused = await off.search('one more');
      expect(refused, isA<OnlineRateLimited>());
      expect(
        (refused as OnlineRateLimited).retryIn,
        const Duration(seconds: 20),
      );
      expect(requests, hasLength(8));

      now = now.add(const Duration(seconds: 20));
      expect(await off.search('after the window'), isA<OnlineHits>());
      expect(requests, hasLength(9));
    },
  );

  group('failures are OnlineUnavailable', () {
    Future<OnlineResult> outcome(
      FutureOr<http.Response> Function(http.Request) respond, {
      Duration timeout = const Duration(seconds: 10),
    }) => client(respond, timeout: timeout).search('margaux');

    test('server error', () async {
      expect(
        await outcome((_) => http.Response('<html>busy</html>', 503)),
        isA<OnlineUnavailable>(),
      );
    });

    test('socket error', () async {
      expect(
        await outcome((_) => throw const SocketException('offline')),
        isA<OnlineUnavailable>(),
      );
    });

    test('client error', () async {
      expect(
        await outcome((_) => throw http.ClientException('reset')),
        isA<OnlineUnavailable>(),
      );
    });

    test('timeout', () async {
      expect(
        await outcome(
          (_) => Completer<http.Response>().future,
          timeout: const Duration(milliseconds: 20),
        ),
        isA<OnlineUnavailable>(),
      );
    });

    test('a body that is not JSON', () async {
      expect(
        await outcome((_) => http.Response('<html>', 200)),
        isA<OnlineUnavailable>(),
      );
    });

    test('JSON that is not a search response', () async {
      for (final body in ['[]', '{"products": "none"}', '{}', 'null']) {
        expect(
          await outcome((_) => http.Response(body, 200)),
          isA<OnlineUnavailable>(),
          reason: body,
        );
      }
    });
  });

  test('parses products into wines and drops the nameless', () async {
    final result = await client(
      (_) => products([
        {
          'code': '3760123456789',
          'product_name': ' Château Margaux 2015 ',
          'brands': 'Château Margaux, Grands Vins',
          'categories_tags': ['en:beverages', 'en:wines', 'en:red-wines'],
          'origins_tags': ['en:france'],
        },
        {
          'code': '8000000000001',
          'lang': 'it',
          'product_name': '',
          'product_name_it': 'Prosecco Rosé',
          'categories_tags': [
            'en:wines',
            'en:rose-wines',
            'en:sparkling-wines',
          ],
          'origins_tags': ['en:italy', 'en:france'],
        },
        {
          'code': '5000000000002',
          'product_name_fr': 'Porto Tawny',
          'categories_tags': ['en:ports', 'en:red-wines'],
        },
        {'code': '5000000000003', 'product_name': 'Vin de table'},
        {'code': '1111111111111', 'brands': 'No Name Co'},
        {'code': '', 'product_name': 'No barcode'},
        {'code': '3760123456789', 'product_name': 'Duplicate'},
        'not a product',
      ]),
    ).search('wine');

    final wines = (result as OnlineHits).wines;
    expect(
      [for (final w in wines) w.name],
      ['Château Margaux 2015', 'Prosecco Rosé', 'Porto Tawny', 'Vin de table'],
    );

    final margaux = wines[0];
    expect(margaux.id, WineId('off:3760123456789'));
    expect(
      (margaux.provenance as FromOpenFoodFacts).barcode,
      Barcode('3760123456789'),
    );
    expect(margaux.winery, 'Château Margaux');
    expect(margaux.type, WineType.red);
    expect(margaux.country, const Country('FR', 'France'));

    expect(wines[1].type, WineType.sparkling);
    expect(wines[1].country, isNull, reason: 'two origins is not clear');
    expect(wines[2].type, WineType.fortified);
    expect(wines[3].type, isNull);
    expect(wines[3].winery, isNull);
  });

  test('maps each wine category to its type', () async {
    Future<WineType?> typeOf(List<String> tags) async {
      final result = await client(
        (_) => products([
          {'code': '1', 'product_name': 'x', 'categories_tags': tags},
        ]),
      ).search('x');
      return (result as OnlineHits).wines.single.type;
    }

    expect(await typeOf(['en:white-wines']), WineType.white);
    expect(await typeOf(['en:champagnes']), WineType.sparkling);
    expect(
      await typeOf(['en:dessert-wines', 'en:white-wines']),
      WineType.dessert,
    );
    expect(await typeOf(['en:fortified-wines']), WineType.fortified);
    expect(await typeOf(['en:rose-wines']), WineType.rose);
  });
}
