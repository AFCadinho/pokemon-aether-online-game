# Cloyster forehead highlight (2026-09-22)

## Result

The bright spot is a specular reflection: setting only `specular_value` to zero
removes it in a fixed-pose runtime capture. No albedo, normals, roughness, lights,
camera, skeleton or source files were changed. This intervention is diagnostic,
not a proposed blanket matte-material policy.

No conversion fault was found in the checked parameters. The prepared source
`catalog-100-source-review-02/sources/cloyster/normal/pm0091_00_00-ready.blend`
has constant IOR 1.4500000477 and SpecularMaskMap 0.5. The embedded runtime
specular is 0.4591837132, consistent with the existing F0 mapping. Both eyes
have source roughness 0.1, exported as 26/255 (ordinary eight-bit quantization).
The source body roughness maps are grayscale Non-Color images, not an RGB
normal map accidentally treated as roughness; their minimum is 58/255.

Four texture positions per body material match the source within floating-point
precision, accounting for Blender's bottom-up pixel storage:

| Material | (0,0) | (.25,.25) | (.5,.5) | (.75,.75) |
| --- | --- | --- | --- | --- |
| body_a | .694118 | 1 | 1 | .384314 |
| body_b | .701961 | 1 | .423529 | .803922 |

This is a parameter/sample audit and a causal render intervention, not a complete
source-image equivalence test. Blender and Godot BRDFs and scene lighting can
still differ. Removing or softening glints is an art-direction decision, not a
proven importer repair. No runtime policy or model approval changes in this step.

## Reproduction

The existing `material_darkness_probe.gd` now records runtime roughness samples
and source-derived specular. Set `SPECULAR_PROBE=1` and a fresh absolute
`DARKNESS_OUTPUT` directory through the assigned slot environment. This renders
the current shader and a zero-specular intervention for six unchanged,
hash-checked models (Cloyster, Dragonite, Garchomp, Azumarill, Forretress, Blissey).

Local evidence: `.tmp/specular-probe-01/`, 12 Forward+/Vulkan PNGs and report.json.
Cloyster's no-specular capture was directly inspected against the previous
current-policy capture. Runtime Cloyster SCN SHA-256:
`887bfd934834e221b16acdad59dd3e0916aca606221954674201b5d3611f036f`.
All six pairs rendered successfully. No live Forest/PvP test is claimed.
