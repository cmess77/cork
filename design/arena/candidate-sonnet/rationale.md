# Cork design rationale (candidate-sonnet)

## Problem

Cork is a single-user, offline Android wine journal. It logs tastings against wines found in a bundled read-only FTS5 index (fixed schema from a parallel workstream), optionally Open Food Facts, or manual entry. It derives stats and badges from the journal and backs up as one JSON file. Constraints the shape honors. The index schema is fixed and has no vintage and no metadata table. The journal is a separate writable DB. Open Food Facts allows 10 searches per minute and forbids search-as-you-type. Badges must never be stored. Tastings reference local wines only. The app is greenfield (`flutter create`, package dir `cork`, Android id `one.bigpapa.cork`), so there is no surrounding system to ground against.

## Usage (caller's view)

Written first; `sketch.md` section 1 holds the three real call sites and section 3 onward was derived from them. In short: `lookup.suggest(q)` and `lookup.searchOnline(q)` both return `WineDraft`s. Manual entry is `WineDraft.manual(...)`. A draft becomes a `Wine` only through `draft.asWine`, which is null until it is complete. `journal.saveTasting(tasting, wine: wine)` is the one write for logging and editing. Stats screens are `Provider`s that apply pure functions (`summarize`, `breakdown`, `evaluateBadges`) to `watchEntries()`. Backup is `exportJson` / `importJson`.

## Shape

**Data first.** The central type is `JournalEntry(tasting, wine)`. Every dominant read (feed, each stat, each badge, CSV) is a pass over `List<JournalEntry>`, so the joined list comes out of one drift stream and everything else is a fold. Nothing asks for an index or cache later, because the access patterns are "all entries, in memory", which is true at personal scale.

**Types carry the invariants** (per type-system-discipline). `Score` is integer tenths in 10..50, so 0.1 steps are exact and there is no float equality. `Rating5` is 1..5. `GlassAppearance` is color and intensity together, never half. `Vintage` is a sealed year, NV, or absent. `WineId` and `TastingId` cannot be swapped. Enums are stored by stable string key, never ordinal. `WineDraft.type` is nullable only because Open Food Facts cannot always classify a hit, and `Journal.saveTasting` takes a `Wine`, so an unclassified draft cannot be persisted.

**Provenance is one string.** `Provenance.key` ("index/xwines-v1/123", "off/<barcode>", "manual") is the only stored form, and everything else derives from it (per encode-lessons-in-structure, derive instead of sync). For index and OFF wines, `WineId` is a UUIDv5 of that key. That makes "adopt this wine" idempotent with no lookup-to-journal handshake. Picking the same wine twice, on two days, or after an import, lands on the same primary key. Wines are inserted only if absent (per make-operations-idempotent), so a later lookup never overwrites the user's corrected copy. A user who opens the log screen, picks a hit, and cancels leaves no orphan Wine row, because the Wine is written inside `saveTasting`'s transaction. The index release string is in the key, so a rebuilt index with renumbered ids cannot collide with old journal wines.

**Lookup interface depth.** `WineLookup` has two query methods and a factory. Behind them sit asset install with a version marker, the read-only sqlite3 handle, FTS5 query sanitizing and bm25 column weighting, stale-query dropping, the OFF HTTP client, User-Agent, a client-side 10/min throttle, and wire-to-domain parsing. Callers see only `WineDraft` and a three-case sealed `OnlineResult`. No FTS strings, JSON, or HTTP types cross the boundary (per boundary-discipline). `suggest` and `searchOnline` are separate methods, not a mode flag, so as-you-type code cannot reach the network by construction.

**Persistence** is drift for the journal, plain `sqlite3` read-only for the index. Drift gives typed tables, compile-checked queries, `watch()` streams that feed Riverpod, and a migration workflow with dumped schemas and generated `stepByStep` upgrades plus tests that upgrade from every released version. The index stays outside drift because it is a replaceable asset with hand-written FTS5 SQL, and drift's table model adds nothing for it.

**Stats and badges** are pure functions in a package that may only import `domain/`. Badges are a const table of `(id, title, target, metric)` over a `Facts` accumulator. One chronological fold evaluates all of them and yields `earnedAt` as the `tastedAt` of the crossing entry, so "earned on" dates are derived too. Adding a badge is a data row. Edit or delete a tasting, the drift stream re-emits, and badges re-derive. There is no badge or stats table to repair.

**Backup** is a versioned JSON document over `JournalSnapshot`, a plain domain value. The codec is pure, so it is tested without files. The decoder is the boundary: it migrates old `formatVersion`s forward, refuses newer, and turns per-record failures into `SkippedRecord`s so one bad row does not lose a restore. Ids are identity, so re-importing is a no-op, and merge replaces a tasting only when the file's `updatedAt` is newer.

**State management** is Riverpod with hand-written providers. Streams from drift, derived `Provider`s for stats, and two overridden singletons (db, lookup) opened in `main()`.

**Structure enforcement.** `test/architecture_test.dart` fails if anything under `domain/` or `stats/` imports Flutter, drift, sqlite3, http, or `dart:io`. That keeps the pure core pure without relying on reviewers noticing.

**Depth summary.** Public surface is about nine methods on `Journal`, two on `WineLookup`, a dozen pure stat functions, and four on `BackupService`/codec. It hides FTS5, OFF, throttling, SQL, migrations, merge rules, and badge crossing dates. Call chains are at most ui -> providers -> one module -> domain, so three files.

## Synthesis decision

Filled in by arena.

## Tradeoffs accepted

- We accept in-memory stats and feed filtering over `watchEntries()` in exchange for one copy of the logic (Dart, unit-testable) and no SQL aggregation. This is correct at thousands of rows and wrong at hundreds of thousands. `watchEntries` is the single place to add paging.
- We accept a nullable `WineDraft.type` (and `asWine`) in exchange for not discarding unclassifiable OFF hits. The null cannot reach persistence.
- We accept that `Wine` is a snapshot copy of the index row rather than a reference, in exchange for the journal rendering and exporting with no index present. Index corrections never propagate to existing journal wines.
- We accept deterministic wine ids from provenance in exchange for idempotent adopt. Two manual entries of the same wine are two wines; there is no fuzzy merge.
- We accept no tombstones: importing an old backup in `merge` mode resurrects tastings deleted since. `replace` is the cure. This is a deliberate non-sync simplification.
- We accept vintage on `Tasting` rather than `Wine`, because the index has no vintage and one label is tasted in many years. Manual entry's vintage becomes `vintageHint`, copied to the first tasting.
- We accept a per-currency-blind price band: bands apply only to the home currency and other currencies are omitted from that breakdown.
- We accept `suggest` on the main isolate first. If profiling on a mid-range phone says otherwise, `OfflineIndex` moves to a worker isolate behind the same signature.
- We accept dessert and port sharing one `TypeGroup` for stats and the every-type badge, while `WineType` keeps both.
- We accept `Score.tenths` default of 3.0 in `Tasting.start`, so the required field always exists, in exchange for an extra UI confirmation requirement.

## Alternatives considered

- **sqflite with hand-written SQL for both databases.** Loses on interface depth: every call site sees SQL strings and manual row mapping, no typed migrations or watch streams, and the pure domain would leak into mappers. It also uses the platform SQLite, whose FTS5 availability across Android versions I have not verified (inferred risk), whereas `sqlite3_flutter_libs` ships its own build.
- **One drift database with the index `ATTACH`ed.** Hides nothing extra, couples the replaceable asset to the user DB's file and lifecycle, and drift codegen cannot model the FTS5 virtual table anyway. Separate files also make index replacement a file swap with no migration.
- **Isar/ObjectBox object store.** Fast typed objects, but cannot open the fixed FTS5 SQLite index, so two storage engines would be needed, and JSON export plus SQL-style group-bys would be hand-built. No gain over drift here.
- **Stats in SQL (views or `GROUP BY` queries) and a stored badge table.** Rejected outright for badges by requirement. For stats it splits logic between SQL and Dart, makes `earnedAt` hard to derive, and tests need a database. The fold-in-memory shape has a smaller surface and more behavior in pure functions.
- **Separate public interfaces per source (`OfflineIndex`, `OffClient`, manual form) selected by the UI.** Pushes FTS, throttling, and rate-limit handling onto every caller, and the three result types would need reconciling in the UI. One `WineLookup` returning `WineDraft` is smaller and safer.
- **Lookup that persists on pick (`lookup.adopt(hit) -> Wine`).** Creates orphan wines when the user cancels, and needs lookup to know about the journal. Deterministic ids plus write-in-`saveTasting` removed the need.
- **Bloc/Cubit or Provider with ChangeNotifier.** Bloc adds an event layer over what is already a stream-in, derive-out graph. ChangeNotifiers would hold derived state that must be kept in sync with the journal, against the derive-don't-sync rule.
- **Event-sourced tasting log.** Gives free history, but is machinery for a requirement (edit and delete, no sync) that plain rows with `updatedAt` already meets.

## Implementation reconciliation

Empty. Fill in during implementation.

## Open questions and risks

- Does `sqlite3_flutter_libs`' bundled SQLite have FTS5 enabled with `bm25()` and `prefix='2 3'` working against the shipped file? I believe so but have not run it. This is the first thing to spike.
- Can the index workstream add a one-row `meta(release TEXT)` table? The sketch hard-codes `OfflineIndex.release = 'xwines-v1'` and bumps it by hand. A mismatch with a rebuilt asset would silently alias wine ids.
- Where does the asset get copied, and how large is it? The sketch assumes copy-to-app-support with a version marker on first run (Android cannot open a Flutter asset in place). First-run copy time and the doubled storage (APK plus copy) need measuring.
- Is the Open Food Facts search endpoint and its wine category filter as I assume (legacy `cgi/search.pl` with `json=1`)? The v2 search API does not do text queries, as far as I know. Verify before building the client.
- Home currency: is a fixed setting (default CAD above is a guess) acceptable for price bands, or should bands be per-currency?
- Should dessert and port be one group in stats and badges, or separate? The requirements list both forms.
- Should `import` in `merge` mode ever delete? The no-tombstone choice means old backups can resurrect deleted tastings.
- Is a default score of 3.0 acceptable, or should the form start empty and block save? The type requires a value.
- Should photos be embedded by default in export? Base64 photos can make the file large; the sketch makes it a flag.
- Is an aroma wheel with a three-level tree final? Descriptor ids are append-only paths; reorganizing categories later would need an alias map.

## Next implementation step

Run a spike that copies `assets/wine_index.db` to app-support, opens it read-only through `sqlite3`, runs the `bm25` MATCH query for `buildMatch('chat bla')` on a mid-range device, and records the latency, before writing any other code.
