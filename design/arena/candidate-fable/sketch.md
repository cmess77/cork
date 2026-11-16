# Cork candidate "fable": the journal is one immutable value

Thesis in four lines.

1. The whole journal is one immutable in-memory value, `Journal`. A lifetime of tastings is tens of thousands of rows at most, so it fits in memory with room to spare.
2. Every read (feed, filters, stats, badges, export) is a pure function of `Journal`. Every write is a list of idempotent `JournalChange`s committed synchronously by one writer.
3. SQLite stores each wine, tasting, and wishlist item as one JSON document row. The row codec is the export codec, so there is one schema-migration ladder, not two.
4. A lookup result is already a `Wine`. Its `WineId` is derived from its provenance, so "adopt this search hit" is a plain upsert with no dedup query.

## 1. Usage (written first, the types below are derived from it)

### Quickstart

```dart
// main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dirs = await AppDirs.resolve();                 // path_provider, once
  final store = JournalStore.open(dirs.journalDb);      // sync: open, migrate, load
  final lookup = await BundledWineLookup.open(dirs, journal: () => store.journal);
  runApp(ProviderScope(
    overrides: [
      journalStoreProvider.overrideWithValue(store),
      wineLookupProvider.overrideWithValue(lookup),
    ],
    child: const CorkApp(),
  ));
}
```

The journal is loaded before the first frame, so no screen handles a "journal loading" state.

### Call site A: check in a wine (search, pick, save, badge toast, wishlist offer)

```dart
// ui/checkin/wine_search_field.dart   (as you type: offline only)
onChanged: (text) async {
  final hits = await ref.read(wineLookupProvider).suggest(text);   // List<Wine>
  setState(() => _hits = hits);   // journal wines first, then the bundled index
},

// "Search online" button: explicit tap only
onPressed: () async {
  switch (await ref.read(wineLookupProvider).searchOnline(_text)) {
    case OnlineHits(:final wines):          setState(() => _hits = wines);
    case OnlineRateLimited(:final retryIn): _showCooldown(retryIn);
    case OnlineUnavailable():               _showOfflineHint();
  }
},

// "Can't find it? Add by hand" produces the same type
final wine = Wine.manual(id: WineId.mintManual(), name: 'Nonna\'s Rosso', type: WineType.red);

// ui/checkin/checkin_screen.dart   (wine came from any of the three paths above)
var draft = TastingDraft.forWine(wine, now: DateTime.now());
draft = draft.copyWith(
  score: Score.fromTenths(42),
  color: const GlassColor(Hue.ruby, Intensity.deep),
  descriptors: {...draft.descriptors, const DescriptorId('fruit.black.blackberry')},
);

void onSave() {
  final tasting = draft.build(TastingId.mint());      // null while score is unset
  if (tasting == null) return;
  final store = ref.read(journalStoreProvider);
  final before = store.journal;
  final after = store.commit([SaveWine(wine), SaveTasting(tasting)]);   // one transaction

  for (final badge in newlyEarned(before, after)) _celebrate(badge);    // pure diff
  if (after.wishlist.containsKey(wine.id)) _offerUnwishlist(wine.id);   // commits [Unwishlist(id)]
}
```

Editing is the same `SaveTasting` with the same id. Deleting is `DeleteTasting(id)`. Badges and stats follow because nothing derived is stored.

### Call site B: stats screen, with drill-down into the feed

```dart
// ui/stats/stats_screen.dart
final stats = ref.watch(statsProvider);                 // JournalStats
Text('${stats.overall.count} tastings, ${stats.uniqueWines} wines, '
     'avg ${stats.overall.mean.toStringAsFixed(2)}');
RatingOverTimeChart(stats.overTime);
for (final g in stats.by[Dimension.grape]!)
  ListTile(
    title: Text(g.key),
    trailing: Text('${g.tally.count} · ${g.tally.mean.toStringAsFixed(1)}'),
    onTap: () => openFeed(FeedFilter(facets: {Dimension.grape: {g.key}})),
  );

// ui/feed/feed_screen.dart
final entries = ref.watch(feedProvider(filter));        // List<Entry>, newest first
final scoped = computeStats(entries);                   // stats for any filtered slice, same function

// ui/badges/badges_screen.dart
for (final b in ref.watch(badgesProvider))              // List<BadgeStatus>
  BadgeTile(b.rule.title, progress: b.progress, target: b.rule.target, earnedAt: b.earnedAt);
```

### Call site C: backup

```dart
// ui/settings/backup_screen.dart
final file = await ref.read(backupProvider).exportJson(includePhotos: true);
await Share.shareXFiles([XFile(file.path)]);

switch (ref.read(backupProvider).preview(await picked.readAsString())) {
  case ImportReady(:final incoming):
    final ok = await _confirm('Replace your journal with ${incoming.journal.tastings.length} tastings?');
    if (ok) await ref.read(backupProvider).restore(incoming);   // writes a safety export first
  case ImportRejected(:final reason):
    _showError(reason);                                 // NotACorkFile | NewerVersion | Malformed
}
```

## 2. Module map

```
lib/
  main.dart                  composition: open store + lookup, runApp
  app/
    cork_app.dart            MaterialApp, routes, theme
    providers.dart           every Riverpod provider. The only file that names concrete classes.
    app_dirs.dart            AppDirs: journal db path, index dir, photos dir, exports dir
  domain/                    pure Dart. Imports nothing outside dart:core, dart:math, dart:collection.
    ids.dart                 WineId, TastingId, DescriptorId, PhotoRef, CurrencyCode
    wine.dart                Wine, WineType, Provenance, Country
    glass_color.dart         Hue, ColorFamily, Intensity, GlassColor
    tasting.dart             Tasting, TastingDraft, Vintage, Stars, Score, Sweetness, Level, FinishLength, Money
    aroma_wheel.dart         AromaWheel, AromaCategory, AromaSubcategory, Descriptor
    aroma_wheel_data.dart    const aromaWheel = AromaWheel([...])   (the data)
    journal.dart             Journal, Entry, WishlistItem, JournalChange, Journal.apply
    dimension.dart           Dimension (one registry for stats breakdowns, feed facets, badge rules)
    feed.dart                FeedFilter, filterFeed
    stats.dart               JournalStats, Tally, GroupStat, computeStats
    badges.dart              BadgeRule, badgeRules, BadgeStatus, deriveBadges, newlyEarned
  data/
    journal_codec.dart       JSON <-> domain, plus the document version ladder. Pure. Used by db AND backup.
    journal_db.dart          sqlite3: open, load, write changes. Private to journal_store.
    journal_store.dart       JournalStore: the single writer. Holds the current Journal.
    photos.dart              PhotoStore: content-addressed label photos
    backup.dart              Backup: JSON export/import, CSV export
  lookup/
    wine_lookup.dart         WineLookup (interface), OnlineResult, BundledWineLookup
    wine_index.dart          bundled FTS5 db. Private to lookup.
    open_food_facts.dart     HTTP, parse, rate limiter. Private to lookup.
  ui/
    feed/  checkin/  wine/  wishlist/  stats/  badges/  settings/
```

Import rules, enforced by `test/architecture_test.dart` (a grep over import lines):

- `domain/` imports nothing from `data/`, `lookup/`, `ui/`, `package:flutter`, or `package:sqlite3`.
- `ui/` imports `domain/`, `app/providers.dart`, and the three facades `journal_store.dart`, `wine_lookup.dart`, `backup.dart`. Never `journal_db.dart`, `wine_index.dart`, or `open_food_facts.dart`.
- `sqlite3` is imported only by `journal_db.dart` and `wine_index.dart`. `http` only by `open_food_facts.dart`.

Dependencies: `sqlite3`, `flutter_riverpod`, `path_provider`, `http`, `image_picker`, `share_plus`, `crypto`, plus a chart package chosen at the stats screen. No code generation.

## 3. Domain types

### ids.dart

```dart
/// Derived from provenance, so the same real-world wine gets the same id on
/// every device and every adoption. 'xw:112233', 'off:3760123456789', 'm:<uuid>'.
extension type const WineId(String value) {
  factory WineId.forIndex(int xWinesId) => throw UnimplementedError();
  factory WineId.forBarcode(String offCode) => throw UnimplementedError();
  factory WineId.mintManual() => throw UnimplementedError();   // random, dart:math Random.secure
}

extension type const TastingId(String value) {
  factory TastingId.mint() => throw UnimplementedError();      // random 128-bit hex
}

/// Stable slug into the aroma wheel: 'fruit.citrus.lemon'. Append-only vocabulary.
extension type const DescriptorId(String value) {}

/// '<sha256 hex>.jpg'. A file name inside the photos dir, never an absolute path.
extension type const PhotoRef(String fileName) {}

/// ISO 4217, upper case. Validated at the form and codec boundaries.
extension type const CurrencyCode(String code) {}
```

### wine.dart

```dart
/// Matches the bundled index's `type` column one to one.
enum WineType { red, white, rose, sparkling, dessert, fortified }   // 'Dessert/Port' -> fortified

sealed class Provenance {
  const Provenance();
}
final class FromIndex extends Provenance {
  const FromIndex(this.xWinesId);
  final int xWinesId;
}
final class FromOpenFoodFacts extends Provenance {
  const FromOpenFoodFacts(this.barcode);
  final String barcode;
}
final class EnteredByHand extends Provenance {
  const EnteredByHand();
}

final class Country {
  const Country(this.code, this.name);
  final String code;   // ISO 3166-1 alpha-2, as the index gives it
  final String name;
}

/// A label, not a bottle. Vintage lives on Tasting and WishlistItem, because the
/// index is vintage-agnostic and "unique wines" must not split by year.
///
/// Invariant: id == WineId derived from provenance (random for EnteredByHand).
/// Lookup results are Wines that are simply not in the journal yet.
final class Wine {
  const Wine({
    required this.id,
    required this.name,
    required this.provenance,
    this.winery,
    this.type,
    this.grapes = const [],
    this.region,
    this.country,
    this.abv,
    this.typicalBody,
    this.typicalAcidity,
  });

  factory Wine.manual({
    required WineId id,
    required String name,
    required WineType type,
    String? winery,
    List<String> grapes,
    String? region,
    Country? country,
  }) => throw UnimplementedError();

  final WineId id;
  final String name;
  final Provenance provenance;
  final String? winery;
  /// Null only for Open Food Facts hits whose category does not say. The wine
  /// form asks for it. Stats put null under "Unspecified". Badges ignore it.
  final WineType? type;
  final List<String> grapes;
  final String? region;
  final Country? country;
  final double? abv;
  /// Index hints. Prefill the collapsed structure fields of a new tasting.
  final Level? typicalBody;
  final Level? typicalAcidity;

  Wine copyWith({String? name, String? winery, WineType? type, List<String>? grapes,
      String? region, Country? country}) => throw UnimplementedError();
}
```

### glass_color.dart

```dart
enum ColorFamily { white, rose, red }
enum Intensity { pale, medium, deep }

/// One flat scale. A hue owns its family, so "ruby white" cannot be written.
/// `argb` is the swatch at medium intensity. The enum name is the wire name.
enum Hue {
  waterWhite(ColorFamily.white, 0xFFF7F7EC),
  greenYellow(ColorFamily.white, 0xFFE9EDB5),
  lemon(ColorFamily.white, 0xFFF1E78C),
  straw(ColorFamily.white, 0xFFE8D36B),
  gold(ColorFamily.white, 0xFFE0B842),
  deepGold(ColorFamily.white, 0xFFCF9A2B),
  amber(ColorFamily.white, 0xFFB8741F),
  brownWhite(ColorFamily.white, 0xFF7A4A1E),
  palePink(ColorFamily.rose, 0xFFF6CFC9),
  salmon(ColorFamily.rose, 0xFFF4A68C),
  onionSkin(ColorFamily.rose, 0xFFD9946A),
  deepPink(ColorFamily.rose, 0xFFE0607E),
  purple(ColorFamily.red, 0xFF5B1647),
  ruby(ColorFamily.red, 0xFF8E1B2E),
  garnet(ColorFamily.red, 0xFF7B2A1E),
  tawny(ColorFamily.red, 0xFF9A5A2C),
  brownRed(ColorFamily.red, 0xFF5E3A22);

  const Hue(this.family, this.argb);
  final ColorFamily family;
  final int argb;

  static List<Hue> of(ColorFamily f) => throw UnimplementedError();
}

final class GlassColor {
  const GlassColor(this.hue, this.intensity);
  final Hue hue;
  final Intensity intensity;
  /// Swatch for the picker and the feed tile: hue shifted by intensity.
  int get argb => throw UnimplementedError();
}
```

### tasting.dart

```dart
/// 1..5. The only constructor checks the range.
extension type const Stars._(int value) {
  factory Stars(int value) => throw UnimplementedError();          // throws RangeError outside 1..5
}

/// Overall score in tenths, 10..50. Integer so 0.1 steps are exact and groupable.
extension type const Score._(int tenths) {
  factory Score.fromTenths(int tenths) => throw UnimplementedError();
  static Score? tryParse(num value) => throw UnimplementedError(); // 4.2 -> 42, null if out of range
  double get value => tenths / 10;
}

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
// `Vintage?` null means "not recorded".

enum Sweetness { boneDry, dry, offDry, mediumSweet, sweet, luscious }
enum FinishLength { short, medium, long }
/// WSET five-point scale for body, acidity, tannin.
enum Level { low, mediumMinus, medium, mediumPlus, high }

/// Hundredths of the currency's major unit for every currency. No FX, ever.
final class Money {
  const Money(this.hundredths, this.currency);
  final int hundredths;
  final CurrencyCode currency;
}

/// A saved check-in. Only wine, date, and score are required, so a check-in
/// can be three taps. Everything else is detail the user may add.
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
  final DateTime tastedAt;          // UTC instant
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
  final Level? tannin;              // the form shows it for reds; the type does not forbid it elsewhere
  final Set<DescriptorId> descriptors;
  final String notes;
  final String? place;
  final Money? price;
  final PhotoRef? photo;

  TastingDraft toDraft() => throw UnimplementedError();   // edit flow
}

/// Form state. Same fields as Tasting with `score` nullable and no id.
final class TastingDraft {
  factory TastingDraft.forWine(Wine wine, {required DateTime now}) =>
      throw UnimplementedError();   // prefills date, body and acidity hints
  TastingDraft copyWith({/* every field */ Score? score, GlassColor? color,
      Set<DescriptorId>? descriptors}) => throw UnimplementedError();
  Score? get score => throw UnimplementedError();
  Set<DescriptorId> get descriptors => throw UnimplementedError();

  /// The one gate from form to journal. Null while the score is missing.
  Tasting? build(TastingId id) => throw UnimplementedError();
}
```

### aroma_wheel.dart and aroma_wheel_data.dart

```dart
final class Descriptor {
  const Descriptor(this.id, this.label);
  final DescriptorId id;
  final String label;
}
final class AromaSubcategory {
  const AromaSubcategory(this.label, this.descriptors);
  final String label;
  final List<Descriptor> descriptors;
}
final class AromaCategory {
  const AromaCategory(this.label, this.argb, this.subcategories);
  final String label;
  final int argb;                    // wheel segment color
  final List<AromaSubcategory> subcategories;
}

final class AromaWheel {
  const AromaWheel(this.categories);
  final List<AromaCategory> categories;

  /// Total. An id this build does not know (imported from a newer Cork, or a
  /// retired descriptor) still renders, labelled from its last slug segment.
  Descriptor resolve(DescriptorId id) => throw UnimplementedError();
  AromaCategory? categoryOf(DescriptorId id) => throw UnimplementedError();
}

// aroma_wheel_data.dart
const aromaWheel = AromaWheel([
  AromaCategory('Fruit', 0xFFB03A48, [
    AromaSubcategory('Citrus', [
      Descriptor(DescriptorId('fruit.citrus.lemon'), 'Lemon'),
      Descriptor(DescriptorId('fruit.citrus.grapefruit'), 'Grapefruit'),
    ]),
    AromaSubcategory('Black fruit', [
      Descriptor(DescriptorId('fruit.black.blackberry'), 'Blackberry'),
    ]),
  ]),
  // Floral, Spice, Earth, Oak, Herbal, Microbial, ...
]);
// test: ids unique, and test/golden/descriptor_ids.txt only ever grows.
```

### journal.dart

```dart
final class WishlistItem {
  const WishlistItem({required this.wineId, required this.addedAt, this.vintage, this.note = ''});
  final WineId wineId;
  final DateTime addedAt;
  final Vintage? vintage;
  final String note;
}

/// A tasting joined to its wine. What every derivation iterates.
typedef Entry = ({Tasting tasting, Wine wine});

/// The whole journal as one immutable value. The single source of truth in
/// memory. Everything else on this class is a view derived from these three maps.
///
/// Invariant: every Tasting.wineId and every wishlist key is a key of `wines`.
final class Journal {
  const Journal.raw(this.wines, this.tastings, this.wishlist);
  static const empty = Journal.raw({}, {}, {});

  final Map<WineId, Wine> wines;               // by id: resolve a tasting's wine, detect "already mine"
  final Map<TastingId, Tasting> tastings;      // by id: edit and delete
  final Map<WineId, WishlistItem> wishlist;    // at most one entry per wine

  /// Newest first. Built once per Journal value (late final), never maintained.
  List<Entry> get feed => throw UnimplementedError();
  /// Wine detail page and "tasted 3x" chips. Built once, lazily.
  List<Tasting> tastingsOf(WineId id) => throw UnimplementedError();
  /// Wines with at least one tasting or a wishlist entry. Search suggestions.
  Iterable<Wine> get myWines => throw UnimplementedError();

  /// Pure reducer. Each change is an upsert or a delete by id, so applying a
  /// change twice equals applying it once. Throws StateError if a SaveTasting
  /// or Wishlist names a wine that is absent (a programming error, not user input).
  Journal apply(Iterable<JournalChange> changes) => throw UnimplementedError();
}

sealed class JournalChange {
  const JournalChange();
}
final class SaveWine extends JournalChange {        // adopt a lookup hit, or edit a wine
  const SaveWine(this.wine);
  final Wine wine;
}
final class SaveTasting extends JournalChange {     // create and edit
  const SaveTasting(this.tasting);
  final Tasting tasting;
}
final class DeleteTasting extends JournalChange {
  const DeleteTasting(this.id);
  final TastingId id;
}
final class Wishlist extends JournalChange {
  const Wishlist(this.item);
  final WishlistItem item;
}
final class Unwishlist extends JournalChange {
  const Unwishlist(this.wineId);
  final WineId wineId;
}
```

Access patterns traced through the structure:

| Pattern | Path |
|---|---|
| Feed, newest first | `journal.feed` (sorted once per value) |
| Open a tasting to edit | `journal.tastings[id]` |
| Wine detail, repeat tastings | `journal.tastingsOf(wineId)` |
| "Is this search hit already mine?" | `journal.wines.containsKey(hit.id)` (id derives from provenance) |
| Is it wishlisted? | `journal.wishlist.containsKey(wineId)` |
| Stats, badges, filters | one pass over `journal.feed` |
| Export | the three maps, as they are |

## 4. Derivations (pure functions)

### dimension.dart

```dart
/// The ways a tasting can be grouped. One registry drives stats breakdowns,
/// feed facets, and badge rules. Adding a breakdown is adding a value here.
enum Dimension {
  type, grape, country, region, winery, vintage, priceBand;

  /// Zero, one, or many keys. A blend counts once under each of its grapes.
  /// priceBand keys carry the currency ('AUD 20-35'), so currencies never mix.
  Iterable<String> keysOf(Entry e) => throw UnimplementedError();
}
```

### feed.dart

```dart
final class FeedFilter {
  const FeedFilter({this.text = '', this.facets = const {}, this.from, this.to, this.minScore});
  final String text;                          // wine, winery, notes, place, descriptor labels
  final Map<Dimension, Set<String>> facets;   // AND across dimensions, OR within one
  final DateTime? from;
  final DateTime? to;
  final Score? minScore;
}

List<Entry> filterFeed(Journal journal, FeedFilter filter) => throw UnimplementedError();
```

### stats.dart

```dart
final class Tally {
  const Tally(this.count, this.mean);
  final int count;
  final double mean;                 // mean overall score, 0 when count is 0
}
final class GroupStat {
  const GroupStat(this.key, this.tally, this.uniqueWines);
  final String key;
  final Tally tally;
  final int uniqueWines;
}

final class JournalStats {
  const JournalStats({
    required this.overall,
    required this.uniqueWines,
    required this.overTime,
    required this.by,
    required this.topWines,
    required this.scoreDistribution,
    required this.sweetnessDistribution,
  });
  final Tally overall;
  final int uniqueWines;
  final List<({DateTime month, Tally tally})> overTime;      // chart series, oldest first
  final Map<Dimension, List<GroupStat>> by;                  // every Dimension, sorted by count
  final List<({Wine wine, Tally tally})> topWines;           // by mean, ties by count
  final Map<Score, int> scoreDistribution;                   // half-point bins
  final Map<Sweetness, int> sweetnessDistribution;
}

/// Takes entries, not a Journal, so the same function serves the whole journal
/// and any filtered slice ("my 2026", "just Syrah").
JournalStats computeStats(Iterable<Entry> entries) => throw UnimplementedError();
```

### badges.dart

```dart
/// Rules are data. No badge is ever written to disk.
sealed class BadgeRule {
  const BadgeRule(this.id, this.title, this.target);
  final String id;
  final String title;
  final int target;
}
final class TastingCount extends BadgeRule {        // first, 10, 50, 100 tastings
  const TastingCount(super.id, super.title, super.target);
}
final class DistinctKeys extends BadgeRule {        // 5 grapes, 10 countries
  const DistinctKeys(super.id, super.title, super.target, this.dimension);
  final Dimension dimension;
}
final class SameKey extends BadgeRule {             // 10 of a single grape
  const SameKey(super.id, super.title, super.target, this.dimension);
  final Dimension dimension;
}
final class EveryType extends BadgeRule {           // a tasting of every WineType
  const EveryType(String id, String title) : super(id, title, 6);
}

const badgeRules = <BadgeRule>[
  TastingCount('first', 'First pour', 1),
  TastingCount('t10', 'Ten down', 10),
  TastingCount('t50', 'Fifty', 50),
  TastingCount('t100', 'Century', 100),
  DistinctKeys('g5', 'Five grapes', 5, Dimension.grape),
  DistinctKeys('c10', 'Ten countries', 10, Dimension.country),
  SameKey('g10', 'Devotee', 10, Dimension.grape),
  EveryType('types', 'Full flight'),
];

final class BadgeStatus {
  const BadgeStatus(this.rule, this.progress, this.earnedAt);
  final BadgeRule rule;
  final int progress;               // clamped to rule.target
  final DateTime? earnedAt;         // tastedAt of the tasting that crossed the line. Derived.
}

/// One chronological pass with running counters per rule.
List<BadgeStatus> deriveBadges(Iterable<Entry> entries) => throw UnimplementedError();

/// Rules earned in `after` and not in `before`. Drives the celebration after a
/// save with no stored "already shown" flag.
List<BadgeRule> newlyEarned(Journal before, Journal after) => throw UnimplementedError();
```

## 5. Persistence

### Choice: `package:sqlite3` directly, document rows, synchronous single writer

```sql
-- journal.db, PRAGMA journal_mode=WAL, foreign_keys=ON, user_version=1
CREATE TABLE meta     (key TEXT PRIMARY KEY, value TEXT NOT NULL);   -- 'doc_version' -> '1'
CREATE TABLE wines    (id TEXT PRIMARY KEY, doc TEXT NOT NULL);
CREATE TABLE tastings (id TEXT PRIMARY KEY,
                       wine_id TEXT NOT NULL REFERENCES wines(id),
                       doc TEXT NOT NULL);
CREATE TABLE wishlist (wine_id TEXT PRIMARY KEY REFERENCES wines(id), doc TEXT NOT NULL);
```

`doc` is exactly the JSON object that the export file holds for that record.

```dart
// data/journal_codec.dart   (pure)
const currentDocVersion = 1;

final class JournalCodec {
  static Map<String, Object?> encodeWine(Wine w) => throw UnimplementedError();
  static Map<String, Object?> encodeTasting(Tasting t) => throw UnimplementedError();
  static Map<String, Object?> encodeWishlistItem(WishlistItem i) => throw UnimplementedError();

  /// Parse, do not validate: every enum name, range, and reference is checked
  /// here and nowhere else. Callers get a Journal or a reason.
  static Decoded decode({
    required int docVersion,
    required Iterable<Object?> wines,
    required Iterable<Object?> tastings,
    required Iterable<Object?> wishlist,
  }) => throw UnimplementedError();
  // TODO: run raw maps through _upgraders[docVersion..current] first, then parse.
}

sealed class Decoded {}
final class DecodedJournal extends Decoded {
  DecodedJournal(this.journal);
  final Journal journal;
}
final class DecodeFailure extends Decoded {
  DecodeFailure(this.path, this.message);     // 'tastings[14].score', 'expected 1.0..5.0, got 7'
  final String path;
  final String message;
}

/// The migration ladder. One pure function per version step, raw JSON in, raw JSON out.
/// Serves stored rows and imported files alike.
typedef DocUpgrade = ({
  List<Map<String, Object?>> wines,
  List<Map<String, Object?>> tastings,
  List<Map<String, Object?>> wishlist,
}) Function(({
  List<Map<String, Object?>> wines,
  List<Map<String, Object?>> tastings,
  List<Map<String, Object?>> wishlist,
}) docs);
const List<DocUpgrade> _upgraders = [/* index i upgrades version i+1 to i+2 */];
```

```dart
// data/journal_store.dart
/// The only writer of journal.db and the only holder of the current Journal.
/// A Listenable so Riverpod (or any widget) can observe it.
final class JournalStore extends ChangeNotifier {
  /// Synchronous. Creates the schema, upgrades stored docs if doc_version is
  /// behind (all rows rewritten in one transaction), then loads everything.
  static JournalStore open(String dbPath) => throw UnimplementedError();

  Journal get journal => throw UnimplementedError();

  /// Applies the changes to the current value, writes the touched rows in one
  /// SQL transaction, then swaps the in-memory value and notifies.
  /// Synchronous on purpose: two commits cannot interleave.
  /// Crash before COMMIT: nothing happened. Crash after: next launch loads it.
  Journal commit(List<JournalChange> changes) => throw UnimplementedError();

  /// Import. Deletes every row and inserts `next` in one transaction.
  void replaceAll(Journal next) => throw UnimplementedError();
}
```

```dart
// data/photos.dart
final class PhotoStore {
  /// Downscales to a 1600 px long edge JPEG, hashes it, writes temp then renames
  /// to '<sha256>.jpg'. Same image twice yields the same ref and one file.
  Future<PhotoRef> add(Uint8List pickedBytes) => throw UnimplementedError();
  File fileFor(PhotoRef ref) => throw UnimplementedError();
  /// Deletes files no tasting references. Run at launch, before any draft exists.
  Future<void> sweep(Journal journal) => throw UnimplementedError();
}
```

### Migration story

- **Record shape changes** (new field, renamed enum value, split field): add one `DocUpgrade`, bump `currentDocVersion`. Stored rows upgrade at next open. Old backup files upgrade at import. One ladder, tested with plain JSON fixtures in `test/fixtures/journal_v<N>.json`, no database needed.
- **Table shape changes** (rare, since tables are id plus doc): `PRAGMA user_version` with an ordered list of SQL scripts, each in a transaction.
- **If a column is ever needed for SQL** (say the journal outgrows memory): add `GENERATED ALWAYS AS (json_extract(doc, '$.tastedAt'))` plus an index. The codec does not change.
- **Wire names**: enum `.name` values are the wire format. `test/golden/wire_names.txt` snapshots every enum name, so a rename fails a test until an upgrader exists.

## 6. Wine lookup

```dart
// lookup/wine_lookup.dart
/// Finds wines. Hides the bundled index, Open Food Facts, the journal's own
/// wines, FTS syntax, HTTP, rate limiting, and asset installation.
/// Results are domain `Wine`s whose ids derive from provenance.
abstract interface class WineLookup {
  /// As-you-type. Never touches the network. Never throws on any input string.
  /// Order: wines already in the journal (most recently tasted first), then
  /// index hits by relevance. An index hit already in the journal appears once,
  /// as the journal's copy. Under two characters returns only journal wines.
  Future<List<Wine>> suggest(String text, {int limit = 20});

  /// Explicit user tap only. Enforces Open Food Facts' 10 per minute budget
  /// internally, so no caller can breach it.
  Future<OnlineResult> searchOnline(String text);
}

sealed class OnlineResult {
  const OnlineResult();
}
final class OnlineHits extends OnlineResult {
  const OnlineHits(this.wines);
  final List<Wine> wines;             // FromOpenFoodFacts provenance, type may be null
}
final class OnlineRateLimited extends OnlineResult {
  const OnlineRateLimited(this.retryIn);
  final Duration retryIn;
}
final class OnlineUnavailable extends OnlineResult {   // no network, timeout, 5xx, bad payload
  const OnlineUnavailable();
}

final class BundledWineLookup implements WineLookup {
  static Future<BundledWineLookup> open(AppDirs dirs, {required Journal Function() journal}) =>
      throw UnimplementedError();
  @override
  Future<List<Wine>> suggest(String text, {int limit = 20}) => throw UnimplementedError();
  @override
  Future<OnlineResult> searchOnline(String text) => throw UnimplementedError();
}
```

```dart
// lookup/wine_index.dart   (private to lookup/)
final class WineIndex {
  /// SQLite cannot open a file inside the APK. Copies assets/wine_index.db to
  /// '<indexDir>/wine_index.<assetVersion>.db' via temp file and rename, skips
  /// the copy when that file exists, deletes other versions, opens read-only.
  static Future<WineIndex> install(String indexDir) => throw UnimplementedError();

  List<Wine> search(FtsQuery query, int limit) => throw UnimplementedError();
  // SELECT w.* FROM wines_fts f JOIN wines w ON w.id = f.rowid
  //  WHERE wines_fts MATCH ?1
  //  ORDER BY bm25(wines_fts, 10.0, 6.0, 3.0, 2.0)   -- name, winery, grapes, region
  //  LIMIT ?2
  // Row -> Wine: id -> WineId.forIndex + FromIndex, grapes JSON -> List<String>,
  // type text -> WineType, body/acidity text -> Level.
}

/// User text made safe for MATCH. 'chât marg' -> '"chât"* "marg"*'.
extension type const FtsQuery._(String match) {
  /// Null when no token has two or more characters (the index has prefix='2 3').
  static FtsQuery? parse(String userText) => throw UnimplementedError();
}
```

```dart
// lookup/open_food_facts.dart   (private to lookup/)
final class OpenFoodFacts {
  OpenFoodFacts({required String appVersion, http.Client? client});
  static const contact = 'TODO generic project address';   // never personal data
  // User-Agent: 'Cork/$appVersion ($contact)'

  /// Sliding window of 8 calls per 60 s (two under the documented 10).
  Future<OnlineResult> search(String text) => throw UnimplementedError();
  // TODO: GET search with category wines, fields=code,product_name,brands,categories_tags,
  //       countries_tags,origins. Parse each product into Wine at this boundary:
  //       product_name -> name, brands -> winery, categories_tags -> WineType?,
  //       code -> FromOpenFoodFacts + WineId.forBarcode. Drop products with no name.
}
```

Manual entry needs no lookup method. The wine form builds a `Wine` with `Wine.manual`, and the same form opens prefilled when an online hit has `type == null`.

## 7. State management: Riverpod, hand-written providers, one file

```dart
// app/providers.dart
final journalStoreProvider = Provider<JournalStore>((_) => throw UnimplementedError()); // overridden in main
final wineLookupProvider   = Provider<WineLookup>((_) => throw UnimplementedError());   // overridden in main
final photoStoreProvider   = Provider<PhotoStore>((ref) => throw UnimplementedError());
final backupProvider       = Provider<Backup>((ref) => throw UnimplementedError());

/// The current journal value. Rebuilds when the store commits.
final journalProvider = Provider<Journal>((ref) {
  final store = ref.watch(journalStoreProvider);
  store.addListener(ref.invalidateSelf);
  ref.onDispose(() => store.removeListener(ref.invalidateSelf));
  return store.journal;
});

final statsProvider  = Provider<JournalStats>((ref) => computeStats(ref.watch(journalProvider).feed));
final badgesProvider = Provider<List<BadgeStatus>>((ref) => deriveBadges(ref.watch(journalProvider).feed));
final feedProvider   = Provider.family<List<Entry>, FeedFilter>(
    (ref, filter) => filterFeed(ref.watch(journalProvider), filter));   // FeedFilter needs ==/hashCode
```

Screen-local form state (`TastingDraft`, search text, hits) stays in `StatefulWidget`s. Riverpod holds only app-wide state.

## 8. Backup

```dart
// data/backup.dart
final class Backup {
  Backup(JournalStore store, PhotoStore photos, AppDirs dirs);

  Future<File> exportJson({required bool includePhotos}) => throw UnimplementedError();
  Future<File> exportCsv() => throw UnimplementedError();     // one row per tasting, wine columns flattened

  /// Pure parse of a picked file. Touches nothing.
  ImportPreview preview(String fileText) => throw UnimplementedError();

  /// 1. Writes exports/pre-import-<timestamp>.json of the current journal.
  /// 2. Stores incoming photos (content-addressed, so re-running is harmless).
  /// 3. store.replaceAll(incoming.journal).
  Future<void> restore(Incoming incoming) => throw UnimplementedError();
}

sealed class ImportPreview {}
final class ImportReady extends ImportPreview {
  ImportReady(this.incoming);
  final Incoming incoming;
}
final class ImportRejected extends ImportPreview {
  ImportRejected(this.reason);
  final ImportProblem reason;
}
final class Incoming {
  Incoming(this.journal, this.photos);
  final Journal journal;
  final Map<PhotoRef, Uint8List> photos;
}
sealed class ImportProblem {}
final class NotACorkFile extends ImportProblem {}
final class NewerVersion extends ImportProblem {
  NewerVersion(this.version);
  final int version;
}
final class Malformed extends ImportProblem {
  Malformed(this.path, this.message);
  final String path;
  final String message;
}
```

### Export file shape (version 1)

```json
{
  "format": "cork.journal",
  "version": 1,
  "exportedAt": "2026-11-15T07:04:11Z",
  "appVersion": "0.1.0",
  "wines": [
    {
      "id": "xw:112233",
      "name": "Les Vieilles Vignes Syrah",
      "winery": "Domaine Exemple",
      "type": "red",
      "grapes": ["Syrah"],
      "region": "Crozes-Hermitage",
      "country": { "code": "FR", "name": "France" },
      "abv": 13.5,
      "typicalBody": "high",
      "typicalAcidity": "medium",
      "provenance": { "source": "xwines", "id": 112233 }
    },
    {
      "id": "off:3760123456789",
      "name": "Rosé de Provence",
      "provenance": { "source": "openfoodfacts", "barcode": "3760123456789" }
    },
    { "id": "m:5f0c9a2e7b1d4c3a", "name": "Nonna's Rosso", "type": "red",
      "provenance": { "source": "manual" } }
  ],
  "tastings": [
    {
      "id": "8c1f4be2a07d4e6f9b3c2d1e0f5a6b7c",
      "wineId": "xw:112233",
      "tastedAt": "2026-11-14T08:30:00Z",
      "score": 4.2,
      "vintage": 2019,
      "color": { "hue": "ruby", "intensity": "deep" },
      "aroma": 4, "flavor": 4, "finish": 3, "finishLength": "medium",
      "sweetness": "dry",
      "body": "mediumPlus", "acidity": "medium", "tannin": "mediumPlus",
      "descriptors": ["fruit.black.blackberry", "spice.pepper.black", "oak.vanilla"],
      "notes": "Opened up after 20 minutes.",
      "place": "The corner bottle shop",
      "price": { "amount": "32.00", "currency": "AUD" },
      "photo": "9f2c0d...e1.jpg"
    }
  ],
  "wishlist": [
    { "wineId": "off:3760123456789", "addedAt": "2026-11-01T02:10:00Z", "vintage": "NV", "note": "" }
  ],
  "photos": { "9f2c0d...e1.jpg": "<base64 JPEG>" }
}
```

Rules: absent key means "not recorded" and nulls are never written. `vintage` is an integer year or the string `"NV"`. `score` is a decimal number with one fractional digit. `price.amount` is a decimal string. `photos` is present only when the user ticked "include photos". Unknown keys are ignored on import, and unknown descriptor ids are kept.
