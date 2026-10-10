#!/usr/bin/env python3
"""Prepare a local, qualified-cohort pilot; no admission to a published release.

Reads approved archives in place and derives task-owned native scenes. The
16-pair visual/native receipt bounds this pilot. Broader catalogs need their own
qualification rather than silently inheriting the sample's approval.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/sprite_factory"))
from native_resource_compression_probe import Zstd, decode, encode


def sha(data):
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archives", type=Path, required=True, help="Approved archive basename/path map")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if os.environ.get("POKEAETHER_SLOT") != ROOT.parent.name:
        parser.error("Run in the assigned slot through slot-env")
    output = args.output.resolve()
    output.relative_to(ROOT / ".tmp")
    output.mkdir(parents=True, exist_ok=False)
    archives = json.loads(args.archives.read_bytes())
    source_bytes = (ROOT / "release/approved_3d_bundles_v10_index.json").read_bytes()
    source_index = json.loads(source_bytes)
    sources = {row["appearances"][0]["runtime_identity"]: row for row in source_index["assets"]}
    v11 = {row["asset_id"]: row for row in json.loads((ROOT / "release/approved_3d_bundles_v11_index.json").read_bytes())["assets"]}
    bindings = json.loads((ROOT / "release/approved_3d_lossless_binding.json").read_bytes())["models"]
    qualified = json.loads((ROOT / "tools/sprite_factory/model_pair_cohort_results.json").read_bytes())
    assert qualified["pixel_frames_exact_first_source"] == qualified["pixel_frames"] == 320
    codec = Zstd()
    input_data = {"schema": 1, "production_namespace": True, "source_index_sha256": sha(source_bytes), "models": []}
    source_receipt = []
    source_directory = output / "sources"
    source_directory.mkdir()
    for pair in qualified["pairs"]:
        asset = sources[pair["species"]]
        path = Path(archives[Path(asset["object_key"]).name])
        data = path.read_bytes()
        assert len(data) == asset["size_bytes"] and sha(data) == asset["sha256"]
        with zipfile.ZipFile(path) as archive:
            for appearance in asset["appearances"]:
                identity = appearance["runtime_identity"]
                original = archive.read("models/" + appearance["variant"] + ".scn")
                assert sha(original) == appearance["runtime_sha256"]
                raw = original[4:] if original[:4] == b"RSRC" else decode(original, codec)
                assert sha(raw) == bindings[identity]["decoded_sha256"]
                native = original if original[:4] == b"RSRC" else encode(raw, 262144, 9, codec)
                assert sha(native) == bindings[identity]["candidate_sha256"]
                target = source_directory / (identity.replace("@", "-") + ".scn")
                target.write_bytes(native)
                input_data["models"].append({"identity": identity, "path": str(target), "sha256": sha(native)})
        assert sha(path.read_bytes()) == asset["sha256"]
        source_receipt.append({"asset_id": asset["asset_id"], "archive_sha256": asset["sha256"]})
    input_path = output / "input.json"
    input_path.write_bytes(encoded(input_data))
    subprocess.run([sys.executable, str(ROOT / "tools/run_model_texture_sharing_probe.py"),
                    "--mode", "pair", "--input", str(input_path), "--output", str(output / "generated"),
                    "--timeout", "1800"], check=True)
    generated = json.loads((output / "generated/report.json").read_bytes())
    proof = {model["identity"]: model for pair in qualified["pairs"] for model in pair["models"]}
    index = {"schema": 1, "kind": "pokeaether-optional-asset-index", "catalog_revision": "shared-model-pilot-v1",
             "runtime_contract": {"pokemon_3d": 2, "godot": "4.6"}, "assets": []}
    packs = output / "packs"
    packs.mkdir()
    pack_list = []
    render = {"schema": 1, "models": [], "packs": []}
    for pair in generated["pairs"]:
        original_asset = sources[pair["species"]]
        previous = v11[original_asset["asset_id"]]
        directory = output / "members" / pair["species"]
        directory.mkdir(parents=True)
        files = {}
        appearances = []
        for row in pair["models"]:
            identity = row["identity"]
            assert row["semantic_sha256"] == proof[identity]["headless_semantic_sha256"]
            candidate = Path(row["candidate_path"]).read_bytes()
            assert sha(candidate) == row["candidate_sha256"]
            raw = decode(candidate, codec)
            native = encode(raw, 262144, 9, codec)
            assert decode(native, codec) == raw
            name = "models/" + row["variant"] + ".scn"
            files[name] = native
            appearances.append({"variant": row["variant"], "runtime_identity": identity, "runtime_path": name,
                                "runtime_sha256": sha(native), "bytes": len(native), "source_sha256": row["source_sha256"],
                                "cache_source_bytes": bindings[identity]["cache_source_bytes"],
                                "semantic_sha256": row["semantic_sha256"]})
            render["models"].append({"identity": identity, "source_path": row["source_path"], "source_sha256": row["source_sha256"],
                                     "candidate_path": pair["namespace"] + "/" + name, "candidate_sha256": sha(native)})
        for path in sorted((Path(pair["directory"]) / "textures").glob("*.res")):
            raw = decode(path.read_bytes(), codec)
            native = encode(raw, 262144, 9, codec)
            assert decode(native, codec) == raw
            files["textures/" + path.name] = native
        manifest = {"schema": 1, "kind": "pokeaether-model-pair", "asset_id": previous["asset_id"],
                    "species_id": previous["species_id"], "form_id": previous["form_id"], "version": previous["version"] + 1,
                    "dependencies": previous["dependencies"], "appearances": appearances, "resource_root": pair["namespace"],
                    "files": [{"path": name, "bytes": len(data), "sha256": sha(data),
                               "decoded_bytes": struct.unpack_from("<I", data, 12)[0]}
                              for name, data in sorted(files.items())]}
        files["bundle.json"] = encoded(manifest)
        for name, data in files.items():
            target = directory / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        pack_path = packs / (pair["species"] + ".pck")
        pack_list.append({"output": str(pack_path), "files": [{"virtual_path": pair["namespace"] + "/" + name,
                                                               "source_path": str(directory / name)} for name in sorted(files)]})
        asset = {key: value for key, value in previous.items() if key not in ["sha256", "size_bytes", "object_key", "appearances", "version"]}
        asset.update({"format": "model-pair-pck-v1", "version": manifest["version"], "appearances": appearances, "pair_manifest": manifest})
        index["assets"].append(asset)
    pack_list_path = output / "pack-list.json"
    pack_list_path.write_bytes(encoded(pack_list))
    subprocess.run(["godot", "--headless", "--path", str(ROOT), "--script", "res://tools/sprite_factory/pack_model_pair_probe.gd",
                    "--", str(pack_list_path)], check=True)
    for asset, row in zip(index["assets"], pack_list, strict=True):
        path = Path(row["output"])
        data = path.read_bytes()
        asset["sha256"], asset["size_bytes"] = sha(data), len(data)
        name = f'v{asset["version"]}-{asset["sha256"]}.pck'
        path.rename(packs / name)
        asset["object_key"] = f'optional-assets/pokemon_3d/{asset["species_id"]}/{asset["form_id"]}/{name}'
        render["packs"].append({"path": str(packs / name), "sha256": asset["sha256"]})
    included = {asset["asset_id"] for asset in index["assets"]}
    for asset in index["assets"]:
        for dependency in asset["dependencies"]:
            if dependency not in included:
                index["assets"].append(v11[dependency])
                included.add(dependency)
    (output / "pilot-index.json").write_bytes(encoded(index))
    (output / "render-input.json").write_bytes(encoded(render))
    (output / "sources.json").write_bytes(encoded(source_receipt))
    print("Prepared local pilot:", len(index["assets"]), "pairs;", sum(a["size_bytes"] for a in index["assets"]), "pack bytes")


if __name__ == "__main__":
    main()
