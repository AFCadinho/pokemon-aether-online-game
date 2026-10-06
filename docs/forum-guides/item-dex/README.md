# Item Dex guide screenshots

Prepared for [Item Dex: Where to Find Items](https://forums.pokeaether.com/t/item-dex-where-to-find-items/95).
These files are a local review pack; the forum post has not been edited.

## Suggested placement and captions

1. Before **Looking up an item**: [Open Item Dex](01-open-item-dex.png).
   Caption: **Open the Item Dex using the book icon in the top-right corner.**
2. After the search instructions: [Search for Heart Scale](02-search-heart-scale.png).
   Caption: **Enter an item name, then select the matching result to see its details.**
3. Under **Understanding WHERE TO GET**: [Read the available sources](03-where-to-get.png).
   Caption: **Check the source, chance, repeatability and requirements before choosing where to collect an item.**
4. Optional follow-up under the same section: [Scroll through fishing sources](04-compare-fishing-sources.png).
   Caption: **Scroll to compare more sources. Different rods have different Fishing requirements and treasure chances.**

The first image includes an editorial arrow and label. All four crops preserve
the original rendered pixels. The `-full.png` files retain the 1920 × 1080
capture frames; `01-open-item-dex-original-full.png` retains the navigation frame
without its annotation.

## Capture provenance

- Real Godot Item Dex controls from `scenes/interface/ui_overlay.tscn` and
  `scripts/ui/ui_overlay.gd`, rendered in a local 1920 × 1080 viewport.
- English locale, desktop layout, default UI scale.
- The actual Pallet Town visual map is used as the background. There is no
  logged-in player or gameplay session. Unrelated HUD panels are hidden for the
  three popup shots.
- Heart Scale metadata comes from the paired backend's
  `pokemon-data/data/items/treasures.json`; acquisition sources come from its
  `pokemon-data/tools/generate_item_sources.py` using local gameplay authority
  files. The shop catalogs were checked: Heart Scale has no shop source.
- The capture uses the UI's existing result-button and selection handlers.
  The item payload is supplied locally; this pack does not verify an online
  login, server search or the production deployment.
- `capture-provenance.json` records source revisions and the captured public
  item payload. `geometry.json` records the original UI bounds.

## Review

Godot capture exited successfully. The capture checked navigation visibility,
the selected Heart Scale name, and all three fishing source cards. All four
crops were visually inspected for readable text, correct icon placement,
scrolling and unobstructed content. Original full frames were retained.

Before publishing, confirm that these screenshots still match the deployed
client. No gameplay code or production data was changed for this pack.
