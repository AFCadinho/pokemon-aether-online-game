# Remaining lossless texture sharing after v16

This is an offline, unpublished candidate. Production still selects the approved
v16 collection. No updater pins, release workflows, model profiles or source
budgets are changed by this study.

## Measured archive sizes

| Collection | Archive bytes |
| --- | ---: |
| Published v16 | 6,989,696,054 |
| Expanded sharing, including all new pools and manifests | 6,795,118,238 |
| Additional net saving | 194,577,816 |

The candidate changes 185 model pairs and moves 1,836 texture members from those
pairs into 50 new data-only texture packs (354 shared texture groups). The
existing Minior pool stays in place. The complete collection still supplies
1,420 model pairs and 2,840 normal/shiny appearances, with 1,471 archives in total.

Each new pool groups only textures with exactly the same set of consumers.
Consequently a model never has to download textures used only by other members
of that pool. There are at most three texture dependencies per changed model;
56 changed models use multiple pools. Unprofitable small pools are excluded
using a conservative allowance for repeated manifests and scene rewrites.
The final net saving uses complete physical PCK sizes, including pack headers,
embedded manifests, alignment and fresh scene namespaces.

## Evidence and scope

The builder reads the hash-bound published v16 assembly and the existing full
lossless texture audit in place. It retains an exact existing payload for each
pooled texture. Meshes, skins, animation libraries and private textures remain
byte-for-byte unchanged. Scene edits are restricted to equal-length resource
path rebinding; native resource bodies remain exact.

`qualify_shared_texture_expansion.py` compares all 185 changed pairs with their
released v16 sources using Godot 4.6.2 and the Linux Compatibility renderer.
It checks both appearances, complete normalized scene and decoded texture/mip
states, every animation at three positions, deep scene duplicates, simultaneous
actors, local material isolation and survival after another actor is freed.
It repeats the complete cohort in fresh processes with reverse model order.

`shared_texture_expansion_contract_check.gd` checks the complete candidate
dependency graph, game and launcher metadata validation, dependency ordering,
missing/tampered pools, and continued exclusion of unpublished appearance hashes
from production selectors. `validate_shared_texture_expansion.py` independently
reopens the changed archives and pools and binds their exact native bodies,
collection accounting, original source budgets and cold/restart evidence.

The tracked receipt is `release/shared_texture_expansion_v16_qualification.json`.
Its `runtime_approved` and `publication_approved` flags remain false: this is
native equivalence and dependency-contract evidence, not an updater release
approval. Windows, macOS and physical Android runtime qualification is not
claimed. Actual downloader/launcher handoff qualification, fresh release pins
and normal release certification are still needed before activating this
candidate on R2.

## Reproduce in an assigned slot

Run from the assigned frontend directory, with all commands through the workspace
`ops/worktrees/slot-env SLOT --` wrapper.
Use fresh output directories inside that frontend slot's `.tmp` directory.
Retained evidence and archives must remain at their hash-bound paths; do not
copy caches, configuration or old outputs into another slot.

```sh
python3 tools/study_shared_texture_expansion.py --output .tmp/expansion
python3 tools/qualify_shared_texture_expansion.py \
  --configuration .tmp/expansion/configuration.json \
  --work .tmp/expansion-qualified --workers 2
godot --headless --path . --log-file .tmp/expansion-contract-engine.log \
  --script res://tests/shared_texture_expansion_contract_check.gd \
  -- .tmp/expansion/configuration.json > .tmp/expansion-contract.log 2>&1
python3 tools/validate_shared_texture_expansion.py \
  --qualification .tmp/expansion-qualified/qualification.json \
  --contract-log .tmp/expansion-contract.log \
  --output .tmp/expansion-validated.json
```

The contract check can also run in the linked minimal project created by
`run_shared_texture_runtime_checks.project`, without importing unrelated game
assets or enabling the candidate in the game.
