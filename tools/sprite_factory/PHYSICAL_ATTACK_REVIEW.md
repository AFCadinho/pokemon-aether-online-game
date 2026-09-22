# Physical attack review catalog

`physical_attack_review.py` compares the two native SCVI physical attack clips
without changing the runtime catalog or enabling a move mapping. Every preview
is a short `idle -> attack -> idle` loop generated from an identity-gated,
action-scoped Blender source.

The automatic pass measures local bone motion and groups alternate clips as
`forelimb-led`, `leg-led`, `tail-led`, `wing-led`, `body-led`, `mixed`, or
`unknown`. Those groups are reliable navigation aids, not move semantics. A
forelimb-led animation cannot automatically be called a punch or claw/slash,
and whole-body motion does not by itself prove a charge. Semantic labels remain
unapproved until visually confirmed.

The HTML gallery supports:

- side-by-side primary and alternate loops;
- filters for the automatic alternate-motion group and Pokémon name;
- explicit labels for bite, claw/slash, punch, kick, body/charge, tail, wing,
  generic, and unclear;
- one confirmation checkbox and note per Pokémon;
- download of a review decision JSON file.

The downloaded decisions are review evidence only. No script consumes them as
a runtime mapping automatically.

## Current local review

The current screened cohort produced 75/75 review-ready Pokémon and 150 loops:

`slot-b/frontend/.tmp/physical-attack-review-75-02/index.html`

The deliberately conservative semantic pass marked 2 alternate clips as clear
suggestions (Cloyster: body/charge; Marill: tail) and kept 73 in the human
review queue. This is evidence that skeletal metrics are useful for sorting but
cannot safely replace visual semantics across varied anatomy.

The subsequent contact-sheet review classified 69 alternate clips as visual
candidates and retained 6 genuinely ambiguous clips for animated/human review:
Delibird, Drowzee, Gardevoir, Jigglypuff, Psyduck, and Slaking. Candidate labels
are stored in `physical_attack_semantic_decisions.json`; the evidence-bound
export is `physical_attack_semantic_evidence.json`. Every evidence row records
the exact SCVI action, prepared-source hash, and lossless-loop hash. Both files
remain `runtime_approved: false`; neither is consumed by battle routing.

Those six ambiguous cases were subsequently reviewed in the animated gallery.
Both physical clips are retained in `physical_attack_human_review.json` with
their exact source-action and loop hashes. Their alternate labels are now:
Delibird body/charge, Drowzee kick, Gardevoir body/charge, Jigglypuff
body/charge, Psyduck body/charge, and Slaking punch. Slaking's primary clip has
an additional reviewer note that it reads more like a grab. This closes the
semantic queue for this 75-Pokémon cohort without activating runtime routing.

| Visual family | Count |
| --- | ---: |
| body/charge | 36 |
| tail | 13 |
| wing | 7 |
| punch | 7 |
| kick | 1 |
| claw/slash | 5 |
| bite | 3 |
| generic | 3 |

Alternate-clip navigation groups:

| Group | Pokémon |
| --- | ---: |
| mixed | 28 |
| forelimb-led | 17 |
| body-led | 13 |
| leg-led | 7 |
| unknown | 5 |
| wing-led | 3 |
| tail-led | 2 |

No label, reviewed-model registry, scene, battle mapping, or player setting was
changed by this run.

## Reproduction

First build a current identity inventory with `scvi_identity.py`. Then run:

```sh
python tools/sprite_factory/physical_attack_review.py \
  --inventory /absolute/path/to/inventory.json \
  --prepared /absolute/path/to/new-review-sources \
  --output /absolute/path/to/new-review-output \
  --screened-registry scripts/battle/battle_ui/screened_model_catalog.json \
  --prepare-missing \
  --importer /absolute/path/to/pinned-importer \
  --python-deps /absolute/path/to/importer-dependencies \
  --model-root /absolute/path/to/model-dump \
  --motion-root /absolute/path/to/romfs/pokemon/data \
  --jobs 2
```

Use `--resume` after an interrupted render. Complete rows and lossless WebP
loops are reused; incomplete rows are regenerated. The output directory must be
new unless `--resume` is explicit.
