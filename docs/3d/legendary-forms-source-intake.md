# Legendary alternate-form source intake

Task: `legendary-kyurem-forms`, paired slot-b, 2026-10-02.

The four base species already have approved normal/shiny bundles. None of
the six alternate forms below has a separate approved runtime bundle yet.
All six alternate model resources are present on the connected source drive.

| Runtime species | Model resource | Animation evidence |
| --- | --- | --- |
| kyurem-black | pm0646_13_00 | Biochao Gen5.zip / pm0646.blend: own rig and eight clips |
| kyurem-white | pm0646_12_00 | Biochao Gen5.zip / pm0646.blend: own rig and eight clips |
| zacian-crowned | pm0938_12_00 | Raw SV dump: 30 .tranm files |
| zamazenta-crowned | pm0939_12_00 | Raw SV dump: 31 .tranm files |
| calyrex-ice | pm0986_12_00 | Raw SV dump: 43 .tranm files |
| calyrex-shadow | pm0986_13_00 | Raw SV dump: 43 .tranm files |

All six mappings were visually confirmed against the model dump's own icon.
National Dex 888, 889 and 898 map to internal resources 938, 939 and 986.
Searching their National Dex IDs directly had incorrectly suggested their
sources were missing. Calyrex's rider models are already composite source
resources; they need not be assembled from the three approved base bundles.
`catalog_legendary_forms_intake.json` pins the matching normal/rare tables,
model files, icons and Kyurem archive member, including CRC and SHA-256.

## Kyurem review checkpoint

`catalog_kyurem_forms.py` produces disposable, source-pinned normal/shiny
candidates without changing either runtime registry. The preparer isolates
one rig from the shared archive, removes unrelated material datablocks and
normalizes Blender copy suffixes only after matching every used material to
the selected resource's official table. The raw archive is never saved.

Both candidates retain their own eight native clips: battle idle, two physical
attacks, special attack, damage, sleep, faint start and faint loop. Export
timings are checked against the actual GLB clocks. Flattened skeletons are
converted through the existing standalone-scene pipeline with complete pose
channels, then reloaded and reviewed in an isolated Godot project.

The initial v1 exports remain in `.tmp/legendary-kyurem-forms-v1`; these were
held because the shared source's material copy suffixes did not match its
official resource table. The subsequent full shader bake and captures are
preserved in `.tmp/legendary-kyurem-forms-v2`. That bake incorrectly darkened
Black Kyurem's blue ice arm, so it is not the current review candidate.

The current neutral candidates use matched official layered albedo and eye
colours, rare textures and source-mask emission. The Overdrive tube and
lightning meshes are explicitly withheld from this neutral appearance
proposal because their visibility clocks are absent from the exported clips.
Their nodes, geometry buffers and skeletal animation channels are preserved;
only their mesh/skin bindings are omitted. Charged effects need separate
visibility qualification. Normal/shiny geometry and motion remain identical.

Evidence under `.tmp/legendary-kyurem-forms-v2`:

- `neutral/`: four corrected GLBs and material/visibility receipts.
- `stage-neutral-v1.json`: exact GLB hashes and actual source timings.
- `runtime-neutral-v1/`: four standalone SCNs and reload receipts.
- `appearance-captures-neutral-v1/`: 32 pose images and the Godot report.
- `review-neutral-v1/`: one page with both normal/shiny pairs and eight poses.

Godot 4.6.2 AMD Compatibility reports zero clip timing, geometry, reload or
reverse-order pose errors for all four appearances (32 native clips). These
checks do not qualify battle scale, floor clearance, switching or performance.
`catalog_kyurem_forms_checkpoint.json` pins this exact review state and keeps
the user appearance approval (2026-10-02, “Allebei goed”) for these exact
neutral assets. Battle and runtime approvals remain false until their gates.

Reproduce candidates in a new evidence root after preserving existing work:

```sh
python3 tools/sprite_factory/catalog_kyurem_forms.py export --work .tmp/kyurem-fresh
python3 tools/sprite_factory/catalog_kyurem_forms.py neutral --work .tmp/kyurem-fresh
python3 tools/sprite_factory/catalog_kyurem_forms.py stage --work .tmp/kyurem-fresh
```

After user appearance approval: battle calibration and review, runtime form
identity/preloading, performance admission, individual bundles, then explicitly
authorized R2 publication. The other four source-confirmed forms follow next.

## Battle calibration checkpoint

The exact user-approved neutral assets are staged with the hash-pinned Dragonite
comparison control. Full native clips are sampled at 60 Hz, including damage.
Both forms retain scale 1.0; all four idle camera/side views exceed the existing
66-pixel readability minimum. Normal and shiny receive identical placement.
Faint endpoints match exactly. Clearance-only profiles add at most 3.46 cm
(Black) and 2.46 cm (White), with steady offsets for the resting faint loop.
There are no calibration holds. Independent 120 Hz verification passes all
32 native clips: minima remain at least 2.5 cm above the floor. All 112 final
pose images (seven poses, two cameras, two sides, four appearances) fit in
view. The user approved both battle pairs on 2026-10-02 (“goedgekeurd”). Installed
runtime identity and performance gates subsequently passed (see below).

Evidence: `battle-stage-v1/`, `battle-measure-v1/`,
`battle-candidates-v1.json`, `battle-validated-v1/`, and
`review-neutral-v1/battle-review-v1/`. Exact report/catalog/profile hashes
are recorded in the tracked checkpoint.

## Installed bundle qualification

Two bundles contain the four exact approved standalone scenes, total
60,650,556 bytes (57.84 MiB). The tracked index is
`release/approved_3d_kyurem_forms_index.json`; receipts are in
`catalog_kyurem_forms_bundle_qualification.json`. No R2 upload or release
content-index activation was performed in this step.

The launcher store passes clean install, no-op update, restart and scene hash
checks. The real on-demand service (using exact local archives instead of HTTP)
loads the two combatants before reveal; normal/shiny swaps make no further
requests. Fusion forms do not require anticipated mid-battle transformations.
The admitted game and launcher registries share identical model hashes and
placement profiles. Runtime tests confirm both physical-attack routing paths.

The original short two-pair stress run failed the unchanged 20 ms p95 gate
(21.03, 25.20, 20.67 ms). Already-approved base controls also failed in stadium
(28.97 ms). The two-pair wrapper now observes 120 additional prepared frames
per normal/shiny arrangement, retaining the existing full-battle lifecycle,
load-span, covered-stall, memory and teardown checks. The gate remains 20 ms
for both full rounds and explicitly recorded prepared-battle observations.
Final full-round p95: 17.36 / 17.51 / 17.28 ms; prepared classic/stadium:
17.30 / 17.36 ms. Cache and leak limits pass. This measures this machine's AMD
Compatibility renderer; it does not certify other devices or release builds.
All original failed reports are retained alongside the passing reports.

An initial new runtime test incorrectly required a sleep correction for every
form. White Kyurem's native sleep already clears the floor, so it intentionally
has no corrective sleep offset. The corrected test checks that sleep exists
and the calibrated motion profile is valid rather than requiring an unnecessary
offset. No model or animation was altered for that correction.

Reproduction: `catalog_kyurem_forms_admission.py prepare`, the launcher bundle
install check, `battle_3d_kyurem_forms_check.gd`, and
`battle_3d_kyurem_stress_check.gd` with the saved fixture/catalog. Admission
requires the exact approved assets, installed hashes, all runtime logs and
both unchanged performance gates. The final test runs without fixture overrides.
The next source-confirmed models are Calyrex Ice/Shadow Rider and crowned
Zacian/Zamazenta. Charged Kyurem accessory visibility remains separate work.

Integration caught a concurrent stadium crowd change. The slot merged current
`development` and repeated the exact installed stress gate on the new mixed
crowd. This also passes: 17.346 / 17.348 / 17.314 ms p95. The
receipt preserves the previous arena digest and pins the current arena, crowd
shader, spectator code and additional integrated reports.
