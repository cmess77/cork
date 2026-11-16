# Cork architecture

The contract is `design/arena/candidate-fable/sketch.md`, amended by this file. Where the two disagree, this file wins. The other three candidates stay in `design/arena/` as reference for the grafts below.

## Why this base

Four candidates (opus, fable, sonnet, haiku) were judged on six criteria. Fable scored 26, opus 21, sonnet 20, and haiku 13. The coordinator's independent reading agreed. Fable wins on the three criteria that compound over time.

- **One codec, one upgrade ladder.** Stored rows and backup files share the same JSON shape and the same pure `DocUpgrade` functions, so there is one migration story instead of a drift schema ladder plus a backup ladder.
- **Deterministic wine ids.** `WineId` is `xw:<X-Wines WineID>`, `off:<barcode>`, or `m:<uuid>`. Adopting the same wine twice converges with no dedup query, and the same wine has the same id on another device. This is safe because `tool/build_wine_index.dart` stores the X-Wines WineID as `wines.id`.
- **One `Dimension` registry.** Stats breakdowns, feed facets, and badge rules all read one enum, so adding a dimension is one member.

The judge was a Fable model judging a Fable candidate. That is a possible bias, offset by the coordinator reaching the same pick on the rationale alone.

## Grafts

| From | Graft | Replaces in base |
|---|---|---|
| opus 3j | `GroupKey(id, label, sortKey)` returned by `Dimension.keysOf` | bare `String` keys, so vintage and price bands sort correctly |
| opus 3a | `grapeKey()` folds case, accents, and whitespace inside `Dimension.keysOf` | raw grape strings |
| opus 3c | FTS search runs on a long-lived background isolate. The index is installed per app build to app-support with temp-file-then-rename | `suggest` on the UI isolate |
| opus 3m | Export and import stream one photo at a time | whole-file string decode |
| sonnet 5 | `JournalChange` splits `SaveWine` into `AdoptWine` (insert if absent, never overwrite) and `EditWine` | overwriting upsert, which clobbered user edits on re-pick |
| sonnet 3 | `WineType.group` returns a `TypeGroup` of red, white, rosé, sparkling, dessert, or fortified | the hard-coded 6 in `EveryType` |
| sonnet 5 | Saving a tasting of a wishlisted wine takes `removeFromWishlist: bool` in the same commit | a separate follow-up write |
| haiku 1 | `TastingDraft.build()` returns `Checked<Tasting>`, which is either `Valid(value)` or `Invalid(List<Issue>)`, and each `Issue` names its field | a bare `null` |
| haiku 1 | Branded `IndexWineId` and `Barcode` inside `Provenance` | raw ints and strings |
| opus, sonnet, haiku | `Money` stores minor units per ISO 4217 exponent | hundredths for every currency |

## Required fixes to the base

- `Wine.manual` gives `grapes` a default of `const []`.
- A doc-version upgrade at open writes a safety backup before rewriting rows.
- `suggest` keeps returning results while the last token is short. It falls back to the previous results and never blanks between words.
- Journal-owned wines rank ahead of index hits in `suggest`, so manual and online wines can be found again.

## Decisions taken without asking (owner may override)

- **Required fields.** Only the overall score is required. Every other tasting field is optional.
- **Types.** X-Wines `Dessert/Port` maps to `WineType.fortified`. Stats and the every-type badge use six groups.
- **Backup format.** Backup is a `.cork` zip holding `journal.json` and a `photos/` folder. A photo-free plain-JSON export is also offered. Base64 photos inside JSON were rejected, at an estimated 270 MB per 1,000 photos (unmeasured).
- **Import.** Import replaces the journal after writing an automatic safety backup. Merge is left for later. Deterministic ids keep that option open.
- **Price bands.** Bands are per currency: under 15, 15 to 30, 30 to 60, and 60 and over, in major units. The default currency comes from the device locale.
- **Open Food Facts.** The User-Agent is `Cork/<version> (https://git.bigpapa.one/cmess/cork)`. The limiter allows 8 searches per 60 seconds, inside `WineLookup`.
- **Glass enums.** `GlassFamily`, `GlassHue`, and `GlassIntensity` currently live in `lib/ui/theme/glass_colors.dart` from the design pass. They move to `domain/`, and the theme keeps only `glassDisplayColor`.

## Persistence stack

- `sqlite3` plus `sqlite3_flutter_libs`, so Android ships a SQLite build with FTS5 instead of relying on the system SQLite. Verify FTS5 and `remove_diacritics 2` on the emulator before building screens on top.
- The journal uses document rows (`id`, foreign key, `doc` JSON), as the base specifies. `PRAGMA user_version` gates rare table-shape changes.
- State management is Riverpod with hand-written providers in `lib/app/providers.dart`.

## Implementation reconciliation

Deviations found while building, each with its reason. Where an entry here disagrees with the sections above, this entry wins.

- **No `sqlite3_flutter_libs`.** `package:sqlite3` 3.x compiles and bundles its own SQLite (3.53.4, with FTS5) through Dart build hooks, and `sqlite3_flutter_libs` is end-of-life. `integration_test/index_gate_test.dart` proves FTS5 and `remove_diacritics 2` on the device. Measured on the medium_phone emulator, debug build: cold index install 1488 ms, warm 21 ms, first query 5 ms.
- **Fonts are bundled, not fetched.** `google_fonts` downloads fonts at runtime, which breaks the offline-first rule. The OFL Sofia Sans variable fonts live in `assets/fonts/` and `CorkFonts` in `cork_theme.dart` sets both `fontWeight` and the `wght` axis, because a variable font file otherwise renders every weight at its default instance.
