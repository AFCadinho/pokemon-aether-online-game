"""Dry-run semantic move-to-model attack routing without activating runtime data."""
from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path


ALLOWED_FAMILIES = {"bite", "claw_slash", "punch", "kick", "body_charge",
                    "tail", "wing", "generic"}
ALLOWED_ACTIONS = {"physical_attack", "physical_attack_2"}


def load_move_intents(path: Path, move_index: dict) -> dict[str, str]:
    data = json.loads(path.read_text())
    if data.get("schema") != 1:
        raise ValueError("Unsupported move-intent schema")
    result = {}
    for family, names in data.get("families", {}).items():
        if family not in ALLOWED_FAMILIES or not isinstance(names, list):
            raise ValueError(f"Unsupported move family: {family}")
        for name in names:
            if name in result:
                raise ValueError(f"Move has duplicate intents: {name}")
            if name not in move_index:
                raise ValueError(f"Move intent is absent from move index: {name}")
            if str(move_index[name].get("category", "")).lower() != "physical":
                raise ValueError(f"Move intent is not physical: {name}")
            result[name] = family
    return result


def family_actions(clips: dict) -> dict[str, str]:
    """Prefer the established primary clip when both clips share a family."""
    result = {}
    for action in ("physical_attack", "physical_attack_2"):
        family = str(clips.get(action, {}).get("family", ""))
        if family in ALLOWED_FAMILIES and family not in result:
            result[family] = action
    return result


def build_audit(human_review_path: Path, intents_path: Path, moves_path: Path) -> dict:
    reviewed = json.loads(human_review_path.read_text())
    moves = json.loads(moves_path.read_text())
    if reviewed.get("runtime_approved") is not False:
        raise ValueError("Human review evidence must not be runtime-approved")
    intents = load_move_intents(intents_path, moves)
    physical_moves = sorted(name for name, data in moves.items()
                            if str(data.get("category", "")).lower() == "physical")
    species_actions = {}
    for species, evidence in sorted(reviewed.get("entries", {}).items()):
        if evidence.get("status") != "confirmed":
            raise ValueError(f"Unconfirmed human evidence: {species}")
        actions = family_actions(evidence.get("clips", {}))
        if any(action not in ALLOWED_ACTIONS for action in actions.values()):
            raise ValueError(f"Invalid action candidate: {species}")
        species_actions[species] = actions
    intent_counts = Counter(intents.values())
    coverage = Counter()
    primary_matches = 0
    alternate_matches = 0
    for actions in species_actions.values():
        for family, action in actions.items():
            coverage[family] += 1
            pair_count = intent_counts[family]
            if action == "physical_attack_2":
                alternate_matches += pair_count
            else:
                primary_matches += pair_count
    classified_pairs = len(intents) * len(species_actions)
    exact_pairs = primary_matches + alternate_matches
    unclassified_moves = sorted(set(physical_moves) - set(intents))
    return {
        "schema": 1,
        "scope": "physical_attack_routing_dry_run_not_runtime_mapping",
        "runtime_approved": False,
        "policy": {
            "exact_family_match": "use reviewed family action",
            "duplicate_family": "prefer physical_attack",
            "missing_family_or_intent": "physical_attack",
        },
        "counts": {
            "species": len(species_actions),
            "physical_moves": len(physical_moves),
            "classified_moves": len(intents),
            "unclassified_moves": len(unclassified_moves),
            "all_species_move_pairs": len(physical_moves) * len(species_actions),
            "classified_species_move_pairs": classified_pairs,
            "exact_family_pairs": exact_pairs,
            "primary_exact_pairs": primary_matches,
            "alternate_exact_pairs": alternate_matches,
            "classified_fallback_pairs": classified_pairs - exact_pairs,
            "unclassified_fallback_pairs": len(unclassified_moves) * len(species_actions),
        },
        "intent_move_counts": dict(sorted(intent_counts.items())),
        "species_family_coverage": dict(sorted(coverage.items())),
        "candidate_family_actions": species_actions,
        "unclassified_physical_moves": unclassified_moves,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    root = Path(__file__).resolve().parents[2]
    parser.add_argument("--human-review", type=Path, default=Path(__file__).with_name(
        "physical_attack_human_review.json"))
    parser.add_argument("--intents", type=Path, default=root / "data" /
                        "physical_move_animation_intents.json")
    parser.add_argument("--moves", type=Path, default=root / "data" / "move_summary_index.json")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = build_audit(args.human_review, args.intents, args.moves)
    rendered = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.write_text(rendered)
    else:
        print(rendered, end="")


if __name__ == "__main__":
    main()
