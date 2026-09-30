# Remaining 76: native UV recovery and appearance approval

Checkpoint: `tools/sprite_factory/catalog_remaining_76_shiny_checkpoint.json`.
These are review candidates, not admitted runtime models or bundles. The
approved catalogue remains 807 ordinary species plus Mega Dragonite.

## Cause and correction

The legacy connected-material bake sampled only Blender UV `[0,1]`. Of these
76 GLBs, 69 use material UVs outside the first tile and 60 have eye UVs there.
Non-periodic source eye adjustments meant wrapping that first-tile bake lost
the faces and some body details.

`catalog_native_uv_domain_recovery.py` pins the original GLB, Blend SHA-256 and
archive member size/CRC. It evaluates the connected native colour/alpha graph
over each affected material's actual UV domain using separate source and bake
UV layers. A glTF texture transform maps the original UV accessors into the
new image. Geometry, skins and animation bytes are preserved. Native alpha is
re-evaluated; it is not asserted identical to the incorrect first-tile bake.
First-tile materials are retained. Ambiguous or unsupported bindings fail
closed. Disposable Blend extractions retain the original source basename so
multi-rig isolation can verify the texture variant identity.

All 69 affected originals were recovered; seven required no domain change.
The currently selected Sirfetch'd pair instead uses the verified ZA
`pm0981_00_31` source with genuine normal/rare material tables and seven native
clips. Its source and timings are recorded separately from the legacy input.

Authored shiny palettes were rebuilt from the corrected normals, checked
against pinned local HOME references, and corrected further where needed.
Source UV/bone masks preserve Lickitung's tongue, Buzzwole's chest and
Dracovish's head markings. Dubwool's face and Nihilego's cap/rim use explicit
source regions. Palette operations preserve pixel alpha and UV transforms.

## Evidence and approval

Artifacts are retained under `.tmp/remaining-274-production/shiny-76`:

- `native-uv-domain-combined-v2.json`: 69 recoveries and seven unchanged inputs.
- `review-stage-v2.json`: the 152 current, hash-pinned runtime candidates.
- `uv-final-pair-parity-v3.json`: all 76 actual SCN geometry/skin/skeleton/
  visibility/animation pairs match exactly; materials are excluded here.
- `uv-final-material-pair-proof-v3.json`: all 76 pairs have identical UV
  transforms, texcoords, image dimensions and pixel alpha.
- `appearance-76-v2/index.html`: 794 selected pose renders and 152 references,
  with zero reported rendering/pose/timing errors and scene-bound hashes.

Focused Python checks: 10 tests for native UV domains, palette invariants and
GLB geometry/animation parity. All 76 normal and shiny appearances were
inspected again. On 2026-09-30 the user answered **“allemaal goed”** to the
new page's **idle/attack eyes and body details** review. That approval is bound
to the exact page and runtime-stage hashes in the checkpoint.

## Remaining work

Sleep expressions and final battle qualification were explicitly excluded
from that appearance approval. They remain pending for all 76. The four-model
sleep-expression pilot is separate evidence and is not admitted into these
current scenes. Native eye atlas layouts must be checked before applying
sleep expression offsets to other materials.

The earlier 73-model grounding report belongs to superseded scene hashes.
It also reported idle half-frame failures for Togedemaru and Dhelmise. Resolve
those cases using actual posed geometry and fresh scene-bound evidence before
accepting calibration. Do not weaken the clearance gate or treat exit status
alone as a successful qualification.

After sleep and battle review pass, run qualification and bundle installation
checks, then create individual bundles. No new runtime admission, bundle,
R2 publication or player-visible change has occurred in this checkpoint.
