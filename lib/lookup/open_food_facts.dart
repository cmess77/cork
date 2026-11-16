import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/ids.dart';
import '../domain/wine.dart';
import 'wine_lookup.dart';

/// Only the v1 `cgi/search.pl` endpoint takes free-text terms;
/// `/api/v2/search` filters by tag only.
final class OpenFoodFacts {
  OpenFoodFacts({
    required String appVersion,
    http.Client? client,
    DateTime Function()? now,
    this._timeout = const Duration(seconds: 10),
  }) : _userAgent = 'Cork/$appVersion (https://git.bigpapa.one/cmess/cork)',
       _client = client ?? http.Client(),
       _ownsClient = client == null,
       _now = now ?? DateTime.now;

  /// Two under Open Food Facts' documented 10 searches per minute per IP.
  static const budget = 8;
  static const window = Duration(seconds: 60);

  final String _userAgent;
  final Duration _timeout;
  final http.Client _client;
  final bool _ownsClient;
  final DateTime Function() _now;
  final _sent = Queue<DateTime>();

  Future<OnlineResult> search(String text) async {
    final terms = text.trim();
    if (terms.isEmpty) return const OnlineHits([]);

    final now = _now();
    while (_sent.isNotEmpty && !now.isBefore(_sent.first.add(window))) {
      _sent.removeFirst();
    }
    if (_sent.length >= budget) {
      return OnlineRateLimited(_sent.first.add(window).difference(now));
    }
    _sent.addLast(now);

    try {
      final response = await _client
          .get(_searchUri(terms), headers: {'User-Agent': _userAgent})
          .timeout(_timeout);
      if (response.statusCode != 200) return const OnlineUnavailable();
      return OnlineHits(
        parseProducts(jsonDecode(utf8.decode(response.bodyBytes))),
      );
    } on Exception {
      return const OnlineUnavailable();
    }
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

Uri _searchUri(String terms) =>
    Uri.https('world.openfoodfacts.org', '/cgi/search.pl', {
      'action': 'process',
      'search_simple': '1',
      'json': '1',
      'page_size': '20',
      'search_terms': terms,
      'tagtype_0': 'categories',
      'tag_contains_0': 'contains',
      'tag_0': 'en:wines',
      'fields': _fields.join(','),
    });

const _localizedNames = [
  'product_name_en',
  'product_name_fr',
  'product_name_it',
  'product_name_es',
  'product_name_de',
  'product_name_pt',
];

const _fields = [
  'code',
  'lang',
  'product_name',
  ..._localizedNames,
  'brands',
  'categories_tags',
  'origins_tags',
];

/// Throws [FormatException] when the payload is not a search response.
/// Products without a name or barcode are dropped, not rejected.
List<Wine> parseProducts(Object? json) {
  if (json case {'products': List products}) {
    final seen = <WineId>{};
    return [
      for (final product in products)
        if (_wine(product) case final wine? when seen.add(wine.id)) wine,
    ];
  }
  throw const FormatException('Not an Open Food Facts search response');
}

Wine? _wine(Object? product) {
  if (product is! Map) return null;
  String? text(String key) => switch (product[key]) {
    String s when s.trim().isNotEmpty => s.trim(),
    _ => null,
  };

  final code = text('code');
  final name =
      text('product_name') ??
      text('product_name_${product['lang']}') ??
      _localizedNames.map(text).nonNulls.firstOrNull;
  if (code == null || name == null) return null;

  final barcode = Barcode(code);
  return Wine(
    id: WineId.forBarcode(barcode),
    name: name,
    provenance: FromOpenFoodFacts(barcode),
    winery: text(
      'brands',
    )?.split(',').map((b) => b.trim()).where((b) => b.isNotEmpty).firstOrNull,
    type: _type(_tags(product['categories_tags'])),
    country: _country(_tags(product['origins_tags'])),
  );
}

Set<String> _tags(Object? tags) => {
  if (tags is List)
    for (final t in tags)
      if (t is String) t.substring(t.indexOf(':') + 1),
};

const _typeTags = [
  (WineType.fortified, ['fortified-wines', 'ports', 'port-wines']),
  (WineType.sparkling, ['sparkling-wines', 'champagnes']),
  (WineType.dessert, ['dessert-wines']),
  (WineType.rose, ['rose-wines']),
  (WineType.red, ['red-wines']),
  (WineType.white, ['white-wines']),
];

WineType? _type(Set<String> categories) {
  for (final (type, tags) in _typeTags) {
    if (tags.any(categories.contains)) return type;
  }
  return null;
}

/// Codes and names are the index's own (X-Wines writes the United Kingdom as
/// 'UK'), so stats group an online wine with index wines from the same country.
Country? _country(Set<String> origins) =>
    origins.length == 1 ? _origins[origins.single] : null;

const _origins = {
  'france': Country('FR', 'France'),
  'italy': Country('IT', 'Italy'),
  'united-states': Country('US', 'United States'),
  'spain': Country('ES', 'Spain'),
  'portugal': Country('PT', 'Portugal'),
  'germany': Country('DE', 'Germany'),
  'australia': Country('AU', 'Australia'),
  'chile': Country('CL', 'Chile'),
  'argentina': Country('AR', 'Argentina'),
  'south-africa': Country('ZA', 'South Africa'),
  'austria': Country('AT', 'Austria'),
  'brazil': Country('BR', 'Brazil'),
  'new-zealand': Country('NZ', 'New Zealand'),
  'canada': Country('CA', 'Canada'),
  'switzerland': Country('CH', 'Switzerland'),
  'greece': Country('GR', 'Greece'),
  'romania': Country('RO', 'Romania'),
  'uruguay': Country('UY', 'Uruguay'),
  'mexico': Country('MX', 'Mexico'),
  'hungary': Country('HU', 'Hungary'),
  'israel': Country('IL', 'Israel'),
  'georgia': Country('GE', 'Georgia'),
  'bulgaria': Country('BG', 'Bulgaria'),
  'croatia': Country('HR', 'Croatia'),
  'moldova': Country('MD', 'Moldova'),
  'slovenia': Country('SI', 'Slovenia'),
  'united-kingdom': Country('UK', 'United Kingdom'),
  'lebanon': Country('LB', 'Lebanon'),
  'luxembourg': Country('LU', 'Luxembourg'),
  'morocco': Country('MA', 'Morocco'),
};
