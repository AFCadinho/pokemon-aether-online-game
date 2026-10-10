# 3D move attachment coverage

Generated from the runtime attachment registry and both supported model catalogs.
The [complete inventory](move-attachment-coverage.json) includes every catalog species/form, normal/shiny variant, battle alias, configured part, and source digest.

## Results

- Catalog models: 1200 species/forms, 1200 normal + 1200 shiny = 2400 identities.
- Additional battle lookup aliases checked separately: 6 (including spelling aliases and shared-model forms).
- At least one configured anatomical attachment: 5 species/forms.
- No anatomical attachment profile: 1195 species/forms; these use bounds-based fallback positions.
- Mouth attachments: 4 species/forms.

| Species/form | Configured parts | Shiny routing |
| --- | --- | --- |
| blastoise | cannons, mouth | Same attachment profile |
| charmander | hand, mouth | Same attachment profile |
| charmeleon | mouth | Same attachment profile |
| pikachu | electric_body | Same attachment profile |
| squirtle | mouth | Same attachment profile |

## Interpretation

Configured parts are partial coverage: Charmander's hand does not provide a foot or tail anchor, and Pikachu's electric-body anchor is not a mouth anchor. Unconfigured parts still fall back to model bounds. Mega and other alternate forms do not inherit base-form profiles; shiny variants do.

This audit checks whether attachment definitions exist. It does not certify bone availability, mouth placement, or every move animation on the actual models. It does not intersect moves with learnsets, so an absent mouth anchor does not imply that a species needs or can use Flamethrower. Bounds fallback can look correct in some poses without following the anatomical part.

## Reproduce

From the workspace root, in the assigned task slot:

```bash
ops/worktrees/slot-env slot-b -- godot --headless --path .worktrees/slot-b/frontend --script res://tools/audit_move_attachments_3d.gd
ops/worktrees/slot-env slot-b -- godot --headless --path .worktrees/slot-b/frontend --script res://tools/audit_move_attachments_3d.gd -- --check
```
