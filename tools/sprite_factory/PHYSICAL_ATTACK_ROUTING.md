# Physical attack routing

The routing prototype separates two independent inputs:

- `data/physical_move_animation_intents.json` assigns an anatomical intent to
  moves only when the move is sufficiently unambiguous;
- `physical_attack_human_review.json` records which intent each reviewed native
  model clip visually represents.

`physical_attack_routing_audit.py` first joined those inputs without changing a
model profile or enabling runtime routing. The generated
`physical_attack_routing_dry_run.json` is explicitly
`runtime_approved: false`.

The selection policy is deliberately conservative:

1. an exact reviewed family uses that native clip;
2. if both clips share a family, the established `physical_attack` clip wins;
3. an unclassified move or unsupported family falls back to
   `physical_attack`;
4. no species-name conditions are allowed.

## Current 75-Pokémon result

- 390 physical moves in the frontend move index;
- 119 deliberately classified move intents and 271 safe unclassified moves;
- 29,250 possible species/move pairs;
- 3,058 exact family matches among the classified pairs;
- 1,130 of those exact matches select `physical_attack_2`;
- 5,867 classified pairs safely fall back to `physical_attack`;
- 20,325 unclassified pairs retain the same established fallback.

The low-risk interpretation is not that every move needs a label. The 119
clear intents prove alternate selection works across the cohort, while all
uncertain semantics preserve existing behavior.

## Runtime activation

The screened local catalog now contains an append-only rebuilt scene for 74 of
the 75 reviewed models. For every rebuilt model, the old GLB document entries,
accessors, buffer views, animation definitions and binary payload are a
byte-identical prefix of the new GLB. Only `physical_attack_2` is appended.
Godot then imports and reloads every resulting scene before its digest enters
the checked-in screened registry.

Forty-seven profiles select the alternate clip for at least one classified move
family. Other reviewed profiles keep their primary clip where it is the better
or duplicate semantic match. Unclassified moves always keep the primary clip.

Meowth remains on the established primary attack. Its alternate source contains
a dynamic visibility clock whose timing semantics are not certified, so the
pipeline blocks that clip instead of guessing. This is a generic visibility
gate, not a species exception. `physical_attack_runtime_activation.json`
records the activated and held sets.

## Reproduction

```sh
cd tools/sprite_factory
python3 physical_attack_routing_audit.py \
  --output physical_attack_routing_dry_run.json
```
