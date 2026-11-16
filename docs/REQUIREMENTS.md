# Cork requirements

Cork is a personal wine journal for Android. Its owner logs each wine they taste and reviews their history. It borrows Untappd's check-in and stats loop. It has no social features and no winery or brewery pages.

## Platform and storage

- Flutter, Android only for now. Package `one.bigpapa.cork`.
- All data lives on the device in SQLite. There is no account and no server.
- Backup is export and import of the whole journal as a single JSON file. CSV export of tastings is a convenience for spreadsheets.

## Wine lookup

Logging a tasting starts by finding the wine.

1. **Offline index, as you type.** A bundled SQLite database built from the X-Wines dataset (CC0, about 100k wines). Columns kept: id, name, type (Red, White, Rosé, Sparkling, Dessert, Dessert/Port), grapes (list), elaborate (varietal or blend), ABV, body, acidity, country code, country, region, winery. Search matches name, winery, grapes, and region with prefix matching and results ranked by relevance. It must feel instant on a mid-range phone.
2. **Online search, on request.** When offline results are not right, a "Search online" action queries Open Food Facts. Its limit is 10 searches per minute per IP, and its docs forbid search-as-you-type, so it runs only on an explicit tap. Requests send a custom User-Agent of the form `Cork/<version> (<contact>)`. The contact must be a generic project address, never personal data.
3. **Manual entry.** The user can always create the wine by hand with name, winery, type, grapes, region, country, and vintage.

Whatever the source, the wine the user picks becomes a local `Wine` record. Tastings reference local wines, never remote IDs directly. The source and its external ID are kept for provenance.

## A tasting (check-in)

- **Wine and vintage.** Vintage is optional or NV.
- **Glass color**, chosen on a visual swatch scale rather than a red or white toggle.
  - Whites: water-white, green-yellow, lemon, straw, gold, deep gold, amber, brown.
  - Rosés: pale pink, salmon, onion-skin, deep pink.
  - Reds: purple, ruby, garnet, tawny, brown.
  - Intensity: pale, medium, or deep. This follows the WSET Systematic Approach to Tasting.
- **Aroma, flavor, and finish**, each rated 1 to 5. Finish also records length as short, medium, or long.
- **Sweetness** on a scale of bone dry, dry, off-dry, medium-sweet, sweet, and luscious.
- **Optional structure fields**, collapsed by default: body, acidity, and tannin (reds), each low to high.
- **Tasting notes** picked as chips from an aroma wheel of category, subcategory, and descriptor (fruit, floral, spice, earth, oak, and so on). The wheel is visible as a reference while picking. Free-text notes are allowed too.
- **Overall score** from 1.0 to 5.0 in 0.1 steps. This is required.
- **Context:** date (default now), where (free text such as a venue or store), price paid with currency, and a label photo from the camera or gallery.

Tastings can be edited and deleted. One wine can have many tastings.

## Wishlist

Save a wine to try later from search or manual entry. Logging a tasting of a wishlisted wine offers to remove it from the list.

## History and stats

- A chronological feed of all tastings, searchable and filterable.
- Overall average score, count of tastings, and count of unique wines.
- Average rating over time as a chart.
- Averages and counts broken down by type (red, white, rosé, sparkling, dessert), grape or varietal, country, region, winery, vintage, and price band.
- Top-rated wines, plus distributions of score and sweetness.

## Badges

Untappd-style milestones computed from the journal, such as first tasting, 10, 50, and 100 tastings, 5 grapes, 10 countries, a tasting of every type, and 10 of a single grape. Badges are derived from data and never stored as separate mutable state, so editing or deleting a tasting re-derives them.

## Out of scope

Friends, feeds, sharing, venues as entities, winery pages, purchasing, and cloud sync.
