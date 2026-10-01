# First five important battle forms

Task: `battle-forms-first-five`, paired slot-a, 2026-10-01.

## Scope

| Runtime identity | SCVI model |
| --- | --- |
| `ogerpon-wellspring` | `pm1120_12_00` |
| `ogerpon-hearthflame` | `pm1120_13_00` |
| `ogerpon-cornerstone` | `pm1120_14_00` |
| `terapagos-terastal` | `pm1130_12_00` |
| `terapagos-stellar` | `pm1130_13_00` |

These are ten **visually approved candidates**, normal and shiny. They are not admitted
to the runtime catalog, bundled, or uploaded. The ordinary species count has
not changed. User approval for earlier DLC species does not approve these forms.
Ogerpon's giant Terastallized mask forms are a separate cohort.

## Sources and animation policy

The SCVI Base + DLC dump supplies each form's own geometry, skeleton, original
materials, and rare material table. Ogerpon's shared textures are resolved by
exact filename and SHA-256 from the sibling source folders. The original dump
is read-only. Cubemap faces already packed into the imported Blender graph
are retained rather than replaced by guessed colour textures.

The dump has no matching native motion files. Public converted Unity packages
by Zyphex Skybreaker supply transform curves:
https://steamcommunity.com/sharedfiles/filedetails/?id=3428100851.
Creator, source URL, package hash, decoded hash, rig identity, and adapted
motion hash are recorded in intake receipts. Source shaders use a static native
colour/emission bake; animated shader flow and live refraction are not reproduced.

Ogerpon's shared `pm1120_11_00_00400_attack01` is explicitly aliased to each
matching mask rig. Its frames remain unchanged in the intake. The directional
attack is presented as a second physical proposal; runtime move routing still
needs integration. Terapagos has one physical proposal. Terastal's special
proposal sequences its native start, one native loop, and native end; this
sequence is authored, with original parts and timing retained in the receipt.

None of these five sources supplies sleep. Rest is authored from each form's
own idle and faint eyelid pose; faint-hold freezes its own faint endpoint.
The normal/shiny geometry, skins, and animation signatures match exactly.

## Ogerpon transform repair

Initial finite-geometry checks missed very large but finite transforms at some
animation starts. Full-clock measurements then exposed additional terminal
feeler spikes during physical attacks. Repeated seeks reproduced the problem,
so this was not a stale screenshot.

The opt-in `explicit_source_hierarchy` worker composes converted Unity local
matrices independently, then uses Blender's local-to-pose conversion with
explicit parent matrices. This avoids evaluating the converted curves against
the SCVI rig's different segment-scale inheritance. Existing callers retain
their previous behaviour.

The converted feeler chain still loses precision under repeated 0.1 scales.
Repairing only `feeler_a_13` reduced the spikes but failed the full-clock
clearance check. For the two Ogerpon physical clips only, `feeler_a_root` and
`feeler_a_01` through `feeler_a_13` now use their own SCVI rest transforms
under the animated spine. Other bone curves, clip clocks, geometry, and
material palettes are retained. This is an authored accessory stabilization,
not a claim that the external conversion was exact.

The renderer now honours an optional candidate maximum posed extent; this
cohort uses a 10 m diagonal guard. The collective page additionally rejects a
full-clock envelope over that limit. Earlier measurements and rejected
candidates are retained in `pre-hierarchy-fix`, `pre-tip-fix`, `pre-chain-fix`, and v1/v2/v3 reports.
No existing floor, timing, or performance threshold was relaxed.

## Terapagos Terastal reference correction

The user rejected v4 and supplied a Terastal reference. Native glass was baked
as opaque white although its material table specifies premultiplied blend and
base alpha 0.2. The type marks require the source alpha test at 0.6. The scoped
material proposal restores those two settings. Its glass uses conventional
alpha compositing, not native thin-glass refraction.

The static native Fresnel colour bake produces neon green/yellow fur, including
in the converted external texture. The separate
`terapagos_reference_palette_worker.py` prepares an explicitly authored blue /
pale yellow palette through the original native colour masks. The existing
worker's official rare-table override validation remains unchanged: an attempt
to send this authored palette through that API was rejected and retained.
Original Blender files and normal/rare material tables are unchanged.

The SCVI import additionally binds `pm1130_12_00_tail_mesh`, which covers the
face even in bind pose. The converted source prefab has five enabled renderers
and does not include that binding. The proposal removes only that extra node's
draw binding; its transforms, skeleton, animations and original mesh data stay
intact. `bodyfur_mesh` remains visible, including the actual rear tail. Whole
fur transparency and hiding bodyfur were investigated and rejected.

`terapagos_terastal_material_proposal.py` guards exact material names, native
alpha settings, authored-palette provenance and the exact five-versus-six
renderer difference. Material-only output retains geometry/skin/motion parity;
final normal and shiny output also match each other. V6 standalone and fresh
battle evidence use the corrected scene hashes. The user approved all five v6 normal/shiny pairs: "Alle vijf goed".
Runtime admission and installed performance remain pending.

## Evidence and reproduction

Local evidence root: `.tmp/battle-forms-first-five-v1` in the slot-a frontend.
`catalog_battle_forms_first_five_checkpoint.json` pins the current candidates
and qualification reports. Large model and image files remain local artifacts.

Source stages are driven by
`tools/sprite_factory/catalog_battle_forms_first_five.py` with phases
`download`, `import`, `convert`, `export`, `material`, and `rest`.
The reviewed palette can be grafted onto repaired motion only after exact
vertex/UV/triangle/weight/named-joint equality passes. This does not grant
appearance approval.

The retained v6 runner recipes are `run-runtime-v6.py`, `capture-v6.py`,
`maskless-v6.py`, `eyes-v6.py`, and `battle-v6.py` under the evidence root.
They invoke Godot through `ops/worktrees/slot-env slot-a`, using the existing
autoload-free offline renderer project. Runtime conversion checks standalone
SCN loading, complete pose channels, clip durations and serialization. Captures
also check reset-before-seek and reversed clip order.

Battle evidence measures native clips at 60 Hz and corrected clearance at
120 Hz, then captures classic/stadium cameras, both sides, physical/special attacks, idle, rest and faint poses next
to Dragonite. Camera containment and HUD bounds checks are offline proxies;
they do not certify installed battle loading or FPS.

Build the joint page with:

```sh
python3 tools/sprite_factory/catalog_battle_forms_review_page.py \
  --evidence-root .tmp/battle-forms-first-five-v1 \
  --output .tmp/battle-forms-first-five-v1/review-v6
```

The page includes two physical Ogerpon proposals, special attacks, rest,
faint-hold, both battle cameras, maskless diagnostic Ogerpon instances, and a
lower camera for Terapagos's eyes. The packed scenes keep their real masks.

Focused unit checks:

```sh
python3 -m unittest discover -s tools/sprite_factory \
  -p test_battle_form_motion_intake.py
```

## Next admission steps

1. Visual approval is complete for the exact v6 candidates.
2. Integrate correct form identities, form switches and anticipated bundle
   preloading, so a battle does not first show an incorrect form or fallback.
3. Check actual battle loading, installed content and performance using the
   existing qualification limits.
4. Admit and create individually versioned form bundles after those gates pass.

Then investigate Aegislash Blade, Palafin Hero, Wishiwashi School, Darmanitan
Zen, Mimikyu Busted, Eiscue Noice and Morpeko Hangry, followed by the major
legendary fused/rider/crowned forms. Desktop release certification remains a
separate task.
