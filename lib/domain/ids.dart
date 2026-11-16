import 'dart:math';

final _random = Random.secure();

String _hex(int bytes) => [
  for (var i = 0; i < bytes; i++)
    _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
].join();

extension type const IndexWineId(int value) {}

extension type const Barcode(String value) {}

extension type const WineId(String value) {
  factory WineId.forIndex(IndexWineId id) => WineId('xw:${id.value}');
  factory WineId.forBarcode(Barcode code) => WineId('off:${code.value}');
  factory WineId.mintManual() => WineId('m:${_hex(8)}');
}

extension type const TastingId(String value) {
  factory TastingId.mint() => TastingId(_hex(16));
}

extension type const DescriptorId(String value) {}

extension type const PhotoRef(String fileName) {
  static final _shape = RegExp(r'^[0-9a-f]{64}\.jpg$');

  static PhotoRef? tryParse(String text) =>
      _shape.hasMatch(text) ? PhotoRef(text) : null;
}

extension type const CurrencyCode(String code) {
  static final _shape = RegExp(r'^[A-Z]{3}$');

  static CurrencyCode? tryParse(String text) {
    final upper = text.trim().toUpperCase();
    return _shape.hasMatch(upper) ? CurrencyCode(upper) : null;
  }

  int get exponent => _exponents[code] ?? 2;
}

const _exponents = {
  'BHD': 3,
  'CLP': 0,
  'ISK': 0,
  'JOD': 3,
  'JPY': 0,
  'KRW': 0,
  'KWD': 3,
  'OMR': 3,
  'PYG': 0,
  'TND': 3,
  'UGX': 0,
  'VND': 0,
};

const commonCurrencies = [
  CurrencyCode('USD'),
  CurrencyCode('EUR'),
  CurrencyCode('GBP'),
  CurrencyCode('AUD'),
  CurrencyCode('CAD'),
  CurrencyCode('NZD'),
  CurrencyCode('CHF'),
  CurrencyCode('JPY'),
  CurrencyCode('ZAR'),
  CurrencyCode('SEK'),
  CurrencyCode('NOK'),
  CurrencyCode('DKK'),
];
