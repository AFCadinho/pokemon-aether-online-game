#!/usr/bin/env python3
"""Admit the four visually and battle reviewed rig recoveries locally."""

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
WORK = ROOT / ".tmp/remaining-catalog-intake"
FOUR = WORK / "four-approved"
NAMES = ("gloom", "vileplume", "dodrio", "torchic")


def read(path):
    return json.loads(path.read_text())


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def encoded(value):
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()


def main():
    rows = read(FOUR / "catalog.json")
    installed = read(FOUR / "installed/installed-catalog.json")
    index = read(FOUR / "bundles/asset-index.json")
    fixture = read(FOUR / "runtime-fixture.json")
    battle = read(WORK / "new-pairs-battle/corrected-v2/battle-review.json")
    stress = read(FOUR / "stress.json")
    log = (FOUR / "stress.log").read_text()
    install_log = (FOUR / "install.log").read_text()
    assert battle["complete"] and {e["species"] for e in battle["entries"] if "clips" in e} == set(NAMES)
    assert len(rows) == len(installed) == 8 and len(index["assets"]) == 4
    assert set(fixture["profiles"]) == set(NAMES)
    assert set(fixture["models"]) == {n + suffix for n in NAMES for suffix in ("", "@shiny")}
    assert "REMAINING_144_BUNDLES_OK bundles=4 scenes=8 resumed=0 no_op=true restart=true" in install_log
    assert "SCRIPT ERROR:" not in install_log and "ERROR:" not in install_log
    assert stress["complete"] and set(stress["species"]) == set(NAMES)
    assert stress["catalog_sha256"] == sha(FOUR / "installed/installed-catalog.json")
    assert [r["arena"] for r in stress["rounds"]] == ["classic", "stadium", "classic"]
    assert "BATCH01_STRESS_OK" in log and "SCRIPT ERROR:" not in log and "ERROR:" not in log
    for cycle in stress["rounds"]:
        assert cycle["pairs"] == cycle["faint_replacements"] == 4
        assert 0 < cycle["frame_p95_ms"] <= 20
        assert not any(s["ms"] > 100 and not s["covered"] for s in cycle["stalls_over_50ms"])
    installed_by_key = {(e["species"], e["variant"]): e for e in installed}
    for row in rows:
        key = (row["species"], row["variant"])
        assert sha(Path(row["path"])) == row["glb_sha256"]
        assert sha(Path(row["runtime_path"])) == row["runtime_sha256"]
        assert sha(Path(installed_by_key[key]["runtime_path"])) == row["runtime_sha256"]
        identity = row["species"] + ("@shiny" if row["variant"] == "shiny" else "")
        assert fixture["models"][identity]["sha256"] == row["runtime_sha256"]
    game = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
    launcher = ROOT / "launcher/data/reviewed_model_catalog.json"
    assert game.read_bytes() == launcher.read_bytes()
    registry = read(game)
    assert len(registry["profiles"]) == 636 and len(registry["models"]) == 1272
    assert not set(NAMES).intersection(registry["profiles"])
    registry["profiles"].update(fixture["profiles"])
    registry["models"].update(fixture["models"])
    evidence = [FOUR / "catalog.json", FOUR / "bundles/asset-index.json",
                FOUR / "installed/installed-catalog.json", FOUR / "runtime-fixture.json",
                FOUR / "install.log", FOUR / "stress.json", FOUR / "stress.log",
                WORK / "eye-corrected/eye-review/review.json",
                WORK / "eye-corrected/eye-level/review.json",
                WORK / "new-pairs-battle/corrected-v2/battle-review.json"]
    evidence += [Path(row["path"]) for row in rows]
    evidence += [Path(row["runtime_path"]) for row in rows]
    receipt = {
        "schema": 1, "date": "2026-09-29", "species": list(NAMES),
        "scope": "four local normal/shiny individual bundles after user appearance, eye and battle approval",
        "runtime_approved": True, "release_approved": False, "published": False,
        "bundle_size_bytes": sum(asset["size_bytes"] for asset in index["assets"]),
        "runtime_rounds": [{key: cycle[key] for key in ("arena", "pairs", "frame_p95_ms")}
                           for cycle in stress["rounds"]],
        "evidence_sha256": {str(path.relative_to(ROOT)): sha(path) for path in evidence},
    }
    receipt_path = HERE / "catalog_remaining_four_admission.json"
    receipt_path.write_bytes(encoded(receipt))
    registry["catalog_remaining_four_admission_sha256"] = sha(receipt_path)
    payload = encoded(registry)
    game.write_bytes(payload)
    launcher.write_bytes(payload)
    print("REMAINING_FOUR_ADMITTED pairs=4 scenes=8 published=false")


if __name__ == "__main__":
    main()
