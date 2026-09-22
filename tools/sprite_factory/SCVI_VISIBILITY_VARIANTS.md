# Visibility targets: catalog-bound gender membership

## Outcome

All fifteen previous variant-binding holds are resolved by one source-metadata
rule. The same 88 GLBs now give **86 visibility preflight passes and two explicit
dynamic-clock holds** (Meowth and Spiritomb). No species-specific code, target-name
rewriting, visual approvals, source edits or installed-package replacements.
This is visibility-feature coverage, not a new production-ready yield.

## Source evidence and rule

The source clips list targets from more than one gender model. These targets are
not necessarily false: Raichu's mapped clips, for example, mark both tail shapes
true. An always-hidden filter would not describe the actual data.

The identity-bound catalog explicitly identifies separate resources using the
same internal species and form, but different gender codes. Their TRMDL mesh
references and TRMSH shape tables establish the exact ownership of each target.
For every one of the fifteen affected pairs, both model descriptors and primary
mesh tables match the corresponding ROMFS files byte for byte.

The resolver now:

1. Rechecks the selected catalog identity and pinned catalog hash.
2. Reads the selected model's primary mesh table through its TRMDL reference.
   This matches the pinned importer's `Meshes(0)` / `loadlods=False` path.
3. Requires exact equality between selected source shape membership and exported
   GLB mesh-node names (only the structural `_shape` suffix is removed).
4. For remaining targets, reads catalog siblings with the same species/form and
   a different gender code. A target is excluded only if exactly one such
   sibling's primary mesh table contains it and the selected table does not.
5. Records excluded targets, owning resource/gender, and all metadata hashes;
   rechecks hashes after export preparation.

There is no `_01_` to `_00_` substitution and no inferred gender from a filename.
Missing active geometry, unknown targets, different-form targets, ambiguous owners,
duplicate tracks, unsafe references and changed metadata remain errors. Inactive
variant tracks are excluded rather than remapped onto an active mesh. Every
selected mesh must still receive a time-zero track in every clip. The rule is
also tested with the opposite gender selected.

Sibling metadata is consulted only when a clip contains additional targets.
Those sibling files are newly hash-bound evidence for membership, not an implicit
approval of the sibling's geometry, animations, materials or identity pipeline.
Shiny/material selection and other-form resolution are outside this change.

## Same-cohort result

Resolved: Raichu, Gyarados, Eevee, Hypno, Scyther, Magikarp, Sudowoodo, Wooper,
Quagsire, Murkrow, Scizor, Heracross, Donphan, Staraptor and Garchomp. They are
listed as observations, not referenced by the resolver code.

The previous 71 passes remain passes; the fifteen now resolve; Meowth and
Spiritomb still fail explicitly on unsupported dynamic visibility clocks.
Original SCN and GLB hashes were checked for all 88. The twelve earlier
technical/source holds outside this group are untouched.

## Focused runtime validation

Raichu, Eevee and Garchomp were converted from unchanged GLBs into new, isolated
SCNs using the new metadata-bound payload. Their **nine mesh array sets are
byte-identical** to the original SCNs (including vertex, index and skin arrays).
The converter successfully saves and reloads all three scenes.

The corrected runtime renderer captured **21 native clips, 625 motion frames and
30 static views**. Every motion-frame mesh state matched its selected source
visibility keys; bone mismatches were zero. Idle, sleep and faint loops were
captured for two cycles. Direct visual checks covered Raichu/Eevee's rear idle
views and Garchomp's idle/faint-loop front views. This is targeted preservation
review, not full visual, shiny, arena or live-PvP certification.

Tests: **18 visibility tests plus 40 existing SCVI tests pass**. Synthetic cases
cover exact and reverse-gender membership, missing selected meshes, unrelated
forms, ambiguous owners, metadata drift, traversal, unused sibling resources,
duplicate source tracks and exclusion of an inactive variant's dynamic track.
The dynamic decoder for an active mesh remains disabled.

Evidence: `visibility_variant_results.json` records all 88 outcomes, the fifteen
ownership proofs, three new scene hashes and probe hashes. Local artifacts:
`.tmp/visibility-variant-stage-01.json`, `.tmp/visibility-variant-runtime-01/`,
`.tmp/visibility-variant-images-01/`. Existing catalogs are not changed.

## Next step

Investigate the two active dynamic-clock cases using raw source tracks and an
independent timing reference; do not stretch bit arrays over the clip. Material
issues in Spiritomb, Gastly and the fire profiles remain separate from visibility.
There is no need to increase the cohort or pursue 100/100 before resolving those
specific questions.
