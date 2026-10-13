# Cross-form resource audit of model release v14

This offline study examines the active 1,420-pair / 2,840-appearance collection
at 8,993,498,070 bytes. It does not change model archives, game/launcher loading,
approved catalogs, R2 or installed generations. This is a storage opportunity
audit, not rollout qualification.

## Scope and safeguards

`tools/audit_cross_form_resources.py` resolves the approved v14 wire index
against its hash-pinned compiled catalog and publication binding. Every retained
archive is read in place and checked against its approved SHA-256 and size. PCK
members, manifest, bounds, MD5 and SHA-256 are independently checked. ZIP scenes
are checked against their approved runtime hashes.

The inventory contains 1,031 geometry-sharing PCK pairs, 334 texture-sharing PCK
pairs and 55 ZIP pairs, with 30,680 external native resource files. Matching
resource filenames nominate candidates; filenames alone cannot qualify a
saving. Godot recomputes each nominated resource's strict semantic signature
from the real checked pack. Full names, locality, class, pixels, dimensions,
format, mipmaps and remaining stored properties must agree. Mesh keys exclude
material bindings, as in the existing geometry-sharing producer; appearances
would have to retain their own effective material overrides.

Nominated external resources must have no dependencies, no scene-local flag
and no material/mesh/method-sensitive animation tracks. The engine also loads
both appearances of all 389 pairs that still contain embedded geometry or
textures and inventories their resources. No scene actor is instantiated or
rendered by this audit. Embedded matches are reported separately: their raw
image bytes are not interchangeable with compressed archive savings.

## Measured external-member opportunity

There are 551 matching resource-signature groups spanning different pairs,
with 3,275 resource occurrences. The corresponding files are not byte-identical
across pairs, so deleting identical R2 objects cannot implement the sharing.

| Category | Compressed duplicate member bytes |
| --- | ---: |
| Textures | 294,431,257 |
| Animation libraries | 7,855,991 |
| Meshes | 561,460 |
| Skins | 26,343 |
| **Total** | **302,875,051** |

This is approximately **303 MB / 3.37%** of the current collection. It counts
each resource once per pair and retains one existing complete copy, choosing
the smallest measured copy. It is a member-byte opportunity, not a measured
replacement archive or guaranteed download/installed saving. Scene rewriting,
container overhead, shared-pool metadata and dependency accounting are not yet
measured. Embedded-resource matches are excluded from this total.

The complete engine run succeeds with no captured errors. It also inventories
6,649 embedded resource objects and finds **152 additional cross-pair signature
groups**: 115 meshes, 35 skins and two animation libraries. Their independently
measured compressed size is unknown, so they add no bytes to the advertised
303 MB opportunity. Geometry matches do not imply identical appearance
materials or interchangeable scene hierarchies.

Conservative groups wholly inside the following named form sets account for:

| Form set | Member-byte opportunity |
| --- | ---: |
| Pikachu | 63,065,182 |
| Ogerpon | 38,960,427 |
| Arceus | 37,184,775 |
| Vivillon | 32,190,015 |
| Alcremie | 28,132,831 |
| Minior | 23,658,077 |

These disjoint examples use exact species-ID prefixes, not an inferred
Pokédex-family mapping, and do not sum to the whole catalog total.

## Recommended next experiment

First measure complete geometry-sharing candidate packs for the **220 newly
added pairs**. They currently share textures but retain geometry and animation
content inside both appearance scenes. The 114 older texture-sharing pairs
include previously deferred resource-name or sensitive-track cases; this audit
does not override those guards. A new pair also needs those same checks before
conversion. Existing schema-2 production loading can support a successful
within-pair conversion, though fresh immutable keys and pinned client catalogs
are still required for release.

For cross-form sharing, use a small Vivillon or Pikachu experiment to measure
complete archives, actual model loading, separate normal/shiny material
ownership, animations, deletion order and cache reinstall/rollback. Current
`model_pair_pack.gd` explicitly rejects dependencies outside each pair's
`resource_root`; a shared pool therefore needs a separately versioned game and
launcher contract. Do not expand that format across the collection based on
the 303 MB inventory alone.

## Reproduction

Run these from the assigned frontend slot. The source-map argument must point
to the retained, approved v14 archives; no archives or other checkout caches
are copied. Output directories must be fresh.

```bash
python3 tools/audit_cross_form_resources.py \
  --sources /absolute/retained/model-release-v14/sources.json \
  --output .tmp/cross-form-resource-audit-v2

/absolute/game/ops/worktrees/slot-env slot-c -- godot --headless \
  --path /absolute/game/.worktrees/slot-c/frontend \
  --log-file /absolute/game/.worktrees/slot-c/frontend/.tmp/resource-engine.log \
  --script res://tools/sprite_factory/cross_form_resource_check.gd -- \
  /absolute/game/.worktrees/slot-c/frontend/.tmp/cross-form-resource-audit-v2/engine-job.json \
  /absolute/game/.worktrees/slot-c/frontend/.tmp/cross-form-resource-audit-v2/engine-report.json

python3 tools/audit_cross_form_resources.py \
  --output .tmp/cross-form-resource-audit-v2 --finalize

python3 -m unittest discover -s tools -p test_audit_cross_form_resources.py
```

The finalized report binds the inventory implementation, engine implementation,
engine input, engine output and v14 source metadata by SHA-256. Local inventory,
engine records, extracted ZIP scenes and logs remain under the assigned slot's
`.tmp/cross-form-resource-audit-v2*`. The compact committed receipt records their
hashes and totals. Linux Godot 4.6.2 semantic loading is the engine scope;
rendered battles and native Windows/macOS/physical Android operation are not
qualified by this audit.
