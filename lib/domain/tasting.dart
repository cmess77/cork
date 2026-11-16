import 'glass_color.dart';
import 'ids.dart';
import 'scales.dart';
import 'wine.dart';

/// A 1 to 5 rating for aroma, flavor, or finish.
extension type const Stars._(int value) {
  factory Stars(int value) {
    RangeError.checkValueInInterval(value, 1, 5, 'stars');
    return Stars._(value);
  }
}

/// Overall score in tenths, 10..50, so 0.1 steps are exact and groupable.
extension type const Score._(int tenths) implements Object {
  static const min = Score._(10);
  static const max = Score._(50);

  factory Score.fromTenths(int tenths) {
    RangeError.checkValueInInterval(tenths, 10, 50, 'tenths');
    return Score._(tenths);
  }

  /// 4.2 becomes 42. Null outside 1.0..5.0 or off the 0.1 grid.
  static Score? tryParse(num value) {
    final tenths = (value * 10).round();
    if ((value * 10 - tenths).abs() > 1e-6) return null;
    if (tenths < 10 || tenths > 50) return null;
    return Score._(tenths);
  }

  double get value => tenths / 10;

  /// "4.2": one fractional digit, always.
  String format() => '${tenths ~/ 10}.${tenths % 10}';
}

sealed class Vintage {
  const Vintage();

  static const earliest = 1800;
  static const latest = 2100;

  /// "2019" or "NV". Null for anything else.
  static Vintage? tryParse(String text) {
    final t = text.trim();
    if (t.toUpperCase() == 'NV') return const NonVintage();
    final year = int.tryParse(t);
    if (year == null || year < earliest || year > latest) return null;
    return VintageYear(year);
  }

  String format();
}

final class VintageYear extends Vintage {
  const VintageYear(this.year);
  final int year;

  @override
  String format() => '$year';

  @override
  bool operator ==(Object other) => other is VintageYear && other.year == year;

  @override
  int get hashCode => year.hashCode;
}

final class NonVintage extends Vintage {
  const NonVintage();

  @override
  String format() => 'NV';

  @override
  bool operator ==(Object other) => other is NonVintage;

  @override
  int get hashCode => 0;
}

/// An amount in the currency's minor unit (cents, or yen for JPY). No FX.
final class Money {
  const Money(this.minor, this.currency);
  final int minor;
  final CurrencyCode currency;

  /// Parses "32", "32.5", or "32.50" in [currency]. Null for negative
  /// amounts, junk, or more decimals than the currency has.
  static Money? tryParse(String text, CurrencyCode currency) {
    final t = text.trim().replaceAll(',', '.');
    final match = RegExp(r'^(\d+)(?:\.(\d*))?$').firstMatch(t);
    if (match == null) return null;
    final exp = currency.exponent;
    final fraction = match.group(2) ?? '';
    if (fraction.length > exp) return null;
    final whole = int.parse(match.group(1)!);
    final minor = exp == 0
        ? whole
        : whole * _pow10(exp) + int.parse(fraction.padRight(exp, '0'));
    return Money(minor, currency);
  }

  double get major => minor / _pow10(currency.exponent);

  /// "32.00": the decimal string the journal file stores.
  String formatAmount() {
    final exp = currency.exponent;
    if (exp == 0) return '$minor';
    final unit = _pow10(exp);
    return '${minor ~/ unit}.${(minor % unit).toString().padLeft(exp, '0')}';
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);
}

int _pow10(int exp) {
  var r = 1;
  for (var i = 0; i < exp; i++) {
    r *= 10;
  }
  return r;
}

/// A saved check-in. Only the wine, date, and score are required.
final class Tasting {
  const Tasting({
    required this.id,
    required this.wineId,
    required this.tastedAt,
    required this.score,
    this.vintage,
    this.color,
    this.aroma,
    this.flavor,
    this.finish,
    this.finishLength,
    this.sweetness,
    this.body,
    this.acidity,
    this.tannin,
    this.descriptors = const {},
    this.notes = '',
    this.place,
    this.price,
    this.photo,
  });

  final TastingId id;
  final WineId wineId;

  /// UTC instant.
  final DateTime tastedAt;
  final Score score;
  final Vintage? vintage;
  final GlassColor? color;
  final Stars? aroma;
  final Stars? flavor;
  final Stars? finish;
  final FinishLength? finishLength;
  final Sweetness? sweetness;
  final Level? body;
  final Level? acidity;
  final Level? tannin;
  final Set<DescriptorId> descriptors;
  final String notes;
  final String? place;
  final Money? price;
  final PhotoRef? photo;
}

/// The field a draft [Issue] belongs to, so the form can put the message there.
enum DraftField { score, vintage, price }

final class Issue {
  const Issue(this.field, this.message);
  final DraftField field;

  /// Names the fix, such as "Set a score".
  final String message;
}

sealed class Checked<T> {
  const Checked();
}

final class Valid<T> extends Checked<T> {
  const Valid(this.value);
  final T value;
}

final class Invalid<T> extends Checked<T> {
  const Invalid(this.issues);
  final List<Issue> issues;
}

/// Tasting form state. Mutable on purpose: it lives in one form's State and
/// mirrors its controls. [build] is the one gate from form to journal.
final class TastingDraft {
  TastingDraft._({
    required this.wine,
    required this.tastedAt,
    required this.currency,
    this.id,
  });

  /// A new tasting. [tastedAt] defaults to [now]; the wine's index hints
  /// prefill body and acidity.
  factory TastingDraft.forWine(
    Wine wine, {
    required DateTime now,
    required CurrencyCode currency,
  }) => TastingDraft._(wine: wine, tastedAt: now, currency: currency)
    ..body = wine.typicalBody
    ..acidity = wine.typicalAcidity;

  /// Edits [t], whose wine is [wine].
  factory TastingDraft.edit(
    Tasting t,
    Wine wine, {
    required CurrencyCode defaultCurrency,
  }) {
    final d =
        TastingDraft._(
            wine: wine,
            tastedAt: t.tastedAt.toLocal(),
            currency: t.price?.currency ?? defaultCurrency,
            id: t.id,
          )
          ..score = t.score
          ..color = t.color
          ..aroma = t.aroma
          ..flavor = t.flavor
          ..finish = t.finish
          ..finishLength = t.finishLength
          ..sweetness = t.sweetness
          ..body = t.body
          ..acidity = t.acidity
          ..tannin = t.tannin
          ..descriptors = {...t.descriptors}
          ..notes = t.notes
          ..place = t.place ?? ''
          ..priceText = t.price?.formatAmount() ?? ''
          ..photo = t.photo;
    switch (t.vintage) {
      case VintageYear(:final year):
        d.vintageText = '$year';
      case NonVintage():
        d.nonVintage = true;
      case null:
    }
    return d;
  }

  /// Null for a new tasting; the edited tasting's id otherwise.
  final TastingId? id;
  Wine wine;
  DateTime tastedAt;
  Score? score;
  String vintageText = '';
  bool nonVintage = false;
  GlassColor? color;
  Stars? aroma;
  Stars? flavor;
  Stars? finish;
  FinishLength? finishLength;
  Sweetness? sweetness;
  Level? body;
  Level? acidity;
  Level? tannin;
  Set<DescriptorId> descriptors = {};
  String notes = '';
  String place = '';
  String priceText = '';
  CurrencyCode currency;
  PhotoRef? photo;

  bool get isEdit => id != null;

  Checked<Tasting> build({TastingId Function() mintId = TastingId.mint}) {
    final issues = <Issue>[];
    final score = this.score;
    if (score == null) issues.add(const Issue(DraftField.score, 'Set a score'));

    Vintage? vintage;
    if (nonVintage) {
      vintage = const NonVintage();
    } else if (vintageText.trim().isNotEmpty) {
      vintage = Vintage.tryParse(vintageText);
      if (vintage == null) {
        issues.add(
          const Issue(
            DraftField.vintage,
            'Enter a year from ${Vintage.earliest} to ${Vintage.latest}',
          ),
        );
      }
    }

    Money? price;
    if (priceText.trim().isNotEmpty) {
      price = Money.tryParse(priceText, currency);
      if (price == null) {
        issues.add(const Issue(DraftField.price, 'Enter a price like 24.50'));
      }
    }

    if (issues.isNotEmpty) return Invalid(issues);
    final trimmedPlace = place.trim();
    return Valid(
      Tasting(
        id: id ?? mintId(),
        wineId: wine.id,
        tastedAt: tastedAt.toUtc(),
        score: score!,
        vintage: vintage,
        color: color,
        aroma: aroma,
        flavor: flavor,
        finish: finish,
        finishLength: finishLength,
        sweetness: sweetness,
        body: body,
        acidity: acidity,
        tannin: tannin,
        descriptors: Set.unmodifiable(descriptors),
        notes: notes.trim(),
        place: trimmedPlace.isEmpty ? null : trimmedPlace,
        price: price,
        photo: photo,
      ),
    );
  }
}
