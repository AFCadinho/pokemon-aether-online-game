#!/usr/bin/env bash

set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"
missing=()
orphaned=()

while IFS= read -r -d '' source_path; do
	sidecar_path="${source_path}.uid"
	if ! git -C "$repo_root" ls-files --error-unmatch -- "$sidecar_path" >/dev/null 2>&1; then
		missing+=("$sidecar_path")
	fi
done < <(git -C "$repo_root" ls-files -z -- '*.gd' '*.gdshader' '*.shader')

while IFS= read -r -d '' sidecar_path; do
	source_path="${sidecar_path%.uid}"
	if ! git -C "$repo_root" ls-files --error-unmatch -- "$source_path" >/dev/null 2>&1; then
		orphaned+=("$sidecar_path")
	fi
done < <(git -C "$repo_root" ls-files -z -- '*.gd.uid' '*.gdshader.uid' '*.shader.uid')

if (( ${#missing[@]} > 0 )); then
	echo "Missing tracked Godot UID sidecars:" >&2
	printf '  %s\n' "${missing[@]}" >&2
fi
if (( ${#orphaned[@]} > 0 )); then
	echo "Tracked Godot UID sidecars without a source file:" >&2
	printf '  %s\n' "${orphaned[@]}" >&2
fi
if (( ${#missing[@]} > 0 || ${#orphaned[@]} > 0 )); then
	exit 1
fi

echo "Godot UID sidecars are complete."
