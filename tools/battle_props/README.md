# Battle prop review

Run through the assigned slot, from the game workspace:

```sh
ops/worktrees/slot-env slot-a -- godot --path .worktrees/slot-a/frontend --rendering-method gl_compatibility --script res://tools/battle_props/preview.gd
```

Writes `/tmp/battle-props-{closed,open,absorb,shake,breakout}.png`. The first
pair enlarges the ball for material/hinge review. Capture uses battle-sized props.
This isolated preview is not a replacement for the player's arena/camera review.

`inspect_models.gd` reports the original model envelopes, materials, clip duration
and lid joint keys. It can run headlessly through the same slot wrapper.
