# Aether training items forum guide

Published in public **Official Guides** (category 13), as `adinho`:
[Aether Training Items – Aether Band & Aether Power Band](https://forums.pokeaether.com/t/aether-training-items-aether-band-aether-power-band/110).

The guide explains prices, personal card credit, the purchase limit per item,
binding, equipping, moving items between the account's Pokémon, PP restoration,
EV yield bonuses, Stored EVs, allocation limits and co-op capture rules.
The prominent upcoming-update notice reflects that the items and Training Items
category are on local development and absent from approved main. No gameplay
deployment was performed.

`guide.md` is the exact published Markdown with Discourse upload references.
`publication.json` records author, category, topic/post IDs, upload references,
rendered preview, anonymous page checks and original-image comparison.
`capture-provenance.json` records revisions, local example data, native UI
controls, image sizes and SHA-256 hashes.

The four PNGs under `0/` are cropped native Godot UI captures: both Gift Store
payment previews, an equipped Aether Power Band and 11 Stored Speed EVs in a
Bulbasaur Summary. They use illustrative local data and no authenticated player
session, running game backend or live purchase. The `0` folder is a capture
target and is unrelated to the forum topic ID. All images were visually reviewed.

## Reproduce screenshots

Run from the game workspace in an assigned frontend slot, replacing `slot-a`
and the absolute output path with the slot assigned to the new task:

```sh
POKEAETHER_GATEWAY_URL=http://127.0.0.1:9 ops/worktrees/slot-env slot-a -- godot \
  --path .worktrees/slot-a/frontend --rendering-method gl_compatibility \
  --audio-driver Dummy --resolution 640x360 \
  --script res://docs/forum-guides/aether-training-items/capture.gd \
  -- /absolute/path/to/capture-output
```

A graphical display is required. The script verifies the absence of a player
session, the Training Items label and the selected personal-credit payment.
It renders existing controls; it neither purchases nor publishes anything.

Gameplay facts were checked against `battle-orchestrator/services/experience_rewards.py`,
wild and co-op reward services, `account-service/services.py`, co-op settlement,
the authoritative item/Store catalogs, and the frontend Party and EV controls.
This task changes only guide artifacts and the changelog.
