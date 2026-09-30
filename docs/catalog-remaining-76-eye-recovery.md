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

## Sleep review and clip transitions

The source eye graphs and atlases were checked for all 75 selected Biochao
sources, preserving the original Blend identity and SHA. Sirfetch'd uses its
selected native ZA sleep expression. For 58 species, the actual closed native
atlas selection is embedded only in the sleep clip. Fixed or geometric eye
sources retain their native presentation. This is an authored expression
selection; it does not claim to recover native blink timing.

All 152 candidates were rendered in idle and sleep with zero reported errors.
On 2026-09-30 the user approved the combined 76-pair sleep page with
**“Allemaal goed”**. Exact page, capture report and scene-stage hashes are
recorded separately from the earlier appearance approval.

The earlier Togedemaru and Dhelmise failures were traced to omitted constant
transform channels in native clips. Godot retained an attack's bone scale when
idle did not animate that channel. The opt-in offline `complete_pose_channels`
step now supplies missing channels using the scene's original baseline pose.
Existing native curves are untouched. Conversion also rejects an incomplete
result count instead of publishing an empty report after a script failure.

Focused Godot checks cover restoration after an attack, unchanged original
keys, repeat application and rejection of an unknown bone binding. Actual
candidate proofs verify all 57,716 original tracks, clocks and interpolations,
plus fresh bone poses at start/midpoint/end of every clip in all 152 scenes.
All 76 normal/shiny scene structures match, and all 76 normals return to their
original idle bounds after a full sequential clip cycle. No clearance gate
was weakened.

Evidence is under `shiny-76/sleep-battle-v1`: `native-pose-proof.json`,
`runtime-pair-parity.json`, `transition-all.json`, `eye-sleep-policy.json`
and `eye-sleep-captures/review.json`.

## Battle measurements

The selected 76 normal scenes passed actual 120 Hz motion clearance and
camera/HUD checks in both cameras and on both sides. Shiny geometry, skin,
visibility and animation tracks match the current actual normal scenes;
the latest shiny scenes were also captured in both cameras and on both sides.

Six cases required scoped repairs. Togetic, Swoobat and Tapu Koko needed
upward-only sleep clearance; native hovering motion was retained. Turtonator's
faint and Yamper's physical attack needed a tighter neighbouring offset
envelope after actual half-frame failures. The original reports are retained,
and the two corrected profiles passed fresh actual 120 Hz checks.

Dhelmise's faint pose floated about 0.83 m too high after the idle lift.
`visual_ground_motion_pack.gd` supplies an authored offset on a separate visual
parent, leaving the gameplay root and every original bone curve intact.
Only faint uses that offset; other clips explicitly restore zero. The selected
normal/shiny pair passed exact scene parity, native key/clock/bone-pose
preservation, fresh 60 Hz measurements and actual 120 Hz motion validation.
Focused tests verify that gameplay placement and native keys are preserved,
idle restores the visual offset, and invalid clocks are rejected.

`battle-76/normal-combined.json` binds the latest normal results and their
retained source reports. `final-canonical-stage.json` and
`final-pair-proof.json` bind the latest selected 152 SCNs, including Dhelmise's
replacement pair. The user approved 75 pairs on 2026-10-01. Wailord was held because its generic
380-pixel width cap made its long body too small beside Dragonite. A larger
species-specific placement is 1.597 times larger. It passed fresh actual120Hz
idle and all-clip clearance, and all16 normal/shiny camera captures remain in
frame and clear of the HUD proxy. Shiny clearance is derived from the pinned
actual scene parity, with fresh shiny renders. The larger size awaits review
at `battle-76/wailord-size-review-v1/index.html`.

## Remaining work

Wailord size review and qualification/bundle checks remain pending. Thirty-four native
sources use centimetres and require placement scale 0.01; the other 42 retain
scale 1.0 before readability/framing calibration. This unit conversion is
checked against local species dimensions and retains native proportions.
Small models use the existing 66-pixel readability target; large models are
checked against actual projections so an oversized first projection cannot
shrink them unnecessarily.

The earlier 73-model grounding report belongs to superseded scene hashes.
It also reported idle half-frame failures for Togedemaru and Dhelmise. Resolve
those cases using actual posed geometry and fresh scene-bound evidence before
accepting calibration. Do not weaken the clearance gate or treat exit status
alone as a successful qualification.

After sleep and battle review pass, run qualification and bundle installation
checks, then create individual bundles. No new runtime admission, bundle,
R2 publication or player-visible change has occurred in this checkpoint.
