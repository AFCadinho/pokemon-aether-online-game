# Thor outfit and hammer accessory

`thor-outfit` opens into `thor-shirt`, `thor-trousers`, `thor-shoes` and `thor-hammer`. The hammer occupies the existing **Back** wardrobe slot (`cape: Thor_Hammer`): it owns the red cape, visible hammer and electricity together. Armor is independent; the accessory also works with other clothing. Both models share item IDs and retain equipment through a gender change. The items are registered for the existing admin grant flow; this task adds no shop price or offer.

Walking/running raises the cape through three authored silhouettes in 0.16 seconds. Stopping lowers it over 0.30 seconds. The cloth and hammer follow the authoritative body frame, including the head bob and hand grip in each direction. Godot draws short cyan arcs and drifting square sparks along the accessory edges, with occasional sparks at rest. The effect does not alter movement, damage or collision. Rear/front cape planes inherit the actor's depth and visibility; switching cape, removing the hammer or leaving the actor frees both effects. No new multiplayer state is needed: remote avatars use the same appearance and animation hooks.

Walking effect sheets use 96×96 cells (48 native pixels), with transparent padding around the unchanged body origin. This leaves room for the longer lifted cloth and its sparks. Static wardrobe/activity sheets retain 64×64 cells; the resting cloth is pixel-identical after removing the effect padding. The renderer derives cell dimensions from each sheet.

Fishing and mounted activities use separate folded cape sheets, with no walking electricity. Fishing hides the hammer to keep the rod clear. Trainer and dialogue layers retain the approved armor and cape, plus a hammer layer controlled by the same Back item. Skin, hair and faces remain independent. Trousers and boots preserve each original Starter mask, including the original fine pixels in female fishing trousers.

## Rebuild and preview

`python tools/build_thor_outfit.py '/path/to/Outfit Concepts/Thor'` reads the approved hand-authored concept and existing Starter sheets, and exports clothing, three cape states, trainer layers and an asset animation. It never changes the original templates. `python tools/generate_cosmetic_variants.py ../backend/pokemon-data/data/items` updates the shared cosmetic catalog.

For a real Godot render, use the assigned slot environment and a rendering display:

```sh
ops/worktrees/slot-env slot-c -- godot --path .worktrees/slot-c/frontend --rendering-method gl_compatibility --audio-driver Dummy --script res://tools/preview_thor_accessory.gd -- /absolute/output/folder
```

This exports 48 frames with both models and four directions. Run `tests/thor_outfit_check.gd` headlessly in the slot for garment masks, item icons, movement poses, trainer layering, local/remote body synchronization, start/stop timing, activity changes, cape replacement and unequip. `tests/appearance_animation_clock_check.gd` covers the existing clothing animation clock. Backend: `python -m unittest tests.test_thor_outfit` covers ownership, box opening, component return and repeated gender changes.
