# Cork domain shape (candidate-haiku)

## Problem

Cork keeps all data on the phone, and no server exists to reconcile against. The journal is one writable SQLite file. The bundled `wine_index.db` is read-only and its schema is fixed by a parallel workstream, so the app must adapt to it. Three constraints shape the design. A wine comes from three sources (offline index, Open Food Facts, manual), but a tasting may reference only a local wine. Stats and badges must re-derive after every edit, so they cannot be stored. A backup must restore on another device, so local ids cannot be autoincrement integers, which collide across devices.

## Usage (caller's view)

Search, adopt, and start a check-in:

```dart
// features/wine_search/search_page.dart
final catalog = ref.read(wineCatalogProvider);
final drafts = await catalog.searchIndex('pinot noi');
final picked = drafts.first; // the user taps a row

final adopted = await catalog.adopt(picked); // deduped by provenance
switch (adopted) {
  case Valid(:final value):
    context.push('/tasting/${value.value}');
  case Invalid(:final issues):
    showIssues(issues); // an Open Food Facts hit with no type stops here
}
```

Save a check-in, then ask about the wishlist:

```dart
// features/tasting_editor/tasting_editor_page.dart
final notifier = ref.read(tastingDraftProvider(wineId).notifier);
final snapshot = ref.read(journalSnapshotProvider).requireValue;
final wasWishlisted = snapshot.isWishlisted(wineId);

notifier.edit((d) => d.copyWith(
      glass: const RedGlass(RedHue.ruby),
      intensity: Intensity.medium,
      aroma: Rating.tryFrom(4),
      flavor: Rating.tryFrom(4),
      finish: Rating.tryFrom(3),
      finishLength: FinishLength.medium,
      sweetness: Sweetness.dry,
      overall: Score.fromTenths(42),
    ));

final result = await notifier.save();
switch (result) {
  case Valid():
    if (wasWishlisted) askToRemoveFromWishlist(wineId);
  case Invalid(:final issues):
    showIssues(issues); // one Issue per missing field or broken rule
}
```

Stats and badges for one screen, with a filter:

```dart
// features/stats/stats_page.dart
final stats = ref.watch(statsProvider(const JournalFilter(types: {WineType.red})));
final earned = ref
    .watch(badgesProvider)
    .where((b) => b.earnedOn != null);
```

The call sites use `searchIndex`, `adopt`, `TastingDraft.copyWith` (freezed), `TastingDraftNotifier.edit` and `save`, `JournalSnapshot.isWishlisted`, `statsProvider`, and `badgesProvider`. Each one appears in `sketch.md`.

## Shape

The data structures come first, and each one answers a concrete access pattern.

The journal snapshot is the single input to every derived view. The feed, stats, and badges each read `JournalSnapshot.chronological`, which joins each tasting to its wine once. Each view is a pure function of that snapshot, so nothing derived is stored, which satisfies the badge rule and avoids sync code.

A wine is copied into the journal at adoption. After that save, the journal never reads the index or the network. Provenance is a sealed type (`FromIndex`, `FromOpenFoodFacts`, `FromManual`), and its key is the unique column `externalKey`. Adoption checks that column, so a retried adoption returns the existing wine.

The index is a separate read-only file reached only through `WineCatalog`. Its FTS5 query joins back to `wines` on rowid and ranks with `bm25`. The journal needs no index table, so the two files never share a writer.

Invariants sit in types where the type can carry them. `Glass` is a sealed class over three hue enums, so a red hue on a white glass does not compile. `Vintage` has three states (year, non-vintage, not recorded), so there is no nullable int paired with a flag. `Score` is integer tenths and `Rating` is an int 1 to 5, both built through a checked constructor. Ids are extension types, so a `WineId` cannot be passed where a `TastingId` belongs, and `IndexWineId` cannot be confused with a local id. Per type-system-discipline, ids and scalars are branded and parsed once.

Parsing happens at boundaries, and the domain trusts what it gets. `TastingDraft.build`, `WineDraft.complete`, `JournalCodec.decode`, `AromaWheel.parse`, and `IndexSearch` row mapping are the only places that check input. Inside `lib/domain` the code is pure. Per boundary-discipline, the shell is thin: the Riverpod notifier calls `build()` and then the repository.

Cross-field rules live in one place, `TastingDraft.build()`. The rule that tannin applies only to red glass is a runtime check, not a type. Splitting `Tasting` into a union by glass family would make every consumer branch, and one check in one function costs less. The draft is the only partial shape, so no partial `Tasting` can exist.

Shared state has one owner per file. Only `DriftJournalRepository` writes the journal, and it uses one connection. Import runs in one transaction, so readers see the old journal or the new one. The index file is written once, at copy, and never again. The Open Food Facts rate budget lives inside its client. Per separate-before-serializing-shared-state, the sharing is removed where the files differ, and the one real writer is the repository.

Interface depth: `WineCatalog` exposes three methods and hides two network or file stacks, the index copy, FTS query building, the 10-per-minute budget, the User-Agent header, and provenance dedupe. `JournalRepository` exposes six methods. `JournalCodec` exposes `encode` and `decode`.

Principle check on structure. Per encode-lessons-in-structure, the domain import rule is an architecture test, not a review comment. Per laziness-protocol, the design uses three lookup methods and no event layer, and it stores no aggregates.

Deliberately not in this shape: no stored badges or aggregate tables, no currency conversion, no tombstones or sync, no venue or winery entities, and no remote ids on tastings.

## Synthesis decision

Pending. Arena fills this section.

## Tradeoffs accepted

- We accept two field lists that mirror each other, `Wine` and `WineDraft`, in exchange for a `Wine` that is always complete.
- We accept two field lists that mirror each other, `Tasting` and `TastingDraft`, in exchange for `build()` being the only rule home and no partial tasting existing.
- We accept a full fold over the in-memory snapshot on each change, in exchange for no derived tables to keep in sync. This holds at personal scale and is unmeasured beyond that.
- We accept UUID text keys with larger rows, in exchange for an import that never collides across devices.
- We accept replace-on-import instead of merge, in exchange for an idempotent restore with no tombstones. A tasting logged on a second device and not exported is lost by a restore. Users should see that in the import screen.
- We accept photos inline as base64 in the JSON, in exchange for the single-file backup the requirements name. Large photo libraries make a large file.
- We accept that `Dessert/Port` folds into `dessert` for breakdowns and badges, in exchange for the five-type breakdown the requirements list. The type keeps the detail.
- We accept that tastings store aroma wheel keys and not labels. A relabeled wheel cannot rewrite history, and unknown keys survive import as they are.
- We accept a hand-written tannin rule in `build()` instead of a type-level split, in exchange for one `Tasting` type.

## Alternatives considered

- sqflite instead of drift. It would mean raw SQL strings, hand-written row mappers, and no typed `watch()` streams. drift costs a codegen step, and it gives typed queries and a stepwise migration path. Judged on depth, drift hides the row shape behind generated types.
- Isar, Hive, or ObjectBox. None is SQLite, and the requirements fix the index as SQLite. This was not viable.
- Bloc instead of Riverpod. Each of about fifteen form fields becomes an event, and each screen needs a bloc. That is more ceremony than the state needs. Riverpod's family providers match one draft per wine directly. Taste call, flagged as an open question.
- Per-source lookup services called from the UI. The UI would then know three sources, the rate budget, and the copy step. The single `WineCatalog` port is the same capability behind fewer names.
- Stored stats or badge tables. This contradicts the requirements, and every edit would need a sync path.
- Autoincrement integer ids. This is simpler, but two devices produce colliding ids, so import would need a remap table.
- Vintage on `Wine`. It would split one wine into one record per vintage, and the index has no vintage column. Vintage belongs to the tasting.
- Glass as one enum with a family attribute. It lets a red family carry a white hue. The sealed type removes that state.
- Merge-on-import with `updatedAt` and tombstones. It is correct for two-way sync, which is out of scope, so it adds cost without a requirement behind it.
- Querying the index through drift. The FTS5 virtual table is not declared to drift, so raw `sqlite3` with a fixed SQL string is smaller and clearer.

## Implementation reconciliation

Not started. Implementation fills this section.

## Open questions and risks

- What are the actual `body` and `acidity` values in `wine_index.db`? The sketch keeps them as unverified strings. Should they become enums once the asset is inspected?
- Should the structure scale be three steps (low, medium, high) or five? The requirements say "low to high" without a count.
- Should tannin key on red glass, as drafted, or on a red wine type? A rosé with a deep hue is the case where the two differ.
- Winery is optional in the domain, but the manual form lists it. Should the domain require it, or should only the form?
- The manual form asks for vintage. The draft puts vintage on the tasting, not the wine. Is that the intended model?
- Photos in the export are inline base64. Is a large file acceptable, or should photos be excluded from the backup?
- Import replaces everything. Is that the wanted restore semantics, or is merge-by-id needed?
- Price bands need edges per currency, and no conversion is drafted. Is one display currency enough?
- Should top-rated wines need a minimum tasting count to rank?
- The index size and the first-launch copy time are unknown until the asset exists. A large copy needs a progress state.
- FTS5 availability depends on `sqlite3_flutter_libs`. This needs a device check, since the Android system SQLite may differ.
- Stats cost is unmeasured. If the journal grows past the low tens of thousands of tastings, the same function signature can move to SQL.

## Next implementation step

Write `lib/domain/scalars.dart` and `lib/domain/tasting.dart` with unit tests for `TastingDraft.build()` and `WineDraft.complete()` before any drift or UI code.
