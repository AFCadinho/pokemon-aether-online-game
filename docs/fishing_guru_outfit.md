# Fishing Guru Outfit Box

Grant `fishing-guru-outfit` through Dev Tools → Add Item; search **Fishing Guru**.
The box supports the **male** model and opens into six separately activated,
fixed-colour wardrobe items:

| Item | Wardrobe slot | Appearance ID |
| --- | --- | --- |
| `fishing-guru-shirt` | Top | `Fishing_Guru_Vest` |
| `fishing-guru-trousers` | Bottom | `Fishing_Guru_Trousers` |
| `fishing-guru-shoes` | Shoes | `Fishing_Guru_Shoes` |
| `fishing-guru-hair` | Hair | `Fishing_Guru_Hair` |
| `fishing-guru-hat` | Headgear | `Fishing_Guru_Hat` |
| `fishing-guru-rod` | Back | `Fishing_Guru_Rod` |

Open the box in the Bag, then activate its six parts in the Bag to unlock them
in Character Customization. Items use the existing tradeable wardrobe rules;
a bound box keeps all its contents bound. Incompatible models cannot consume
the box or components. The rod is a cosmetic Back accessory and does not grant
a functional fishing tool. No role restriction or store offer was added.

## Artwork

The 28 overworld sheets are byte-identical to the reviewed `accessories-02-rod`
experiment. They are 256×256 RGBA with a 4×4 grid, in down/left/right/up row
order. Running explicitly uses the existing walking gait. Fishing and riding
use authored static directional holds; standard movement aliases resolve to
those sheets. The carried rod is deliberately hidden in fish because that
approved body already holds a rod. Hair and headgear include authored activity
alignment, so the existing local/remote code skips extra fallback offsets.

Seven matching trainer layers use the separate approved male trainer base,
a 160×160 canvas and exact 2× logical pixels. Vest, rolled sleeves, bucket hat,
rod, reel and line are new registered pixel drawing. Starter trouser, shoe and
hair silhouettes are attributed template adaptations. The trouser overlay is
cleared at the free hand to preserve the base's fingers and outline. No body
sprites were changed. Rebuild/check with:

```sh
python tools/build_fishing_guru_trainer.py
python tools/build_fishing_guru_trainer.py --check
```

The rod uses paired cape/cape_overlay layers under one equipped Back item,
behind the body and above clothing respectively. Trainer card, dialogue and
item icons use the actual trainer catalog; no enlarged overworld cel or default
shirt/trouser fallback substitutes for trainer artwork. Colors stay fixed even
when the player's ordinary hair color changes. `fishing_guru_asset_hashes.json`
records all 35 new art files and the trainer template sources.

## Focused checks

- `tests/fishing_guru_outfit_check.gd`: all movement aliases and exact resource
  paths, four directions/four frames, local/remote synchronization, authored
  head alignment, fixed color, protected trainer face/hand/ball pixels,
  separate Back removal, portrait/icons, gender eligibility and four locales.
- Backend `tests.test_fishing_guru_outfit`: box opening, activation, ownership,
  returning parts, bound contents, incompatible gender rejection, dev search
  and absence of an unapproved store offer.
- `tools/generate_cosmetic_variants.py ../backend/pokemon-data/data/items --check`.
- Installed `pokeaether-pixelart/scripts/check_trainer_layers.py`: selected
  authored manifest entries, explicit scale/canvas, alpha and pixel grid.

The local `pokeaether-pixelart` skill now requires matching trainer art when
finishing a complete game outfit/box, with a separate trainer workflow and
validator. The original professional artist assets remain read-only.

## Scope

This is a local development integration, not a deployment or a priced Gift
Store listing. A female fit has not been authored. The trainer sprite has been
reviewed in direct and game-portrait orientations; professional artist review
is still useful for the hat's fairly geometric cloth planes and the subtle
reel at native size.
