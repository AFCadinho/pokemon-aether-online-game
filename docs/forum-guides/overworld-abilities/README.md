# Overworld ability guide

Published in public **Official Guides** (category 13), as `adinho`:
[Overworld Abilities – Natures & Item Drops](https://forums.pokeaether.com/t/overworld-abilities-natures-item-drops/109).

The guide covers Synchronize, Compound Eyes, Super Luck and Pickup, including
lead placement, fainted Pokémon, example drop rates, level-based Pickup items,
co-op ownership and moving non-equipment items into the Bag. The prominent
upcoming-update notice reflects that these mechanics are on local development,
not the approved main release. No gameplay deployment was performed.

`guide.md` is the published Markdown, including Discourse upload references.
`publication.json` records the topic, post, author, category, image uploads and
anonymous public-page/image verification. `capture-provenance.json` records
source revisions, native controls, screenshot dimensions and hashes.

The three PNGs under `0/` are native Godot UI captures with local example Abra
and Meowth data. They show the party leader, Synchronize with Modest, and a
Pickup holder carrying an Antidote with **Take held item** available. No live
player account, session or game backend was used. All images were visually
reviewed before publication. The `0` folder is a local capture target and is
unrelated to forum topic IDs.

## Reproduce screenshots

Run from the game workspace in the assigned slot. Replace `slot-a` and the
absolute output path with the slot assigned to the new task:

```sh
POKEAETHER_GATEWAY_URL=http://127.0.0.1:9 ops/worktrees/slot-env slot-a -- godot \
  --path .worktrees/slot-a/frontend --rendering-method gl_compatibility \
  --audio-driver Dummy --resolution 640x360 \
  --script res://docs/forum-guides/overworld-abilities/capture.gd \
  -- /absolute/path/to/capture-output
```

A graphical display is required. The script asserts that it has no player
session and that the Pickup holder exposes the Take action. It renders and
crops existing interface controls; it does not publish anything.

Gameplay facts were checked against `battle-orchestrator/services/` encounter
and drop authorities, `account-service/pickup_services.py`, the Pickup pool,
and the frontend Party, Summary and PC item controls. This task changes only
guide artifacts.
