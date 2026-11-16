---
name: Cork
description: A personal wine journal chalked on a tasting-room slate.
colors:
  slate-0: "#0E1214"
  slate-1: "#151A1D"
  slate-2: "#1B2124"
  slate-3: "#21282C"
  slate-4: "#293135"
  slate-5: "#343D42"
  slate-6: "#4F5A60"
  slate-7: "#76838A"
  slate-8: "#A3AEB3"
  slate-9: "#CDD4D6"
  slate-10: "#EDF0F0"
  chalk-white: "#ECE9E1"
  chalk-grey: "#A9B3B7"
  chalk-yellow: "#EBCB6B"
  chalk-yellow-container: "#4A3D10"
  chalk-yellow-on-container: "#F7E3A6"
  chalk-blue: "#94C2D3"
  chalk-blue-container: "#1F4351"
  chalk-pink: "#E9A6B4"
  chalk-pink-container: "#5A2633"
  chalk-red: "#F08C76"
  whitewash: "#F1F2EF"
  whitewash-ink-variant: "#47525A"
  ochre: "#7C6110"
  ochre-container: "#F6E0A0"
  slate-blue-ink: "#2E6577"
  slate-blue-container: "#BFE6F4"
  berry-ink: "#8C4256"
  brick: "#B3361E"
  tablecloth: "#F7F6F1"
typography:
  display:
    fontFamily: "Sofia Sans Extra Condensed"
    fontSize: "57sp"
    fontWeight: 600
    lineHeight: "64sp"
    letterSpacing: "-0.25sp"
  headline:
    fontFamily: "Sofia Sans Extra Condensed"
    fontSize: "24sp"
    fontWeight: 700
    lineHeight: "32sp"
    letterSpacing: "0.4sp"
  title:
    fontFamily: "Sofia Sans Condensed"
    fontSize: "16sp"
    fontWeight: 600
    lineHeight: "24sp"
    letterSpacing: "0.15sp"
  body:
    fontFamily: "Sofia Sans"
    fontSize: "14sp"
    fontWeight: 400
    lineHeight: "20sp"
    letterSpacing: "0.25sp"
  label:
    fontFamily: "Sofia Sans"
    fontSize: "12sp"
    fontWeight: 600
    lineHeight: "16sp"
    letterSpacing: "0.5sp"
  score:
    fontFamily: "Sofia Sans Extra Condensed"
    fontSize: "28sp"
    fontWeight: 700
    lineHeight: "32sp"
    fontFeature: "tnum"
  board-heading:
    fontFamily: "Sofia Sans Extra Condensed"
    fontSize: "16sp"
    fontWeight: 700
    lineHeight: "20sp"
    letterSpacing: "1.2sp"
rounded:
  xs: "4dp"
  sm: "8dp"
  md: "12dp"
  lg: "16dp"
  xl: "20dp"
  full: "999dp"
spacing:
  xs: "4dp"
  sm: "8dp"
  md: "12dp"
  lg: "16dp"
  xl: "24dp"
  xxl: "32dp"
  xxxl: "48dp"
  gutter: "16dp"
components:
  app-bar:
    backgroundColor: "{colors.slate-3}"
    textColor: "{colors.chalk-white}"
    typography: "{typography.headline}"
    height: "64dp"
  navigation-bar:
    backgroundColor: "{colors.slate-3}"
    textColor: "{colors.chalk-grey}"
    typography: "{typography.label}"
    height: "72dp"
  navigation-bar-selected:
    backgroundColor: "{colors.chalk-yellow-container}"
    textColor: "{colors.chalk-yellow-on-container}"
    rounded: "{rounded.full}"
  fab-extended:
    backgroundColor: "{colors.chalk-yellow}"
    textColor: "{colors.slate-2}"
    typography: "{typography.label}"
    rounded: "{rounded.lg}"
    height: "56dp"
  card:
    backgroundColor: "{colors.slate-1}"
    rounded: "{rounded.sm}"
    padding: "16dp"
  chip:
    backgroundColor: "{colors.slate-2}"
    textColor: "{colors.chalk-white}"
    rounded: "{rounded.sm}"
    height: "32dp"
  chip-selected:
    backgroundColor: "{colors.chalk-blue-container}"
    textColor: "{colors.chalk-white}"
    rounded: "{rounded.sm}"
  text-field:
    backgroundColor: "{colors.slate-1}"
    textColor: "{colors.chalk-white}"
    rounded: "{rounded.sm}"
    height: "56dp"
  glass-swatch:
    backgroundColor: "{colors.tablecloth}"
    rounded: "{rounded.full}"
    size: "48dp"
  score-numeral:
    textColor: "{colors.chalk-yellow}"
    typography: "{typography.score}"
---

# Design System: Cork

Source of truth for code: `lib/ui/theme/cork_theme.dart` (ThemeData, `CorkTokens` ThemeExtension, `Slate`, `CorkSpace`, `CorkRadius`, `CorkMotion`) and `lib/ui/theme/glass_colors.dart` (WSET glass hues and intensities). Frontmatter values above are the dark scheme plus the light-scheme ink colors; the Dart file is normative when they disagree.

## Overview

**Creative North Star: "The Tasting-Room Slate"**

Cork looks like the board a cellar door chalks its pours on. A blue-green slate carries everything; text is chalk; scores are chalked in yellow the way a board prices a glass; and each tasting leaves a dry-brush swipe of its actual glass colour, so a scroll through the journal reads as a history of colour before it reads as words. It is a working Android app first: Material 3 structure, navigation, and controls, with the world entering only through palette, type, density, and that one signature move.

Density is medium-high, like a by-the-glass list: rows are compact, figures are tabular and right-aligned, and nothing is decorated. The slate shell (app bar and navigation bar) stays slate in light theme too, so the app keeps its identity in daylight; only the content ground whitewashes.

The rejected defaults are the category's: burgundy, gold foil, and cream paper with an engraved serif, and its predictable opposite, a white Swiss list with one accent.

**Key Characteristics:**
- Slate ground on an eleven-step ramp; tonal depth only.
- Chalk yellow means "your score" or "the main action", nothing else.
- Every tasting carries a chalk swipe in its WSET glass colour.
- Condensed caps for board headings; humanist sans for reading.
- Stock Material 3 components, themed, never re-invented.

## Colors

A committed slate field with chalk on top: neutrals do most of the work, three chalk colours each own one job, and wine colour is data, never decoration.

### Primary
- **Chalk Yellow** (`chalk-yellow`, light theme `ochre`): overall scores, the extended FAB, the selected navigation indicator, slider tracks, focused field outlines. Never used for decoration or headings.

### Secondary
- **Chalk Blue** (`chalk-blue`, light `slate-blue-ink`): selection in chips and segmented buttons, links, the sparkling series in stats, the online-search affordance.

### Tertiary
- **Chalk Pink** (`chalk-pink`, light `berry-ink`): wishlist state (bookmark filled, "On your wishlist"). Rare.

### Neutral
- **Slate ramp** (`slate-0` to `slate-10`): dark theme surfaces. `slate-2` is the board (surface); `slate-0`, `slate-1`, `slate-3`, `slate-4`, `slate-5` are surface containers lowest to highest; `slate-5` is outlineVariant and `slate-7` is outline. `slate-3` is the shell in both themes.
- **Chalk White** (`chalk-white`): primary text on slate (13.4:1 on `slate-2`).
- **Chalk Grey** (`chalk-grey`): secondary text and inactive icons (7.6:1 on `slate-2`).
- **Whitewash** (`whitewash`): light-theme content ground, with containers stepping down to `#D5DAD8`; ink is `slate-2`.
- **Tablecloth** (`tablecloth`): the white every glass swatch sits on, in both themes, because WSET colour is judged against white.

### Wine data colours
Glass colours live in `glass_colors.dart`: 17 hues (whites: water-white, green-yellow, lemon, straw, gold, deep gold, amber, brown; rosés: pale pink, salmon, onion-skin, deep pink; reds: purple, ruby, garnet, tawny, brown), each with a medium base; pale is lerped toward tablecloth (0.55 whites and rosés, 0.42 reds) and deep drops HSL lightness (0.14, reds 0.09) and adds 0.08 saturation. Wine-type series reuse glass colours (red = ruby, white = lemon or gold in light, rosé = salmon or deep pink in light, dessert = amber, sparkling = chalk blue). Aroma wheel categories have eight fixed chalk colours in `CorkTokens` (fruit, floral, herbal, spice, earth, oak, yeast, oxidative).

### Named Rules
**The One Job Rule.** Each chalk colour owns one meaning. Yellow is score and primary action; blue is selection; pink is wishlist. If a new use does not share that meaning, it gets a neutral.

**The Wine Is Data Rule.** Glass colours appear only where they describe a real tasting or a choice in the picker. They never tint chrome, headers, or empty states.

**The Tablecloth Rule.** A glass colour is always drawn on tablecloth white or as a swipe on slate, never as a fill behind text.

## Typography

**Display / Board Font:** Sofia Sans Extra Condensed (bundled variable fonts in `assets/fonts/`, OFL; the app never fetches fonts)
**Title Font:** Sofia Sans Condensed
**Body / Label Font:** Sofia Sans

**Character:** One superfamily at three widths. The extra-condensed caps are the sign-written board; the normal width is for reading notes and labels at arm's length in dim light.

### Hierarchy
- **Display** (600, 57/45/36sp): the overall score on the tasting form and wine detail. Nowhere else.
- **Headline** (700, 32/28/24sp, +0.4 tracking): screen titles in the app bar, badge names on the badge detail.
- **Board heading** (700, 16sp, +1.2 tracking, caps by caller): month headers in the feed, form section heads ("GLASS", "NOSE AND PALATE"), stats section heads.
- **Title** (Condensed 600, 22/16/14sp): wine names in rows and cards.
- **Body** (400, 16/14/12sp): winery, region, notes, settings descriptions. Notes measure stays under 70 characters per line on tablets.
- **Label** (600, 14/12/11sp): buttons, chips, navigation labels, swatch names.
- **Score** (Extra Condensed 700, 28sp, tabular figures, chalk yellow): every score in a list or row, right-aligned.

### Named Rules
**The Right-Hand Figure Rule.** Scores, counts, and prices sit right-aligned in tabular figures tight to the gutter, like prices on a board.

**The Caps Belong to the Board Rule.** Only board headings are set in caps. Wine names keep their own casing.

## Layout

Phones are the target; 16dp side gutter; 4dp base grid with steps 4, 8, 12, 16, 24, 32, 48. Rows are 72dp (two-line) or 88dp (with thumbnail). Every touch target is at least 48dp with 8dp between targets. Edge-to-edge with status, navigation, cutout, and IME insets applied; the shell slate runs under the transparent status and gesture bars.

Navigation is a Material navigation bar on compact width with five destinations: Journal, Wishlist, Stats, Badges, Settings. On expanded width (tablets, unfolded foldables) the bar becomes a navigation rail on `slate-3`, and the wine detail and tasting form gain a two-pane layout (list left, detail right). System Back and predictive back always work.

**The Quiet Pass Rule.** A dense list earns a quiet header: month headers get 24dp above and 8dp below.

## Elevation & Depth

Tonal layering only. Depth is a step along the slate ramp: board (`slate-2`), cards and fields (`slate-1`, one step darker, inset like a chalk tray), menus and sheets (`slate-1` and `slate-3`), dialogs (`slate-4`). `surfaceTint` is transparent, so Material never washes surfaces with primary. Shadows exist only on the FAB (elevation 2, pressed 4) and on modal sheets and dialogs where Material draws them.

**The One Step Rule.** A child surface sits exactly one ramp step from its parent. Two steps means the hierarchy is wrong.

## Shapes

Squarer than stock Material 3, like a wooden-framed board. Cards, chips, fields, and thumbnails 8dp; search bar 12dp; FAB and bottom-sheet top corners 16dp; dialogs 20dp. Buttons keep Material's stadium shape and the navigation indicator stays a pill. Glass swatches are circles. The chalk swipe is the only irregular edge in the system.

## Motion

Material 3 tokens in `CorkMotion`: 150ms short, 300ms medium, 500ms long; standard easing `Cubic(0.2, 0, 0, 1)`, emphasized decelerate `Cubic(0.05, 0.7, 0.1, 1)`, emphasized accelerate `Cubic(0.3, 0, 0.8, 0.15)`. Page transitions use the predictive-back builder. Search result to wine detail uses a container transform; navigation destinations fade through.

The one authored moment: when a tasting is saved, its chalk swipe draws left to right in 350ms with emphasized decelerate on the row it lands in. With Remove animations on (`MediaQuery.disableAnimationsOf`), every transition is an instant cut and the swipe appears complete.

## Components

### Chalk swipe (signature)
A dry-brush stroke 56 by 6dp drawn under a wine name in the tasting's glass colour, left-aligned with the text. Painted with a `CustomPainter`: a band with a ragged, partly transparent leading and trailing edge and two or three thin gaps along its length, seeded from the tasting id so it is stable across rebuilds. On light theme it draws on whitewash with a 1dp `slate-8` underlay for pale whites so water-white stays visible. Used in feed rows, wine detail history, and the stats "glasses" strip. Never animated except on save.

### Glass swatch
A 48dp circle of tablecloth white with a 36dp inner disc of the glass colour and a 1dp `slate-8` hairline so water-white reads. Selected: 3dp chalk-yellow ring outside the tablecloth and the hue name in label-medium below. Every swatch carries its WSET name; colour is never the only signal.

### Buttons
- **Shape:** Material stadium.
- **Filled:** chalk yellow on slate text, for Save and the single primary action per screen.
- **Tonal:** `secondaryContainer`, for Search online, Export.
- **Outlined / text:** Add manually, Cancel, secondary actions.
- **Extended FAB:** "Log a glass" with a wine-glass icon, chalk yellow, 16dp corners, only on Journal and Wine detail ("Log again"). On Wishlist the FAB is "Add a wine".

### Chips
- **Style:** 8dp corners, 1dp outlineVariant border, transparent ground, label-large text, no checkmark.
- **Selected:** `secondaryContainer` fill. Descriptor chips also carry a 8dp leading dot in their aroma category colour.

### Cards / Containers
- **Corner Style:** 8dp.
- **Background:** `surfaceContainerLow` (one step darker than the board).
- **Shadow Strategy:** none.
- **Internal Padding:** 16dp.
- Cards hold one stats block or one badge each. Never nest cards; feed rows are list rows, not cards.

### Inputs / Fields
- **Style:** filled `surfaceContainerLow`, 1dp outlineVariant outline, 8dp corners.
- **Focus:** 2dp primary outline.
- **Error:** 1dp error outline plus helper text naming the fix ("Pick a wine first").

### Score inputs
- **Overall score:** a Material slider 1.0 to 5.0 with 40 divisions (0.1 steps), the current value in Display above it, value indicator on drag, plus minus 0.1 icon buttons either side for exact entry.
- **1 to 5 ratings (aroma, flavor, finish):** five 48dp tap targets in a row, filled chalk dots up to the value; tap the current value again to clear.
- **Ordinal scales (sweetness, body, acidity, tannin, finish length, intensity):** Material segmented buttons; six segments for sweetness wraps to a labelled discrete slider when the width cannot fit six labels at 12sp.

### Navigation
- **Navigation bar:** `slate-3` in both themes, 72dp, chalk-grey icons and labels, selected destination in a `chalk-yellow-container` pill with on-container icon.
- **Top app bar:** `slate-3`, chalk-white headline-small title, light status icons. Large top app bar on Wine detail and Stats, collapsing on scroll.

## Do's and Don'ts

### Do:
- **Do** take every colour from `Theme.of(context).colorScheme` or `Theme.of(context).cork`; never hard-code hex in widgets.
- **Do** right-align scores in the Score style and chalk yellow.
- **Do** draw glass colour only through `glassDisplayColor` on tablecloth or as a chalk swipe.
- **Do** keep the shell slate in light theme.
- **Do** honor Remove animations with instant cuts.

### Don't:
- **Don't** use burgundy, gold foil, cream paper, or an engraved serif.
- **Don't** tint surfaces with primary (`surfaceTint` stays transparent).
- **Don't** use chalk yellow for anything other than scores and the primary action.
- **Don't** put glass colour behind text or use it in chrome.
- **Don't** set wine names in caps or use handwriting fonts; the chalk is in the swipe, not the type.
- **Don't** use emoji or unicode glyphs for icons; use Material Symbols (rounded, weight 400).
- **Don't** stack FABs or put a FAB on the tasting form.

## Screens

Every screen uses the shell (slate app bar, slate navigation bar on top-level destinations) and the 16dp gutter. Copy below is the shipped copy.

### 1. Journal (home feed)
- **App bar:** title "Cork"; actions Search (opens an in-bar search field that filters the feed by wine, winery, grape, region, where, notes) and Filter (opens a bottom sheet).
- **Filter chips row** under the bar when any filter is active: type, score range, date range, country. Each chip removable; "Clear" text button at the end.
- **Summary line** above the list, body-medium chalk grey: "128 tastings · 97 wines · avg 3.8". One line, not tiles.
- **List:** grouped by month, sticky board heading ("NOVEMBER 2026"). Row (88dp): leading 56dp label photo (8dp corners) or, without a photo, a 56dp glass swatch; title-medium wine name, chalk swipe below it, body-medium "Winery · 2019" (or "NV"), body-small "Nov 12 · Bar Brutal"; trailing score in Score style. Tap opens the tasting on Wine detail; long-press opens Edit / Delete.
- **FAB:** extended "Log a glass", collapses to icon on scroll down.
- **Empty:** centered board heading "NOTHING ON THE BOARD YET", body "Log the first glass you taste and it shows up here.", filled button "Log a glass".
- **Filtered empty:** "No tastings match these filters." with a "Clear filters" text button.

### 2. Wine search (step one of logging, also used by Wishlist)
- **Layout:** full-screen route; Material search bar pinned at top, autofocused, hint "Wine, winery, grape or region".
- **Empty query:** "Recent" list of the last 10 wines logged or viewed.
- **As you type (offline):** results update on every keystroke from the bundled index; rows show wine name with the matched prefix in weight 700, "Winery · Region, Country", and a leading 12dp dot in the wine-type series colour plus the type word in label-small. Trailing bookmark icon toggles the wishlist (chalk pink when on). Up to 50 rows, ranked by relevance.
- **Footer, always visible above the keyboard:** tonal button "Search online" (cloud icon) and outlined button "Add manually". Both stay reachable with zero results.
- **Online results:** appear in a second section headed "FROM OPEN FOOD FACTS" with a linear progress bar while loading. States: offline ("You're offline. Your saved wines and the built-in list still work."), rate-limited ("Online search is busy. Try again in a minute."), none ("Nothing online for 'query'. Add it manually."). Online search never fires on typing; editing the query clears online results and re-enables the button.
- **Pick:** tapping a row creates or reuses the local Wine and opens the Tasting form. In Wishlist mode it adds to the wishlist and returns with a snackbar "Added to wishlist".
- **Add manually:** a form screen with name (prefilled from the query), winery, type (segmented: Red, White, Rosé, Sparkling, Dessert), grapes (chip input), region, country (dropdown), vintage (number or NV toggle). Save continues to the tasting form, or to wishlist in that mode.

### 3. Tasting form (new and edit)
Full-screen route, app bar title "New tasting" or "Edit tasting", close icon leading, "Save" text button trailing (enabled once the overall score is set). A filled "Save tasting" button also ends the form. Sections in one scroll, board headings for each; only wine and overall score are required.
- **Wine:** card with wine name, winery, region; "Change" text button; vintage field (number, or NV chip). If the wine is on the wishlist, a chalk-pink line: "On your wishlist. Remove it when you save?" with a switch, default on.
- **OVERALL:** Display score numeral ("3.8"; before a score is set, "Set a score" in headline chalk grey with helper "Required"), slider 1.0 to 5.0 in 0.1 steps, minus and plus buttons.
- **GLASS:** segmented White / Rosé / Red (defaults from wine type); a horizontally scrolling row of glass swatches for that family's hues (whites 8, rosés 4, reds 5); segmented Pale / Medium / Deep below, and the swatches re-render at the chosen intensity. Caption shows the WSET phrase: "Medium ruby".
- **NOSE AND PALATE:** Aroma, Flavor, Finish rows, each a label and five chalk dots (1 to 5). Finish adds a segmented Short / Medium / Long.
- **SWEETNESS:** segmented Bone dry, Dry, Off-dry, Medium-sweet, Sweet, Luscious (falls back to a labelled discrete slider on narrow widths).
- **STRUCTURE:** expansion tile, collapsed by default, "Body, acidity, tannin". Inside: segmented Low / Med- / Medium / Med+ / High for body and acidity, and tannin shown only for red and rosé glasses.
- **NOTES:** selected descriptor chips (removable) and an "Add descriptors" tonal button opening the descriptor picker; then a multiline "Notes" field.
- **DESCRIPTOR PICKER (bottom sheet, expands to full height):** top half shows the aroma wheel, a sunburst of three rings (category, subcategory, descriptor) in the eight aroma category colours on slate. It is a reference: it highlights the current category and every selected descriptor, and tapping a category segment scrolls the list to it, but picking happens below. Bottom half: category tabs (Fruit, Floral, Herbal, Spice, Earth, Oak, Yeast, Oxidative), subcategory board headings, descriptor filter chips. A search field filters descriptors by name. "Done" filled button.
- **CONTEXT:** Date and time (defaults to now; date and time pickers), Where (free text with suggestions from past entries), Price (number field with currency dropdown, default from Settings), Label photo (tile with "Take photo" and "Choose from gallery"; thumbnail with remove once set).
- **On save:** returns to Journal or Wine detail, the new row's chalk swipe draws in, snackbar "Tasting saved" (and "Removed from wishlist" if applicable, with Undo).
- **Edit:** same form, prefilled; overflow menu "Delete tasting" opens a Material dialog "Delete this tasting? Stats and badges will update." with Cancel and Delete.
- **Discard guard:** Back with unsaved changes opens "Discard this tasting?" dialog.

### 4. Wine detail
- **Large app bar:** wine name (headline), "Winery" below, collapsing; actions: wishlist bookmark, overflow (Edit wine).
- **Facts:** two-column key/value grid in body-medium: Type, Grapes, Region, Country, ABV, Source ("X-Wines", "Open Food Facts", or "Added by you").
- **Your verdict:** average score in Display chalk yellow with "from 3 tastings" below; a row of chalk swipes, one per tasting in date order, showing how the glass looked each time.
- **Tastings:** list of this wine's tastings, newest first, row as in the feed but led by date and vintage; tap to expand inline (expand-in-place keeps notes, descriptors, structure, where, price, photo) with Edit action.
- **FAB:** extended "Log again".

### 5. Stats
- **Range:** segmented button at top: 30 days, 12 months, All time.
- **Summary card:** "Average 3.8 · 128 tastings · 97 wines", plus the "glasses" strip: every tasting's chalk swipe in date order, wrapping, so the period reads as colour.
- **AVERAGE OVER TIME:** line chart, monthly mean score with dots sized by tasting count, y-axis 1 to 5, chalk yellow line, chalk grey axes in label-small tabular figures. Fewer than 3 months: "Log a few more months to see a trend."
- **BREAKDOWN:** segmented or scrollable chips for Type, Grape, Country, Region, Winery, Vintage, Price; below, a sortable list (Count, Average) where each row is name, a thin horizontal bar of count in the series colour (type uses wine-type series, others chalk blue), count, and average in Score style. Price bands default to Under 15, 15 to 30, 30 to 60, 60 plus in the default currency (bands are open in PRODUCT.md).
- **DISTRIBUTIONS:** score histogram in 0.5 bins as a dot plot with diameters from the fixed score-dot ramp (6, 9, 12, 16, 22dp); sweetness as six stacked bars labelled with the WSET terms.
- **TOP RATED:** the 10 highest-average wines, rows as on the feed, tap to Wine detail.
- **Empty:** "Stats appear after your first tasting."

### 6. Badges
- **Grid:** two columns of cards. Each card: a 48dp badge mark (Material Symbol in a chalk ring), name in title-medium, rule in body-small ("Taste wines from 10 countries").
- **Earned:** ring and icon chalk yellow, earned date in label-small ("Earned Nov 3, 2026").
- **Locked:** dashed `badgeLocked` ring, icon chalk grey, progress bar and "7 of 10".
- **Sections:** board headings EARNED and IN PROGRESS. Tap opens a bottom sheet with the badge, its rule, and the tastings that count toward it.
- Badges re-derive from the journal on every change; an edit that loses a badge simply moves it back to In progress, no alert.

### 7. Wishlist
- **List:** wines with name, "Winery · Region", added date, chalk-pink bookmark; sort menu (Recently added, Name).
- **Row actions:** tap opens Wine detail; swipe to remove with snackbar "Removed from wishlist" and Undo; trailing "Log" icon button opens the tasting form.
- **FAB:** extended "Add a wine" opens Wine search in wishlist mode.
- **Empty:** "Save wines you want to try. Tap the bookmark in search, or Add a wine."

### 8. Settings
Material list with board-heading groups.
- **JOURNAL:** Default currency (dropdown), Theme (System, Light, Dark).
- **BACKUP:** "Export journal" (JSON, opens the system save dialog; subtitle "Everything: wines, tastings, photos list, wishlist"), "Import journal" (file picker, then dialog "Replace your journal with this backup? Your current 128 tastings will be replaced." Cancel / Replace), "Export tastings as CSV" (subtitle "For spreadsheets").
- **ABOUT:** version, "Wine data from X-Wines (CC0)", "Online search by Open Food Facts (ODbL)", "Your data stays on this phone."
- Feedback is snackbar: "Journal exported", "Imported 128 tastings", errors name the problem ("That file isn't a Cork backup.").

## Decision record

Impeccable's decision page and interviews were not served. The owner's standing directive was to take the number 1 choice at every option point, and this pass ran as a subagent with no question tool. Each point and its alternatives:

1. **Init interview.** Skipped; PRODUCT.md inferred from `docs/REQUIREMENTS.md` and relayed answers, with inferences labelled.
2. **Visitor mode.** Operate (app UI), per impeccable's mode table. Alternatives: none applicable.
3. **Visual world.** Took the lead card of the direction round, the roll's assigned direction (grounded candidate 7 of 7, seed:acf3f3cfca52c471): the tasting-room chalk slate. The grounded list, by resonance: (1) estate label printing, engraved type on cream stock with foil, also impeccable's own pick and the category's most familiar look; (2) the wine-atlas appellation map, flat tinted parcels and italic commune names; (3) the white-tablecloth tilt, glass colour against linen; (4) the restaurant wine list, column rhythm and right-hand prices; (5) the wine-shop shelf talker, kraft card and marker score; (6) the branded cork stamp, the literal reading of the name; (7) the tasting-room chalk slate. The tablecloth tilt survives inside the chosen world as the swatch backing, and the wine list survives as the Right-Hand Figure Rule.
4. **Challengers dealt by the roll, all declined** (each loses on audience identification and product clarity), with the discipline each donated: zoo and gardens guide map, flat unmodulated colour fills with no gradients; acetate tab-board manual, depth used strictly as rank (The One Step Rule); vertical media feed, tasting detail expands in place in lists; star atlas, a fixed magnitude ramp of dot diameters for score distributions; cassette j-card, figures right-aligned tight to the margin; darkroom exposure record, all neutrals snapped to one eleven-step ramp.
5. **Build path.** Code-led (Operate surfaces always are). No image generation was available.
6. **Fonts.** Sofia Sans family via `google_fonts`. Alternatives considered: Barlow plus Barlow Condensed, Roboto with Roboto Condensed (system default).
7. **Dark or light.** Scene: one person logging a glass at a dim bar or dinner table. Dark is the designed-first scheme, light is first-class for daylight at home or in a shop, and the shell stays slate in both. Theme follows the system by default.
8. **DESIGN.md existing-file choice.** Not applicable; no DESIGN.md existed.
