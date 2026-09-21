"""Read-only preflight for the existing offline 3D source-report contract.

This validates metadata/files, not mesh quality or Godot import compatibility.
No species allowlist: runtime support is a separate, explicitly reviewed gate.
"""
import argparse
import json
import math
import re
from pathlib import Path

REQUIRED_ACTIONS = ("idle", "physical_attack", "special_attack", "damage", "sleep", "faint_start")


def validate_report(path):
    path = Path(path)
    errors = []
    try:
        data = json.loads(path.read_text())
    except (OSError, ValueError) as exc:
        return [f"report: {exc}"]
    if not isinstance(data, list) or not data:
        return ["report: expected a non-empty array"]
    seen = set()
    for index, entry in enumerate(data):
        label = f"entry {index}"
        if not isinstance(entry, dict):
            errors.append(f"{label}: expected an object")
            continue
        species = entry.get("species")
        if not isinstance(species, str) or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", species):
            errors.append(f"{label}: species must be a canonical lowercase identifier")
        elif species in seen:
            errors.append(f"{label}: duplicate species {species}")
        else:
            seen.add(species)
            label = species
        source = entry.get("path")
        if not isinstance(source, str) or not source:
            errors.append(f"{label}: missing GLB path")
        else:
            model = Path(source)
            if not model.is_absolute():
                errors.append(f"{label}: GLB path must be absolute (current importer contract)")
            elif model.suffix.lower() != ".glb" or not model.is_file():
                errors.append(f"{label}: GLB file missing or wrong extension")
            else:
                try:
                    with model.open("rb") as handle:
                        header = handle.read(12)
                    if len(header) != 12 or header[:4] != b"glTF" or int.from_bytes(header[4:8], "little") != 2 or int.from_bytes(header[8:12], "little") != model.stat().st_size:
                        errors.append(f"{label}: invalid GLB v2 header/length")
                except OSError as exc:
                    errors.append(f"{label}: cannot read GLB: {exc}")
        # In exporter reports this is the original Blender source hash, NOT
        # the GLB hash. Do not compare unrelated stages' hashes.
        expected = entry.get("source_sha256")
        if expected is not None and (not isinstance(expected, str) or not re.fullmatch(r"[0-9a-f]{64}", expected)):
            errors.append(f"{label}: source_sha256 must be a lowercase SHA-256 digest")
        timing = entry.get("action_timing")
        if not isinstance(timing, dict):
            errors.append(f"{label}: missing action_timing object")
            continue
        for action in REQUIRED_ACTIONS:
            if action not in timing:
                errors.append(f"{label}: missing required action {action}")
        for action, spec in timing.items():
            if not isinstance(spec, dict):
                errors.append(f"{label}/{action}: expected timing object")
                continue
            for key in ("frames", "speed"):
                value = spec.get(key)
                if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value <= 0:
                    errors.append(f"{label}/{action}: {key} must be finite and positive")
            if not isinstance(spec.get("loop"), bool):
                errors.append(f"{label}/{action}: loop must be boolean")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    args = parser.parse_args()
    errors = validate_report(args.report)
    print(json.dumps({"valid": not errors, "errors": errors}, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
