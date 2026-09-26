# Automatic 3D battle arena selection

The resolved battle environment continues to drive 2D backgrounds and platforms.
The 3D arena also uses the battle kind:

| Battle | 3D arena |
| --- | --- |
| Wild land encounter | Generic grassfield, or cave when the environment is a cave |
| Wild surf, fishing or water-tile encounter | Generic sea arena |
| NPC trainer or rival on a map with an authored arena | That map's arena |
| Gym trainer or leader | That gym's indoor arena |
| Trainer on a map without an authored arena | The environment's generic arena |
| PvP and training arena | The existing stadium environment |

The source map still determines whether a wild encounter is grass, cave or water.
Explicit local review arena selections retain their precedence. Nearby battle
spectators use the source wild/trainer kind when available. The world prewarms
the wild arena for its current map; the battle presenter can replace a prepared
empty scene if the response later specifies a different arena.

The 3D presenter still falls back to its classic stage when required model
calibration or the forest art pack is unavailable. These rules do not alter
encounters, backend battle state or model approval.
