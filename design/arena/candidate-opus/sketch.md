# Cork candidate (opus): one journal snapshot, everything else derived

The whole journal is read into one immutable `JournalSnapshot` and exposed as a stream. The feed, the filters, the stats, the badges, the wishlist and the export all come from pure functions over that snapshot. `Journal` is the only thing that writes to the journal database. `WineFinder` is the only thing that reads the wine index or Open Food Facts. A picked wine stays a `WineCandidate` until a tasting or wishlist save adopts it, so the user can browse search results without leaving orphan rows behind.

## 1. Usage first (the spec)

### 1a. Search screen, as you type, with the explicit online fallback

```dart
// lib/ui/search/search_screen.dart
class SearchScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);              // debounced text
    final results = ref.watch(offlineSearchProvider(query));   // AsyncValue<List<WineCandidate>>

    return Column(children: [
      SearchField(onChanged: ref.read(searchQueryProvider.notifier).set),
      Expanded(child: results.when(
        data: (candidates) => CandidateList(
          candidates: candidates,
          // A candidate is a value. Nothing is written until the tasting is saved.
          onPick: (c) => context.push('/log', extra: TastingForm.forCandidate(c)),
          onWishlist: (c) => ref.read(journalProvider).addToWishlist(c),
          footer: SearchOnlineButton(onTap: () => _searchOnline(context, ref, query)),
        ),
        loading: () => const CandidateListSkeleton(),
        error: (e, _) => ErrorTile(e),
      )),
    ]);
  }

  Future<void> _searchOnline(BuildContext context, WidgetRef ref, String query) async {
    final finder = ref.read(wineFinderProvider);
    switch (await finder.searchOnline(query)) {
      case OnlineHits(:final candidates):
        showOnlineResults(context, candidates);
      case OnlineRateLimited(:final retryAfter):
        showSnack(context, 'Online search is busy. Try again in ${retryAfter.inSeconds}s.');
      case OnlineUnavailable():
        showSnack(context, 'No connection. You can still add the wine by hand.');
    }
  }
}

// Manual entry goes through the same door as the other two sources.
final candidate = WineCandidate.manual(WineDetails(
  name: 'Cuvée Maison', winery: 'Domaine X', type: WineType.red,
  grapes: ['Grenache', 'Syrah'], region: 'Rhône', country: Country('FR', 'France'),
));
context.push('/log', extra: TastingForm.forCandidate(candidate, vintage: Vintage.year(2021)));
```

### 1b. Saving a tasting: wishlist offer and new-badge celebration, with no stored badge state

```dart
// lib/ui/log/log_tasting_screen.dart
Future<void> _save(BuildContext context, WidgetRef ref, TastingForm form) async {
  final input = form.toInput();          // null until a score is chosen; the button is disabled then
  if (input == null) return;

  final journal = ref.read(journalProvider);
  final before = earnedBadgeIds(ref.read(snapshotProvider).requireValue);

  final saved = await journal.logTasting(input);   // adopts the candidate and inserts, in one transaction

  if (saved.wasWishlisted && context.mounted &&
      await confirm(context, 'Remove ${saved.wine.details.name} from your wishlist?')) {
    await journal.removeFromWishlist(saved.wine.id);
  }

  final after = earnedBadgeIds(await journal.snapshot());
  for (final badge in newlyEarned(before, after)) {
    if (context.mounted) celebrate(context, badge);
  }
  if (context.mounted) context.pop();
}
```

### 1c. Stats, badges and the feed read the same snapshot

```dart
// lib/ui/stats/stats_screen.dart
final stats = ref.watch(statsProvider);        // derived: computeStats(snapshot), memoized by Riverpod
Text('${stats.tastingCount} tastings, ${stats.uniqueWineCount} wines, avg ${stats.averageScore}');
ScoreTrendChart(points: stats.monthlyAverage);
BreakdownTable(rows: stats.breakdown(Dimension.grape));   // a blend counts once per grape
SweetnessHistogram(counts: stats.sweetnessDistribution);

// lib/ui/badges/badges_screen.dart
final badges = ref.watch(badgesProvider);      // List<BadgeStatus>, recomputed after every edit or delete
BadgeGrid(badges: badges);                     // earnedAt is the date of the tasting that crossed the line

// lib/ui/feed/feed_screen.dart
final entries = ref.watch(feedProvider(FeedFilter(text: 'barolo', types: {WineType.red}, minScore: Score.of(4.0))));
```

### 1d. Backup

```dart
final file = await ref.read(backupProvider).exportTo(dir);           // cork-journal-2026-11-15.json
final report = await ref.read(backupProvider).importFrom(picked, mode: ImportMode.merge);
showSnack(context, '${report.winesUpserted} wines, ${report.tastingsUpserted} tastings imported');
// Importing the same file twice changes nothing: ids are UUIDs and merge keeps the newer updatedAt.
```

## 2. Module map

Modules follow domain knowledge, not layers. Each folder's top file is its public surface. Anything under a folder's `src/` is private to that folder, and `test/architecture_test.dart` fails the build when an import crosses that line (Dart cannot enforce `src/` privacy inside one app package).

```
lib/
  main.dart                      runApp(ProviderScope(child: CorkApp()))
  app/
    app.dart                     MaterialApp.router, theme, routes
    providers.dart               composition root: every Provider lives here and nowhere else
  wine/
    wine.dart                    Wine, WineId, WineDetails, WineType, Country, Provenance, Vintage
    finder.dart                  WineFinder, WineCandidate, OnlineSearchResult   (public lookup surface)
    src/
      index_db.dart              opens assets/wine_index.db read-only, FTS5 query + bm25 ranking
      index_install.dart         copies the asset to app support dir, atomically, once per app build
      off_client.dart            Open Food Facts HTTP, User-Agent, JSON -> WineDetails parse
      rate_limiter.dart          token bucket, 10 per 60s, honours 429 Retry-After
      fts_query.dart             user text -> safe FTS5 MATCH expression (pure)
  tasting/
    tasting.dart                 Tasting, TastingId, TastingInput, Score, Rating, Finish, Sweetness,
                                 Structure, Level, Money, Currency, PhotoRef
    glass_color.dart             GlassHue (with swatch ARGB and family), Intensity, GlassColor
    aroma_wheel.dart             const aromaWheel tree; DescriptorId; lookup helpers
    tasting_form.dart            TastingForm: the editable draft the log screen holds
  journal/
    journal.dart                 Journal (sole writer), JournalSnapshot, JournalEntry, WishlistItem, SavedTasting
    src/
      db.dart                    drift JournalDatabase, tables, schemaVersion, migrations
      rows.dart                  row <-> domain mapping (the only place that knows column names)
      photos.dart                photo file store under app documents dir
  insights/
    stats.dart                   computeStats, JournalStats, Dimension, Breakdown (pure)
    badges.dart                  badge catalog as data, deriveBadges, newlyEarned (pure)
    feed.dart                    FeedFilter, applyFeedFilter (pure)
  backup/
    backup.dart                  Backup service: exportTo, importFrom, exportCsv
    src/
      format_v1.dart             JournalSnapshot <-> JSON v1 (pure), wire names
      csv.dart                   tastings -> CSV (pure)
  ui/
    search/  log/  feed/  wine/  stats/  badges/  wishlist/  settings/
    widgets/                     swatch picker, aroma wheel picker, score slider, charts
```

Dependency direction: `ui -> app/providers -> {journal, wine/finder, backup, insights} -> {wine, tasting}`. `insights` depends only on `journal.dart` types plus `wine` and `tasting`. `wine` and `tasting` import nothing from Flutter, so the whole domain and insights layer runs under plain `dart test`.

## 3. Type sketches

### 3a. `lib/wine/wine.dart`

```dart
/// Local journal wine id. A UUID string, so backups merge without collisions.
extension type const WineId(String value) {}

enum WineType {
  red('red', 'Red'),
  white('white', 'White'),
  rose('rose', 'Rosé'),
  sparkling('sparkling', 'Sparkling'),
  dessert('dessert', 'Dessert'),
  fortified('fortified', 'Dessert/Port');

  const WineType(this.wire, this.indexLabel);
  /// Stable name in backups and in the journal DB. Never derived from `.name`,
  /// so renaming the enum member cannot break an old backup.
  final String wire;
  /// The exact value in wine_index.db `wines.type`.
  final String indexLabel;

  /// Parses the index's `type` column. Unknown labels return null (boundary).
  static WineType? fromIndex(String label) => throw UnimplementedError();
  static WineType fromWire(String wire) => throw UnimplementedError();
}

/// ISO 3166-1 alpha-2 code plus display name, as the index stores them.
final class Country {
  const Country(this.code, this.name);
  final String? code;      // null for manual entries where the user typed only a name
  final String name;
}

/// What the user sees and edits about a wine. Copied out of the source at adoption,
/// so the journal never depends on the index file or the network to render.
final class WineDetails {
  const WineDetails({
    required this.name,
    this.winery,
    this.type,
    this.grapes = const [],
    this.elaborate,
    this.abv,
    this.body,
    this.acidity,
    this.region,
    this.country,
  });
  final String name;
  final String? winery;
  final WineType? type;          // null when an online or manual wine did not say
  final List<String> grapes;     // display spelling; compare with grapeKey()
  final String? elaborate;       // "Varietal/100%", "Assemblage/Blend", ...
  final double? abv;
  final String? body;            // index wording, e.g. "Full-bodied"; not the tasting's Level
  final String? acidity;
  final String? region;
  final Country? country;
}

/// Where a wine came from. The (source, externalId) pair is unique in the journal,
/// which makes adopting the same index or barcode wine twice return the same Wine.
sealed class Provenance {
  const Provenance();
}
final class FromIndex extends Provenance {
  const FromIndex(this.xwinesId);
  final int xwinesId;            // wine_index.db wines.id, which must stay the X-Wines WineID
}
final class FromOpenFoodFacts extends Provenance {
  const FromOpenFoodFacts(this.barcode);
  final String barcode;          // OFF product `code`
}
final class Manual extends Provenance {
  const Manual();
}

final class Wine {
  const Wine({required this.id, required this.details, required this.provenance,
              required this.createdAt, required this.updatedAt});
  final WineId id;
  final WineDetails details;
  final Provenance provenance;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Vintage belongs to the bottle you tasted, so it lives on Tasting, not Wine.
/// `null` on a Tasting means "not recorded"; NonVintage means the label says NV.
sealed class Vintage {
  const Vintage();
  const factory Vintage.year(int year) = VintageYear;
  static const nv = NonVintage();
}
final class VintageYear extends Vintage {
  const VintageYear(this.year) : assert(year >= 1800 && year <= 2200);
  final int year;
}
final class NonVintage extends Vintage {
  const NonVintage();
}

/// Case- and accent-folded key so "Syrah" and "syrah " group together in stats and badges.
String grapeKey(String grape) => throw UnimplementedError();
```

### 3b. `lib/wine/finder.dart`

```dart
/// A wine the user can pick. Uniform across sources so one list widget renders all three.
/// `existing` is set when this wine is already in the journal (same provenance, or a local hit).
final class WineCandidate {
  /// Built by IndexDb hits, OffClient results and JournalReader.matchWines.
  const WineCandidate(this.details, this.provenance, {this.existing, this.history});
  factory WineCandidate.manual(WineDetails details) => WineCandidate(details, const Manual());

  final WineDetails details;
  final Provenance provenance;
  final WineId? existing;
  /// "You've had this 3 times, avg 4.1". Filled for journal hits only.
  final ({int count, Score average})? history;
}

sealed class OnlineSearchResult {
  const OnlineSearchResult();
}
final class OnlineHits extends OnlineSearchResult {
  const OnlineHits(this.candidates);
  final List<WineCandidate> candidates;
}
final class OnlineRateLimited extends OnlineSearchResult {
  const OnlineRateLimited(this.retryAfter);
  final Duration retryAfter;
}
/// Offline, DNS failure, 5xx, or a payload we could not parse. The UI says the same thing for all.
final class OnlineUnavailable extends OnlineSearchResult {
  const OnlineUnavailable(this.cause);
  final Object cause;
}

/// The one lookup surface. Reads only; adopting a candidate is Journal's job.
abstract interface class WineFinder {
  /// As-you-type search. Fast and offline. Returns the user's own journal wines that match
  /// first (manual and online wines included, so they can be found again), then index hits
  /// ranked by bm25 with name > winery > grapes > region weights. Index hits the user has
  /// already adopted are folded into their journal entry, never listed twice.
  /// Queries shorter than 2 characters return []. Runs on drift's background isolate.
  Future<List<WineCandidate>> search(String query, {int limit = 30});

  /// Explicit-tap search against Open Food Facts. Never called from a text listener.
  /// Rate limiting lives here, so no caller can exceed 10 requests per minute.
  Future<OnlineSearchResult> searchOnline(String query);
}

final class DefaultWineFinder implements WineFinder {
  DefaultWineFinder({required IndexDb index, required JournalReader journal, required OffClient off});
  // IndexDb, OffClient are wine/src types. JournalReader is a read-only view Journal hands out.

  @override
  Future<List<WineCandidate>> search(String query, {int limit = 30}) {
    // TODO:
    // 1. q = parseFtsQuery(query); if q == null return [].
    // 2. In parallel: index.match(q, limit) and journal.matchWines(query) (LIKE over a few hundred rows).
    // 3. adoptedIds = journal.wineIdsForIndexIds(indexHits.map(id)) : one IN query.
    // 4. Merge: journal hits first, then index hits not in adoptedIds. Stable, no re-sort across groups.
    throw UnimplementedError();
  }

  @override
  Future<OnlineSearchResult> searchOnline(String query) => throw UnimplementedError();
}
```

### 3c. `lib/wine/src/*` (private)

```dart
// fts_query.dart
/// Turns user text into an FTS5 MATCH string: each token quoted and suffixed with `*`,
/// tokens ANDed. Quotes and FTS operators in input are neutralised. Returns null if nothing is left.
/// `"cht"* AND "marg"*` for "Cht Marg". The index's prefix='2 3' makes 2-3 char tokens cheap.
String? parseFtsQuery(String userText) => throw UnimplementedError();

// index_db.dart
final class IndexHit {
  const IndexHit(this.xwinesId, this.details);
  final int xwinesId;
  final WineDetails details;      // grapes JSON already parsed here, type mapped via fromIndex
}
final class IndexDb {
  /// Opened with sqlite3 `OpenMode.readOnly` on the installed copy.
  static Future<IndexDb> open(File installed) => throw UnimplementedError();
  /// SELECT w.* FROM wines_fts JOIN wines w ON w.id = wines_fts.rowid
  /// WHERE wines_fts MATCH ? ORDER BY bm25(wines_fts, 10.0, 5.0, 2.0, 1.0) LIMIT ?
  Future<List<IndexHit>> match(String ftsQuery, int limit) => throw UnimplementedError();
}

// index_install.dart
/// Assets cannot be opened in place on Android. Copy to <appSupport>/wine_index/<buildNumber>.db
/// via a temp file and rename, so a crash mid-copy leaves no half-file to open. Deletes older copies.
/// Running it twice is a no-op when the target exists.
Future<File> installWineIndex({required String buildNumber}) => throw UnimplementedError();

// off_client.dart
final class OffClient {
  OffClient({required http.Client http, required RateLimiter limiter, required String userAgent});
  // userAgent = 'Cork/$version (cork-app@bigpapa.one)' : a project address, never the user's.
  /// GET world.openfoodfacts.org search with categories_tags=en:wines, fields restricted.
  /// Parses into WineCandidate with FromOpenFoodFacts provenance. Never returns OFF JSON.
  Future<OnlineSearchResult> search(String query) => throw UnimplementedError();
}
/// Maps OFF categories_tags (en:red-wines, en:rose-wines, en:sparkling-wines, ...) to WineType.
WineType? wineTypeFromOffCategories(List<String> tags) => throw UnimplementedError();

// rate_limiter.dart
final class RateLimiter {
  RateLimiter({int capacity = 10, Duration window = const Duration(minutes: 1), DateTime Function()? clock});
  /// Takes a token or returns how long until one is free. A 429 calls [backOff].
  Duration? tryAcquire() => throw UnimplementedError();
  void backOff(Duration retryAfter) => throw UnimplementedError();
}
```

### 3d. `lib/tasting/tasting.dart`

```dart
extension type const TastingId(String value) {}   // UUID

/// Overall score, 1.0 to 5.0 in 0.1 steps, held as integer tenths (10..50)
/// so equality, grouping and storage never meet a float.
extension type const Score._(int tenths) {
  static Score of(double value) => throw UnimplementedError();   // rounds to 0.1, asserts range
  static Score? tryTenths(int tenths) => throw UnimplementedError(); // boundary parse
  double get value => tenths / 10;
}

/// 1..5 for aroma, flavor and finish.
extension type const Rating._(int value) {
  static Rating of(int v) => throw UnimplementedError();         // asserts 1..5
  static Rating? tryParse(Object? raw) => throw UnimplementedError();
}

enum FinishLength { short('short'), medium('medium'), long('long');
  const FinishLength(this.wire); final String wire; }

final class Finish {
  const Finish({this.rating, this.length});
  final Rating? rating;
  final FinishLength? length;
}

/// Ordered; index order is the scale order, which the sweetness histogram relies on.
enum Sweetness {
  boneDry('bone_dry'), dry('dry'), offDry('off_dry'),
  mediumSweet('medium_sweet'), sweet('sweet'), luscious('luscious');
  const Sweetness(this.wire); final String wire;
}

/// WSET structure levels. "low to high" in the requirements; medium(-) and medium(+) included.
enum Level { low('low'), mediumMinus('medium_minus'), medium('medium'),
             mediumPlus('medium_plus'), high('high');
  const Level(this.wire); final String wire; }

final class Structure {
  const Structure({this.body, this.acidity, this.tannin});
  final Level? body;
  final Level? acidity;
  /// Shown for reds (and when the wine's type is unknown). Not rejected for other types,
  /// because a manual wine may have no type and an orange wine has tannin.
  final Level? tannin;
  static const empty = Structure();
}

/// ISO 4217 code, upper-case, validated at the boundary.
extension type const Currency._(String code) {
  static Currency? tryParse(String raw) => throw UnimplementedError();
}

/// Minor units, so 24.99 USD is 2499. JPY has 0 minor digits; Currency knows that.
final class Money {
  const Money(this.amountMinor, this.currency);
  final int amountMinor;
  final Currency currency;
}

/// A label photo stored by Journal under <appDocuments>/photos/<uuid>.jpg.
/// Only the relative path is persisted, so moving app storage does not break references.
extension type const PhotoRef(String relativePath) {}

/// A saved tasting.
final class Tasting {
  const Tasting({
    required this.id, required this.wineId, required this.score, required this.tastedAt,
    this.vintage, this.color, this.aroma, this.flavor, this.finish = const Finish(),
    this.sweetness, this.structure = Structure.empty, this.descriptors = const {},
    this.notes = '', this.place, this.price, this.photo,
    required this.createdAt, required this.updatedAt,
  });
  final TastingId id;
  final WineId wineId;
  final Vintage? vintage;
  final GlassColor? color;
  final Rating? aroma;
  final Rating? flavor;
  final Finish finish;
  final Sweetness? sweetness;
  final Structure structure;
  final Set<DescriptorId> descriptors;
  final String notes;
  final Score score;                  // the one required judgement
  final DateTime tastedAt;            // instant, stored UTC, shown local
  final String? place;
  final Money? price;
  final PhotoRef? photo;
  final DateTime createdAt;
  final DateTime updatedAt;           // import merge key
}

/// What Journal.logTasting / updateTasting accept. The wine is a candidate, so the
/// adopt-then-insert happens in one transaction and a never-saved pick leaves no row.
/// `score` is non-nullable here; TastingForm.toInput() returns null until it is set.
final class TastingInput {
  const TastingInput({required this.wine, required this.score, required this.tastedAt,
    this.vintage, this.color, this.aroma, this.flavor, this.finish = const Finish(),
    this.sweetness, this.structure = Structure.empty, this.descriptors = const {},
    this.notes = '', this.place, this.price, this.photo});
  final WineCandidate wine;
  final Score score;
  final DateTime tastedAt;
  final Vintage? vintage;
  final GlassColor? color;
  final Rating? aroma;
  final Rating? flavor;
  final Finish finish;
  final Sweetness? sweetness;
  final Structure structure;
  final Set<DescriptorId> descriptors;
  final String notes;
  final String? place;
  final Money? price;
  final PhotoInput? photo;            // new bytes, kept photo, or removal
}

sealed class PhotoInput { const PhotoInput(); }
final class KeepPhoto extends PhotoInput { const KeepPhoto(this.ref); final PhotoRef ref; }
final class NewPhoto extends PhotoInput { const NewPhoto(this.file); final XFile file; } // from image_picker
```

### 3e. `lib/tasting/glass_color.dart`

```dart
enum GlassFamily { white, rose, red }

/// One enum, family attached to each member, so the swatch picker is `GlassHue.values.where(family)`
/// and there is no second list to keep in sync. White "brown" and red "brown" are distinct hues.
enum GlassHue {
  waterWhite(GlassFamily.white, 'water_white', 0xFFF7F6EE),
  greenYellow(GlassFamily.white, 'green_yellow', 0xFFEEEFB0),
  lemon(GlassFamily.white, 'lemon', 0xFFF3E98A),
  straw(GlassFamily.white, 'straw', 0xFFEBD77A),
  gold(GlassFamily.white, 'gold', 0xFFDDB54A),
  deepGold(GlassFamily.white, 'deep_gold', 0xFFC9962E),
  amber(GlassFamily.white, 'amber', 0xFFB8731F),
  whiteBrown(GlassFamily.white, 'white_brown', 0xFF8A5A22),
  palePink(GlassFamily.rose, 'pale_pink', 0xFFF6CFCB),
  salmon(GlassFamily.rose, 'salmon', 0xFFF2A48C),
  onionSkin(GlassFamily.rose, 'onion_skin', 0xFFD9906B),
  deepPink(GlassFamily.rose, 'deep_pink', 0xFFE0607E),
  purple(GlassFamily.red, 'purple', 0xFF4B1338),
  ruby(GlassFamily.red, 'ruby', 0xFF7A1025),
  garnet(GlassFamily.red, 'garnet', 0xFF7C2A21),
  tawny(GlassFamily.red, 'tawny', 0xFF94502A),
  redBrown(GlassFamily.red, 'red_brown', 0xFF6B3A1F);

  const GlassHue(this.family, this.wire, this.argb);
  final GlassFamily family;
  final String wire;
  final int argb;                     // base swatch at medium intensity
}

enum Intensity { pale('pale'), medium('medium'), deep('deep');
  const Intensity(this.wire); final String wire; }

final class GlassColor {
  const GlassColor(this.hue, this.intensity);
  final GlassHue hue;
  final Intensity intensity;
  /// Swatch shown in the picker and feed: hue's base lightened or darkened by intensity.
  int get swatchArgb => throw UnimplementedError();
}

/// Default family for the picker, from the wine's type. Sparkling and unknown default to white.
GlassFamily defaultFamilyFor(WineType? type) => throw UnimplementedError();
```

### 3f. `lib/tasting/aroma_wheel.dart`

```dart
/// Dotted path, e.g. 'fruit.red_fruit.cherry'. Stored in the journal and in backups.
/// The wheel is append-only: an id once shipped is never removed or renamed.
/// test/aroma_wheel_test.dart checks every id in test/fixtures/aroma_ids_v1.txt still resolves.
extension type const DescriptorId(String path) {}

final class AromaCategory {
  const AromaCategory(this.id, this.label, this.subcategories);
  final String id;                    // 'fruit'
  final String label;                 // 'Fruit'
  final List<AromaSubcategory> subcategories;
}
final class AromaSubcategory {
  const AromaSubcategory(this.id, this.label, this.descriptors);
  final String id;                    // 'red_fruit'
  final String label;
  final List<AromaDescriptor> descriptors;
}
final class AromaDescriptor {
  const AromaDescriptor(this.id, this.label);
  final DescriptorId id;              // 'fruit.red_fruit.cherry'
  final String label;                 // 'Cherry'
}

/// The wheel itself is Dart const data, not a runtime asset: typed, no async load,
/// and a typo in an id is a compile-visible diff.
const List<AromaCategory> aromaWheel = [
  AromaCategory('fruit', 'Fruit', [
    AromaSubcategory('citrus', 'Citrus', [
      AromaDescriptor(DescriptorId('fruit.citrus.lemon'), 'Lemon'),
      AromaDescriptor(DescriptorId('fruit.citrus.grapefruit'), 'Grapefruit'),
      // ...
    ]),
    // red_fruit, black_fruit, stone_fruit, tropical, dried_fruit ...
  ]),
  // floral, herbal, spice, earth, oak, autolytic, other ...
];

/// O(1) lookup built once from [aromaWheel]. Unknown ids (from a newer backup) resolve to null
/// and are kept on the tasting, rendered as their raw last segment.
AromaDescriptor? descriptorById(DescriptorId id) => throw UnimplementedError();
AromaCategory categoryOf(AromaDescriptor d) => throw UnimplementedError();
```

### 3g. `lib/tasting/tasting_form.dart`

```dart
/// The log screen's editable draft. Immutable with copyWith; held in a Notifier.
/// Unlike TastingInput, score may be absent here.
final class TastingForm {
  const TastingForm._({required this.wine, this.editing, this.score /* ...all TastingInput fields nullable... */});
  factory TastingForm.forCandidate(WineCandidate wine, {Vintage? vintage}) => throw UnimplementedError();
  factory TastingForm.fromTasting(Tasting t, Wine wine) => throw UnimplementedError();

  final WineCandidate wine;
  final TastingId? editing;           // set when editing an existing tasting
  final Score? score;
  // ...

  TastingForm copyWith(/* ... */) => throw UnimplementedError();
  /// Null until score is chosen. The only way to build a TastingInput from UI state.
  TastingInput? toInput() => throw UnimplementedError();
}
```

### 3h. `lib/journal/journal.dart`

```dart
/// One tasting with its wine, the unit every read path consumes.
final class JournalEntry {
  const JournalEntry(this.tasting, this.wine);
  final Tasting tasting;
  final Wine wine;
}

final class WishlistItem {
  const WishlistItem(this.wine, this.addedAt);
  final Wine wine;
  final DateTime addedAt;
}

/// The whole journal, immutable. Entries sorted by tastedAt descending.
/// A personal journal is hundreds to a few thousand tastings (photos are refs, not bytes),
/// so holding it in memory is cheaper than any query layer and makes every read a pure function.
final class JournalSnapshot {
  const JournalSnapshot({required this.entries, required this.wines, required this.wishlist});
  final List<JournalEntry> entries;
  final Map<WineId, Wine> wines;          // includes wishlist-only wines with no tasting
  final List<WishlistItem> wishlist;
  bool isWishlisted(WineId id) => throw UnimplementedError();
  List<JournalEntry> tastingsOf(WineId id) => throw UnimplementedError();
}

final class SavedTasting {
  const SavedTasting(this.tasting, this.wine, {required this.wasWishlisted});
  final Tasting tasting;
  final Wine wine;
  /// True when the wine was on the wishlist at save time. The UI offers removal; Journal never
  /// removes it silently.
  final bool wasWishlisted;
}

/// Read-only view handed to WineFinder, so the finder can annotate hits without write access.
abstract interface class JournalReader {
  Future<List<WineCandidate>> matchWines(String userText, {int limit = 10});
  Future<Map<int, WineId>> wineIdsForIndexIds(Iterable<int> xwinesIds);
}

/// Sole writer of the journal database and the photo directory.
abstract interface class Journal implements JournalReader {
  /// Emits on open and after every committed write (drift table watch, coalesced).
  Stream<JournalSnapshot> watch();
  Future<JournalSnapshot> snapshot();

  /// In one transaction: adopt input.wine (upsert by provenance, or reuse `existing`),
  /// copy the photo into the store, insert the tasting.
  Future<SavedTasting> logTasting(TastingInput input);
  /// Same adopt rules; the wine may change. Replaced photos are deleted after commit.
  Future<SavedTasting> updateTasting(TastingId id, TastingInput input);
  /// Deletes the tasting and its photo. The wine stays (it may be wishlisted or re-tasted).
  Future<void> deleteTasting(TastingId id);

  /// Edit a wine's details (fix a typo in a manual wine). Provenance is unchanged.
  Future<Wine> updateWine(WineId id, WineDetails details);

  /// Idempotent: adding twice keeps the first addedAt.
  Future<Wine> addToWishlist(WineCandidate wine);
  /// Idempotent: removing an absent wine is a no-op.
  Future<void> removeFromWishlist(WineId id);

  /// Used only by Backup. Upserts by id, keeping the row with the newer updatedAt.
  Future<ImportCounts> mergeAll(JournalSnapshot incoming, Map<TastingId, List<int>> photoBytes);
  /// Used only by Backup (restore). Wipes then merges, in one transaction.
  Future<ImportCounts> replaceAll(JournalSnapshot incoming, Map<TastingId, List<int>> photoBytes);
  Future<List<int>?> readPhoto(PhotoRef ref);
}

final class ImportCounts {
  const ImportCounts(this.winesUpserted, this.tastingsUpserted, this.wishlistUpserted);
  final int winesUpserted, tastingsUpserted, wishlistUpserted;
}
```

### 3i. `lib/journal/src/db.dart` (drift, private)

```dart
@DataClassName('WineRow')
class Wines extends Table {
  TextColumn get id => text()();                      // UUID
  TextColumn get name => text()();
  TextColumn get winery => text().nullable()();
  TextColumn get type => text().nullable()();         // WineType.wire
  TextColumn get grapes => text().map(const JsonStringList())();
  TextColumn get elaborate => text().nullable()();
  RealColumn get abv => real().nullable()();
  TextColumn get body => text().nullable()();
  TextColumn get acidity => text().nullable()();
  TextColumn get region => text().nullable()();
  TextColumn get countryCode => text().nullable()();
  TextColumn get country => text().nullable()();
  TextColumn get source => text()();                  // 'xwines' | 'off' | 'manual'
  TextColumn get externalId => text().nullable()();   // null only for manual
  IntColumn get createdAt => integer()();             // epoch ms UTC
  IntColumn get updatedAt => integer()();
  @override Set<Column> get primaryKey => {id};
  // UNIQUE(source, external_id): SQLite treats NULLs as distinct, so manual wines never collide.
  @override List<Set<Column>> get uniqueKeys => [{source, externalId}];
}

class Tastings extends Table {
  TextColumn get id => text()();
  TextColumn get wineId => text().references(Wines, #id)();
  IntColumn get vintageYear => integer().nullable()();
  BoolColumn get nonVintage => boolean().withDefault(const Constant(false))();
  // CHECK (NOT (non_vintage AND vintage_year IS NOT NULL))
  TextColumn get glassHue => text().nullable()();
  TextColumn get glassIntensity => text().nullable()();
  IntColumn get aroma => integer().nullable()();
  IntColumn get flavor => integer().nullable()();
  IntColumn get finishRating => integer().nullable()();
  TextColumn get finishLength => text().nullable()();
  TextColumn get sweetness => text().nullable()();
  TextColumn get body => text().nullable()();
  TextColumn get acidity => text().nullable()();
  TextColumn get tannin => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get scoreTenths => integer().check(scoreTenths.isBetweenValues(10, 50))();
  IntColumn get tastedAt => integer()();
  TextColumn get place => text().nullable()();
  IntColumn get priceMinor => integer().nullable()();
  TextColumn get priceCurrency => text().nullable()();
  TextColumn get photo => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  @override Set<Column> get primaryKey => {id};
}

class TastingDescriptors extends Table {
  TextColumn get tastingId => text().references(Tastings, #id, onDelete: KeyAction.cascade)();
  TextColumn get descriptor => text()();              // DescriptorId.path
  @override Set<Column> get primaryKey => {tastingId, descriptor};
}

class Wishlist extends Table {
  TextColumn get wineId => text().references(Wines, #id)();
  IntColumn get addedAt => integer()();
  @override Set<Column> get primaryKey => {wineId};
}

@DriftDatabase(tables: [Wines, Tastings, TastingDescriptors, Wishlist])
class JournalDatabase extends _$JournalDatabase {
  JournalDatabase(super.e);
  @override int get schemaVersion => 1;
  @override MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: stepByStep(/* generated by `dart run drift_dev make-migrations` */),
    beforeOpen: (d) async => customStatement('PRAGMA foreign_keys = ON'),
  );
}
// Opened with driftDatabase(name: 'journal') from drift_flutter, which runs on a background isolate.
```

### 3j. `lib/insights/stats.dart`

```dart
/// A grouping axis. Each member owns how an entry maps to its keys, so adding an axis
/// is one enum member and the breakdown table needs no new branch.
enum Dimension {
  type, grape, country, region, winery, vintage, priceBand;

  /// Grape is multi-valued: a Grenache-Syrah blend yields two keys. The rest yield 0 or 1.
  Iterable<GroupKey> keysOf(JournalEntry e) => throw UnimplementedError();
}

/// Display label plus a stable sort key (e.g. vintage year, price band lower bound).
final class GroupKey {
  const GroupKey(this.id, this.label, this.sortKey);
  final String id;
  final String label;
  final Comparable<Object> sortKey;
}

/// Price bands are per currency; a USD and a EUR tasting never share a band.
/// Bands in major units: <10, 10-20, 20-40, 40-80, 80+.
GroupKey priceBandOf(Money price) => throw UnimplementedError();

final class Breakdown {
  const Breakdown(this.key, this.count, this.averageScore);
  final GroupKey key;
  final int count;
  final Score averageScore;           // rounded to tenths for display; computed from exact sums
}

final class MonthPoint {
  const MonthPoint(this.month, this.count, this.averageScore);
  final DateTime month;               // first day of month, local
  final int count;
  final double averageScore;
}

final class JournalStats {
  final int tastingCount;
  final int uniqueWineCount;          // distinct wineId with at least one tasting
  final double? averageScore;         // null when empty
  final List<MonthPoint> monthlyAverage;
  final List<(Wine, Score average, int count)> topWines;   // by average, ties by count
  final Map<Score, int> scoreDistribution;                  // per 0.5 bin lower bound
  final Map<Sweetness, int> sweetnessDistribution;          // every member present, 0 if none
  List<Breakdown> breakdown(Dimension d) => throw UnimplementedError();  // memoized per d
  JournalStats._(/* ... */);
}

/// Pure. One pass for totals and distributions; breakdowns grouped lazily per dimension.
JournalStats computeStats(JournalSnapshot s) => throw UnimplementedError();
```

### 3k. `lib/insights/badges.dart`

```dart
/// A quantity that never decreases as tastings are added in chronological order.
/// Monotonicity is what makes "earned at" well defined: it is the tastedAt of the entry
/// at which the metric first reached the threshold.
sealed class Metric {
  const Metric();
  MetricCounter start();
}
final class TastingCount extends Metric { const TastingCount(); /* ... */ }
final class DistinctGrapes extends Metric { const DistinctGrapes(); }
final class DistinctCountries extends Metric { const DistinctCountries(); }
/// Counts which of the given types have been tasted. "Every type" is threshold = types.length.
final class DistinctTypesOf extends Metric { const DistinctTypesOf(this.types); final Set<WineType> types; }
/// The highest tasting count for any single grape key.
final class MaxPerGrape extends Metric { const MaxPerGrape(); }

abstract interface class MetricCounter {
  void add(JournalEntry e);
  int get value;
}

final class BadgeDef {
  const BadgeDef(this.id, this.title, this.description, this.metric, this.threshold);
  final String id;                    // stable, e.g. 'tastings_50'; used to diff before/after
  final String title;
  final String description;
  final Metric metric;
  final int threshold;
}

/// The catalog is data. Adding a badge is one line.
const badgeCatalog = <BadgeDef>[
  BadgeDef('first_tasting', 'First Pour', 'Log your first tasting', TastingCount(), 1),
  BadgeDef('tastings_10', 'Getting Corked', '10 tastings', TastingCount(), 10),
  BadgeDef('tastings_50', 'Cellar Regular', '50 tastings', TastingCount(), 50),
  BadgeDef('tastings_100', 'Centurion', '100 tastings', TastingCount(), 100),
  BadgeDef('grapes_5', 'Grape Explorer', '5 different grapes', DistinctGrapes(), 5),
  BadgeDef('countries_10', 'Globetrotter', 'Wines from 10 countries', DistinctCountries(), 10),
  BadgeDef('every_type', 'Full Spectrum', 'Red, white, rosé, sparkling and dessert',
      DistinctTypesOf({WineType.red, WineType.white, WineType.rose, WineType.sparkling, WineType.dessert}), 5),
  BadgeDef('single_grape_10', 'Devotee', '10 tastings of one grape', MaxPerGrape(), 10),
];

final class BadgeStatus {
  const BadgeStatus(this.def, this.progress, this.earnedAt);
  final BadgeDef def;
  final int progress;                 // min(value, threshold), for progress bars
  final DateTime? earnedAt;           // null while locked
  bool get earned => earnedAt != null;
}

/// Pure. One chronological fold over all entries, one counter per catalog metric
/// (metrics shared by several badges are counted once). O(n * metrics).
List<BadgeStatus> deriveBadges(JournalSnapshot s, {List<BadgeDef> catalog = badgeCatalog}) =>
    throw UnimplementedError();

Set<String> earnedBadgeIds(JournalSnapshot s) => throw UnimplementedError();
Iterable<BadgeDef> newlyEarned(Set<String> before, Set<String> after) => throw UnimplementedError();
```

### 3l. `lib/insights/feed.dart`

```dart
final class FeedFilter {
  const FeedFilter({this.text = '', this.types = const {}, this.minScore, this.from, this.to,
                    this.countryCode, this.grapeKey});
  final String text;                  // matches wine name, winery, grapes, region, place, notes
  final Set<WineType> types;          // empty = all
  final Score? minScore;
  final DateTime? from, to;
  final String? countryCode;
  final String? grapeKey;
  // == and hashCode so Riverpod family caching works
}

List<JournalEntry> applyFeedFilter(JournalSnapshot s, FeedFilter f) => throw UnimplementedError();
```

### 3m. `lib/backup/backup.dart` and the JSON v1 shape

```dart
enum ImportMode { merge, replace }

final class ImportReport {
  final ImportCounts counts;
  final List<String> warnings;        // e.g. "3 unknown aroma descriptors kept as-is"
}

sealed class ImportFailure implements Exception {}
final class NotACorkBackup extends ImportFailure {}
final class NewerFormat extends ImportFailure { NewerFormat(this.version); final int version; }
final class CorruptBackup extends ImportFailure { CorruptBackup(this.path, this.reason); final String path, reason; }

final class Backup {
  Backup(this._journal);
  final Journal _journal;
  /// Streams JSON to disk (photos as base64 one at a time), so memory stays flat.
  Future<File> exportTo(Directory dir) => throw UnimplementedError();
  /// Parses the whole file into domain types first; nothing is written unless parsing succeeds.
  Future<ImportReport> importFrom(File file, {ImportMode mode = ImportMode.merge}) =>
      throw UnimplementedError();
  Future<File> exportCsv(Directory dir) => throw UnimplementedError();
}

// src/format_v1.dart : pure
Map<String, Object?> encodeWine(Wine w) => throw UnimplementedError();
Map<String, Object?> encodeTasting(Tasting t, {String? photoBase64}) => throw UnimplementedError();
/// Throws CorruptBackup with a JSON path ("tastings[12].score") on the first bad field.
({JournalSnapshot snapshot, Map<TastingId, List<int>> photos, List<String> warnings})
    decodeBackup(Map<String, Object?> json) => throw UnimplementedError();
```

```json
{
  "format": "cork.journal",
  "formatVersion": 1,
  "exportedAt": "2026-11-15T19:04:11.000Z",
  "appVersion": "1.0.0+1",
  "wines": [
    {
      "id": "0193a5c2-7b1e-7d4a-9f0e-2c1b4a6d8e01",
      "name": "Barolo Cannubi", "winery": "Damilano", "type": "red",
      "grapes": ["Nebbiolo"], "elaborate": "Varietal/100%",
      "abv": 14.0, "body": "Full-bodied", "acidity": "High",
      "region": "Barolo", "country": {"code": "IT", "name": "Italy"},
      "provenance": {"source": "xwines", "externalId": "100123"},
      "createdAt": "2026-11-01T18:00:00.000Z", "updatedAt": "2026-11-01T18:00:00.000Z"
    }
  ],
  "tastings": [
    {
      "id": "0193a5c3-0000-7000-8000-000000000001",
      "wineId": "0193a5c2-7b1e-7d4a-9f0e-2c1b4a6d8e01",
      "vintage": 2017,
      "color": {"hue": "garnet", "intensity": "medium"},
      "aroma": 4, "flavor": 5, "finish": {"rating": 4, "length": "long"},
      "sweetness": "dry",
      "structure": {"body": "medium_plus", "acidity": "high", "tannin": "high"},
      "descriptors": ["fruit.red_fruit.cherry", "floral.rose", "earth.tar"],
      "notes": "Tar and roses, as promised.",
      "score": 4.4,
      "tastedAt": "2026-11-01T19:30:00.000-05:00",
      "place": "Enoteca Uno",
      "price": {"amountMinor": 6800, "currency": "USD"},
      "photo": {"mime": "image/jpeg", "base64": "..."},
      "createdAt": "2026-11-01T19:45:00.000Z", "updatedAt": "2026-11-02T08:10:00.000Z"
    }
  ],
  "wishlist": [
    {"wineId": "0193a5c2-7b1e-7d4a-9f0e-2c1b4a6d8e01", "addedAt": "2026-10-20T12:00:00.000Z"}
  ]
}
```

Wire rules. `vintage` is an integer year, the string `"NV"`, or absent. `score` is a decimal with one place, parsed to tenths. Enum values use each enum's `wire` field. Absent optional fields are omitted, not `null`. `provenance.externalId` is absent for `"manual"`. The format is decoupled from the drift schema: v1 is written from domain types, so a schema migration never changes the backup format, and a future v2 decoder upgrades v1 JSON in memory before decoding.

### 3n. `lib/app/providers.dart`

```dart
final journalProvider = Provider<Journal>((ref) => throw UnimplementedError()); // overridden in main after open
final wineFinderProvider = Provider<WineFinder>((ref) => throw UnimplementedError());
final backupProvider = Provider((ref) => Backup(ref.watch(journalProvider)));

final snapshotProvider = StreamProvider<JournalSnapshot>((ref) => ref.watch(journalProvider).watch());
final statsProvider = Provider<JournalStats>((ref) => computeStats(ref.watch(snapshotProvider).requireValue));
final badgesProvider = Provider<List<BadgeStatus>>((ref) => deriveBadges(ref.watch(snapshotProvider).requireValue));
final feedProvider = Provider.family<List<JournalEntry>, FeedFilter>(
    (ref, f) => applyFeedFilter(ref.watch(snapshotProvider).requireValue, f));

final searchQueryProvider = NotifierProvider<DebouncedQuery, String>(DebouncedQuery.new); // 120 ms
final offlineSearchProvider = FutureProvider.autoDispose.family<List<WineCandidate>, String>(
    (ref, q) => ref.watch(wineFinderProvider).search(q));   // a newer q disposes the older future's listener
```

`main()` opens the journal and installs the index before `runApp`, then overrides `journalProvider` and `wineFinderProvider`. The splash covers the one-time index copy on first launch after install or upgrade.

## 4. Dependencies

`drift`, `drift_flutter` (bundles `sqlite3_flutter_libs`, a SQLite build with FTS5), `flutter_riverpod`, `go_router`, `http`, `image_picker`, `path_provider`, `package_info_plus`, `uuid`, `share_plus` and `file_picker` for backup, `fl_chart`. Dev: `drift_dev`, `build_runner`.
