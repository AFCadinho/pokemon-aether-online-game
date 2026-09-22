# Local Garchomp activation — 2026-09-22

User-authorized local activation of the reviewed standing-bank candidate.
Only normal Garchomp changes; the other 74 screened entries and shiny fallback
remain unchanged. This does not promote it into the portable production pack.

## Paired metadata update

- `screened_model_catalog.json`: Garchomp SCN/GLB hashes now match the candidate.
- Garchomp faint-start timing: 100 native frames instead of 80; other timing,
  placement and playback speeds unchanged.
- Local `/home/adinho/Documents/3d_models/PokeAether/screened-catalog-v1/catalog.json`:
  only Garchomp's runtime path and hash changed.
- New SCN remains at the retained slot-b artifact path recorded in
  `garchomp_bank_candidate_results.json`. No binary was overwritten or copied
  between checkouts, and no settings/session/cache files were modified.

Restart the local development client, select 3D battle presentation, and inspect
normal Garchomp in Pokédex, summary or a newly started battle. An already open
client/battle may still hold the old resource snapshot.

## Verification through normal admission

- `screened_model_catalog_check.gd`: all 75 entries accepted; unaffected
  Charizard/Azumarill asynchronous loads passed.
- `summary_model_preview_check.gd`: Garchomp/Azumarill, existing play menu,
  faint→damage reset, zoom, replay, independent cards and fallback passed.
  Pre-existing unrelated icon/audio UID fallbacks were logged.
- `garchomp_arena_review.gd` with `CANDIDATE_USE_ACTIVE_CATALOG=1`: uses the
  unmodified production presenter class, **not** the candidate admission adapter.
  Both Forest and Stadium passed two action/faint/replacement cycles, with
  candidate hash and 100-frame timing asserted after normal catalog loading.
- Active-catalog captures/results retained in slot-b/frontend
  `.tmp/garchomp-active-arena-review-01/`.

Earlier reports remain historical snapshots of the then-inactive candidate;
this document records the subsequent local activation. Small ground contact
deviations and the artificial faint-start interruption limitation remain as
documented in the candidate/arena reports. No claim of full networked PvP,
all-arena, shiny or distribution certification is made.

## Rollback

`garchomp_local_activation_rollback.json` preserves the exact old catalog entry,
old registry model and old timing/placement profile. The old SCN still exists
unchanged at its original path and its SHA-256 was rechecked before activation.
Restore all three metadata sections together if rollback is requested; restoring
only the catalog path would fail the hash gate or pair the wrong faint duration.

No main promotion, push, deployment, full integration gate or catalog-wide
rebuild was performed.
