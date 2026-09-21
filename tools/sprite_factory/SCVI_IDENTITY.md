# SCVI identity gate

The resource catalog in the supplied ROMFS explicitly maps internal species,
form and gender codes to model, material-table, configuration, icon and animation
resources. `pmNNNN` is a resource ID. It must never be interpreted as a National
Dex number. The first 100-model batch made that mistake for some entries.

## Evidence chain

1. `pokemon/catalog/catalog/poke_resource_table.trpmcatalog` supplies the resource
   references and internal species/form/gender tuple. Its SHA-256 is retained.
2. Internal species IDs are translated with the bounded, pinned
   [pkNX Gen9 mapping](https://github.com/kwsch/pkNX/blob/d191cd0e5c05f2af81d9a41c1f1d82e6621b351a/FlatBuffers/SV/Shared/Gen9/SpeciesConverterSV.cs).
   This second translation is published reverse-engineering data, not a claim
   that the ROMFS catalog itself contains National Dex IDs. No arithmetic offset
   is guessed from resource filenames. Unknown ID coverage fails.
3. The requested species slug and National Dex number come from the local backend
   species JSON. That exact file and its hash are attached to the evidence.
4. Model/config/material-table, binary mesh/skeleton and the selected normal
   material resources must match ROMFS byte-for-byte. Unselected sibling material
   files are hash-bound but not treated as inputs to the normal importer.
   Texture PNGs and the complete
   selected model directory are hash-bound for reproducibility; PNG/BNTX pixel
   parity is a separate visual/material question.
   TRMDL mesh, skeleton and default-material references are also parsed and must
   resolve within the selected, verified resource.
5. The extracted resource bundle (`*_base.tracn`) references TRACR files whose
   explicit track references must contain every selected TRANM/TRACM. Catalog
   paths use the logical `.tracn` stem; the supplied extraction has named bundles.
   The reader records the actual bundle and resource hashes. It never borrows
   tracks from another resource directory.
6. SCVI source import and diagnostic GLB export repeat the proof check. Export
   additionally requires the prepared import's species, resource ID, normal
   variant, source hashes and selected actions to agree. Changed evidence,
   relabelled jobs, missing identities and mixed sources are rejected.
   Prepared Blender files have an import-time hash. Older imports require their
   pre-existing source-review hash before read-only reuse; current bytes are
   never accepted as a replacement baseline.

The bounded decoder follows the pinned PokeDocs schemas for
[TRPMCATALOG](https://github.com/pkZukan/PokeDocs/blob/de20b28d82d5d8b473905eb2c24e5d8b47841ca8/SV/Flatbuffers/resources/trpmcatalog.fbs),
[TRACN](https://github.com/pkZukan/PokeDocs/blob/de20b28d82d5d8b473905eb2c24e5d8b47841ca8/SV/Flatbuffers/animation/tracn.fbs)
and [TRACR](https://github.com/pkZukan/PokeDocs/blob/de20b28d82d5d8b473905eb2c24e5d8b47841ca8/SV/Flatbuffers/animation/tracr.fbs).
Schema version 6 is the reviewed catalog version. The explicit null and egg
sentinels are excluded. Catalog sharing is preserved in the parsed data:
multiple forms can legitimately share a model. Such forms, and cross-form
animation catalogs, are held until their selector semantics are implemented.
Gender is retained as the catalog's numeric code, not guessed from filenames.

## Reproduction

Run from the assigned frontend slot, supplying absolute local paths:

```sh
python tools/sprite_factory/scvi_identity.py \
  --batch tools/sprite_factory/catalog_100_observation_batch.json \
  --catalog "$romfs/pokemon/catalog/catalog/poke_resource_table.trpmcatalog" \
  --model-root "$models" --motion-root "$romfs/pokemon/data" \
  --species-root "$species_data" --output "$new_inventory"

python tools/sprite_factory/identity_batch_review.py \
  --inventory "$new_inventory/inventory.json" \
  --model-root "$models" --motion-root "$romfs/pokemon/data" \
  --importer "$pinned_importer" --python-deps "$importer_deps" \
  --output "$new_review"
```

Optional `--prepared-from` reuses existing imports read-only after source/action
provenance checks. Source pose renders and GLB export still run again. Outputs
must be new directories. Run subsequent Godot review/conversion through the slot
environment. Python/Flatpak commands use the normal user's Flatpak installation.

Old inventory without identity evidence can still be inspected, but cannot start
a new SCVI import or SCVI diagnostic export. Recreate its inventory using this
gate. Existing installed assets and legacy Blend review are unchanged.

## Scope

This first gated run supports normal variants with a unique catalog tuple and
resource selection. Shared-form selectors and full shiny verification are not
silently inferred. A proof establishes source identity and binds the input
files; it does not establish visual quality, relative battle scale, grounding,
shader parity, or runtime approval. Every result remains `runtime_approved=false`.

The same requested 100 species are retained. A corrected lookup may point to
another resource ID, or may be unavailable in this catalog. Counts from the
first run therefore cannot be treated as counts of correctly identified species.

## Completed same-cohort run

These are the original gated-run results. The subsequent incremental repair
results and remaining holds are in [SCVI_IDENTITY_HARDENING.md](SCVI_IDENTITY_HARDENING.md).

The local catalog has 680 non-sentinel form/gender rows covering 478 National
Dex species. Its SHA-256 is
`24b322e3d9575f8c6648862c3a08db1940eb9e2e03d2efa490e5b21c55c9f96e`.
The original 100-row batch had **18 wrong species/resource associations**.
Eleven can be corrected using this catalog; seven requested species are absent.
The previous report's Cursola-like identification of `pm0801` was incorrect:
the catalog identifies it as species 747, Mareanie.

| Measurement | Gated rerun |
| --- | ---: |
| Same requested species | 100 |
| Verified identity and source bundle | 91 |
| Identity/source holds | 9 |
| Successful GLB + standalone SCN conversion | 84 |
| Export holds after identity verification | 7 |
| Native mapped clips per successful model | 7 |
| Godot pose/timing error entries | 0 |
| Runtime pose captures | 420 |
| Approved/activated models | 0 |

Identity holds:

- Silvally, Blacephalon, Marshadow, Stakataka, Alcremie, Hydrapple and Terapagos:
  no matching species/form/gender row in the supplied catalog. No substitute.
- Pikachu: the model dump's `pm0025_00_00.trskl` differs from ROMFS.
- Eevee: the model dump's `pm0133_00_00_rare.trmtr` differs from ROMFS. This
  initial gate binds the complete source bundle, so even a normal-only review
  holds on this mismatch. The reason is a source conflict, not a claim that
  the normal Eevee mesh itself is wrong.

Export holds, grouped with the corrected species identities:

- Non-affine effect UV track: Charmander.
- Unsupported source shader profiles: Grimer, Muk, Moltres, Ceruledge.
- Missing/ambiguous auxiliary effect loop: Typhlosion.
- Empty mapped sleep action: Spiritomb.

The original failures labelled Blacephalon and Stakataka concerned other
resources; those labels must not guide species-specific fixes. Source mapping
and converter output were rechecked with the final gate. A limited export
repeat corrected sandbox read grants for three legacy source-review hashes;
those harness failures are retained in the earlier logs, not counted as source
or model defects.

All exported idle front/back contact sheets were scanned for identity, and all
five poses were inspected for the corrected identities. New visual observations
remain: Magearna's bouquet and Decidueye's arrow-like accessory stay visible
across sampled poses; Cinderace has black effect geometry near its feet. These
need source visibility/material investigation before art approval. Gastly's
previous smoke faceting/overlap concern remains. A successful identity check
does not hide these visual issues or turn an export into an approved model.

Focused validation: 36 identity/intake/review Python tests; exact comparison of
the pinned National Dex offsets; real-source proof and prepared-file hash checks;
84 complete native-clip Godot timing/pose reviews; 84 SCN reload/dependency/hash
checks; 420 runtime captures. No full development gate was run.

Compact per-species evidence is committed in
`catalog_100_identity_results.json`. Slot-b local artifacts:

- `.tmp/catalog-100-identity-02/inventory.json`
- `.tmp/catalog-100-identity-rerun-01/` — source renders and initial exports
- `.tmp/catalog-100-identity-final/` — consolidated export/Godot report
- `.tmp/catalog-100-identity-runtime/` and `.tmp/catalog-100-identity-images/`
- `.tmp/catalog-100-identity-results/index.html` — full image gallery

Next work is to obtain matching metadata for the seven absent species,
reconcile the two conflicting source bundles, then investigate the four export
failure groups and the visible accessory/effect issues. A larger species batch
is not needed to resolve these findings.
