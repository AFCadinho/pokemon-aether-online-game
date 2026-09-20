# Reviewed material response in desktop battles

The runtime uses the locked neutral three-light rig (white ambient 0.14,
key 1.15, fill 0.25, rim 0.45). Do not adjust the rig to compensate for a
material. Shadow grain remains a separate render-quality/performance issue.

## Representation

Schema 1 embeds two reviewed UV endpoint textures and a source-derived specular
value in each StandardMaterial3D's `pokeaether_material_response` metadata.
The PackedScene root carries the same schema marker. Textures are embedded with
mipmaps; the interactive client loads no PNGs, source reports or temporary scripts.
Existing threaded scene loading prepares all resources under the opening cover.

One additional full-resolution MSAA-matched linear HDR viewport measures summed
irradiance with the source's gray 0.8 diffuse probe. The final shader applies the
source EASE ramp after summation, then uses Godot's standard BRDF. Source IOR and
specular level map to Godot specular through `sqrt(F0 / 0.16)`. No species-specific
color, scale, light or shader parameters are introduced.

The second pass mirrors the presenter's transforms, skeleton poses, blend shapes,
visibility and camera before drawing. Its AnimationPlayers do not run independent
clocks. Switching replaces the corresponding mirror; teardown releases viewport,
mirrors and textures. There is no persistent global texture cache.

Legacy catalogs without response metadata retain standard materials under neutral
lighting. Schema 1 only covers the audited opaque, nonmetallic, nonemissive source
graphs with constant IOR/specular and a white-to-black EASE ramp at 0.5 and 1.0.
The offline tool rejects other graphs; this is not yet a universal graph converter.

## Offline preparation

Run `tools/sprite_factory/embed_battle_material_response.gd` through the assigned
slot environment, with these environment variables:

- `POKEAETHER_3D_STAGE_REPORT`: existing prepared runtime JSON (not the GLB report).
- `POKEAETHER_RESPONSE_MAPS`: reviewed endpoint-map report.
- `POKEAETHER_RESPONSE_INPUTS`: reviewed source-material input report.
- `POKEAETHER_RESPONSE_OUTPUT`: distinct output JSON; generated models live beside it.

Select the resulting catalog only after focused tests pass. Keep the previous
models for rollback; no source model or editor configuration needs rewriting.

## Integration evidence (2026-09-20)

Dragonite/Roaring Moon: twelve 512×512 RGBA captures (fixed pose and five sampled
animation/rotation positions per species) are pixel-identical to the approved
research reference. The runtime shader contains no dynamic source-code rewriting.
Generated self-contained scenes are 12,294,226 and 25,419,314 bytes respectively.

Focused checks: `battle_material_response_check.gd`, `battle_screen_host_check.tscn`
with the prepared catalog, and three rounds of `battle_3d_presentation_check.gd`
including response bindings, resource dependencies, pose synchronization and cleanup.
Local evidence lives in slot-c `.tmp/material-response-runtime/`.

Initial observed shader compilation still produced a ~1.1 s preparation frame;
this integration does not make shader compilation asynchronous. Action p95 was
about 17.4 ms on the tested RTX 3070 Laptop GPU. Those are local observations, not
a low-end desktop guarantee. The extra HDR pass retains the previously measured
GPU/memory cost; no quality or rendering-performance reduction is claimed here.
