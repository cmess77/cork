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
- **No `TypeGroup`.** The six groups ARCHITECTURE names are exactly the six `WineType` values, so a second enum would be a 1:1 copy. Stats group by `WineType` and `EveryType.target` is `WineType.values.length`.
- **Glass enums keep the design-pass names and colours.** `GlassFamily`, `GlassHue`, `GlassIntensity`, and `GlassColor` live in `lib/domain/glass_color.dart` with each hue's medium colour as an `argb` int. The theme keeps only `glassTablecloth` and `glassDisplayColor`. The sketch's `Hue`/`ColorFamily`/`Intensity` names and swatch values were superseded by DESIGN.md.
- **`TastingDraft` is mutable form state.** It lives in one form's `State` and mirrors its controls, so `copyWith` with clearable nullable fields would only add ceremony. Vintage and price are held as the text the user typed, and `build()` parses them, returning `Invalid` with an `Issue` per field (`score`, `vintage`, `price`). `TastingDraft.edit(tasting, wine)` replaces `Tasting.toDraft()`.
- **Unrecorded values have no group.** `Dimension.keysOf` yields nothing for a missing type, region, country, vintage, or price, instead of an "Unspecified" group. Breakdowns show only what was recorded.
- **Stats shapes.** `Tally` keeps the tenths sum so means are exact. `scoreBins` is nine half-point bins (1.0 to 1.4 through 5.0) rather than a `Map<Score, int>`. `GroupStat.key` is a `GroupKey`.
- **`Journal` is not const.** Its derived views (`feed`, `tastingsOf`, `recentWines`) are `late final`, computed once per value. `recentWines` replaces `myWines` and includes wines with no activity left, so a hand-entered wine whose only tasting was deleted can still be found.
- **Aroma wheel.** Categories are keyed by an `AromaFamily` enum whose colours are the eight `CorkTokens` aroma tokens, instead of an `argb` per category. Descriptor ids derive from labels as `family.subcategory.descriptor` slugs, and `test/golden/descriptor_ids.txt` keeps the vocabulary append-only.
- **Badges.** Two rules beyond the sketch: Passport (3 countries) and Regional tour (10 regions). Each rule has a `description` for the badge card, and `BadgeStatus.counted` lists the tastings that count toward it for the badge sheet.
- **`Country.code` is nullable**, for a country typed by hand with no ISO code. `FeedFilter` gains `maxScore`, and its facets hold `GroupKey.id`s.
- **`BundledWineLookup.open` takes plain values, not `AppDirs`.** Its parameters are `indexDir`, `loadAsset`, `journal`, and `appVersion`. `AppDirs` does not exist yet, and `loadAsset` lets host tests install a fixture index the same way the device installs the bundled one. The facade builds its own `OpenFoodFacts`, so nothing outside `lookup/` names that class or `package:http`. `open` throws when the index cannot be installed or opened. After that, `suggest` never throws, and an index failure degrades to journal-only results.
- **Index search is split across three pieces.** `installWineIndex` is a function. `WineIndex` is the synchronous read-only connection. `IndexWorker` owns a `WineIndex` on one long-lived isolate. `FtsQuery` is a class that carries its tokens, not an extension type, because the journal match and the ranking tier reuse them. Each FTS token is lower-cased but not folded, because unicode61 does not fold `ß`. Journal matching folds both sides with `fold`.
- **A name-prefix tier on top of bm25.** Of the top 200 bm25 rows, wines whose folded name starts with the typed words, in order, come first. Plain bm25 put `Margaux du Château Margaux` first for "chateau marg" and the grand vin fourth. With the tier the grand vin is first, and `test/lookup/wine_index_test.dart` fails without it. Measured on the medium_phone emulator, debug build, one run of 55 keystrokes: p50 14.8 ms, p95 37.8 ms, max 43.2 ms.
- **An index hit already in the journal shows the journal's copy at the hit's rank**, even when the journal copy no longer matches the typed words (the user renamed it). It is never dropped and never shown twice.
- **Open Food Facts uses `cgi/search.pl`.** OFF documents v1 as the only server API with full-text `search_terms`, and `/api/v2/search` filters by tag only. The query sends `tag_0=en:wines` with `tagtype_0=categories` and a `fields` list. The one live probe got HTTP 503, which the OFF docs give as the response when the global search limits are exceeded, so 503 maps to `OnlineUnavailable`. Search-a-licious (`search.openfoodfacts.org`) is the documented successor for full-text search, and moving there changes only `_searchUri` and `parseProducts`. `origins_tags` map to the index's own country codes and names (X-Wines writes `UK`), and only when the product has exactly one origin.
- **Photos are downscaled by the picker.** `image_picker` is called with a 1600 px bound and JPEG quality 85, so `PhotoStore.add` only hashes and writes (temp then rename). This avoids a pure-Dart image codec on the UI isolate.
- **Backup API.** `Backup.preview` takes the picked file's path, not its text, and tells a `.cork` zip from plain JSON by its magic bytes, reading only `journal.json` from the zip. `Incoming` keeps the source path so `restore` streams photos out of the zip one at a time. `restore` returns the safety backup, which is a full `.cork`. Problems are `NotCorkBackup`, `BackupTooNew`, and `BackupDamaged(path, detail)`, each with the snackbar message. The file-level parse (`encodeJournalFile`, `decodeJournalFile`) is pure and lives in `journal_codec.dart`.
- **Upgrade safety backup is the composition root's job.** `JournalStore.open(path, beforeUpgrade:)` hands the old raw docs to the callback before it rewrites any row. With one doc version so far, the ladder function is tested with a fake two-step ladder, and the store's upgrade branch cannot run yet.
- **Settings live outside the journal.** Default currency and theme are a small `settings.json` (`SettingsStore`), so importing a backup never changes preferences.
