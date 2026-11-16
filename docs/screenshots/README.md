# Emulator screenshots

Captured on 2026-11-15 from the Android emulator `medium_phone` (1080 x 2400, API 36), debug build, with `adb exec-out screencap`. The app was driven by `adb input` through one session. All journal content is synthetic demo data typed for this run. The label photo is a screenshot pushed into the emulator's gallery, not a real label.

Light theme, in the order the flow ran:

- `01-journal-empty`: the empty board.
- `02-search`: "chateau marg" typed offline; the bundled index answers per keystroke.
- `04-form-filled`: the tasting form with vintage, score 4.2, deep ruby glass, and ratings.
- `06-descriptor-picker`, `07-picker-selected`: the aroma wheel reference and three picked descriptors.
- `11-form-photo`: notes, where, price, and a label photo from the gallery.
- `12-discard-guard`: Back with unsaved changes.
- `14-stats`, `15-badges`: stats and badges after the first tasting.
- `16-wine-detail`, `17-wine-detail-top`: wine detail with the tasting expanded, and its facts.
- `18-row-menu`: long-press on a feed row.
- `23-saved-snackbar-fab`: the save snackbar lifting the FAB (after the fix).
- `25-wishlist-added`, `26-form-wishlisted`, `29-saved-removed-from-wishlist`: wishlist add, logging a wishlisted wine, and the removal with Undo.
- `31-badges-before-delete`, `32-delete-dialog`, `34-badges-after-delete`: deleting a tasting re-derives badges (Five grapes 3 to 2, Passport 2 to 1).
- `35-edit-form`: editing a tasting.
- `37-settings`, `38-export-save-dialog`, `39-exported`: export through the system save dialog.
- `42-import-picker`, `43-import-confirm`, `45-journal-restored`: import of that file after deleting the last tasting, and the restored journal. The dialog copy in `43` ("Your current 0 tastings") was reworded afterwards for an empty journal.

Dark theme and font scale:

- `46-settings-dark`, `47-search-dark`, `48-form-dark`, `49-journal-dark`, `50-stats-dark`, `51-stats-dark-lower`, `52-badges-dark`.
- `53-journal-font130`, `54-badges-font130`: system font scale 1.3.
