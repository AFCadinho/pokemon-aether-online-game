# Item Assets

Item icons live under:

`res://assets/items/icons/`

Use item ids from the backend item metadata JSON as the canonical key. UI code should resolve icons through a small item icon service/helper instead of hardcoding individual paths in scenes.

Recommended lookup flow:

1. Normalize the item id, for example `poke-ball`.
2. Try matching an icon file in `res://assets/items/icons/`.
3. Fall back to a default missing-item icon when no exact match exists.

Reward data should continue to use item ids:

```json
{ "id": "potion", "quantity": 2 }
```

## Mega Champions Phase 3 provenance

The 45 Mega Stone icons referenced by `data/mega_champions_catalog.generated.json`
already existed in the tracked item-icon corpus before the rollout work. Their
repository introduction is recorded by commit
`e69fb3c38c2e326fd62e0e0be16465a252ccbf23` (2026-06-20).

The original upstream source and license were not recorded with that import.
They therefore remain blocked from public Mega Champions release until a
licensing review identifies and approves their provenance. Phase 3 does not
import, replace, or publish any item or Pokémon artwork.

## Lift Key icon

`icons/LIFTKEY.png` is an original icon generated with the built-in ImageGen tool.
It is exported as a transparent 48×48 RGBA PNG using nearest-neighbor sampling,
a 24-color palette and binary alpha for crisp pixel edges. The shared
`ItemIconResolver` automatically resolves the canonical `lift-key` item ID to
this filename; no per-screen override or backend change is required.

Generation prompt:

> Use case: stylized-concept. Asset type: a single game inventory pixel-art icon, the Lift Key for a retro monster-catching RPG. Create ONE small traditional metal key, diagonal from bow at upper left to teeth at lower right. Square-rounded brass/gold bow with a small transparent central hole, short silver-gray shaft and two unmistakable key teeth. Match a Nintendo DS/GBA-style inventory icon: constructed on a strict 24 by 24 pixel logical grid, each logical pixel a hard square, 1 logical pixel dark charcoal outline, 3 gold shades and 3 cool silver-gray shades, sparse white highlights upper left. Simple, readable at native 48x48 pixels (24x24 enlarged exactly 2x nearest neighbor). Single centered key occupying about 20x20 logical pixels with transparent padding on all sides. Flat pixel clusters, stepped diagonal edges, no antialiasing, no soft edges, no gradients, no shadow outside the sprite. Genuine transparent alpha background, not a checkerboard. No text, letters, logo, frame, background, drop shadow, or extra objects. Output the pixel icon alone, square composition. This is an original Lift Key inventory sprite in the same visual family as small classic RPG pixel item icons.

## Gold Teeth icon

`icons/GOLDTEETH.png` is original artwork generated with the built-in ImageGen
tool. It is exported as a transparent 48×48 RGBA PNG from a 24×24 logical grid,
using nearest-neighbor sampling, a reduced palette and binary alpha. The shared
`ItemIconResolver` resolves `gold-teeth` automatically for inventory and rewards.

Generation prompt:

> Use case: stylized-concept. Asset type: one small original pixel-art inventory icon for the Gold Teeth quest item in a classic handheld monster-catching RPG. Subject: a recognizable removable GOLDEN DENTURE, a little horseshoe-shaped upper set of golden false teeth, seen from front and slightly above, with a dark hollow interior and 6 chunky individually separated gold teeth forming a smiling U-shaped dental arch. No human face or lips. Style: strict 24 by 24 logical pixel grid, hard square pixel clusters, dark brown one-pixel outline, 3-4 warm gold tones from brown ochre to bright pale yellow, tiny white highlights upper left. Simple silhouette instantly readable at 48x48 final (24x24 doubled). Centered subject about 20 logical pixels wide and 14 high, ample genuinely transparent padding. Keep entire denture visible. No antialiasing, smooth contours, gradients, blurry edges, glow, cast shadow, text, letters, numbers, watermark, frames, checkerboard or extra objects. Generate the single icon alone on actual transparent alpha, square composition.
