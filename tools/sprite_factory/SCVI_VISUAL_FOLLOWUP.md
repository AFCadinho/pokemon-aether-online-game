# Fixed 100 — nine visual holds: source diagnosis

> Implementation follow-up: `SCVI_VISIBILITY_PLAYBACK.md` records generic fixed
> and framed playback, strict mesh/clock binding, five new runtime controls and
> explicit holds for unresolved variants and dynamic clocks.

## Result

This step diagnoses the nine holds from `SCVI_RUNTIME_VISUAL_REVIEW.md`.
It does not change models, publish catalog entries or raise the 79/100 screening
count. All nine original SCN hashes still match. No species-specific manifests
or permanent accessory exclusions were added.

**Missing visibility playback is a demonstrated shared contributor in five
models.** A fixed-source-visibility A/B intervention removes the observed loose
accessories in four models, and unwanted sleeping geometry in Spiritomb. The
source's fixed visibility does **not** repair Spiritomb's missing face.

| Control | Source evidence and isolated render result |
| --- | --- |
| Rillaboom | `stick_mesh_shape` is false during sleep; applying it removes both suspended sticks. Alternate drum meshes also switch by clip. |
| Decidueye | Arrow is false in all seven mapped clips; idle A/B removes it. Wing/cap/cloak meshes have different visibility in other clips, including nonconstant tracks. |
| Magearna | Flower and blaster are false in all seven mapped clips. Faint-loop A/B removes the bouquet and obsolete body parts, retaining the closed ball. Faint-start body/ball transition is not constant. |
| Cinderace | Stone and four fireball meshes are false in all seven mapped clips; idle A/B removes the black spiky effect. This says nothing about the material quality when another clip intentionally shows it. |
| Spiritomb | Sleep/faint-loop disable three purple body meshes and two eye alternatives. A/B removes the geometry below the stone. Idle still lacks its face after selecting the source's eye alternative: a separate unresolved material/geometry issue. |

The diagnostic instantiated the existing SCNs in the corrected runtime renderer
and changed only `MeshInstance3D.visible` in memory. Exact source target names
minus `_shape` resolved uniquely for every tested target; this is evidence for
these five models, not yet a universal export binding contract. The light-copy
renderer already synchronizes mesh visibility. Five models × idle/sleep/faint
loop × before/after produced **30 captures**. The five symptom pairs above and
Spiritomb's unchanged idle face were inspected directly; other captures are
retained as evidence, not claimed as full animation review.

## Visibility storage: why not implement an always-hidden list

The 63 mapped TRACM files contain **399 fixed, 15 framed-8 and six dynamic**
visibility tracks. The pinned [PokeDocs schema](https://github.com/pkZukan/PokeDocs/blob/de20b28d82d5d8b473905eb2c24e5d8b47841ca8/SV/Flatbuffers/animation/tracm.fbs)
describes the latter payloads as Boolean vectors, but the actual dump stores
compressed bytes. For example, Spiritomb's physical-attack right-eye track has
frame keys `[0,83,91]` with a one-byte payload `[5]`; the complementary closed-eye
track contains `[2]`. Its dynamic eye payload includes bytes `255` and `192`.
Treating each byte as one Boolean would silently lose transitions.

`inspect_visibility()` therefore decodes fixed values, preserves frame keys and
nonconstant raw payloads, and leaves bit order, sample count and clock semantics
uninterpreted. It is a read-only diagnostic, not a runtime animation decoder.
Unknown unions and malformed fixed values fail explicitly. No unsupported
nonconstant track is silently treated as always visible or always hidden.

The skeletal importer previously warned about unapplied material/blendshape
channels but omitted visibility warnings. It now reports
`unapplied_tracm_visibility:<clip>:<count>` through the same diagnostic path.
This changes reporting only, not conversion gates or playback. Existing reports
are historical and were not rewritten to imply they used the new warning.

## Dugtrio: compression exists in the source

For `spine_a_03`, the raw mapped idle clip has scale `(1,1,1)`. The mapped
faint-start clip ends at `(0.15,1,1)`, and faint-loop contains that same fixed
scale. Loading the unchanged SCN and sampling faint-loop in Godot yields
`(0.15,1,1)` too. Thus the conspicuous 15% compression is not invented by the
runtime scale track. Files match their identity-inventory source hashes.

This is a numeric track comparison, not complete mesh-deformation equivalence
or proof of artistic intent. Keep a source-pose review hold; do not clamp the
scale or substitute another animation without examining a trusted reference.

## Smoke/fire: separate material investigation

Gastly, Charmander and Moltres have fixed-true visibility for all meshes in these
seven mapped clips. Their smoke/fire should not be hidden to pass screening.
Gastly uses the NonDirectional displacement profile; Charmander uses Unlit
displacement; Moltres uses three Unlit UV2 displacement materials. All are
labelled Opaque in the source. The current effect implementation uses unshaded
alpha blending, inverted mask-alpha opacity and normal-directed displacement.
That is an existing approximation, not established shader parity. This source
inspection does not prove which approximation causes the observed facets or
black cutouts. No shader values were changed on speculation.

Next: implement and validate a **generic visibility track path**, including
compressed dynamic/framed tracks, exact mesh binding, clip reset and transition
timing. Use these five controls, then check affected members of the same fixed
cohort. Investigate Spiritomb's face and the smoke/fire material profiles
separately with controlled shader interventions. No larger batch is needed yet.

## Evidence and focused checks

`visual_followup_source_results.json` records per-clip source hashes, fixed-hidden
targets, raw nonconstant storage, material signatures, Dugtrio's scale samples
and A/B image hashes. Sources and all nine original SCNs are unchanged.
Local diagnostic captures: `.tmp/visibility-fixed-probe-01/`; scratch probe
scripts and input are hash-bound in the ledger. They are not installed game assets.

- 63 TRACM files decoded; 66 source-file comparisons including Dugtrio's three
  skeletal clips match the identity inventory.
- 30 Forward+/Vulkan runtime A/B captures completed with unique target bindings.
- Eight decoder/warning tests, including synthetic binary fixtures for fixed,
  dynamic, framed-8, framed-16 and malformed encodings.
- 40 focused `test_scvi_*.py` tests pass. No complete paired gate or release.
