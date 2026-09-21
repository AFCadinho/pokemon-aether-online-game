# Fixed 100: skeleton patterns and multi-material timelines

The cohort is unchanged. This is a source-pattern audit plus one targeted
conversion, not a new 100-model render run and not production approval.

## Pikachu: evidence, not a wildcard exception

All 93 catalog-resolved model/ROMFS skeleton pairs were decoded and compared.
92 are byte-identical. Only Pikachu differs: the six eyelid priority fields are
0 in the model dump and 2 in ROMFS. Other fields decoded by the pinned schema
agree. Seven requested identities remain absent from this catalog.

All 93 skeletons have some nonzero priorities, so priority metadata is common;
the **mismatch** is not common within this cohort. The current importer consumer
`PokemonSwitch.py` does not read `Priority()` in its model import path.

An isolated Blender A/B probe imported Pikachu twice. The only intervention was
redirecting its single read-only skeleton file access to the ROMFS counterpart.
It emitted JSON only: no candidate Blend, GLB, SCN or approval. Source hashes were
checked again afterwards. Both imports produced identical:

- named rest bones, parent links and bind matrices;
- mesh vertices and skin-weight data;
- pose matrices at every native frame of the seven mapped clips (**781 frames
  per source**, including sleep and faint loop).

This establishes equivalence for the tested importer and clips, **not** original
game animation-layer/priority semantics. Unknown schema fields are outside the
decoded comparison. Pikachu stays `source_review_required`; the byte-identity
gate has no ignore-priority rule, species whitelist or automatic waiver.
If importer behavior or source hashes change, the diagnostic must be repeated.

## Multi-material fix and Moltres

In all **5,308 TRACM files** under the cohort's 93 resolved resource directories,
the three bytes labelled frame multipliers in the
[pinned reverse-engineered schema](https://github.com/pkZukan/PokeDocs/blob/de20b28d82d5d8b473905eb2c24e5d8b47841ca8/SV/Flatbuffers/animation/tracm.fbs)
equal the number of populated material, visibility and blendshape timelines.
There were zero exceptions. This is local structural evidence supporting a
count interpretation; the field names alone were not reliable timing evidence.

The export reader now retains declared **and** measured timeline counts before
filtering by material. Multi-material playback is allowed only when they agree,
the complete UV key range agrees with the root duration, and any nested material
clock agrees with the root clock. Mismatches and independent clocks remain held.
No frame rate is multiplied or divided. Fixtures without structural evidence
retain the old single-timeline restriction.

Moltres now exports three fire materials, each with 281 source samples and a
280/60 = **4.6667-second** loop. Fresh source review/GLB export, standalone SCN
conversion/reload and native pose/timing review passed, with zero Godot errors
and seven mapped clips. Five runtime images were captured. Idle and attack were
visually inspected: species identity is correct, but flame facets are conspicuous.
Visual quality remains unapproved. Existing affine packages retain their shader.

## Remaining families and acceptance criteria

| Case | Evidence/category | Requirement before releasing the hold |
| --- | --- | --- |
| Seven absent identities | Missing catalog tuple | Matching metadata or separately verified source route; never substitute another species |
| Pikachu | Priority-only source difference; importer A/B equal | Explicit source/priority review, not a generic skeleton-equivalence waiver |
| Grimer + Muk | Same Standard lit displacement signature including animated normal UV | Implement lit layered displacement and normal-UV semantics together; compare both models |
| Ceruledge | Different Standard lit displacement signature plus unlit UV2 fire | Preserve lit body material, PBR layers and separate effect surface |
| Typhlosion | Auxiliary visibility loop, no material tracks | Native mesh-visibility playback; do not fabricate a UV loop |

The scanned visibility tracks contain **18,957 fixed-bool**, **210 dynamic-bool**,
**179 framed-8-bool**, and **1 framed-16-bool** encodings. These are storage-family
counts, not implemented visibility support. In particular, Magearna, Decidueye
and Spiritomb use multiple families; implementing fixed visibility alone will
not solve every accessory/sleep issue. Cinderace also needs material review.

## Status, tests and reproduction

- Identity gate remains 92 verified / 8 held.
- All 92 verified entries rechecked at material/effect preflight: 88 pass / 4 held.
- Cumulative technical conversions: previous 87 plus Moltres = **88**. Only
  Moltres was converted in this step; this is not 88 fresh conversions.
- Visual approval and battle/runtime qualification are separate, still pending
  for this experimental cohort. Previously installed approved assets are untouched.
- 57 focused Python tests pass, plus Godot material-effect compatibility tests,
  standalone Moltres conversion/reload, seven-clip timing/pose checks, five runtime
  captures and the two-source Pikachu import comparison. No full paired gate ran.

`catalog_100_cohort_review_results.json` retains the per-species technical,
visual and runtime-review states and compact evidence. Full local artifacts:

- `.tmp/cohort-source-audit-03.json`
- `.tmp/pikachu-skeleton-ab-01.json`
- `.tmp/moltres-timeline-review-01/`
- `.tmp/moltres-timeline-runtime-01/`
- `.tmp/moltres-timeline-images-01/`

Reproduce the read-only audit from the assigned frontend slot:

```sh
python tools/sprite_factory/scvi_source_audit.py \
  --inventory /absolute/path/to/identity-gated/inventory.json \
  --importer /absolute/path/to/pinned/addon \
  --dependencies /absolute/path/to/pinned/python-deps \
  --output /absolute/path/to/new-audit.json
```

The audit loads generated Titan schema modules, not the Blender add-on entry
point, and records decoder/consumer hashes. `skeleton_ab_worker.py` is a separate
isolated Blender diagnostic taking an entry, importer/dependency paths and a
new JSON output path. It must never be used as a production import route.
