# Male adventure outfit collection

Six male-only outfits from the approved `pokeaether_assets/outfit/overworld/skins/Outfit Designs` collection.

| Outfit | Box item ID | Parts |
| --- | --- | --- |
| Aether Voyager | `aether-voyager-outfit` | top, bottom, shoes |
| Rotom Engineer | `rotom-engineer-outfit` | top, bottom, shoes, facegear |
| Celebi Forest Ranger | `celebi-forest-ranger-outfit` | top, bottom, shoes |
| Lucario Aura Fighter | `lucario-aura-fighter-outfit` | top, bottom, shoes |
| Relic Explorer | `relic-explorer-outfit` | top, bottom, shoes |
| Lugia Sky Captain | `lugia-sky-captain-outfit` | top, bottom, shoes, facegear |

Boxes yield separate `-shirt`, `-trousers`, `-shoes` items; Rotom Engineer and Lugia Sky Captain also yield `-goggles`. Grant a box through the existing local admin item-grant flow and open it in the Bag, then activate its items in Character Customization. These are tradeable fixed-colour cosmetics using the same lifecycle as the Tuxedo outfit. No shop pricing or public reward source is assigned.

The backend rejects opening or activating these items on female trainers without consuming them. Ownership and gender are also enforced when saving appearance. Female manifests contain none of these male parts.

## Rendering and source mapping

- 60 transparent sheets: 20 parts × walking, fishing and riding, each 256×256 (4×4 frames of 64×64).
- Row order: down, left, right, up. Walking columns: idle, step 1, idle, step 2. Run uses the existing walking fallback; surf and mount resolve to ride.
- Tops include each outfit's scarf/gloves where present; goggles use the existing facegear slot. No new equipment slots or animation clocks are introduced.
- The user's selected body, skin tone and hair remain independent. No preview Base or Hair layers are installed.
- `data/male_adventure_outfit_sources.json` records the input layers and SHA-256 of every exported sheet. Layers are composited without scaling or creative edits, in Shirt → Scarf → Gloves order.
- Item names and bag icons cover English, Dutch, Brazilian Portuguese and Simplified Chinese.

## Scope

This collection supplies overworld clothing. Authored battle trainer layers have not been supplied; battle and dialogue portraits continue to use the existing catalog fallback for these parts. The collection is registered locally, not published or deployed.

## Checks

Run via `game/ops/worktrees/slot-env SLOT -- godot --headless --path PATH`:

- `--script res://tests/male_adventure_outfits_check.gd`: male availability, female exclusion, fixed colours, all six movement aliases, exact texture selection/frame sizes, localized icons and 18 composited engine renders in slot-local userdata.
- `--script res://tests/appearance_animation_clock_check.gd`: local and remote body/clothing frame synchronization.

Backend: `python -m unittest tests.test_male_adventure_outfits` in the isolated Python 3.13 account-service test environment. Covers all six box/wardrobe/return lifecycles, rejected female use without consuming inventory and absence from the Gift Store.
