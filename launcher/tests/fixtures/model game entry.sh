#!/bin/sh
# Offline test entry point, launched by the real launcher process function.
# All paths and userdata belong to the caller's isolated slot test run.
if [ -n "$POKEAETHER_E2E_GAME_BINARY" ]; then
    exec "$POKEAETHER_E2E_GAME_BINARY" --log-file "$POKEAETHER_E2E_CHILD_LOG" "$@"
fi
exec "$POKEAETHER_E2E_GODOT" --path "$POKEAETHER_E2E_GAME_ROOT" --log-file "$POKEAETHER_E2E_CHILD_LOG" --script res://tests/launcher_model_process_child.gd "$@"
