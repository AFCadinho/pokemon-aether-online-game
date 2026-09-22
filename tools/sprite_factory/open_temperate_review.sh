#!/usr/bin/env bash
set -euo pipefail
source_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
workspace="$source_root"
while [[ ! -x "$workspace/ops/worktrees/slot-env" && "$workspace" != / ]]; do
    workspace="$(dirname -- "$workspace")"
done
review="$workspace/.worktrees/slot-c/.tmp/fancifulcrow-review-01/TemperateForestPack-main"
catalog="$workspace/.worktrees/slot-c/.tmp/battle-stage-pbr-01/glb/report.json"
if [[ ! -f "$review/tools/sprite_factory/temperate_battle_review.gd" || ! -f "$catalog.runtime.json" ]]; then
    echo "Prepare the purchased Temperate Forest project first; see TEMPERATE_REVIEW.md." >&2
    exit 1
fi
exec "$workspace/ops/worktrees/slot-env" slot-c -- env \
    POKEAETHER_3D_STAGE_REPORT="$catalog" \
    godot --path "$review" --script res://tools/sprite_factory/temperate_battle_review.gd "$@"
