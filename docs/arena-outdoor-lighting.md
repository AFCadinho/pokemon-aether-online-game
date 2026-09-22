# Outdoor battle lighting

Every arena definition explicitly declares its lighting profile. The generic
grassfield, generic water arena, Route 1 and Route 22 (land and water) use
`arenas/shared/outdoor_lighting.gd`. The cave and enclosed stadium retain their
purpose-built lighting. The catalog adds the controller inside outdoor arenas so
both pooled environment passes and independently built material-response arenas
receive it.

The controller reads WorldTimeService, matching the overworld's UTC/server clock
and debug time. Dawn is 05:00–08:00, dusk 17:30–20:30. Colors and energies
interpolate continuously; the directional key uses warm sunlight or cool moonlight
with a stable direction. Ambient and weak directional fill preserve model detail.
Only the key contributes a sky disc. This is stylized lighting, not an astronomical
sun/moon orbit. The overworld photo-mode exposure override is intentionally local
to photo mode.

Each pass owns its Environment and procedural Sky. No sky textures or duplicate
map assets are shipped. The sky radiance map uses 128px resolution; parameters
update only when the world-clock second changes. Pooled worlds suspend the
controller together with their rendering and resume on acquisition.

Desktop releases deliver the shared forest art as the required
`battle-environment-forest` launcher pack. Its fixed `forest-runtime/` layout is
validated before installation, and the launcher supplies the absolute manifest
path to the client. The arena code and layouts remain in the game PCK; the one
shared 68 MiB forest PCK is downloaded only when its content version changes.

Focused checks: `tests/outdoor_lighting_check.gd`, `tests/route_1_arena_check.gd`.
Visual checks: `tests/route_1_arena_preview.gd` and
`tests/outdoor_battle_preview.gd` (actual Garchomp/Azumarill material passes).
The previews use POKEAETHER_FOREST_MANIFEST and POKEAETHER_STAGE_OUTPUT;
the Pokémon preview also requires SUMMARY_MODEL_CATALOG. Use slot-env for all
Godot invocations. Captures cover 06:00, 12:00, 19:00 and 23:00.
