"""Bind append-only verified attack clips to the screened local catalog."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from physical_attack_routing_audit import ALLOWED_FAMILIES


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def activate(registry: dict, local: list, runtime: list, reviews: dict) -> tuple[dict, list, dict]:
    runtime_by_species = {entry["species"]: entry for entry in runtime}
    local_by_species = {entry["species"]: entry for entry in local}
    if len(runtime_by_species) != len(runtime):
        raise ValueError("Duplicate runtime species")
    activated = []
    for species, entry in sorted(runtime_by_species.items()):
        if species not in registry["models"] or species not in local_by_species:
            raise ValueError("Runtime species is outside screened catalog: " + species)
        path = Path(entry["runtime_path"])
        if digest(path) != entry["runtime_sha256"]:
            raise ValueError("Runtime scene hash changed: " + species)
        timing = entry["action_timing"]
        if "physical_attack_2" not in timing:
            raise ValueError("Runtime scene lacks alternate attack: " + species)
        profile = registry["profiles"][registry["models"][species]["profile"]]
        for action, old_timing in profile["action_timing"].items():
            if timing.get(action) != old_timing:
                raise ValueError("Established timing changed: " + species + ":" + action)
        evidence = reviews[species]
        if evidence.get("status") != "confirmed":
            raise ValueError("Unconfirmed semantic review: " + species)
        actions = {}
        runtime_animations = entry["animations"]
        for action in ("physical_attack", "physical_attack_2"):
            clip = evidence["clips"][action]
            family = clip["family"]
            if family not in ALLOWED_FAMILIES:
                continue
            if runtime_animations[action]["source_action"] != clip["source_action"]:
                if action == "physical_attack_2":
                    raise ValueError("Alternate source action differs: " + species)
                continue
            actions.setdefault(family, action)
        profile["action_timing"]["physical_attack_2"] = timing["physical_attack_2"]
        profile["attack_family_actions"] = actions
        model = registry["models"][species]
        model["glb_sha256"] = entry["glb_sha256"]
        model["sha256"] = entry["runtime_sha256"]
        local_by_species[species]["runtime_path"] = entry["runtime_path"]
        local_by_species[species]["runtime_sha256"] = entry["runtime_sha256"]
        activated.append({"species": species, "attack_family_actions": actions,
                          "runtime_sha256": entry["runtime_sha256"]})
    blocked = [{"species": species, "reason": "alternate_runtime_not_certified"}
               for species in sorted(set(registry["models"]) - set(runtime_by_species))]
    report = {"schema": 1, "runtime_approved": False, "runtime_activated": True,
              "policy": "append-only GLB verification plus confirmed human semantics",
              "counts": {"activated_models": len(activated),
                         "profiles_selecting_alternate": sum(
                             "physical_attack_2" in item["attack_family_actions"].values()
                             for item in activated),
                         "blocked_models": len(blocked)},
              "activated": activated,
              "blocked": blocked}
    return registry, [local_by_species[key] for key in sorted(local_by_species)], report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", type=Path, required=True)
    parser.add_argument("--launcher-registry", type=Path, required=True)
    parser.add_argument("--local-catalog", type=Path, required=True)
    parser.add_argument("--runtime-report", type=Path, required=True)
    parser.add_argument("--human-review", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    registry = json.loads(args.registry.read_text())
    launcher = json.loads(args.launcher_registry.read_text())
    if (registry.get("schema") != launcher.get("schema") or
            set(registry.get("models", {})) != set(launcher.get("models", {})) or
            set(registry.get("profiles", {})) != set(launcher.get("profiles", {}))):
        raise ValueError("Frontend and launcher screened registry scopes differ")
    local = json.loads(args.local_catalog.read_text())
    runtime = json.loads(args.runtime_report.read_text())
    reviews = json.loads(args.human_review.read_text())["entries"]
    registry, local, report = activate(registry, local, runtime, reviews)
    rendered = json.dumps(registry, indent=2, sort_keys=True) + "\n"
    args.registry.write_text(rendered)
    args.launcher_registry.write_text(rendered)
    args.local_catalog.write_text(json.dumps(local, indent=2) + "\n")
    args.report.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
