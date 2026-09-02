extends RefCounted

class_name BattleRenderLayers

## Shared canvas ordering for dynamic battle visuals. Keep move effects in
## front of the Pokemon. Trainer art belongs physically behind the active
## Pokemon, while trainer callouts remain readable above move overlays.
const FIELD := 0
const TRAINER_ART := -1
const MOVE_FOREGROUND := 50
const TRAINER_CALLOUTS := 51
## Compatibility alias for presentation that must remain above move overlays.
const TRAINERS := TRAINER_CALLOUTS
