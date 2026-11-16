import 'dart:math';

final _random = Random.secure();

String _hex(int bytes) => [
  for (var i = 0; i < bytes; i++)
    _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
].join();

/// An X-Wines WineID, the primary key of the bundled index.
extension type const IndexWineId(int value) {}

/// An Open Food Facts product code (EAN/UPC barcode digits).
extension type const Barcode(String value) {}

/// Derived from provenance, so the same real-world wine gets the same id on
/// every device and every adoption: 'xw:112233', 'off:3760123456789', `m:<hex>`.
extension type const WineId(String value) {
  factory WineId.forIndex(IndexWineId id) => WineId('xw:${id.value}');
  factory WineId.forBarcode(Barcode code) => WineId('off:${code.value}');
  factory WineId.mintManual() => WineId('m:${_hex(8)}');
}

extension type const TastingId(String value) {
  factory TastingId.mint() => TastingId(_hex(16));
}

/// Stable slug into the aroma wheel, such as 'fruit.citrus.lemon'.
/// The vocabulary is append-only: ids already written to a journal never change.
extension type const DescriptorId(String value) {}

/// `<sha256 hex>.jpg`: a file name inside the photos directory, never a path.
extension type const PhotoRef(String fileName) {
  static final _shape = RegExp(r'^[0-9a-f]{64}\.jpg$');

  static PhotoRef? tryParse(String text) =>
      _shape.hasMatch(text) ? PhotoRef(text) : null;
}

/// ISO 4217 code, upper case.
extension type const CurrencyCode(String code) {
  static final _shape = RegExp(r'^[A-Z]{3}$');

  static CurrencyCode? tryParse(String text) {
    final upper = text.trim().toUpperCase();
    return _shape.hasMatch(upper) ? CurrencyCode(upper) : null;
  }

  /// Digits after the decimal point in this currency's minor unit.
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

/// Offered first in the currency picker. Any valid ISO code is accepted.
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
