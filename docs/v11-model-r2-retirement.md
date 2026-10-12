# Retiring the v11 payloads after production v13 activation

The current Windows/Linux/macOS production manifests select v13. Of the 1,200
v11 ZIPs, v13 reuses 55 (140,477,672 bytes). The other 1,145 ZIPs total
12,716,839,877 bytes and are the sole deletion allowlist. Indexes, shared PCKs,
the 55 reused ZIPs, game/launcher archives and other assets are excluded.

Before deleting anything, `tools/retire_v11_model_objects.py backup` copies the
entire v11 release (all 1,200 ZIPs plus its pinned index) into a separate durable
directory outside the task worktrees. Sources are retained immutable release
archives read in place, not credentials, game installations or userdata. Every
copied file is checked against its size and SHA-256, then the whole backup is
rehashed independently. A `restore-archives-report.json` binds the backed-up
paths to the approved legacy metadata and is accepted by the existing v11
publication tool.

The operation authorized on 12 October 2026 uses:

```sh
backup=/home/adinho/Documents/PokeAetherBackups/r2-v11-20261012
credentials=/home/adinho/Desktop/pokemonaetheronline/game/pokemon-aether-online/.env

python3 tools/retire_v11_model_objects.py backup \
  --backup-directory "$backup" \
  --archives-report .tmp/lossless-catalog-v1/prepared/report.json

python3 tools/publish_approved_3d_index_v11.py \
  --archives-report "$backup/restore-archives-report.json"

python3 tools/retire_v11_model_objects.py plan \
  --backup-directory "$backup" --credentials "$credentials" \
  --plan release/approved_3d_bundles_v11_retirement_plan.json

# Apply requires the exact SHA-256 printed by the reviewed plan.
python3 tools/retire_v11_model_objects.py apply \
  --backup-directory "$backup" --credentials "$credentials" \
  --plan release/approved_3d_bundles_v11_retirement_plan.json \
  --receipt release/approved_3d_bundles_v11_retirement_receipt.json \
  --confirm-plan-sha256 REVIEWED_PLAN_SHA256

python3 tools/retire_v11_model_objects.py verify \
  --backup-directory "$backup" --credentials "$credentials"
```

Commands execute from the assigned frontend task worktree. Credentials are read
from the existing authorized file in place and never copied into the backup,
plan, journal or receipt. Backup verification and live v13 descriptor/index
verification precede deletion. The signed R2 inventory must contain every
active payload at its pinned size. Each deletion is checked at the origin and
journaled; fresh manifest snapshots gate every batch. The final receipt confirms
all 1,200 current payloads remain and all 1,145 retired keys are absent at R2.
This leaves public manifests byte-identical. An interrupted apply can be rerun
with the same plan/digest; completed journal entries keep their original outcome.

## Restoration

After a deliberate retirement, v11 is an offline archive, not an immediately
available R2 rollback generation. Older clients requesting its retired ZIPs
must update. The two production observations (shiny Hydreigon and normal
Tyranitar) supplement the earlier full qualification; they do not constitute
native Windows/macOS runtime testing or telemetry for all model loads.

To restore the immutable old files, prepare an assigned frontend task or release
worktree containing the existing v11 publisher, then run the following only
after explicit restoration authorization:

```sh
python3 tools/publish_approved_3d_index_v11.py \
  --archives-report /home/adinho/Documents/PokeAetherBackups/r2-v11-20261012/restore-archives-report.json \
  --credentials /home/adinho/Desktop/pokemonaetheronline/game/pokemon-aether-online/.env \
  --apply
```

Without `--apply`, that command rehashes all backup archives and validates the
approved metadata entirely offline. With `--apply`, it uploads missing v11
objects and verifies full public GET hashes and HEAD sizes. It restores the
model collection without changing any active game/launcher manifest. Switching
players back requires a separately authorized compatible game/launcher release;
changing only a model descriptor would violate installed client pins.

Keep the backup directory and its manifest with the plan and retirement receipt.
The origin inventory, rather than cached CDN responses, proves deletion. A CDN
may temporarily keep an old response after the R2 object has been retired.
