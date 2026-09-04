extends RefCounted

class_name BattleRenderLayers

## Shared canvas ordering for dynamic battle visuals. Keep move effects in
## front of the Pokemon. Trainer art sits above opaque arena platforms but
## behind active Pokemon, while trainer callouts remain readable above moves.
const FIELD := 0
const TRAINER_ART := 1
const POKEMON := 2
const MOVE_FOREGROUND := 50
## Side-condition cards are an informational overlay, so they stay readable
## when they overlap battle-stage art and party previews.
const SIDE_CONDITION_INDICATORS := 110
## Trainer speech must remain above every ordinary battle-stage overlay.
const TRAINER_CALLOUTS := 120
## Compatibility alias for presentation that must remain above move overlays.
const TRAINERS := TRAINER_CALLOUTS
