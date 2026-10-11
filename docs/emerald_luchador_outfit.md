# Emerald Luchador

One gender-adaptive `emerald-luchador-outfit` box contains five independent cosmetics:

| Item ID | Wardrobe category | Appearance ID |
| --- | --- | --- |
| `emerald-luchador-shirt` | Top | `EmeraldLuchador_Shirt` |
| `emerald-luchador-trousers` | Bottom | `EmeraldLuchador_Trousers` |
| `emerald-luchador-shoes` | Shoes | `EmeraldLuchador_Shoes` |
| `emerald-luchador-mask` | Facegear | `EmeraldLuchador_Mask` |
| `emerald-luchador-wings` | Back | `EmeraldLuchador_Wings` |

The box is registered for item grants and opens from the Bag. There is no Gift Store offer or price. Normal box/components use the existing tradeable wardrobe lifecycle; a bound box preserves binding on its contents. Activating each component moves it to Character Customization. Both player models share the same item/appearance IDs and retain ownership through gender changes.

## Art and rendering

The 48 equipment PNGs are copied without modification from the approved `designs/Emerald Luchador/Model Assets` package in `/home/adinho/Documents/pokeaether_assets/outfit`. `emerald_luchador_asset_hashes.json` records their SHA-256 hashes. Trainer textures are 160×160. Overworld sheets are 256×256 with 4×4 64×64 frames, including authored walk, fish and ride poses for both models. Standard movement fallbacks supply running, surfing, mounts, surf fishing and pickpocketing.

The Back item drives `cape` and `cape_overlay`. Its rear sheet is behind the body; the overlay handles the view from behind. The trainer overlay is deliberately transparent. The existing layer rendering order and body animation synchronization apply unchanged. No custom cape simulation is needed.

Mask revision 2 replaces the thin gold eye frame with a black-and-gold wrestling mask inspired by Mega Hawlucha. The eight mask PNGs include forehead and cheek coverage with native eye/mouth apertures, and use the same authored head offsets. The face mask remains open at the back. Other equipment, body sprites, appearance IDs and existing ownership are unchanged. Source material and its registration script are archived in the original asset package.

Dedicated mask activity sheets already contain their head offsets. Local and remote appearance code skips the fallback facegear offset when an authored activity sheet exists. Existing facegear that falls back to walking sprites retains its activity offset.

`data/cosmetic_variants.json` is generated from the paired backend catalog:

```sh
python3 tools/generate_cosmetic_variants.py ../backend/pokemon-data/data/items
```

Focused check: `tests/emerald_luchador_outfit_check.gd`, covering both models, equipment loading, authored poses, trainer art, icons, ownership classification, local/remote synchronization, mask activity offsets and presence serialization. The paired backend test covers opening, activation, gender changes, returning individual parts and bound variants.
