# Batch material response correction

The approved Dragonite and Roaring Moon used source-derived shadow-colour
endpoints and specular response metadata. Phase 5's GLB-to-SCN conversion had
omitted that preparation. This was not a lower-quality mesh source: removing
the response from the approved models reproduces the batch result exactly in
the controlled idle render.

## Pipeline

- `phase5_godot_export_worker.py` now bakes the supported SCVI graph response
  before the existing PBR conversion. `scvi_response_bake.py` works on copies,
  never saves the source Blend, and emits hashed endpoint images and constant
  source IOR/specular inputs in `export.json.material_response`.
- `material_response_pack.gd` validates the GLB binding, endpoint hashes,
  supported ramp, inputs and surfaces, embeds the textures in the runtime SCN,
  and sets the existing renderer's response metadata. The runtime converter
  checks that this survives a save/reload. The earlier standalone embed tool
  uses the same implementation.
- Shiny conversion explicitly discards the normal response and requires its
  own exported response. No per-species tint or lighting correction is added.
- Unsupported graphs fail review rather than receive guessed colours. This
  supports the audited opaque, nonmetallic EASE-ramp graph only, not arbitrary
  Blender materials, animated materials, emission or transparency. Direct
  Biochao translations remain a separate review path.

## Model revisions and local evidence

Four new runtime hashes are registered: normal/shiny Dragonite and Roaring
Moon. Geometry, embedded GLB textures and motion are unchanged; all four GLBs
are byte-identical to their previous Phase 5 exports. Grounding and motion
profiles are reused with the resolved runtime hash. Explicit previous hashes
remain approved so installing this code does not invalidate existing packs.
The launcher and game registry/validator snapshots must stay identical.

Local evidence is retained under slot-c (not shipped as game assets):

- `.tmp/response-batch-01`: four Blender exports, hashed source endpoints.
- `.tmp/response-runtime-01`: four rebuilt self-contained SCNs and full
  14-entry catalog; ten unrelated runtime scenes are unchanged.
- `.tmp/model-quality-fixed`: fixed-camera neutral-light idle comparison.
  Approved normal and corrected normal images match in every RGBA pixel for
  both controls; all normal endpoint pixels also match the approved bake.
  This is a controlled pose comparison, not every-pose visual certification.
- `.tmp/response-stress-02`: production-registry lifecycle run completes, but
  records one uncovered 175 ms interval when loading Snorlax/Dragonite;
  shader pipeline counters also increase. Retained as cold-run evidence, not
  a claim of hitch-free rendering.
- `.tmp/response-stress-pack`: repeat using the installed portable package;
  all 3 battles, 36 mixed switches, 21 duplicate/faint replacements, 21
  variant checks and 3 replay sequences complete. Frame p95 is
  17.43/17.55/17.88 ms, maximum main-thread load callback 2.04 ms and final
  two-round static-memory growth 67,496 bytes. The same Snorlax/Dragonite
  interval recurs at 176.65 ms: this is reproducible, not dismissed as noise.
  The strict <=100 ms uncovered-hitch qualification therefore does **not**
  pass. Material fidelity and functional tests pass; shader/load warm-up is
  a remaining performance issue, and this change is not renewed full 5C
  performance certification or live PvP certification.
- `.tmp/response-launcher-test`: real launcher import/selection, checksum and
  malformed-package rejection checks in isolated test storage.

The new local artifact is `artifacts/phase5-reviewed-models-v2.zip`, installed
separately at `model-packs/phase5-reviewed-v2/catalog.json`. Import/select v2 in
the launcher's 3D-model window, or choose that catalog in local game settings.
Saved selections and v1 files are not overwritten; v1 keeps its old appearance.
This is a local development artifact, not a published release.

Artifact SHA-256: `3979b2c6a3a98a9c3a8f9ab030a727404fd329b4d40bca4f9baa787db13b50e2`.

Focused checks: 28 Python tests (registry parity, package security/backward
compatibility, review and acceptance logic); batch material validation and
SCN round-trip; portable runtime admission; real launcher package import;
the two functional stress runs above. Existing scene UID fallback warnings
remain; no runtime/script errors in the completed stress runs.
