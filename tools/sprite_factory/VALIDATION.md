# V1 reference validation — 2026-09-18

Validated locally in slot C with Blender 5.2.0 LTS (build fbe6228777e7), Pillow
12.3.0 and Godot 4.6.2. Sources were opened with embedded execution disabled and
were not saved. Output remains under `slot-c/.tmp/sprite-factory-v1/`.

## Results

| Reference | Canonical frames, both views | Independent rebuild | Compared with hand-made POC | QC |
| --- | ---: | --- | --- | --- |
| Dragonite | 1,426 | All master files byte-identical; runtime metadata identical | All 1,426 frames pixel-identical | 0 errors, 4 loop-end warnings |
| Rattata | 478 | All master files byte-identical; runtime metadata identical | 456 exact; 22 with at most 2/255 error in a colour channel at a few pixels | 0 errors, 0 warnings |

Rattata's maximum per-frame mean absolute channel error against the POC is
0.0000228882 on a 0–255 scale. Its two factory builds match exactly. Both species
have at least 24 transparent pixels at their tightest frame boundary, with no
camera clipping detected across every selected frame.

Final canonical build IDs:

- Dragonite: `ce06bb46efe806ddb06f3ab5a29775c06e3abe0c602f7c372b6d9308cc5a1312`
- Rattata: `e240ee677c637c069e76b51c4626259c7c76520f64cdbff83120436d974387af`

Complete independently rendered sets are retained in `validated/` and `repeat/`.
Blender writes volatile Date/RenderTime stamps into PNG metadata, so initial file
hashes differed despite identical pixels. The final pipeline strips only those
metadata chunks, preserving compressed image data and colour-profile chunks.
`finalize` produced `canonical/` and `canonical-repeat/` from the verified full
sets using the identical archived Blender renderer; those canonical masters are
byte-identical. The final full `.blend` build command, including raw-output
preservation and canonicalization, was additionally exercised with a two-frame
Rattata action in both views under `end-to-end-smoke/`.

No reference was automatically approved. Both final sets are `needs_review` and
are exposed only through `preview.json`. Existing human approval of the POC was
used as a comparison baseline, not transferred to newly built artifacts.

## Preserved species overrides

The reference manifests preserve the POC cameras/lighting, source material
assignments, 512px frames and 24 FPS interpretation. Dragonite uses the original
front/back orthographic scale about 4.3683, target height 1.15 and idle speed 1.3×.
Rattata uses front/back scales about 1.3253/1.1107, target height 0.45 and idle 1×.
Their independent in-game render scales are 2.6667 and 4.4 respectively, preserving
the reviewed large/small relationship. Anchors are `[256,256]`; per-view platform
offsets are recorded in each manifest.

Dragonite has explicit mappings for idle, physical, special, damage, sleep,
faint_start and faint_loop. Its loop is the reviewed first down-loop pose held
indefinitely. Rattata has no mapped sleep; its last down-start frame supplies the
KO hold. Both use 3× attack/KO-start playback and 2× damage, matching the POCs.
No recovery/end action is selected.

## Issues discovered

- Rattata's saved scene FPS is 25, not 24. The manifest explicitly interprets
  its action frames at 24 FPS to preserve the accepted POC timing.
- Both blends contain an `SMDBatchImport` text block, which was never executed.
- Dragonite contains two empty texture nodes feeding only an inactive emission
  branch (unlinked Emission Strength = 0). This is recorded as a specific source
  exception; active colour, normal, roughness and AO textures remain embedded.
- Dragonite idle and sleep still contain duplicate first/last rendered frames
  for both views. These existed in the POC and are reported for human review;
  no master frame was automatically removed.
- No verified shiny source was identified. Shiny remains unavailable and falls
  back to existing assets.

## Tests and local visual checks

- Six Python tests cover quality baseline, unavailable shiny, source/hash/action
  rejection, recovery/timing validation, clipping/empty frames, exact atlas
  round-tripping, warning acknowledgement, per-view rejection, tampering and
  metadata-only canonicalization.
- `verify` checks every atlas cell against its canonical master and validates
  build identity and archived code hashes.
- `check_rendered_sprite_assets.gd` passed for both species/views: lazy loading,
  missing form/shiny, rejected/corrupt actions, fallback to idle for unavailable
  sleep, actual attack/VFX routing, sleep, nonblocking faint hold, ordinary
  Pikachu fallback, and preview-catalog isolation from the approved path.
- Existing Dratini router/VFX regression passed.
- The real battle scene was rendered with both Rattata-back/Dragonite-front and
  Dragonite-back/Rattata-front. Front/back contact sheets and both compositions
  were inspected. These are composition probes, not a claim of playing a full
  server-backed battle. The supplied local launcher is for that human review.
- Godot reported the existing resource-UID text-path fallback warnings in the
  isolated scene probe and an ObjectDB-at-shutdown warning in the router test.
  Assertions passed and both composition probes completed. Single-battle routing
  is validated here; other modes/platforms still need separate review.

## Size and memory

| Reference | Canonical master PNGs | Runtime PNGs + metadata | Previews |
| --- | ---: | ---: | ---: |
| Dragonite | 265.78 MiB | 106.36 MiB | 54.33 MiB |
| Rattata | 76.29 MiB | 25.00 MiB | 9.74 MiB |

These are actual file sizes, excluding preserved raw/duplicate validation builds.
RGBA8 idle texture storage is approximately 96 MiB per Dragonite view and 32 MiB
per Rattata view before driver/engine overhead. One mixed battle initially needs
about 128 MiB of those texture pixels. The cache currently retains subsequently
loaded actions for the process lifetime. No FPS/resolution/texture reduction was
used to reduce these costs. Async decoding and cache eviction remain separate
optimization work; current PNG first-load decoding may hitch.

## Review and next validation

Human review still decides action semantics, face/eyes, loop seams, KO poses,
platform grounding, relative scale and battle tempo. Only a human-approved exact
build can enter an approved catalog. Partial view/action approval is supported;
unapproved actions use existing behavior, and missing identities use the normal
animated/HOME asset chain. Correct shiny materials need their own source review.

Suggested small next set, when suitable local sources are supplied: Pidgeot
(flying bird), Machamp (humanoid), Gastly (floating), Onix (long), and Venusaur
(broad/low). This evidence does not justify a full-Dex production run.
