# Store outfit preview appearance

Store product cards use a consistent, restrained hairstyle for each trainer
model. Outfit detail previews use the player's own hair and saved hair colour.
Hair supplied by the outfit always takes precedence, including its fixed or
selected Chroma colour. An explicitly bald trainer stays bald in a normal detail
preview. Cross-model previews and missing appearance data use the matching
model's neutral profile.

The rules live in `data/store_preview_appearance.json` and are resolved by
`scripts/services/store_preview_appearance_policy.gd`. Both the Store icon
renderer and live character preview use this resolver. It does not modify
outfit contents, unlocks, saved appearance, equipped clothing or checkout data.
Inventory icons use a separate cache and do not acquire Store presentation hair.
The shared battle-icon compositor now also renders a requested base body/head
and copies source images before scaling them, so repeated renders remain stable.

## Rule format and precedence

The versioned configuration has four sections:

- `defaults`: `card` is `neutral`; `detail` is `player`.
- `neutral_hair`: existing hair ID and fixed colour for `male` and `female`.
- `outfits`: optional overrides keyed by canonical product ID.
- `headgear`: compatibility rules keyed by appearance part ID.

Modes are `player`, `neutral`, `hidden` and `custom`. A custom rule has a `hair`
map with `male` and/or `female` profiles, each containing `id` and `color`.
The priority is included outfit hair, then explicit outfit rule, then headgear
rule, then the context default. A missing custom gender profile uses that
gender's neutral hair, never another model's art. Bound product aliases resolve
to the same outfit rule. Player mode on a card also uses the neutral profile,
keeping catalog cards independent of the viewer's appearance.

For example, an authored helmet can use:

```json
"example-helmet-outfit": {
  "card": "hidden",
  "detail": "hidden"
}
```

An outfit needing shorter compatible hair can use:

```json
"example-hat-outfit": {
  "detail": "custom",
  "hair": {
    "male": {"id": "Aether_Male_Hair_01", "color": "#5a3728"},
    "female": {"id": "Hair", "color": "#6b4632"}
  }
}
```

These are format examples, not active products. Use authored, model-compatible
hair and visually check the relevant hat/helmet before adding a live override.
Partial clipping requires appropriate existing hair art or a separately authored
compatible profile; the resolver does not invent cropped sprites.

## Current exceptions

The full Mysterious hood hides presentation hair in both contexts, preventing
large hairstyles from protruding through its silhouette. The starter Cap and
Aether Royal Crown use neutral compatibility hair. Ordinary outfits and goggles
keep the default behaviour. Included hairstyles such as Classic, IronFanton and
Aether Blossom are preserved even when a compatibility rule exists.

Store cards insert presentation hair below beard, headgear and facegear layers.
Detail previews keep the existing directional layering. Outfits without included
hair show a localized note that the hairstyle is not part of the purchase.
Colour experiments on another product do not recolour the player's presentation
hair, and presentation hair never enters Chroma checkout colours.

## Checks and render examples

Run these focused checks through the assigned slot environment:

```sh
ops/worktrees/slot-env slot-a -- godot --headless --path .worktrees/slot-a/frontend --script res://tests/store_preview_hair_policy_check.gd
ops/worktrees/slot-env slot-a -- godot --headless --path .worktrees/slot-a/frontend --script res://tests/donator_store_cosmetic_subtabs_check.gd
ops/worktrees/slot-env slot-a -- godot --headless --path .worktrees/slot-a/frontend --script res://tests/male_adventure_outfits_check.gd
```

The policy check covers priorities, hidden/custom profiles, cross-model fallback,
bald players, included hair, layer ordering, isolated caches, localization,
unchanged saved appearance and checkout colours, stable source images and the
base head/body. It saves `store_preview_hair_cards.png` and
`store_preview_hair_details.png` to slot-local `user://` storage for visual review.

Card comparison columns are Voyager, Rotom Engineer, Mysterious, Classic,
IronFanton and Blossom. Rows are ordinary item icon / Store icon for a male
viewer, then the same pair for a female viewer; gender-restricted products use
their supported model. Detail comparison rows use male/female trainers with a
blue hairstyle, making preserved personal hair and outfit/headwear overrides
visible. Render artifacts stay outside source control.
