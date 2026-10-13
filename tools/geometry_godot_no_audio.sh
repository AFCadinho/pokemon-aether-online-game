#!/usr/bin/env bash
# Offline model/PNG study only: retain the real renderer, disable host audio.
set -euo pipefail
geometry_args=("$@")
if [[ "${POKEAETHER_GEOMETRY_CLOCK_V2:-0}" == 1 ]]; then
  for index in "${!geometry_args[@]}"; do
    if [[ "${geometry_args[$index]}" == res://tools/sprite_factory/new_pair_geometry_render.gd ]]; then
      geometry_args[$index]=res://tools/sprite_factory/new_pair_geometry_render_v2.gd
    fi
  done
fi
exec "${POKEAETHER_GEOMETRY_GODOT_BIN:?Set the real Godot executable}" --audio-driver Dummy "${geometry_args[@]}"
