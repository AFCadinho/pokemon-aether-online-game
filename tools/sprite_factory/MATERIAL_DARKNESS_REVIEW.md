# Shared battle-material readability (2026-09-22)

## Findings and decision

Six unchanged, hash-checked cohort SCNs were rendered through the actual runtime
material-response helper, with a fixed idle pose, camera and neutral lighting:
Dragonite, Cloyster, Azumarill, Forretress, Blissey and Garchomp.

All their original material base colors are white. Forcing the runtime base
factor to white produces identical images in all six cases. There is no evidence
of an accidentally repeated base-color multiplier here.

Holding lighting fixed and selecting the lit endpoint instead of the complete
shadow response removes much of the near-black color on Garchomp. The original
prepared Blender graph also contains the MULTIPLY shadow-color stage feeding
the final lit material. Its downstream fresnel, metal and rim controls are zero
on the inspected Garchomp body material. This does **not** establish an importer
bug or justify removing those source colors from the catalog.

The change is a deliberate **runtime presentation policy**: weight the extra
authored shadow-color blend by 0.35, while leaving ordinary scene lighting and
cast shadows intact. This is not a promise of exact SCVI/Blender appearance.
There are no per-species exceptions, regenerated assets, new approvals, light
changes, texture/gamma modifications or changes to animation/placement.
Legacy standard materials and unlit effect shaders are unaffected. The separate
Pokédex StandardMaterial preview is also unaffected by this battle-shader change.

## Repeatable evidence

Run through `ops/worktrees/slot-env slot-b`, with a new absolute `DARKNESS_OUTPUT`
directory, Godot Forward+ and
`--script res://tools/sprite_factory/material_darkness_probe.gd`.
The probe requires the original local cohort SCNs named by the review ledger.
It never writes model resources. Its viewport uses UPDATE_ALWAYS, including
when the host Control is not visible; otherwise readbacks can be stale.

Local `.tmp/darkness-probe-04/` contains 36 PNGs and six HDR light-pass images:
current readability, original strength 1, white-factor intervention, forced lit
endpoint, forced shadow endpoint and unlit lit-endpoint for each species.
All six strength-1 captures reproduce `.tmp/darkness-probe-03/`'s original shader
captures pixel-for-pixel. Their white-factor captures are also identical.
All six current-policy captures were directly inspected: darker colors remain
more legible, with directional shading and highlights still visible.

This is a bounded single-pose review under neutral lighting, **not** a new
catalog certification, source render equivalence, or a live Forest/PvP test.
The user's actual Forest view remains the final aesthetic check. Existing
Cloyster specular highlights and render shadow grain are not repaired here.

Focused checks: `battle_material_response_check.gd` validates the common policy
and original material/lighting contract; `battle_material_response_order_check.gd`
checks pass ownership and pooled reuse. No full development gate is required.
Both checks passed. The six-species probe also completed on OpenGL Compatibility
(`.tmp/darkness-probe-gl-01/`); its Garchomp capture was directly inspected. These
cross-backend captures are a shader smoke test, not pixel-equivalence evidence.
