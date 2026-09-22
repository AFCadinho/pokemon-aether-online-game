# Catalog 100 — observation-only scale test

This batch deliberately tests the source-to-Godot conversion path at a larger
scale without activating, admitting or repairing any Pokémon. The explicit
cohort is in `catalog_100_observation_batch.json`: 100 normal-variant,
SCVI-compatible candidates spanning small, large, quadruped, humanoid, flying,
floating, segmented and unusual-body forms. It is not a promise that each source
directory has a verified National Pokédex identity.

## Results

| Stage | Result |
| --- | ---: |
| Inventory/source review | 100 / 100 candidates available |
| GLB export for review | 92 |
| Held before export | 8 |
| Exported pose/timing Godot review errors | 0 |
| Standalone SCN conversions | 92 |
| Captured auto-fit review frames | 460 (five per conversion) |
| Runtime-approved/admitted | 0 |

The eight holds are intentionally fail-closed. No opaque fallback, synthetic
clip or species-specific repair was introduced:

- `charmander`: one effect UV channel is non-affine.
- `typhlosion`, `blacephalon`, `stakataka`: an auxiliary effect loop is missing
  or ambiguous.
- `grimer`, `muk`, `moltres`: an unsupported source shader profile is present.
- `spiritomb`: the mapped sleep action is empty.

These are four generic failure groups, not eight manual manifest edits. They are
the next hardening candidates only after their source semantics are established.

## Important source-identity finding

**Follow-up correction:** the supplied resource catalog explicitly identifies
these models. Our batch incorrectly treated several resource IDs as National
Dex IDs. For example, `pm0801` maps to internal species 747 (Mareanie), not
Magearna. The original visual description below was provisional and incorrectly
called it Cursola-like. There is no evidence here of a corrupt/mislabelled dump.
See [SCVI_IDENTITY.md](SCVI_IDENTITY.md) for the verified lookup and hard gate.

The technical 92/100 result is **not** a 92-model approval result. The static
gallery exposed a separate source-integrity boundary: some supplied SCVI-dump
directories cannot currently be trusted to mean the National Pokédex number we
assigned to their `pmNNNN` path. For example, the source icon and converted
model under `pm0801` are visibly Cursola-like while the batch mapping labelled
that directory `magearna`; the sampled `cinderace` and `corviknight` entries are
also visibly not their expected species. The issue is present in the supplied
source mapping, not a Godot material, scale or animation correction.

Consequently, all 100 rows remain observation-only. Before a second 100-model
pass or any model admission, inventory needs an identity-validation layer that
checks each source icon/model against a trusted species identity mapping. It
must fail closed on a mismatch; no guessed offset or per-species remap should be
committed from this sample alone.

## Evidence and limits

Slot-local, ignored artifacts contain the reproducible evidence:

- `.tmp/catalog-100-source-review-02/` — source review jobs;
- `.tmp/catalog-100-export/` — GLBs and Godot pose/timing review;
- `.tmp/catalog-100-runtime/` — standalone SCNs and hash checks;
- `.tmp/catalog-100-images/` — 460 rendered frames;
- `.tmp/catalog-100-results/index.html` — gallery and machine-readable
  `observations.json`.

Frames use normal variants and automatic framing. They test conversion,
animation availability and source identity review; they do not certify battle
scale, grounding, battle lighting, shader parity, shiny parity, memory/cache
behaviour, live battles or performance. No source asset was edited.

## Next phase

1. Add a generic, trusted source-identity validator before inventory admission.
2. Diagnose the four export-hold groups as source semantics, adding only generic
   rules that are evidenced across models.
3. Rerun this exact cohort unchanged. Only then select candidates for separate
   battle framing and admission review.
