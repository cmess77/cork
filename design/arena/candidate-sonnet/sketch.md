# Cork design sketch (candidate-sonnet)

Shape in one paragraph. Pure-Dart `domain/` (typed values, no Flutter, no drift) feeds pure `stats/` (stats and badges as folds over `List<JournalEntry>`). `data/` is drift over the writable journal DB. `lookup/` is one class, `WineLookup`, over a read-only `sqlite3` handle on the bundled index plus an Open Food Facts client, and it only ever returns `WineDraft`s. `backup/` is a pure JSON codec over a `JournalSnapshot`. Riverpod wires streams to screens. Badges are never stored. Wine ids for external wines are derived from provenance, so "adopting" a wine is an idempotent upsert and needs no lookup-to-journal handshake.

---

## 1. Caller's usage (the spec)

### 1a. Log a tasting (screen controller)

```dart
// lib/ui/log/log_tasting_controller.dart
final lookup = ref.read(wineLookupProvider);
final journal = ref.read(journalProvider);

// As-you-type, offline only. Latest-wins; stale queries are dropped inside WineLookup.
final List<WineDraft> hits = await lookup.suggest('chat blanc');

// Explicit "Search online" tap. Never called from onChanged.
final OnlineResult online = await lookup.searchOnline('chateau musar 2015');
switch (online) {
  case OnlineHits(:final drafts):   showHits(drafts);
  case OnlineRateLimited(:final retryAfter): toast('Try again in ${retryAfter.inSeconds}s');
  case OnlineUnavailable():         toast('No connection');
}

// Manual entry produces the same type as a hit.
final draft = WineDraft.manual(name: 'Cousin Pierre', type: WineType.red, grapes: ['Gamay'], vintageHint: Vintage.year(2022));

// Build and save. Tasting needs a complete Wine, so an unclassified draft cannot reach save.
final Wine wine = draft.asWine!;                       // null until the user picks a type
final tasting = Tasting.start(wineId: wine.id, now: clock())
    .copyWith(score: Score.tenths(43), glass: GlassAppearance(GlassColor.ruby, Intensity.deep),
              sweetness: Sweetness.dry, descriptors: {DescriptorId('fruit.red.cherry')});
await journal.saveTasting(tasting, wine: wine, removeFromWishlist: userSaidYes);   // one transaction, idempotent
```

### 1b. Stats screen (derived, never stored)

```dart
// lib/app/providers.dart
final entriesProvider = StreamProvider<List<JournalEntry>>((ref) => ref.watch(journalProvider).watchEntries());

final summaryProvider   = Provider((ref) => ref.watch(entriesProvider).whenData(summarize));
final byGrapeProvider   = Provider((ref) => ref.watch(entriesProvider).whenData((e) => breakdown(e, Dimension.grape)));
final badgesProvider    = Provider((ref) => ref.watch(entriesProvider).whenData(evaluateBadges));
// Edit or delete a tasting -> drift stream re-emits -> every provider re-derives. No badge state to fix up.
```

### 1c. Backup and restore

```dart
// lib/ui/settings/backup_tile.dart
final svc = ref.read(backupServiceProvider);
final File f = await svc.exportJson(includePhotos: true);          // writes cork-journal-2026-11-15.json
final ImportReport r = await svc.importJson(picked, mode: ImportMode.merge);
// r.winesAdded, r.tastingsAdded, r.tastingsUpdated, r.skipped: List<SkippedRecord{path, reason}>
```

---

## 2. Module map

```
lib/
  main.dart                      bootstrap: open journal DB, copy index asset, ProviderScope
  domain/                        PURE DART. No flutter, drift, sqlite3, http, dart:io.
    ids.dart                     WineId, TastingId (extension types over String; v5/v4 minting)
    wine.dart                    Wine, WineDraft, WineType, Provenance
    tasting.dart                 Tasting, Vintage, Score, Rating5, Level, Sweetness, Finish, Price, PhotoRef
    glass.dart                   GlassColor, ColorFamily, Intensity, GlassAppearance
    aroma_wheel.dart             AromaWheel (const data), DescriptorId, lookup/breadcrumb
    wishlist.dart                WishlistItem
    journal_entry.dart           JournalEntry(tasting, wine), JournalSnapshot
  stats/                         PURE DART. Imports domain only.
    stats.dart                   summarize, breakdown, scoreOverTime, topRated, histograms
    badges.dart                  BadgeDef table, Facts accumulator, evaluateBadges
  lookup/
    wine_lookup.dart             PUBLIC: WineLookup, OnlineResult
    offline_index.dart           private: read-only sqlite3 handle, FTS5 query, asset install
    fts_query.dart               private pure: raw text -> FTS5 MATCH string
    open_food_facts.dart         private: http client, throttle, wire -> WineDraft
  data/
    database.dart                drift tables, converters, schemaVersion, stepByStep migrations
    journal.dart                 PUBLIC: Journal (watch, save, delete, wishlist, snapshot in/out)
    photo_store.dart             PhotoStore: save/resolve/sweep
  backup/
    snapshot_codec.dart          PURE: JournalSnapshot <-> Map<String,Object?> (versioned)
    csv_export.dart              PURE: List<JournalEntry> -> String
    backup_service.dart          thin IO shell: file picker, Journal.readSnapshot/applySnapshot
  app/
    providers.dart               Riverpod graph (hand-written, no codegen)
  ui/
    log/ history/ stats/ wishlist/ settings/ widgets/   screens and widgets only
drift_schemas/                   generated schema dumps, one per schemaVersion (migration tests)
test/
  architecture_test.dart         fails if domain/ or stats/ import flutter|drift|sqlite3|http|dart:io
  stats/ domain/ backup/ data/   behavior tests over pure fns and in-memory drift
```

Dependency direction: `ui -> app -> {data, lookup, backup, stats} -> domain`. `stats` and `backup/snapshot_codec` depend only on `domain`. `lookup` and `data` never import each other (they meet only on `domain` types).

---

## 3. Domain types

```dart
// lib/domain/ids.dart
import 'package:uuid/uuid.dart';

extension type const WineId(String value) {
  /// Deterministic for provenance-backed wines: the same index row or barcode always yields the same id.
  factory WineId.forProvenance(Provenance p) => throw UnimplementedError(); // uuid.v5(namespace, p.key)
  factory WineId.random() => throw UnimplementedError();                    // manual wines, uuid.v4
}
extension type const TastingId(String value) {
  factory TastingId.random() => throw UnimplementedError();
}
```

```dart
// lib/domain/wine.dart
enum WineType {
  red, white, rose, sparkling, dessert, dessertPort;
  /// Stable storage/export key. Never use `index`.
  String get key => throw UnimplementedError();
  static WineType? fromKey(String k) => throw UnimplementedError();
  /// Five-way grouping used by stats and the every-type badge (dessert + port share a group).
  TypeGroup get group => throw UnimplementedError();
}
enum TypeGroup { red, white, rose, sparkling, dessert }

/// Where a Wine came from. `key` is the single stored representation: derive, never sync.
sealed class Provenance {
  const Provenance();
  String get key;                                        // "index/<release>/<id>", "off/<barcode>", "manual"
  /// Boundary parse (DB read, JSON import). Unknown prefix throws FormatException; the import codec turns that into a SkippedRecord.
  factory Provenance.parse(String key) => throw UnimplementedError();
}
final class FromIndex extends Provenance { const FromIndex({required this.release, required this.indexId}); final String release; final int indexId; @override String get key => throw UnimplementedError(); }
final class FromOpenFoodFacts extends Provenance { const FromOpenFoodFacts(this.barcode); final String barcode; @override String get key => throw UnimplementedError(); }
final class Manual extends Provenance { const Manual(); @override String get key => 'manual'; }

/// A label identity (not a vintage). Self-contained snapshot: the journal never needs the index to render.
final class Wine {
  const Wine({required this.id, required this.name, required this.type, required this.provenance,
      this.winery, this.grapes = const [], this.elaborate, this.abv, this.body, this.acidity,
      this.countryCode, this.country, this.region, required this.createdAt});
  final WineId id;
  final String name;
  final WineType type;
  final Provenance provenance;
  final String? winery;
  final List<String> grapes;          // display names, order preserved; grape stats count each
  final String? elaborate;            // "Varietal/100%" | "Assemblage/Blend" in the X-Wines data
  final double? abv;
  final String? body, acidity;        // index values, free text: informational, not the tasting's structure fields
  final String? countryCode, country, region;
  final DateTime createdAt;
  Wine copyWith({String? name, WineType? type, String? winery, List<String>? grapes, String? region, String? country}) => throw UnimplementedError();
}

/// What lookup returns and the manual form edits. Not persistable until `asWine != null`.
final class WineDraft {
  const WineDraft({required this.id, required this.provenance, required this.name, this.type,
      this.winery, this.grapes = const [], this.elaborate, this.abv, this.body, this.acidity,
      this.countryCode, this.country, this.region, this.vintageHint});
  factory WineDraft.manual({required String name, WineType? type, String? winery, List<String> grapes,
      String? country, String? region, Vintage? vintageHint}) => throw UnimplementedError();
  final WineId id;                    // WineId.forProvenance(...) or random for manual
  final Provenance provenance;
  final String name;
  final WineType? type;               // null only for online hits that cannot be classified
  final Vintage? vintageHint;         // manual entry collects vintage; it lands on the Tasting, not the Wine
  final String? winery, elaborate, body, acidity, countryCode, country, region;
  final List<String> grapes;
  final double? abv;
  WineDraft copyWith({WineType? type, String? name}) => throw UnimplementedError();
  /// Null while `type == null` or `name` is blank. The only way to obtain a Wine from a draft.
  Wine? asWine({DateTime? now}) => throw UnimplementedError();
}
```

```dart
// lib/domain/glass.dart
enum ColorFamily { white, rose, red }
enum Intensity { pale, medium, deep }

/// The visual swatch scale as data. Reds and whites each have a "brown"; distinct members, shared label.
enum GlassColor {
  // whites
  waterWhite(ColorFamily.white, 0xFFF4F6EE), greenYellow(ColorFamily.white, 0xFFE6EBA8), lemon(ColorFamily.white, 0xFFF1E58A),
  straw(ColorFamily.white, 0xFFE8D37A), gold(ColorFamily.white, 0xFFD9B54A), deepGold(ColorFamily.white, 0xFFC1912B),
  amber(ColorFamily.white, 0xFFB26A1F), whiteBrown(ColorFamily.white, 0xFF7B4A1E),
  // roses
  palePink(ColorFamily.rose, 0xFFF6D9D4), salmon(ColorFamily.rose, 0xFFF2B3A0), onionSkin(ColorFamily.rose, 0xFFE59B80), deepPink(ColorFamily.rose, 0xFFD96A83),
  // reds
  purple(ColorFamily.red, 0xFF5B1E4F), ruby(ColorFamily.red, 0xFF8E1B2E), garnet(ColorFamily.red, 0xFF74211F),
  tawny(ColorFamily.red, 0xFF9A4A24), redBrown(ColorFamily.red, 0xFF6B3A22);
  const GlassColor(this.family, this.argb);
  final ColorFamily family;
  final int argb;                      // swatch; UI wraps in Color(argb)
  String get key => name;              // stable export key
  static GlassColor? fromKey(String k) => throw UnimplementedError();
  static List<GlassColor> inFamily(ColorFamily f) => throw UnimplementedError();
}

/// Both parts or neither: a half-chosen appearance is unrepresentable.
final class GlassAppearance { const GlassAppearance(this.color, this.intensity); final GlassColor color; final Intensity intensity; }
```

```dart
// lib/domain/tasting.dart
enum Sweetness { boneDry, dry, offDry, mediumSweet, sweet, luscious }   // ordered; key == name
enum Level { low, mediumMinus, medium, mediumPlus, high }                 // body, acidity, tannin
enum FinishLength { short, medium, long }

/// 1..5 whole stars. Parse at boundary; constructor is private.
extension type const Rating5._(int value) {
  static Rating5? tryParse(int v) => (v >= 1 && v <= 5) ? Rating5._(v) : null;
  factory Rating5(int v) => throw UnimplementedError(); // asserts range
}
/// Overall score as integer tenths, 10..50. No double arithmetic drift, exact 0.1 steps.
extension type const Score._(int tenths) {
  static Score? tryParse(int tenths) => (tenths >= 10 && tenths <= 50) ? Score._(tenths) : null;
  factory Score.tenths(int t) => throw UnimplementedError();
  double get asDouble => tenths / 10;
  String get display => throw UnimplementedError();   // "4.3"
}
final class Finish { const Finish(this.rating, this.length); final Rating5 rating; final FinishLength length; }

/// null year -> not recorded; Vintage.nv -> explicitly non-vintage.
sealed class Vintage {
  const Vintage();
  factory Vintage.year(int y) => throw UnimplementedError();     // 1800..currentYear+1
  static const Vintage nv = NonVintage();
  String get key;                                                // "2019" | "NV"
  static Vintage? parse(String? key) => throw UnimplementedError();
}
final class VintageYear extends Vintage { const VintageYear(this.year); final int year; @override String get key => '$year'; }
final class NonVintage extends Vintage { const NonVintage(); @override String get key => 'NV'; }

final class Price {
  const Price({required this.minorUnits, required this.currency}); // 1850 CAD = $18.50
  final int minorUnits; final String currency;                      // ISO 4217, upper-case
}
extension type const PhotoRef(String fileName) {}                   // relative to PhotoStore root

final class Tasting {
  const Tasting._({required this.id, required this.wineId, required this.tastedAt, required this.score,
      required this.createdAt, required this.updatedAt, this.vintage, this.glass, this.aroma, this.flavor,
      this.finish, this.sweetness, this.body, this.acidity, this.tannin,
      this.descriptors = const {}, this.notes = '', this.place, this.price, this.photo});

  /// New check-in. Score defaults to 3.0 so the required field is always present; the UI makes the user confirm it.
  factory Tasting.start({required WineId wineId, required DateTime now}) => throw UnimplementedError();

  final TastingId id;
  final WineId wineId;
  final DateTime tastedAt;               // UTC instant; stats bucket by local date
  final Score score;                     // required
  final Vintage? vintage;
  final GlassAppearance? glass;
  final Rating5? aroma, flavor;
  final Finish? finish;
  final Sweetness? sweetness;
  final Level? body, acidity, tannin;
  final Set<DescriptorId> descriptors;   // stable ids into AromaWheel
  final String notes;                    // free text, '' when none
  final String? place;
  final Price? price;
  final PhotoRef? photo;
  final DateTime createdAt, updatedAt;   // updatedAt stamped by Journal.saveTasting (merge key on import)

  Tasting copyWith({Score? score, Vintage? vintage, GlassAppearance? glass, Rating5? aroma, Rating5? flavor,
      Finish? finish, Sweetness? sweetness, Level? body, Level? acidity, Level? tannin,
      Set<DescriptorId>? descriptors, String? notes, String? place, Price? price, PhotoRef? photo,
      DateTime? tastedAt}) => throw UnimplementedError();   // nullable-clearing via a Clear sentinel wrapper in impl
}
```

```dart
// lib/domain/aroma_wheel.dart
/// Stable path id, e.g. "fruit.citrus.lemon". Ids are append-only: labels may change, ids never do.
extension type const DescriptorId(String path) {
  String get categoryId => path.split('.').first;
}
final class Descriptor { const Descriptor(this.id, this.label); final DescriptorId id; final String label; }
final class AromaSubcategory { const AromaSubcategory(this.id, this.label, this.descriptors); final String id, label; final List<Descriptor> descriptors; }
final class AromaCategory { const AromaCategory(this.id, this.label, this.subcategories); final String id, label; final List<AromaSubcategory> subcategories; }

abstract final class AromaWheel {
  /// The wheel is a const tree in this file. Sample slice; the full wheel is authored data, not logic.
  static const List<AromaCategory> categories = [
    AromaCategory('fruit', 'Fruit', [
      AromaSubcategory('fruit.citrus', 'Citrus', [Descriptor(DescriptorId('fruit.citrus.lemon'), 'Lemon'), Descriptor(DescriptorId('fruit.citrus.grapefruit'), 'Grapefruit')]),
      AromaSubcategory('fruit.red', 'Red fruit', [Descriptor(DescriptorId('fruit.red.cherry'), 'Cherry'), Descriptor(DescriptorId('fruit.red.strawberry'), 'Strawberry')]),
    ]),
    AromaCategory('floral', 'Floral', [/* ... */]),
    AromaCategory('spice', 'Spice', [/* ... */]),
    AromaCategory('earth', 'Earth', [/* ... */]),
    AromaCategory('oak', 'Oak', [/* ... */]),
  ];
  /// Built once by walking `categories`. Unknown ids (old export, retired descriptor) return null; callers render the raw path tail.
  static Descriptor? describe(DescriptorId id) => throw UnimplementedError();
  static List<String> breadcrumb(DescriptorId id) => throw UnimplementedError(); // ['Fruit','Citrus','Lemon']
}
```

```dart
// lib/domain/wishlist.dart, journal_entry.dart
final class WishlistItem { const WishlistItem({required this.wine, required this.addedAt, this.note}); final Wine wine; final DateTime addedAt; final String? note; }

/// The unit every read model and stat consumes: a tasting with its wine already joined.
final class JournalEntry { const JournalEntry(this.tasting, this.wine); final Tasting tasting; final Wine wine; }

/// Everything in the journal, as plain domain values. Export, import, and tests all speak this.
final class JournalSnapshot {
  const JournalSnapshot({required this.wines, required this.tastings, required this.wishlist});
  final List<Wine> wines; final List<Tasting> tastings; final List<WishlistEntry> wishlist;
}
final class WishlistEntry { const WishlistEntry({required this.wineId, required this.addedAt, this.note}); final WineId wineId; final DateTime addedAt; final String? note; }
```

---

## 4. Wine lookup (single interface)

```dart
// lib/lookup/wine_lookup.dart  (the only file other modules import from lookup/)
sealed class OnlineResult { const OnlineResult(); }
final class OnlineHits extends OnlineResult { const OnlineHits(this.drafts); final List<WineDraft> drafts; }
final class OnlineRateLimited extends OnlineResult { const OnlineRateLimited(this.retryAfter); final Duration retryAfter; }
final class OnlineUnavailable extends OnlineResult { const OnlineUnavailable(); }   // offline, timeout, 5xx, unparseable

/// Hides: asset install and version marker, read-only sqlite3 handle, FTS5 query building and bm25 ranking,
/// stale-query dropping, Open Food Facts transport, User-Agent, 10/min client throttle, wire->domain parsing.
/// Exposes: two methods returning domain drafts. Writes nothing.
final class WineLookup {
  /// Installs the bundled index into app-support on first run or when the asset release changed (idempotent), then opens it read-only.
  static Future<WineLookup> open({required String appVersion, required String contact /* generic project address */}) => throw UnimplementedError();

  /// Offline FTS5. As-you-type safe. Returns [] for queries whose last token has < 2 chars after trimming.
  /// If called again before the previous call finishes, the earlier future completes with the latest result's
  /// list (latest-wins) rather than racing out of order.
  Future<List<WineDraft>> suggest(String query, {int limit = 30}) => throw UnimplementedError();

  /// Explicit user action only. Throttled client-side to 10/min; returns OnlineRateLimited instead of sending when the bucket is empty.
  Future<OnlineResult> searchOnline(String query) => throw UnimplementedError();

  Future<void> close() => throw UnimplementedError();
}
```

Private internals (not exported):

```dart
// lib/lookup/fts_query.dart (pure, unit-tested)
/// "chat  blanc!" -> '"chat"* "blanc"*'. Strips FTS5 syntax characters (quotes, parens, colon, *, ^, -), lowercases,
/// splits on non-letter/digit, implicit AND across tokens. Returns null when no usable token.
String? buildMatch(String raw) => throw UnimplementedError();

// lib/lookup/offline_index.dart
final class OfflineIndex {
  static const release = 'xwines-v1';                       // bumped with every index rebuild; part of Provenance.key
  Future<List<WineDraft>> search(String match, int limit) => throw UnimplementedError();
  // SELECT w.* FROM wines_fts JOIN wines w ON w.id = wines_fts.rowid
  //  WHERE wines_fts MATCH ?1 ORDER BY bm25(wines_fts, 10.0, 6.0, 2.0, 1.0) LIMIT ?2   -- cols: name, winery, grapes, region
  // row -> WineDraft: grapes JSON array decoded here; type text -> WineType.fromKey; id = WineId.forProvenance(FromIndex(...))
}

// lib/lookup/open_food_facts.dart
final class OpenFoodFactsClient {
  OpenFoodFactsClient({required String userAgent /* "Cork/<version> (<contact>)" */});
  Future<OnlineResult> search(String query) => throw UnimplementedError();
  // TODO: restrict to wine categories; classify type from categories_tags; drop hits with no product_name; id = barcode ("code")
}
```

---

## 5. Persistence

Choice: **drift** (on `sqlite3` + `sqlite3_flutter_libs`) for the journal. The index is opened with plain `sqlite3`, read-only, as a separate file. Different lifecycle (replaceable asset vs user data), different access style (hand-written FTS5 SQL vs typed CRUD).

```dart
// lib/data/database.dart  (drift; sketch of tables, not codegen output)
class Wines extends Table {
  TextColumn get id => text()();                        // WineId
  TextColumn get name => text()();
  TextColumn get type => text()();                      // WineType.key
  TextColumn get provenanceKey => text()();             // Provenance.key (single stored form)
  TextColumn get winery => text().nullable()();
  TextColumn get grapes => text().map(const JsonStringList())();   // '["Gamay"]'
  TextColumn get elaborate => text().nullable()();
  RealColumn get abv => real().nullable()();
  TextColumn get body => text().nullable()();
  TextColumn get acidity => text().nullable()();
  TextColumn get countryCode => text().nullable()();
  TextColumn get country => text().nullable()();
  TextColumn get region => text().nullable()();
  IntColumn get createdAt => integer()();               // epoch ms UTC
  @override Set<Column> get primaryKey => {id};
}
class Tastings extends Table {
  TextColumn get id => text()();
  TextColumn get wineId => text().references(Wines, #id)();          // RESTRICT: wines with tastings are never deleted
  IntColumn get tastedAt => integer()();
  IntColumn get scoreTenths => integer().check(scoreTenths.isBetweenValues(10, 50))();
  TextColumn get vintage => text().nullable()();                      // null | 'NV' | '2019' (Vintage.key)
  TextColumn get glassColor => text().nullable()();
  TextColumn get glassIntensity => text().nullable()();
  IntColumn get aroma => integer().nullable()();
  IntColumn get flavor => integer().nullable()();
  IntColumn get finishRating => integer().nullable()();
  TextColumn get finishLength => text().nullable()();
  TextColumn get sweetness => text().nullable()();
  TextColumn get body => text().nullable()();
  TextColumn get acidity => text().nullable()();
  TextColumn get tannin => text().nullable()();
  TextColumn get descriptors => text().map(const JsonStringList())();  // sorted DescriptorId paths
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get place => text().nullable()();
  IntColumn get priceMinor => integer().nullable()();
  TextColumn get priceCurrency => text().nullable()();
  TextColumn get photo => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  @override Set<Column> get primaryKey => {id};
  // indexes: (wine_id), (tasted_at DESC)
}
class WishlistItems extends Table {
  TextColumn get wineId => text().references(Wines, #id, onDelete: KeyAction.cascade)();   // PK => one entry per wine
  IntColumn get addedAt => integer()();
  TextColumn get note => text().nullable()();
  @override Set<Column> get primaryKey => {wineId};
}
// No badge table, no stats table, by design.

@DriftDatabase(tables: [Wines, Tastings, WishlistItems])
class JournalDb extends _$JournalDb {
  JournalDb(super.e);
  @override int get schemaVersion => 1;
  @override MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: stepByStep(/* from1To2: (m, schema) async { ... } */),   // generated by `drift_dev make-migrations`
    beforeOpen: (d) async => d.customStatement('PRAGMA foreign_keys = ON'),
  );
}
```

Migration story: every released `schemaVersion` gets a dumped schema JSON in `drift_schemas/`; `drift_dev` generates `stepByStep` helpers and per-version test databases; CI runs "upgrade from every dumped version, assert data survives". Enums are stored as stable text keys (never ordinals), so adding an enum member is not a migration. Export `formatVersion` is separate from `schemaVersion` (the JSON format changes only when its shape does).

```dart
// lib/data/journal.dart  (the only public persistence surface)
final class Journal {
  Journal(JournalDb db, {DateTime Function() clock = DateTime.now});

  Stream<List<JournalEntry>> watchEntries();                  // joined, newest first; the input to all stats
  Stream<List<WishlistItem>> watchWishlist();
  Stream<bool> watchIsWishlisted(WineId id);

  /// Upsert tasting (create or edit: same call, idempotent on tasting.id), insert-if-absent for `wine`
  /// (an adopted wine is never overwritten by a later lookup), optionally drop the wishlist entry. One transaction.
  Future<void> saveTasting(Tasting t, {required Wine wine, bool removeFromWishlist = false});
  Future<void> deleteTasting(TastingId id);

  Future<void> addToWishlist(Wine wine, {String? note});      // insert-if-absent wine + upsert entry
  Future<void> removeFromWishlist(WineId id);

  Future<void> updateWine(Wine w);                            // manual corrections to the journal copy

  Future<JournalSnapshot> readSnapshot();
  Future<ImportReport> applySnapshot(JournalSnapshot s, {required ImportMode mode});
}
enum ImportMode { merge, replace }
```

Photos: `PhotoStore` writes `photos/<tastingId>-<n>.jpg` under app documents and returns a `PhotoRef`. `Journal` never touches files. Orphans (tasting deleted, crash mid-save) are removed by `PhotoStore.sweep(livePhotos)` at startup, computed from the DB, so no delete bookkeeping exists to get out of sync.

```dart
// lib/data/photo_store.dart
final class PhotoStore {
  Future<PhotoRef> save(Uint8List jpegBytes, {required TastingId forTasting}) => throw UnimplementedError();
  File resolve(PhotoRef ref) => throw UnimplementedError();
  Future<int> sweep(Set<PhotoRef> live) => throw UnimplementedError();   // deletes files not in `live`; returns count
}
```

---

## 6. Stats and badges (pure)

```dart
// lib/stats/stats.dart
final class Summary { const Summary({required this.tastingCount, required this.uniqueWineCount, required this.averageScore}); final int tastingCount, uniqueWineCount; final double? averageScore; }
Summary summarize(List<JournalEntry> e) => throw UnimplementedError();

enum Dimension { type, grape, country, region, winery, vintage, priceBand }
final class GroupStat { const GroupStat({required this.key, required this.label, required this.count, required this.averageScore}); final String key, label; final int count; final double averageScore; }

/// Groups by dimension. `grape` is multi-valued: a two-grape blend counts toward both. Entries with no value for the
/// dimension (no vintage, no price, price in a non-home currency) are omitted, not bucketed as "unknown".
/// Sorted by count desc, then average desc, then label.
List<GroupStat> breakdown(List<JournalEntry> e, Dimension d, {String homeCurrency = 'CAD'}) => throw UnimplementedError();

enum Bucket { day, week, month }
final class ScorePoint { const ScorePoint(this.bucketStart, this.averageScore, this.count); final DateTime bucketStart; final double averageScore; final int count; }
List<ScorePoint> scoreOverTime(List<JournalEntry> e, {Bucket bucket = Bucket.month, Duration utcOffset = Duration.zero}) => throw UnimplementedError();

final class RankedWine { const RankedWine(this.wine, this.bestScore, this.averageScore, this.tastingCount); final Wine wine; final Score bestScore; final double averageScore; final int tastingCount; }
List<RankedWine> topRated(List<JournalEntry> e, {int limit = 10, int minTastings = 1}) => throw UnimplementedError();

/// Eight half-point bins over 1.0..5.0 (5.0 lands in the last bin).
List<int> scoreHistogram(List<JournalEntry> e) => throw UnimplementedError();
Map<Sweetness, int> sweetnessDistribution(List<JournalEntry> e) => throw UnimplementedError();
```

```dart
// lib/stats/badges.dart
/// Single-pass accumulator over chronological entries. Every badge reads one number off it.
final class Facts {
  Facts add(JournalEntry e) => throw UnimplementedError();      // returns a new Facts; no mutation shared across passes
  int get tastingCount => throw UnimplementedError();
  int get distinctGrapes => throw UnimplementedError();
  int get distinctCountries => throw UnimplementedError();
  int get distinctTypeGroups => throw UnimplementedError();
  int get maxTastingsOfOneGrape => throw UnimplementedError();
}

/// Badge definitions are a const table. A badge is "metric >= target"; there is no per-badge code.
final class BadgeDef {
  const BadgeDef({required this.id, required this.title, required this.description, required this.target, required this.metric});
  final String id, title, description; final int target; final int Function(Facts) metric;
}
const List<BadgeDef> badgeDefs = [ /* first-tasting(1), 10/50/100 tastings, 5 grapes, 10 countries, every type (5 groups), 10 of one grape */ ];

final class BadgeStatus {
  const BadgeStatus(this.def, {required this.progress, this.earnedAt});
  final BadgeDef def; final int progress;
  final DateTime? earnedAt;                 // tastedAt of the entry that first crossed the target; null if not earned
  bool get earned => earnedAt != null;
}

/// Sorts by tastedAt, folds Facts, records the first crossing per badge. Editing or deleting a tasting changes the
/// input and therefore the result; nothing is stored.
List<BadgeStatus> evaluateBadges(List<JournalEntry> e) => throw UnimplementedError();
```

---

## 7. Export / import JSON shape

```jsonc
{
  "format": "cork-journal",
  "formatVersion": 1,
  "exportedAt": "2026-11-15T18:04:11Z",
  "appVersion": "1.0.0",
  "wines": [
    { "id": "7b1f...", "name": "Chateau Musar", "type": "red", "provenance": "index/xwines-v1/10231",
      "winery": "Chateau Musar", "grapes": ["Cabernet Sauvignon","Cinsault"], "elaborate": "Assemblage/Blend",
      "abv": 14.0, "body": "Full-bodied", "acidity": "Medium",
      "countryCode": "LB", "country": "Lebanon", "region": "Bekaa Valley", "createdAt": "2026-03-02T19:10:00Z" }
  ],
  "tastings": [
    { "id": "c0de...", "wineId": "7b1f...", "tastedAt": "2026-03-02T19:42:00Z",
      "vintage": "2015",                                   // "2015" | "NV" | absent
      "scoreTenths": 43,
      "glass": { "color": "garnet", "intensity": "deep" },
      "aroma": 4, "flavor": 4, "finish": { "rating": 5, "length": "long" },
      "sweetness": "dry", "body": "high", "acidity": "mediumPlus", "tannin": "high",
      "descriptors": ["fruit.red.cherry", "spice.baking.clove"],
      "notes": "Funky, then silky.",
      "place": "Home", "price": { "minor": 5200, "currency": "CAD" },
      "photo": { "mime": "image/jpeg", "base64": "..." },   // present only when includePhotos
      "createdAt": "2026-03-02T19:44:00Z", "updatedAt": "2026-03-02T19:44:00Z" }
  ],
  "wishlist": [ { "wineId": "9aa2...", "addedAt": "2026-04-01T10:00:00Z", "note": "from Sam" } ]
}
```

```dart
// lib/backup/snapshot_codec.dart (pure)
Map<String, Object?> encodeSnapshot(JournalSnapshot s, {required String appVersion, required DateTime now, Map<TastingId, Uint8List> photos = const {}}) => throw UnimplementedError();

/// Boundary parser. Runs `migrateJson` up to the current formatVersion, then parses into domain types.
/// Refuses formatVersion greater than supported (throws UnsupportedFormat). Per-record failures
/// (bad enum key, score out of range, dangling wineId) go to `skipped` with a JSON path; they never abort the file.
DecodeResult decodeSnapshot(Map<String, Object?> json) => throw UnimplementedError();
Map<String, Object?> migrateJson(Map<String, Object?> json) => throw UnimplementedError();   // v1->v2 steps chained

final class DecodeResult { const DecodeResult(this.snapshot, this.photos, this.skipped); final JournalSnapshot snapshot; final Map<TastingId, Uint8List> photos; final List<SkippedRecord> skipped; }
final class SkippedRecord { const SkippedRecord(this.path, this.reason); final String path, reason; }
final class ImportReport { const ImportReport({required this.winesAdded, required this.tastingsAdded, required this.tastingsUpdated, required this.skipped}); final int winesAdded, tastingsAdded, tastingsUpdated; final List<SkippedRecord> skipped; }
```

Import semantics. Ids are the identity, so re-importing the same file is a no-op (idempotent). `merge`: insert missing wines, insert missing tastings, replace a tasting only when the file's `updatedAt` is newer, never delete. `replace`: one transaction that clears the three tables then inserts. Unknown descriptor ids are kept as-is. CSV (`csv_export.dart`) is one-way, one row per tasting with wine columns joined, descriptors as a `;`-joined label list.

---

## 8. State management

**Riverpod** (`flutter_riverpod`, hand-written providers, no `riverpod_generator`). The only async sources are drift streams and two one-shot lookups. Everything else is `Provider` derivation over `entriesProvider`.

```dart
// lib/app/providers.dart
final journalDbProvider  = Provider<JournalDb>((ref) => throw UnimplementedError()); // overridden in main() after open
final journalProvider    = Provider((ref) => Journal(ref.watch(journalDbProvider)));
final wineLookupProvider = Provider<WineLookup>((ref) => throw UnimplementedError()); // overridden in main()
final photoStoreProvider = Provider<PhotoStore>((ref) => throw UnimplementedError());
final backupServiceProvider = Provider((ref) => BackupService(ref.watch(journalProvider), ref.watch(photoStoreProvider)));

final entriesProvider  = StreamProvider<List<JournalEntry>>((ref) => ref.watch(journalProvider).watchEntries());
final wishlistProvider = StreamProvider<List<WishlistItem>>((ref) => ref.watch(journalProvider).watchWishlist());
// Feed filter state is a plain Notifier<FeedFilter>; filtered feed = Provider combining entries + filter (in-memory).
```

Scale assumption (stated, not hidden): one person's journal, thousands of tastings at most. Feed search/filter and all stats run in memory over `watchEntries()`. If that stops being true, `watchEntries` is the single place to add paging.
