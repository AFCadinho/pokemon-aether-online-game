#!/usr/bin/env python3
"""Package relocatable experiment bundles; never admit/publish an asset index."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import subprocess

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/sprite_factory"))
from native_resource_compression_probe import Zstd, decode, encode


def encoded(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if os.environ.get("POKEAETHER_SLOT") != ROOT.parent.name:
        parser.error("Run through the assigned slot-env")
    output = args.output.resolve()
    output.relative_to(ROOT / ".tmp")
    output.mkdir(parents=True, exist_ok=False)
    generated = json.loads(args.input.read_bytes())
    bindings = json.loads((ROOT / "release/approved_3d_lossless_binding.json").read_bytes())["models"]
    codec = Zstd()
    result = {"schema": 1, "prototype_only": True, "pairs": [], "codec": {"block_size": 262144, "level": 9, "libzstd": codec.version}}
    render = {"schema": 1, "models": [], "packs": []}
    packs = []
    for pair in generated["pairs"]:
        species = pair["species"]
        record = {"species": species}
        for kind in ("baseline", "shared"):
            directory = output / species / kind
            files = {}
            models = []
            for row in pair["models"]:
                identity = row["identity"]
                source = Path(row["source_path"]).read_bytes()
                assert sha(source) == row["source_sha256"]
                raw_source = source[4:] if source[:4] == b"RSRC" else decode(source, codec)
                assert sha(raw_source) == bindings[identity]["decoded_sha256"]
                if kind == "baseline":
                    data = encode(raw_source, 262144, 9, codec)
                    assert sha(data) == bindings[identity]["candidate_sha256"]
                else:
                    saved = Path(row["candidate_path"]).read_bytes()
                    assert sha(saved) == row["candidate_sha256"]
                    raw = decode(saved, codec)
                    data = encode(raw, 262144, 9, codec)
                    assert decode(data, codec) == raw
                name = "models/" + row["variant"] + ".scn"
                files[name] = data
                models.append({"identity": identity, "path": name, "semantic_sha256": row["semantic_sha256"]})
            if kind == "shared":
                for path in sorted((Path(pair["directory"]) / "textures").glob("*.res")):
                    raw = decode(path.read_bytes(), codec)
                    data = encode(raw, 262144, 9, codec)
                    assert decode(data, codec) == raw
                    files["textures/" + path.name] = data
            manifest = {"schema": 1, "kind": "pokeaether-model-pair-experiment", "prototype_only": True,
                        "species": species, "variant": kind, "models": models, "resource_root": pair["namespace"] + "/" + kind,
                        "files": [{"path": name, "bytes": len(data), "sha256": sha(data)} for name, data in sorted(files.items())]}
            files["bundle.json"] = encoded(manifest)
            for name, data in sorted(files.items()):
                path = directory / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
            pin = {"installed_payload_bytes": sum(map(len, files.values())), "directory": str(directory), "manifest": manifest}
            record[kind] = pin
            pin["resource_root"] = manifest["resource_root"]
            pack_path = output / (species + "-" + kind + ".pck")
            packs.append({"output": str(pack_path), "files": [{"virtual_path": manifest["resource_root"] + "/" + name, "source_path": str(directory / name)} for name in files]})
        for model in record["shared"]["manifest"]["models"]:
            render["models"].append({"identity": model["identity"], "source_path": record["baseline"]["resource_root"] + "/" + model["path"], "source_sha256": next(f["sha256"] for f in record["baseline"]["manifest"]["files"] if f["path"] == model["path"]), "candidate_path": record["shared"]["resource_root"] + "/" + model["path"], "candidate_sha256": next(f["sha256"] for f in record["shared"]["manifest"]["files"] if f["path"] == model["path"])})
        result["pairs"].append(record)
    pack_list = output / "pack-list.json"
    pack_list.write_bytes(encoded(packs))
    subprocess.run(["godot", "--headless", "--path", str(ROOT), "--script", "res://tools/sprite_factory/pack_model_pair_probe.gd", "--", str(pack_list)], check=True)
    for pair in result["pairs"]:
        for kind in ("baseline", "shared"):
            pin = pair[kind]
            path = output / (pair["species"] + "-" + kind + ".pck")
            pin["pack"] = path.name
            pin["pack_sha256"] = sha(path.read_bytes())
            pin["pack_bytes"] = path.stat().st_size
            render["packs"].append({"path": str(path), "sha256": pin["pack_sha256"]})
    (output / "fixture.json").write_bytes(encoded(result))
    (output / "render-input.json").write_bytes(encoded(render))
    print("Prototype pairs:", len(result["pairs"]))
    for row in result["pairs"]:
        a, b = row["baseline"]["pack_bytes"], row["shared"]["pack_bytes"]
        print(row["species"], a, b, "saving", round(100 * (a-b) / a, 2), "%")


if __name__ == "__main__":
    main()
