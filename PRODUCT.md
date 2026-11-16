# Product

<!-- impeccable:product-schema 1 -->

> Interview substitution: this file was written by a subagent with no question tool. Facts come from `docs/REQUIREMENTS.md` and the owner's relayed answers (offline-first, data on device, wishlist, label photos, where/when/price, badges, WSET tasting color scale). Lines marked *(inferred)* are assumptions to confirm.

## Platform

android

## Stack

Flutter, Material 3 base, Android only. Package `one.bigpapa.cork`. SQLite on device. Existing scaffold answers the stack.

## Users

One person: the owner, a wine drinker who wants to remember what they tasted and how much they liked it. They log a glass at a restaurant table, a bar, a tasting room, a friend's kitchen, or a store, usually one-handed, often in low or warm light, sometimes with no signal *(inferred scene)*. Later, at home, they browse history and stats to decide what to buy again.

## Product Purpose

Cork is a personal wine journal. Each check-in records a wine and a structured tasting. The history and stats loop (feed, averages, breakdowns, badges) turns a pile of check-ins into taste self-knowledge. Success: logging a glass takes well under a minute, and the journal answers "what do I like?" with numbers.

## Positioning

Untappd's check-in and stats loop applied to wine, with none of the social layer, and a tasting form grounded in the WSET Systematic Approach (glass color by hue and intensity, sweetness scale, structure) rather than a bare star rating. Everything works offline from a bundled wine index.

## Operating Context

- Lookup: bundled X-Wines index (about 100k wines, CC0) searched as you type; Open Food Facts only on an explicit "Search online" tap (rate-limited, no search-as-you-type); manual entry always available.
- Tasting fields: wine and vintage (or NV), glass color swatch (white, rosé, red scales) with pale/medium/deep intensity, aroma/flavor/finish 1 to 5, finish length, sweetness (bone dry to luscious), optional body/acidity/tannin, aroma-wheel descriptor chips with the wheel visible, free notes, overall 1.0 to 5.0 in 0.1 steps (required), date, where, price and currency, label photo.
- Wishlist: save a wine to try; logging it offers removal.
- Stats: overall average, counts, average over time, breakdowns by type, grape, country, region, winery, vintage, price band, top rated, score and sweetness distributions.
- Badges: derived from data, never stored as mutable state.
- Backup: whole-journal JSON export/import; CSV export of tastings.

## Capabilities and Constraints

- No account, no server, no cloud sync, no friends, sharing, venue entities, winery pages, or purchasing.
- Online lookup must send `Cork/<version> (<contact>)` with a generic project contact.
- Search must feel instant on a mid-range phone.
- Open: currency default and list *(undecided)*; price band boundaries *(undecided)*; exact badge list beyond the examples in requirements *(undecided)*.

## Brand Commitments

Name: Cork. No other binding assets, logo, or voice exist yet.

## Evidence on Hand

No real tastings, photos, or user data. Any demonstration content is synthetic and must be labeled as such. No invented claims about dataset coverage beyond "about 100k wines".

## Product Principles

1. The check-in is the product. Every screen either gets a glass logged faster or makes past glasses more useful.
2. Structured, not clinical. WSET vocabulary is offered, never demanded; only the wine and the overall score are required.
3. Offline is the normal case. Nothing blocks on the network, and the network is only touched on a tap.
4. The journal is the owner's. Export is complete and import restores everything.
5. Derived, not stored. Stats and badges are computed from tastings so edits never leave stale state.

## Accessibility & Inclusion

No product-specific standard established. Floor: Material 3 contrast, 48 dp targets, sp type honoring system font scale, and color never the only carrier of meaning (glass swatches carry their WSET name) *(inferred)*.
