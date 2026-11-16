# Cork domain types and module map (candidate-haiku)

Scope: scalars and ids, wine and drafts, tasting and draft, aroma wheel, snapshot and filter, stats, badges, the lookup port, persistence, the export format, state management, and the `lib/` module map. Usage call sites and the rationale live in `rationale.md`.

Bodies that are not written yet throw `UnimplementedError()`. Under `lib/domain/` only `dart:core`, `dart:collection`, `dart:typed_data`, `package:freezed_annotation`, and `package:meta` may be imported. `test/architecture_test.dart` enforces that list.

## 1. Scalars, ids, and results

`lib/domain/scalars.dart`

```dart
// Local ids are UUID v4 text generated on the device. Autoincrement integers
// collide when an export from one device is imported on another.
extension type const WineId._(String value) {
  static WineId generate() => throw UnimplementedError();
  static WineId? tryParse(String raw) => throw UnimplementedError();
}

extension type const TastingId._(String value) {
  static TastingId generate() => throw UnimplementedError();
  static TastingId? tryParse(String raw) => throw UnimplementedError();
}

// Issued by the X-Wines dataset. Its own namespace, so it never mixes with WineId.
extension type const IndexWineId(int value) {}

extension type const Barcode._(String value) {
  static Barcode? tryParse(String raw) => throw UnimplementedError();
}

// Aroma wheel key such as "fruit/citrus/lemon". Keys survive label edits.
extension type const DescriptorKey._(String value) {}

extension type const CountryCode._(String value) {
  static CountryCode? tryParse(String raw) => throw UnimplementedError(); // ISO 3166-1 alpha-2
}

extension type const CurrencyCode._(String value) {
  static CurrencyCode? tryParse(String raw) => throw UnimplementedError(); // ISO 4217
}

extension type const Grape._(String value) {
  static Grape? tryParse(String raw) => throw UnimplementedError();
  // Case and whitespace folded. Breakdowns group on this, display uses the value.
  String get key => throw UnimplementedError();
}

// Overall score in tenths, 10 to 50. Integer tenths avoid float equality bugs.
extension type const Score._(int tenths) {
  static Score? fromTenths(int tenths) => throw UnimplementedError();
}

// One aroma, flavor, or finish rating, 1 to 5.
extension type const Rating._(int value) {
  static Rating? tryFrom(int value) => throw UnimplementedError();
}

final class Money {
  const Money({required this.minorUnits, required this.currency});
  final int minorUnits; // 2499 is 24.99 in USD. Exponents per currency live in price_bands.dart.
  final CurrencyCode currency;
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

final class Issue {
  const Issue({required this.field, required this.message});
  final String field; // "overall", "tastings[4].vintage"
  final String message;
}
```

## 2. Wine, provenance, and drafts

`lib/domain/wine.dart`

```dart
enum WineType { red, white, rose, sparkling, dessert, dessertPort }

extension WineTypeGroup on WineType {
  // Breakdowns and badges count Dessert/Port as dessert. The type keeps the distinction.
  WineType get group => throw UnimplementedError();
}

enum Elaboration { varietal, blend }

sealed class Provenance {
  const Provenance();
}

final class FromIndex extends Provenance {
  const FromIndex(this.id);
  final IndexWineId id;
}

final class FromOpenFoodFacts extends Provenance {
  const FromOpenFoodFacts(this.barcode);
  final Barcode barcode;
}

final class FromManual extends Provenance {
  const FromManual();
}

// The local record. Fields are copied at adoption, so after a save the journal
// never reads the bundled index or the network.
final class Wine {
  const Wine({
    required this.id,
    required this.name,
    required this.type,
    required this.provenance,
    required this.grapes,
    this.winery,
    this.elaboration,
    this.abv,
    this.country,
    this.region,
    this.datasetBody,
    this.datasetAcidity,
  });

  final WineId id;
  final String name;
  final String? winery;
  final WineType type;
  final Elaboration? elaboration;
  final List<Grape> grapes; // empty when the source did not say
  final Provenance provenance;
  final double? abv;
  final CountryCode? country;
  final String? region;
  final String? datasetBody; // index vocabulary, unverified (see rationale)
  final String? datasetAcidity;
}

// What lookup returns and what the add-wine form edits. Each source fills what it knows.
// freezed generates copyWith for the form.
final class WineDraft {
  const WineDraft({
    required this.provenance,
    required this.name,
    this.winery,
    this.type,
    this.elaboration,
    this.grapes = const [],
    this.abv,
    this.country,
    this.region,
    this.datasetBody,
    this.datasetAcidity,
  });

  final Provenance provenance;
  final String name;
  final String? winery;
  final WineType? type;
  final Elaboration? elaboration;
  final List<Grape> grapes;
  final double? abv;
  final CountryCode? country;
  final String? region;
  final String? datasetBody;
  final String? datasetAcidity;

  // Refuses when name or type is missing. Everything else may stay empty.
  Checked<Wine> complete(WineId id) => throw UnimplementedError();
}
```

## 3. Tasting

`lib/domain/tasting.dart`

```dart
sealed class Glass {
  const Glass();
}

final class WhiteGlass extends Glass {
  const WhiteGlass(this.hue);
  final WhiteHue hue;
}

final class RoseGlass extends Glass {
  const RoseGlass(this.hue);
  final RoseHue hue;
}

final class RedGlass extends Glass {
  const RedGlass(this.hue);
  final RedHue hue;
}

enum WhiteHue { waterWhite, greenYellow, lemon, straw, gold, deepGold, amber, brown }
enum RoseHue { palePink, salmon, onionSkin, deepPink }
enum RedHue { purple, ruby, garnet, tawny, brown }
enum Intensity { pale, medium, deep }

sealed class Vintage {
  const Vintage();
}

final class VintageYear extends Vintage {
  const VintageYear(this.year);
  final int year;
}

final class NonVintage extends Vintage {
  const NonVintage();
}

enum FinishLength { short, medium, long }
enum Sweetness { boneDry, dry, offDry, mediumSweet, sweet, luscious }
enum Level { low, medium, high }

final class Appearance {
  const Appearance({required this.glass, required this.intensity});
  final Glass glass;
  final Intensity intensity;
}

final class Finish {
  const Finish({required this.rating, required this.length});
  final Rating rating;
  final FinishLength length;
}

final class Palate {
  const Palate({
    required this.aroma,
    required this.flavor,
    required this.finish,
    required this.sweetness,
  });
  final Rating aroma;
  final Rating flavor;
  final Finish finish;
  final Sweetness sweetness;
}

final class Structure {
  const Structure({required this.body, required this.acidity, this.tannin});
  final Level body;
  final Level acidity;
  final Level? tannin; // only with RedGlass. Checked in TastingDraft.build.
}

extension type const PhotoRef._(String relativePath) {}

final class TastingContext {
  const TastingContext({required this.tastedAt, this.where, this.price, this.photo});
  final DateTime tastedAt; // stored as UTC
  final String? where;
  final Money? price;
  final PhotoRef? photo;
}

// A complete tasting. Built only by TastingDraft.build, so no partial one exists.
final class Tasting {
  const Tasting({
    required this.id,
    required this.wineId,
    required this.appearance,
    required this.palate,
    required this.overall,
    required this.context,
    required this.descriptors,
    required this.notes,
    this.vintage,
    this.structure,
  });

  final TastingId id;
  final WineId wineId;
  final Vintage? vintage; // null means not recorded
  final Appearance appearance;
  final Palate palate;
  final Structure? structure;
  final Score overall;
  final TastingContext context;
  final Set<DescriptorKey> descriptors; // unknown keys survive import
  final String notes;
}

// Form state. Every field the user has not answered is null. freezed generates copyWith.
final class TastingDraft {
  const TastingDraft({
    required this.id,
    required this.wineId,
    required this.tastedAt,
    this.vintage,
    this.glass,
    this.intensity,
    this.aroma,
    this.flavor,
    this.finish,
    this.finishLength,
    this.sweetness,
    this.structure,
    this.overall,
    this.where,
    this.price,
    this.photo,
    this.descriptors = const {},
    this.notes = '',
  });

  factory TastingDraft.start({required WineId wineId, required DateTime now}) =>
      throw UnimplementedError();

  final TastingId id;
  final WineId wineId;
  final DateTime tastedAt;
  final Vintage? vintage;
  final Glass? glass;
  final Intensity? intensity;
  final Rating? aroma;
  final Rating? flavor;
  final Rating? finish;
  final FinishLength? finishLength;
  final Sweetness? sweetness;
  final Structure? structure;
  final Score? overall;
  final String? where;
  final Money? price;
  final PhotoRef? photo;
  final Set<DescriptorKey> descriptors;
  final String notes;

  // The only home of cross-field rules. Refuses with one Issue per problem:
  //   glass, intensity, aroma, flavor, finish, finishLength, sweetness, overall required;
  //   VintageYear must be 1800 to tastedAt.year;
  //   structure.tannin allowed only with RedGlass;
  //   price.minorUnits must be >= 0.
  Checked<Tasting> build() => throw UnimplementedError();
}
```

## 4. Aroma wheel

`lib/domain/aroma_wheel.dart`. Data lives in `assets/aroma_wheel.json`.

```dart
final class AromaWheel {
  const AromaWheel({required this.categories});
  final List<WheelCategory> categories;

  // Boundary parse of the bundled asset. Duplicate keys refuse.
  static Checked<AromaWheel> parse(Object? json) => throw UnimplementedError();

  bool contains(DescriptorKey key) => throw UnimplementedError();
  String labelOf(DescriptorKey key) => throw UnimplementedError(); // the raw key when unknown
}

final class WheelCategory {
  const WheelCategory({required this.label, required this.subcategories});
  final String label;
  final List<WheelSubcategory> subcategories;
}

final class WheelSubcategory {
  const WheelSubcategory({required this.label, required this.descriptors});
  final String label;
  final List<WheelDescriptor> descriptors;
}

final class WheelDescriptor {
  const WheelDescriptor({required this.key, required this.label});
  final DescriptorKey key;
  final String label;
}
```

## 5. Snapshot, filter, and wishlist

`lib/domain/journal.dart`

```dart
final class WishlistEntry {
  const WishlistEntry({required this.wineId, required this.addedAt});
  final WineId wineId;
  final DateTime addedAt;
}

// A tasting joined to its wine once, so no derived view repeats the join.
final class TastingEntry {
  const TastingEntry(this.tasting, this.wine);
  final Tasting tasting;
  final Wine wine;
}

// The only input to every derived view: feed, stats, badges.
final class JournalSnapshot {
  const JournalSnapshot({
    required this.wines,
    required this.tastings,
    required this.wishlist,
  });

  final Map<WineId, Wine> wines;
  final List<Tasting> tastings;
  final List<WishlistEntry> wishlist;

  // Ascending by tastedAt. Badges rely on this order.
  List<TastingEntry> get chronological => throw UnimplementedError();

  bool isWishlisted(WineId id) => throw UnimplementedError();
}
```

`lib/domain/journal_filter.dart`

```dart
final class JournalFilter {
  const JournalFilter({
    this.text = '',
    this.types = const {},
    this.from,
    this.to,
    this.minOverall,
    this.countries = const {},
  });

  final String text; // matches wine name, winery, grapes, region, notes
  final Set<WineType> types; // group values, so dessert covers dessert/port
  final DateTime? from;
  final DateTime? to;
  final Score? minOverall;
  final Set<CountryCode> countries;

  bool matches(TastingEntry entry) => throw UnimplementedError();
}

JournalSnapshot applyFilter(JournalSnapshot snapshot, JournalFilter filter) =>
    throw UnimplementedError();
```

## 6. Stats

`lib/domain/stats.dart`. Pure. Called on every snapshot change.

```dart
final class BreakdownRow<K> {
  const BreakdownRow({
    required this.key,
    required this.label,
    required this.tastings,
    required this.wineCount,
    required this.scoreSumTenths,
  });
  final K key;
  final String label;
  final int tastings;
  final int wineCount;
  final int scoreSumTenths;
  double get averageStars => scoreSumTenths / tastings / 10;
}

// Sorted by tasting count descending, then label. A blend counts under each grape.
final class Breakdown<K> {
  const Breakdown(this.rows);
  final List<BreakdownRow<K>> rows;
}

enum PriceBand { low, mid, high, premium, luxury }

final class MonthAverage {
  const MonthAverage({required this.month, required this.averageStars});
  final DateTime month; // first day of the month, UTC
  final double averageStars;
}

final class TopWine {
  const TopWine({required this.wine, required this.averageStars, required this.tastings});
  final Wine wine;
  final double averageStars;
  final int tastings;
}

final class JournalStats {
  const JournalStats({
    required this.tastingCount,
    required this.uniqueWineCount,
    required this.averageStars,
    required this.monthlyAverages,
    required this.byType,
    required this.byGrape,
    required this.byCountry,
    required this.byRegion,
    required this.byWinery,
    required this.byVintage,
    required this.byPriceBand,
    required this.topRated,
    required this.scoreHistogram,
    required this.sweetness,
  });

  final int tastingCount;
  final int uniqueWineCount;
  final double? averageStars; // null when the journal is empty
  final List<MonthAverage> monthlyAverages;
  final Breakdown<WineType> byType;
  final Breakdown<String> byGrape; // keyed on Grape.key
  final Breakdown<CountryCode> byCountry;
  final Breakdown<String> byRegion;
  final Breakdown<String> byWinery;
  final Breakdown<String> byVintage; // "2019" or "NV"
  final Breakdown<PriceBand> byPriceBand;
  final List<TopWine> topRated;
  final Map<int, int> scoreHistogram; // overall tenths to tasting count
  final Map<Sweetness, int> sweetness;
}

JournalStats computeStats(JournalSnapshot snapshot) => throw UnimplementedError();

Breakdown<K> breakdownBy<K>(
  Iterable<TastingEntry> entries,
  Iterable<({K key, String label})> Function(TastingEntry entry) keysOf,
) => throw UnimplementedError();
```

`lib/domain/price_bands.dart` holds the per-currency edges as data. `PriceBand? bandOf(Money money)` returns null for a currency with no table.

## 7. Badges

`lib/domain/badges.dart`. Never stored. Re-derived from the snapshot each time.

```dart
enum BadgeId {
  firstTasting,
  tastings10,
  tastings50,
  tastings100,
  grapes5,
  countries10,
  everyType,
  tenOfOneGrape,
}

// Takes a chronological prefix and returns progress. Every measure is
// non-decreasing as entries are appended, which lets earnedOn use a binary search.
typedef BadgeMeasure = int Function(List<TastingEntry> chronological);

final class BadgeRule {
  const BadgeRule({
    required this.id,
    required this.title,
    required this.target,
    required this.measure,
  });
  final BadgeId id;
  final String title;
  final int target;
  final BadgeMeasure measure;
}

final class EarnedBadge {
  const EarnedBadge({required this.rule, required this.progress, required this.earnedOn});
  final BadgeRule rule;
  final int progress;
  final DateTime? earnedOn; // tastedAt of the entry that first reached target. Null until then.
}

final List<BadgeRule> badgeRules = throw UnimplementedError();

List<EarnedBadge> deriveBadges(JournalSnapshot snapshot) => throw UnimplementedError();
```

## 8. Lookup port and adapters

`lib/domain/wine_catalog.dart`. The port is the only lookup surface the app sees.

```dart
sealed class OnlineSearch {
  const OnlineSearch();
}

final class OnlineFound extends OnlineSearch {
  const OnlineFound(this.drafts);
  final List<WineDraft> drafts;
}

final class OnlineRateLimited extends OnlineSearch {
  const OnlineRateLimited(this.retryIn);
  final Duration retryIn;
}

final class OnlineUnavailable extends OnlineSearch {
  const OnlineUnavailable(this.reason);
  final String reason;
}

abstract interface class WineCatalog {
  // Offline. Runs after a debounce as the user types. Bad input returns an empty list.
  Future<List<WineDraft>> searchIndex(String query, {int limit = 25});

  // Only from an explicit "Search online" tap.
  Future<OnlineSearch> searchOnline(String query);

  // Turns any draft, including manual, into a local Wine. A provenance key that is
  // already saved returns the existing id, so a retried adoption changes nothing.
  Future<Checked<WineId>> adopt(WineDraft draft);
}
```

Adapters, in `lib/wine_lookup/`:

```dart
// lib/wine_lookup/index_search.dart
final class IndexSearch {
  // Copies assets/wine_index.db into app support on first run, then opens it read-only.
  static Future<IndexSearch> open({required Directory supportDir}) => throw UnimplementedError();

  Future<List<WineDraft>> search(String query, {required int limit}) => throw UnimplementedError();

  // "pino noi" becomes '"pino"* AND "noi"*'. Unsafe characters are dropped.
  static String ftsExpression(String raw) => throw UnimplementedError();

  void close() => throw UnimplementedError();
}
```

The search SQL, given the fixed index schema:

```sql
SELECT w.id, w.name, w.winery, w.type, w.grapes, w.elaborate, w.abv,
       w.body, w.acidity, w.country_code, w.country, w.region
FROM wines_fts f
JOIN wines w ON w.id = f.rowid
WHERE wines_fts MATCH ?
ORDER BY bm25(wines_fts, 10.0, 6.0, 4.0, 2.0)
LIMIT ?;
```

```dart
// lib/wine_lookup/open_food_facts.dart
final class OpenFoodFactsClient {
  OpenFoodFactsClient({required this.userAgent, required this.budget});
  final String userAgent; // "Cork/<version> (<generic project contact>)"
  final RateBudget budget; // 10 searches per minute, in process

  Future<OnlineSearch> search(String query) => throw UnimplementedError();
}

final class RateBudget {
  const RateBudget({required this.capacity, required this.window});
  final int capacity;
  final Duration window;

  // Returns null when a request may go now, else how long to wait.
  Duration? tryTake(DateTime now) => throw UnimplementedError();
}
```

```dart
// lib/wine_lookup/catalog.dart
final class CatalogImpl implements WineCatalog {
  CatalogImpl({
    required IndexSearch index,
    required OpenFoodFactsClient openFoodFacts,
    required JournalRepository journal,
  });
  // Each method is a few lines that call the adapters.
}
```

## 9. Persistence

Two files, each with one owner. The bundled index is read-only and is copied, never migrated. The journal is writable and owned by `DriftJournalRepository`.

`lib/domain/journal_repository.dart` (port)

```dart
abstract interface class JournalRepository {
  Stream<JournalSnapshot> watch();

  // One transaction. Upserts the wine and the tasting. Clears the wishlist row when asked.
  Future<void> commitTasting(Wine? newWine, Tasting tasting, {required bool clearWishlist});

  Future<void> deleteTasting(TastingId id);
  Future<void> setWishlisted(WineId wineId, {required bool wishlisted});
  Future<void> saveWine(Wine wine); // upsert by id
  Future<WineId?> findByExternalKey(String key); // "index:<id>" or "off:<barcode>"

  // Import. Replaces everything in one transaction, so readers see the old journal or the new one.
  Future<void> replaceAll(JournalSnapshot next);
}
```

`lib/data/journal_database.dart`

```dart
class Wines extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get winery => text().nullable()();
  TextColumn get type => textEnum<WineType>()();
  TextColumn get elaboration => textEnum<Elaboration>().nullable()();
  TextColumn get grapes => text().map(const GrapeListConverter())(); // JSON array
  TextColumn get externalKey => text().nullable().unique()(); // NULL for manual wines
  RealColumn get abv => real().nullable()();
  TextColumn get countryCode => text().nullable()();
  TextColumn get region => text().nullable()();
  TextColumn get datasetBody => text().nullable()();
  TextColumn get datasetAcidity => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Tastings extends Table {
  TextColumn get id => text()();
  TextColumn get wineId => text().references(Wines, #id, onDelete: KeyAction.restrict)();
  IntColumn get vintageYear => integer().nullable()();
  BoolColumn get isNonVintage => boolean().withDefault(const Constant(false))();
  TextColumn get glassFamily => textEnum<GlassFamily>()();
  TextColumn get glassHue => text()(); // the enum name for that family
  TextColumn get intensity => textEnum<Intensity>()();
  IntColumn get aroma => integer()();
  IntColumn get flavor => integer()();
  IntColumn get finish => integer()();
  TextColumn get finishLength => textEnum<FinishLength>()();
  TextColumn get sweetness => textEnum<Sweetness>()();
  TextColumn get bodyLevel => textEnum<Level>().nullable()();
  TextColumn get acidityLevel => textEnum<Level>().nullable()();
  TextColumn get tanninLevel => textEnum<Level>().nullable()();
  IntColumn get overallTenths => integer()();
  IntColumn get tastedAt => integer()(); // epoch milliseconds, UTC
  TextColumn get whereText => text().nullable()();
  IntColumn get priceMinorUnits => integer().nullable()();
  TextColumn get priceCurrency => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  TextColumn get descriptors => text().map(const DescriptorListConverter())(); // JSON array
  TextColumn get notes => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class WishlistRows extends Table {
  TextColumn get wineId => text().references(Wines, #id, onDelete: KeyAction.cascade)();
  IntColumn get addedAt => integer()();

  @override
  Set<Column> get primaryKey => {wineId};
}

enum GlassFamily { white, rose, red }

@DriftDatabase(tables: [Wines, Tastings, WishlistRows])
class JournalDatabase extends _$JournalDatabase {
  JournalDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: stepByStep(
          // from1To2: (m, schema) async => ...   added per version, never edited
        ),
      );
}
```

The migration story is `schemaVersion` plus `stepByStep`. Each release runs `drift_dev schema dump`, and CI runs `drift_dev schema verify` on the upgrade path from every dumped version. Stored enum values are names. A stored value that no longer parses throws in `row_mappers.dart`, because rows are internal and a bad row is a bug.

`lib/data/drift_journal_repository.dart`, `lib/data/row_mappers.dart`, and `lib/data/photo_store.dart` complete the layer. `PhotoStore` writes `photos/<tastingId>.jpg` under app documents and returns a `PhotoRef`.

## 10. Export and import

`lib/transfer/journal_codec.dart`

```dart
const journalFormatVersion = 1;

final class JournalDocument {
  const JournalDocument({
    required this.exportedAt,
    required this.snapshot,
    required this.photos,
  });
  final DateTime exportedAt;
  final JournalSnapshot snapshot;
  final Map<PhotoRef, Uint8List> photos;
}

abstract final class JournalCodec {
  static Map<String, Object?> encode(JournalDocument document) => throw UnimplementedError();

  // Boundary. Nothing is written unless this returns Valid. Errors name the path,
  // for example "tastings[4].overall: must be 10 to 50".
  static Checked<JournalDocument> decode(Object? json) => throw UnimplementedError();
}

// Tastings only, joined to wine fields. Export only, for spreadsheets.
String tastingsCsv(JournalSnapshot snapshot) => throw UnimplementedError();
```

The JSON file, with placeholder values:

```json
{
  "format": "cork-journal",
  "formatVersion": 1,
  "exportedAt": "2026-11-15T20:00:00Z",
  "wines": [
    {
      "id": "0b7c2e1a-5f0e-4c1e-9a7e-2d4b1f6a8c01",
      "name": "Example Reserve",
      "winery": "Example Estate",
      "type": "red",
      "elaboration": "varietal",
      "grapes": ["Pinot Noir"],
      "abv": 13.5,
      "country": "FR",
      "region": "Bourgogne",
      "datasetBody": null,
      "datasetAcidity": null,
      "provenance": { "source": "index", "indexId": 48213 }
    }
  ],
  "tastings": [
    {
      "id": "7d1e9c33-2a4b-4f7e-8c55-91e0a6b2d742",
      "wineId": "0b7c2e1a-5f0e-4c1e-9a7e-2d4b1f6a8c01",
      "vintage": { "kind": "year", "year": 2019 },
      "glass": { "family": "red", "hue": "ruby" },
      "intensity": "medium",
      "palate": {
        "aroma": 4,
        "flavor": 4,
        "finish": { "rating": 3, "length": "medium" },
        "sweetness": "dry"
      },
      "structure": { "body": "medium", "acidity": "high", "tannin": "medium" },
      "overall": 42,
      "tastedAt": "2026-11-14T19:30:00Z",
      "where": "Home",
      "price": { "minorUnits": 2499, "currency": "USD" },
      "photo": { "file": "photos/7d1e9c33.jpg", "base64": "..." },
      "descriptors": ["fruit/red/cherry"],
      "notes": ""
    }
  ],
  "wishlist": [
    { "wineId": "0b7c2e1a-5f0e-4c1e-9a7e-2d4b1f6a8c01", "addedAt": "2026-11-10T08:00:00Z" }
  ]
}
```

`overall` is stored as tenths so the file never carries a float. `vintage` is `null` when not recorded, and `{"kind":"nv"}` for non-vintage. `photo` is `null` when absent.

`lib/transfer/journal_import.dart` runs `JournalCodec.decode`, then calls `JournalRepository.replaceAll`, then writes photo files. A failed decode writes nothing.

## 11. State management

Riverpod. `lib/app/providers.dart` is the composition root. Features read providers and never import `data/` or `wine_lookup/`.

```dart
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

// Overridden in main.dart with the drift-backed implementation.
final journalRepositoryProvider = Provider<JournalRepository>((ref) => throw UnimplementedError());

final wineCatalogProvider = Provider<WineCatalog>((ref) => throw UnimplementedError());

final journalSnapshotProvider = StreamProvider<JournalSnapshot>(
  (ref) => ref.watch(journalRepositoryProvider).watch(),
);

final statsProvider = Provider.family<JournalStats, JournalFilter>(
  (ref, filter) => throw UnimplementedError(), // computeStats(applyFilter(snapshot, filter))
);

final badgesProvider = Provider<List<EarnedBadge>>((ref) => throw UnimplementedError());

final tastingDraftProvider =
    NotifierProvider.autoDispose.family<TastingDraftNotifier, TastingDraft, WineId>(
  TastingDraftNotifier.new,
);

final class TastingDraftNotifier extends AutoDisposeFamilyNotifier<TastingDraft, WineId> {
  @override
  TastingDraft build(WineId wineId) => throw UnimplementedError();

  void edit(TastingDraft Function(TastingDraft draft) change) => throw UnimplementedError();

  // Runs build(), then commitTasting. The caller asks about the wishlist using
  // JournalSnapshot.isWishlisted captured before saving.
  Future<Checked<TastingId>> save() => throw UnimplementedError();
}
```

## 12. Module map

```
lib/
  main.dart                      runApp in ProviderScope, opens journal and index, overrides repository
  app/
    app.dart                     MaterialApp, theme, router
    providers.dart               Riverpod graph, the only file that names concrete adapters
  domain/                        pure Dart, no I/O
    scalars.dart                 extension-type ids, Score, Rating, Money, Checked, Issue
    wine.dart                    Wine, WineDraft, WineType, Elaboration, Provenance
    tasting.dart                 Tasting, TastingDraft, Glass, Vintage, Appearance, Palate, Structure
    aroma_wheel.dart             AromaWheel parse and lookup
    price_bands.dart             PriceBand and the per-currency edges
    journal.dart                 JournalSnapshot, TastingEntry, WishlistEntry
    journal_filter.dart          JournalFilter, applyFilter
    journal_repository.dart      JournalRepository port
    wine_catalog.dart            WineCatalog port, OnlineSearch
    stats.dart                   computeStats, Breakdown, JournalStats
    badges.dart                  badge rules, deriveBadges
  wine_lookup/                   adapters behind WineCatalog
    catalog.dart                 CatalogImpl, the composition of the three sources
    index_search.dart            index copy, read-only sqlite3, FTS query, row parse
    open_food_facts.dart         HTTP, User-Agent, RateBudget, JSON to WineDraft
  data/                          drift persistence
    journal_database.dart        tables, schemaVersion, migrations
    drift_journal_repository.dart  JournalRepository, the only writer to the journal file
    row_mappers.dart             row to domain and back
    photo_store.dart             label photos in app documents
  transfer/
    journal_codec.dart           JournalDocument to JSON and back, versioned, boundary parse
    journal_import.dart          decode, then replaceAll, then photos
    journal_csv.dart            tastings CSV
  features/
    history/                     feed, search, filter UI
    tasting_editor/              check-in form, aroma wheel picker, swatch picker
    wine_search/                 search field, Search online action, add-wine form
    wishlist/                    wishlist list
    stats/                       charts and breakdown screens (fl_chart)
    badges/                      badge grid
    settings/                    export and import
  design/                        shared widgets: glass swatch, intensity picker, rating row
assets/
  wine_index.db                  given, read-only
  aroma_wheel.json               aroma wheel data
test/
  domain/                        build(), computeStats, deriveBadges, codec round trips
  data/                          drift in-memory tests, schema verify
  architecture_test.dart         domain import allow-list, features do not import data or wine_lookup
```

Call chain for saving a check-in, which crosses the fewest files the feature needs: `features/tasting_editor` calls `tastingDraftProvider` notifier `save()` in `app/providers.dart`, which calls `TastingDraft.build()` in `domain/tasting.dart`, then `JournalRepository.commitTasting` implemented in `data/drift_journal_repository.dart`.

Dependencies: `flutter_riverpod`, `drift`, `drift_flutter`, `sqlite3`, `sqlite3_flutter_libs` (bundles SQLite with FTS5 enabled), `freezed_annotation`, `http`, `path_provider`, `image_picker`, `fl_chart`. Dev: `build_runner`, `drift_dev`, `freezed`. Versions are pinned when added.
