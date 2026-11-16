# Cork candidate (opus): rationale

## Problem

Cork is a single-user, offline wine journal. Three facts make the shape non-obvious. First, wines arrive from three sources with different rules: a bundled 100k-row read-only index searched on every keystroke, Open Food Facts limited to 10 searches a minute and forbidden from search-as-you-type, and hand entry. Tastings must reference only local wines, with provenance kept. Second, the read side is heavy and varied (feed, filters, a dozen stat breakdowns, badges) while the write side is a handful of commands, and badges must never be stored. Third, the journal must round-trip through one JSON file and survive schema changes for years. Fixed constraints: the index is `assets/wine_index.db` with `wines` and the FTS5 table `wines_fts` (prefix `2 3`), and the journal is a separate writable database. Greenfield otherwise, so Phase A grounding was the requirements and the fresh `flutter create` only.

## Usage (caller's view)

See `sketch.md` section 1. The four call sites are the spec. The search screen calls `finder.search(q)` on every debounced keystroke and `finder.searchOnline(q)` only from a button, switching on a sealed result (`OnlineHits`, `OnlineRateLimited`, `OnlineUnavailable`). Manual entry builds `WineCandidate.manual(details)` and goes down the same path. The log screen calls `form.toInput()`, which is null until a score exists, then `journal.logTasting(input)`, which returns `SavedTasting` with `wasWishlisted`, and diffs `earnedBadgeIds` before and after to celebrate. Stats, badges and the feed are each one `ref.watch` of a provider that applies a pure function to the snapshot. Backup is `exportTo(dir)` and `importFrom(file, mode:)`.

## Shape

**One immutable snapshot, everything derived.** `Journal.watch()` emits a `JournalSnapshot` (all entries joined with their wine, all wines, the wishlist) after every commit. Stats, badges, the filtered feed, the wine detail page and the CSV are pure functions of it (`computeStats`, `deriveBadges`, `applyFeedFilter`). A personal journal is hundreds to a few thousand tastings with photos stored by reference, so it fits in memory. I did not measure that, but 5,000 entries at about 1 KB is about 5 MB, which is a guess with margin. This removes the query layer from the read side entirely. Single source of truth per invariant: the database holds facts, and nothing derived is persisted, so editing or deleting a tasting re-derives badges by construction (per model-the-domain).

**A candidate is a value until saved.** `WineCandidate` (details, provenance, optional `existing` id, optional history) is uniform across sources, so one list widget renders journal hits, index hits, online hits and the manual draft. `Journal.logTasting` and `addToWishlist` adopt the candidate inside the same transaction as the insert. Browsing results never writes a row, and there is exactly one way to create a `Wine`. Adoption is idempotent: `UNIQUE(source, external_id)` means picking the same index or barcode wine twice resolves to the same local wine (per make-operations-idempotent). Details are copied at adoption, so the journal renders and exports without the index or the network.

**One lookup interface, two methods.** `WineFinder` hides FTS query building, bm25 column weights, the background isolate, grapes-JSON parsing, the OFF HTTP client, its User-Agent, the token-bucket limiter and 429 handling. The as-you-type `search` also merges the user's own journal wines first, so a manual or online wine is findable again, and folds index hits the user already adopted into their journal entry. That merge lives at the read boundary instead of in a sync step (per separate-before-serializing-shared-state). Two methods instead of one `search(scope:)` because the two have different triggering contracts, and the type of the second (`Future<OnlineSearchResult>`) forces callers to handle rate limiting. The finder never writes. `Journal` is the sole writer of the journal DB and photo store, and the finder gets only a `JournalReader` view.

**Types carry the invariants.** `Score` is integer tenths (10..50) in an extension type, so 0.1 steps are exact and grouping never compares floats. `Rating` is 1..5. `Vintage` is sealed (`VintageYear`, `NonVintage`) and nullable for "not recorded", and it lives on the tasting because vintage is the bottle, not the label. `GlassHue` is one enum with its family and swatch on each member, so the picker filters one list and white brown and red brown are distinct. `Money` is minor units plus an ISO currency. `TastingInput.score` is non-null while `TastingForm.score` is nullable, so "saved without a score" cannot be constructed. Ids are branded `WineId` and `TastingId` over UUIDs (per type-system-discipline).

**Data, not branches.** The aroma wheel is a const Dart tree with dotted, append-only `DescriptorId`s, and a test pins every shipped id. Stats breakdowns are a `Dimension` enum whose members own `keysOf(entry)`, so a blend counts once per grape and adding an axis is one member. Badges are a catalog of `(id, Metric, threshold)`. Every metric is monotone over a chronological fold, which makes `earnedAt` well defined as the tasting that crossed the threshold, and one pass computes every badge (per model-the-domain).

**Persistence: drift on its bundled SQLite for both files.** The journal is a drift database with step-by-step migrations generated by `drift_dev make-migrations`, schema dumps committed, and generated migration tests. The index is copied from the asset to app support storage once per app build (temp file then rename, so a crash leaves nothing half-written) and opened read-only through the same SQLite build. That build includes FTS5, which is the deciding point over sqflite. Android's system SQLite does not guarantee FTS5 across versions; this is inferred from memory and should be confirmed on the lowest target API before relying on it. Row-to-domain mapping lives in one private file, so column names never leak.

**Backup format decoupled from schema.** JSON v1 is written from domain types with explicit `wire` names on every enum, never `.name`. Import parses the whole file into a snapshot before touching the database, so a corrupt file writes nothing. Merge is upsert by UUID keeping the newer `updatedAt`, so importing the same file twice is a no-op. Photos ride along as base64 and are streamed one at a time on export (per boundary-discipline: parse at the edge, trust inside).

**State: Riverpod without codegen.** Providers memoize the derived views, so stats and badges are computed once per snapshot and shared across screens. `autoDispose.family` drops stale searches. All providers live in `app/providers.dart`, one composition root.

**Modules by domain knowledge.** `wine/`, `tasting/`, `journal/`, `insights/`, `backup/`, `ui/`, `app/`. Each folder's top file is its surface, and `src/` is private, enforced by an import-scanning test because Dart cannot enforce it inside one package (per encode-lessons-in-structure). `wine`, `tasting` and `insights` have no Flutter imports and run under `dart test`.

Interface depth. The public surface is `WineFinder` (2 methods), `Journal` (watch, snapshot, 3 tasting commands, 1 wine edit, 2 wishlist commands, and backup-only bulk methods), and three pure functions. Behind it sit FTS escaping and ranking, isolate hops, an HTTP client with rate limiting, transactional adoption with provenance dedup, a photo store, migrations, and a versioned codec.

## Synthesis decision

*Filled in by arena.*

## Tradeoffs accepted

- We accept recomputing all stats and badges on every write, O(n) over the whole journal, in exchange for zero cached or stored derived state. At a few thousand tastings this is milliseconds (guess, unmeasured).
- We accept loading the whole journal into memory in exchange for every read being a pure, testable function. This looks like a scaling oversight. It is a bet on the size of one person's journal.
- We accept that edits to an adopted index wine diverge from the index, in exchange for a self-contained journal. Provenance is kept, so a "refresh from index" action stays possible.
- We accept base64 photos in the single JSON file, which can reach tens of MB, in exchange for honouring "one JSON file" literally. Photos are downscaled at capture (about 1600 px, JPEG quality 80) to bound it.
- We accept a process-local rate limiter, which resets on app restart, in exchange for no persisted limiter state. A 429 still backs off.
- We accept that import does not propagate deletions (no tombstones), because backup is restore, not sync.

## Alternatives considered

- **Repository per table with SQL-backed stats queries** (`TastingRepo`, `WineRepo`, `StatsDao` with `GROUP BY` per dimension). It lost on depth. Every new breakdown is a new query and a new method, grape stats need JSON unnesting in SQL, and badges' `earnedAt` needs window functions. The caller learns one method per question instead of one snapshot.
- **One `WineSource` interface implemented three times** (index, OFF, manual) with a composite. It lost because it hides the difference that matters. OFF must never run per keystroke, and a uniform `search()` invites exactly that. The candidate type is the uniform part. The triggering policy is not.
- **Adopt on pick** (`finder.adopt(candidate)` returns a `Wine` immediately). It lost because browsing leaves orphan wines and the finder becomes a second writer of the journal.
- **ATTACH the index into the journal connection** so search annotates "already tasted" in one query. It lost because drift's schema verification and migrations would see an attached foreign schema, and replacing the index file on upgrade needs detach and reattach. Two queries merged in Dart cost one `IN` lookup.
- **sqflite.** It lost on FTS5 availability (inferred above) and on the absence of typed queries and generated migration tests.

## Implementation reconciliation

*Empty until implementation starts.*

## Open questions and risks

- Is the overall score the only required field? The sketch makes aroma, flavor, finish, sweetness and color optional so a tasting can be logged in seconds. Should any of them be required?
- Should `Dessert/Port` count as dessert for stats and the "every type" badge, or stay its own `fortified` type in both?
- Will the index workstream guarantee `wines.id` equals the X-Wines WineID across rebuilds? Provenance depends on it. If not, provenance should key on a stable natural key instead.
- Is a base64 single-file backup acceptable at a few hundred photos, or should export produce a zip with `journal.json` plus a `photos/` folder?
- Price bands per currency split a mixed-currency journal into several band sets. Is that right, or should bands convert to one home currency (which needs rates, which needs the network)?
- Which generic contact address goes in the OFF User-Agent?
- Risk: if FTS5 `prefix='2 3'` with single-character queries feels slow, `search` already returns `[]` under 2 characters, but the first-keystroke feel should be checked on a mid-range device.

## Next implementation step

Write `lib/tasting/tasting.dart`, `glass_color.dart`, `lib/wine/wine.dart` and `lib/insights/badges.dart` as real code with `dart test` coverage of score parsing and the badge fold, since every other module consumes those types.
