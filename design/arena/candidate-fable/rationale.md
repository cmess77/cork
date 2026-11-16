# Cork candidate "fable": rationale

Types, module map, and full call sites are in [sketch.md](sketch.md).

## Problem

Cork is a single-user, offline-first wine journal. Its owner wants check-ins that take seconds and a history that stays correct when a tasting is edited or deleted. Three things make the shape non-obvious. First, a wine can arrive from a bundled FTS5 index, from Open Food Facts, or from a form, and tastings must reference a local `Wine` whatever the source. Second, stats and badges must be derived and never stored. Third, the journal must survive as one JSON file, which means the JSON shape needs versioning for as long as old backups exist, on top of whatever versioning the database needs. Fixed constraints: the read-only asset `assets/wine_index.db` with `wines` and `wines_fts(name, winery, grapes, region, prefix='2 3')`, a separate writable journal database, and Open Food Facts' rule of 10 searches a minute with no search-as-you-type. The project is a fresh `flutter create`, so there is no existing code to honor.

## Usage (caller's view)

Written before the types. Full versions are in sketch.md section 1.

```dart
// Search: results are already Wines, whichever source they came from.
final hits = await lookup.suggest('chât marg');                 // offline, as you type
final online = await lookup.searchOnline('chateau margaux');    // explicit tap: Hits | RateLimited | Unavailable
final byHand = Wine.manual(id: WineId.mintManual(), name: 'Nonna\'s Rosso', type: WineType.red);

// Check in: one synchronous commit, then pure derivations.
final after = store.commit([SaveWine(wine), SaveTasting(draft.build(TastingId.mint())!)]);
for (final badge in newlyEarned(before, after)) celebrate(badge);
if (after.wishlist.containsKey(wine.id)) offerUnwishlist(wine.id);

// Read: every screen watches a pure function of the journal.
final stats = ref.watch(statsProvider);                         // computeStats(journal.feed)
final syrah = ref.watch(feedProvider(FeedFilter(facets: {Dimension.grape: {'Syrah'}})));

// Backup.
final file = await backup.exportJson(includePhotos: true);
switch (backup.preview(text)) { case ImportReady(:final incoming): ...; case ImportRejected(:final reason): ... }
```

## Shape

**The journal is one immutable value.** `Journal` holds three maps: wines by id, tastings by id, wishlist by wine id. It is loaded whole at launch. I estimate a heavy user at one tasting a day for thirty years, about 11,000 records and a few megabytes, so memory is not the limit (an estimate, not a measurement). Feed order, tastings per wine, and "is this hit already mine" are lazy views computed once per value, so there is no index to keep in sync. This is the structure the access patterns ask for, per model-the-domain.

**Writes are idempotent changes through one synchronous writer.** `JournalStore.commit(List<JournalChange>)` applies upserts and deletes by id inside one SQL transaction, then swaps the in-memory value. Running a change twice equals running it once, and a crash leaves either the old journal or the new one, per make-operations-idempotent. The commit is synchronous, so two commits cannot interleave and nothing needs a lock.

**A lookup hit is a `Wine`, and its id comes from its provenance.** `WineId` is `xw:<index id>`, `off:<barcode>`, or `m:<random>`. Adopting a hit is `SaveWine(wine)`. Picking the same index wine twice converges on one record with no uniqueness query, and the same wine has the same id on a second device, which keeps a future merge-import open.

**`WineLookup` is two methods.** `suggest` never touches the network and never throws. `searchOnline` is the explicit-tap path and returns a sealed result. Behind those sit asset installation, FTS5 query escaping, bm25 weighting, merging the journal's own wines ahead of index hits, HTTP, the User-Agent, payload parsing, and the rate limiter. The limiter lives inside the interface, so a caller who wires `searchOnline` to `onChanged` still cannot breach the limit. No row, JSON, or HTTP type crosses the interface, per boundary-discipline. Manual entry is not a lookup method because it needs no lookup. It is a `Wine` constructor.

**Storage is `package:sqlite3` with document rows.** Each table is an id, a foreign key where one exists, and a `doc` column holding the same JSON object the export file holds. One codec and one upgrade ladder serve stored rows and imported backups. The ladder is pure JSON-to-JSON functions tested against JSON fixtures.

**Derivations are pure functions over `Iterable<Entry>`.** `computeStats`, `deriveBadges`, and `filterFeed` take entries, so the same code serves the whole journal and any filtered slice. `Dimension` is one enum registry with a `keysOf(entry)` extractor. Stats breakdowns, feed facets, and badge rules all read it. Badge rules are a const list of four rule kinds. `earnedAt` is found by replaying tastings in date order, so nothing about badges is persisted.

**Invariants in types**, per type-system-discipline. `Score` is integer tenths in 10..50 and `Stars` is 1..5, each behind a checking constructor. `Hue` is one flat enum whose values own their family, so a white-family ruby cannot exist. `Vintage?` separates a year, NV, and not recorded. `Tasting` requires a score while `TastingDraft` does not, and `draft.build` is the only gate between them. Ids are extension types that cannot be swapped.

**Validation lives in three places**: `JournalCodec.decode` for stored and imported JSON, the Open Food Facts and index row parsers, and the forms. Domain code trusts its inputs.

**Vintage belongs to the tasting, not the wine.** The index is vintage-agnostic and the requirements make vintage a check-in field. A `Wine` is a label. "Unique wines" counts labels, and the vintage breakdown groups tastings.

**State management is Riverpod with hand-written providers in one file.** `journalProvider` exposes the current value. `statsProvider`, `badgesProvider`, and `feedProvider` are one-line derived providers. The store is opened before `runApp`, so no screen handles an async journal.

**Interface depth.** The UI sees three facades (`JournalStore`, `WineLookup`, `Backup`) plus pure functions. That is about eight methods covering two databases, a migration ladder, an HTTP client, a rate limiter, a photo store, and two file formats. What stays exposed is the domain model itself, which the screens need in full.

**Deliberately absent**: repositories per entity, DTO classes, reactive SQL queries, stored aggregates, currency conversion, and a wine-delete command.

## Synthesis decision

*To be filled in by arena.*

## Tradeoffs accepted

- We accept holding the whole journal in memory, with launch time growing with journal size, in exchange for stats, badges, filters, and export being pure functions with no query layer.
- We accept document rows that SQLite cannot constrain column by column or query without `json_extract`, in exchange for one codec and one migration ladder. The escape route is generated columns over `doc`, which leave the codec untouched.
- We accept hand-written JSON codecs and no ORM, in exchange for no code generation and no second set of row classes mirroring the domain.
- We accept synchronous SQLite writes on the UI isolate, in exchange for commits that cannot interleave. A single-row commit should be well under a frame (a guess until measured). `replaceAll` on import will block for longer and sits behind a progress dialog.
- We accept `Wine.type` being nullable for Open Food Facts hits, in exchange for not inventing a type the source did not give. Manual entry requires it.
- We accept that `tannin` is not restricted to reds in the type, because rosé and skin-contact whites have tannin. Showing the field for reds is form policy.
- We accept wine ids that depend on X-Wines ids staying stable across index rebuilds. If the parallel workstream renumbers, `xw:` ids break.
- We accept wines that linger with no tastings and no wishlist entry after a delete. They are never counted, because stats iterate tastings.
- We accept enum names as wire names, guarded by a golden-file test that fails on a rename.

## Alternatives considered

- **drift with normalized tables and SQL aggregates for stats.** The mainstream shape. It hides SQL well, but it exposes generated row classes that must be mapped to domain types, adds a build step, and puts stats in SQL where "pure function over tastings" becomes a query per breakdown. It also leaves two migration ladders, one for tables and one for the export file. Its real strength is schema-snapshot migration tests, which the document-row design replaces with JSON fixtures. It lost because its depth is spent on query power this app does not need.
- **sqflite.** Smallest dependency, but it runs on the platform's SQLite, where I believe FTS5 availability varies by Android version (from memory, unverified). The bundled index requires FTS5. It also needs an FFI shim to run in host tests, while `sqlite3` runs real databases under `flutter test`.
- **A single JSON file as the store.** Even less machinery, and the export is a file copy. It lost because every save rewrites the whole journal, and the requirements say SQLite.
- **`WineCandidate` as a separate type with an `adopt()` step.** It keeps `Wine` meaning "in my journal" by type. It lost because it adds a third field list, a provenance uniqueness index, and a dedup query, all of which deterministic ids make unnecessary. Membership is `journal.wines.containsKey(id)`.
- **One `search(query, source)` method.** A smaller surface on paper. It lost because the two paths have different contracts (never fails versus rate limited and fallible), and a `source` argument makes the forbidden as-you-type online call one enum value away.
- **Plain `ValueNotifier<Journal>` with no state package.** Workable, since the root state is one value. It lost because memoized derived values and test-time overrides of `WineLookup` would be hand-built.

## Implementation reconciliation

*Empty until implementation starts.*

## Open questions and risks

- Should a JSON backup carry label photos? The sketch makes it a tick box and inlines base64 in a top-level `photos` map. At roughly 200 KB a photo, 1,000 photos is a file near 270 MB, which will not decode comfortably on a phone (an estimate). Is "journal JSON plus photos as a separate folder or zip" acceptable, or must it be one file?
- Is import replace-only for now? The sketch replaces the journal after writing a safety export. Deterministic ids leave merge possible later.
- Does "Dessert/Port" in the index become its own `fortified` type, or fold into `dessert`? The requirements list six lookup types and five stats types.
- How should price bands treat mixed currencies? The sketch keys bands by currency and never converts. Which band edges do you want, and per currency or shared?
- What generic contact address goes in the Open Food Facts User-Agent? The sketch leaves a TODO and must not ship with personal data.
- Does the bundled `sqlite3` build have FTS5 on Flutter 3.44, and which tokenizer did the index workstream use? Accent-insensitive matching ("chat" finding "Château") depends on `remove_diacritics`. Both need a five-minute check before anything else is built.
- Risk: `suggest` on a short common prefix may rank tens of thousands of rows. If it costs more than a frame on a mid-range phone, the index moves to a long-lived isolate. The interface already returns a `Future`, so callers do not change.
- Risk: installing the index copies a large asset through `rootBundle` on first launch. Its size and peak memory need measuring once the asset exists.
- Should aroma, flavor, and finish ratings be required? The requirements mark only the overall score as required, and the sketch follows that.

## Next implementation step

Write `domain/` (`ids.dart`, `wine.dart`, `tasting.dart`, `journal.dart` with `Journal.apply`) and `data/journal_codec.dart` with a round-trip test over a hand-written `journal_v1.json` fixture, since every other module consumes those types.
