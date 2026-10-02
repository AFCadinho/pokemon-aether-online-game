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
view. The user battle review is pending. Switching and performance admission
are still required; this checkpoint does not activate runtime forms.

Evidence: `battle-stage-v1/`, `battle-measure-v1/`,
`battle-candidates-v1.json`, `battle-validated-v1/`, and
`review-neutral-v1/battle-review-v1/`. Exact report/catalog/profile hashes
are recorded in the tracked checkpoint.
