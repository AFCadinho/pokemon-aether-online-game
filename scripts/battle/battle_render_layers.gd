extends RefCounted

class_name BattleRenderLayers

## Shared canvas ordering for dynamic battle visuals. Keep move effects in
## front of the Pokemon while reserving the next band for trainer identities.
const FIELD := 0
const MOVE_FOREGROUND := 50
const TRAINERS := 51

