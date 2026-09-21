# Identity follow-up: targeted repairs, not complete catalog approval

This step repairs three conversion holds and diagnoses the remaining cases. It
does **not** claim that every hold is solved or that the complete 100-model
conversion was repeated again. No source assets or installed models were changed.

## Implemented

- Normal-material selection: TRMDL references the normal material explicitly;
  the pinned importer only reads its `_rare.trmtr` sibling when shiny is selected.
  The identity gate now compares the selected normal material to ROMFS, while
  retaining hashes of all siblings. Selected-material mismatches, modified
  siblings, missing identity and shiny-with-normal-proof remain rejected.
  Eevee therefore no longer fails on an unused shiny file.
- Fixed skeletal poses: the importer no longer loses a native clip's duration
  when all source tracks are fixed. Actual fixed key values are duplicated at
  the native endpoint; no guessed idle animation is substituted. Spiritomb's
  sleep and faint-loop clips now preserve their original duration. Old cached
  imports with zero-duration clips require fresh import rather than reuse.
- Non-affine UV effects: bounded integer-frame key sequences retain their
  piecewise-linear sampled values and native loop duration, including UV wrap
  jumps. Unknown key metadata, nonperiodic loops and unsupported frame multipliers
  remain blocked. This is diagnostic playback, not certified original-game
  interpolation/shader parity. Charmander exports with animated fire again.
- A distinct unlit/two-UV material profile is recognized. It does not turn lit
  Standard displacement into unlit fire. Moltres passes material recognition,
  but its material-frame multiplier of three remains unsupported.
- Existing affine packages retain the exact old shader. Sampled effects use a
  separate embedded shader plus float UV texture; both survive standalone SCN
  reload without external shader or texture dependencies.

## Evidence

- Same 100 identity requests rechecked: **92 pass, 8 hold**.
- Material/effect preflight on those 92: **87 pass, 5 hold**. This is preflight,
  not 87 fresh conversions.
- Fresh import/source review/export attempted for Eevee, Charmander, Moltres and
  Spiritomb. **Three GLBs and three standalone SCNs succeed**; Moltres stays held.
- Each successful GLB contains all seven required mapped native clips.
- Godot reports **zero pose/timing errors** for the three successes; the diagnostic
  process returns failure overall because the Moltres hold is retained.
- Fifteen additional runtime pose images captured. Eevee/Charmander identity and
  Spiritomb sleep were inspected. Spiritomb still has visible effect remnants
  below its stone during sleep, so it is not visually approved. Charmander's
  flame geometry also remains visibly coarse; this is not an art-parity claim.
- 53 focused Python tests pass. Godot material-effect tests cover the existing
  affine shader, sampled UV data, invalid input rejection, actor compatibility,
  packed SCN reload and absence of external dependencies.

The previous run's 84 successes plus these three newly converted identities
give **87 cumulative technical candidates**, not 87 battle-approved models.
The compact evidence is in `catalog_100_identity_hardening_results.json`.

Local slot-b evidence:

- `.tmp/identity-hardening-inventory-01/inventory.json`
- `.tmp/identity-hardening-review-01/` (including held Moltres logs)
- `.tmp/identity-hardening-runtime-01/report.json`
- `.tmp/identity-hardening-images-01/`

## Remaining blockers — explicitly not solved

1. **Seven absent identities:** Silvally, Blacephalon, Marshadow, Stakataka,
   Alcremie, Hydrapple and Terapagos have no matching tuple in the supplied
   catalog. Only one catalog was found locally, also present inside the original
   nested `SV-Everything.7z`. More appropriate source metadata, or a separately
   verified non-SCVI source route, is needed; no replacement species is inferred.
2. **Pikachu source mismatch:** decoding both skeletons shows identical 81 nodes
   and 55 bones. Six upper/lower eyelid node priority fields differ (0 versus 2).
   All other fields decoded by the pinned TRSKL schema agree. Byte identity is
   still not established, and priority semantics have not been waived. The source
   files remain unchanged and held.
3. **Grimer, Muk and Ceruledge:** Standard lit displacement/layered PBR profiles
   need their own faithful implementation. Reusing the unlit smoke shader would
   be incorrect. Ceruledge additionally has an unlit UV2 fire surface.
4. **Moltres:** the source loop declares material-frame multiplier 3, while the
   reviewed sampler supports 1. Do not guess that these have the same clock.
5. **Typhlosion:** the auxiliary loop is a 21-frame, 60-fps visibility animation
   with three mesh visibility tracks and no material tracks. It is not a missing
   UV scroll to replace with a constant. Visibility-channel support is required.

The [pinned TRACM schema](https://github.com/pkZukan/PokeDocs/blob/de20b28d82d5d8b473905eb2c24e5d8b47841ca8/SV/Flatbuffers/animation/tracm.fbs)
names the separate material/visibility frame multipliers, but does not specify
the meaning of all interpolation config fields. These unknowns remain explicit.
Previously noted Magearna/Decidueye/Cinderace/Gastly visibility/material concerns
have not been fixed by this step. No full development gate, approval or deployment
was performed.
