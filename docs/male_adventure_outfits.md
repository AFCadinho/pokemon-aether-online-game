# Adaptive adventure outfit collection

Six outfits for male and female trainers from the approved `pokeaether_assets/outfit/overworld/skins/Outfit Designs` collection.

| Outfit | Box item ID | Parts |
| --- | --- | --- |
| Aether Voyager | `aether-voyager-outfit` | top, bottom, shoes |
| Rotom Engineer | `rotom-engineer-outfit` | top, bottom, shoes, facegear |
| Celebi Forest Ranger | `celebi-forest-ranger-outfit` | top, bottom, shoes |
| Lucario Aura Fighter | `lucario-aura-fighter-outfit` | top, bottom, shoes |
| Relic Explorer | `relic-explorer-outfit` | top, bottom, shoes |
| Lugia Sky Captain | `lugia-sky-captain-outfit` | top, bottom, shoes, facegear |

Boxes yield separate `-shirt`, `-trousers`, `-shoes` items; Rotom Engineer and Lugia Sky Captain also yield `-goggles`. Grant a box through the existing local admin item-grant flow and open it in the Bag, then activate its items in Character Customization. These are tradeable fixed-colour cosmetics using the same lifecycle as the Tuxedo outfit. All six boxes are offered in the Aether Gift Store for 350 Aether Gems each (or 350 eligible Gift Voucher credits); loose components are not sold separately.

The same box and part item IDs support both genders. Each unlock declares male and female render variants using the same logical appearance ID. The existing gender-change service retains both ownership and equipped clothing; no database migration, second purchase or duplicate female item is needed.

## Rendering and source mapping

- 120 transparent sheets: 20 parts × 2 models × walking, fishing and riding, each 256×256 (4×4 frames of 64×64).
- Row order: down, left, right, up. Walking columns: idle, step 1, idle, step 2. Run uses the existing walking fallback; surf and mount resolve to ride.
- Tops include each outfit's scarf/gloves where present; goggles use the existing facegear slot. No new equipment slots or animation clocks are introduced.
- The user's selected body, skin tone and hair remain independent. No preview Base or Hair layers are installed.
- `data/male_adventure_outfit_sources.json` records the input layers and SHA-256 of every exported sheet. Layers are composited without scaling or creative edits, in Shirt → Scarf → Gloves order.
- Item names and bag icons cover English, Dutch, Brazilian Portuguese and Simplified Chinese.
- Male trousers and shoes use the existing Starter garment masks for each movement and every frame. Neck openings follow the head movement; front scarves sit lower on the chest. Original face pixels remain uncovered. Two black hip-outline pixels in the walking top keep both idle poses identical without widening the trousers. Female and trainer artwork retain their existing fit.

## Scope

This collection supplies overworld clothing and authored male/female trainer layers. Battle trainers and dialogue portraits resolve their own 160×160 outfit artwork, with scale 1.0. The collection is registered locally, not published or deployed.

## Checks

Run via `game/ops/worktrees/slot-env SLOT -- godot --headless --path PATH`:

- `--script res://tests/male_adventure_outfits_check.gd`: male and female availability, fixed colours, all six movement aliases, exact texture selection/frame sizes, Starter garment masks for every male bottom/shoe frame, localized icons and 36 composited engine renders in slot-local userdata.
- `--script res://tests/appearance_animation_clock_check.gd`: local and remote body/clothing frame synchronization.

Backend: `python -m unittest tests.test_male_adventure_outfits` in the isolated Python 3.13 account-service test environment. Covers all six box/wardrobe/return lifecycles, female box activation and four gender changes per outfit without returning, losing or duplicating items and the 350-Gem Gift Store offers, including bound voucher purchases.

Gender variants are generated from the backend catalog using `tools/generate_cosmetic_variants.py`. All twenty parts now meet the default authored battle-art requirement for both genders; the temporary `battle_rendering: fallback` overrides were removed.

`tests/adventure_outfit_gender_ui_check.gd` applies the actual trainer-service UI response for all six outfits and both genders, checking retained selection, ownership, source items and localized wardrobe names.


## Trainer artwork

Source designs and interactive previews: `pokeaether_assets/outfit/trainer_sprites/Outfit Designs`. Twelve sets use the original male/female trainer bases and 80×80 logical grid, exported at 160×160. Body, face, ball and chosen hair remain independent. Tops include their scarves/gloves; goggles remain separate facegear. The production pipeline registers imagegen clothing onto the existing garment masks and records every runtime layer hash in `data/adventure_trainer_sources.json`.

`tests/adventure_trainer_sprites_check.gd` verifies exact authored paths for all 40 gender/part combinations, full-size scale, twelve engine composites and correctly mirrored dialogue portraits. Existing overworld/gender-change tests remain applicable.
