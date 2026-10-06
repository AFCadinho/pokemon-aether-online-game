#!/usr/bin/env python3
"""Build fresh, unpublished native-compression bundle fixtures from pinned inputs."""
import argparse
import copy
import json
from pathlib import Path
import zipfile

from native_resource_compression_probe import Zstd, decode, encode, sha


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n")


def write_zip(path, manifest, payloads):
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_STORED) as target:
        for name, data in {"bundle.json": (json.dumps(manifest, indent=2) + "\n").encode(), **payloads}.items():
            info = zipfile.ZipInfo(name, (2026, 10, 6, 0, 0, 0))
            info.external_attr = 0o100644 << 16
            target.writestr(info, data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    output.relative_to(root / ".tmp")
    output.mkdir(parents=True, exist_ok=False)
    source = json.loads(args.input.read_text())
    assert source["complete"]
    pinned_bytes = (root / "release/approved_3d_bundles_v10_index.json").read_bytes()
    assert sha(pinned_bytes) == source["index_sha256"]
    index = json.loads(pinned_bytes)
    registry = json.loads((root / "scripts/battle/battle_ui/reviewed_model_catalog.json").read_text())
    by_identity = {e["identity"]: e for e in source["entries"]}
    selected = [asset for asset in index["assets"] if all(a["runtime_identity"] in by_identity for a in asset["appearances"])]
    assert len(selected) * 2 == len(by_identity)
    codec = Zstd()
    fixture = {"prototype_only": True, "production_approved": False,
               "source_report_sha256": sha(args.input.read_bytes()), "libzstd": codec.version,
               "stages": [], "routes": {}, "profiles": {}}
    for label, block, offset in [("original", None, 0), ("native-256k", 262144, 1), ("native-1m", 1048576, 2)]:
        directory = output / label
        directory.mkdir()
        assets, models = [], {}
        for original_asset in selected:
            asset = copy.deepcopy(original_asset)
            entries = [by_identity[a["runtime_identity"]] for a in asset["appearances"]]
            archive = Path(entries[0]["source_archive"])
            original_bytes = archive.read_bytes()
            assert len(original_bytes) == asset["size_bytes"] and sha(original_bytes) == asset["sha256"]
            payloads = {}
            with zipfile.ZipFile(archive) as source_zip:
                manifest = json.loads(source_zip.read("bundle.json"))
                for appearance, entry in zip(asset["appearances"], entries):
                    identity = appearance["runtime_identity"]
                    data = source_zip.read("models/" + appearance["variant"] + ".scn")
                    assert sha(data) == appearance["runtime_sha256"] == entry["source_sha256"]
                    raw = decode(data, codec)
                    assert sha(raw) == entry["raw_sha256"]
                    if block is not None:
                        data = encode(raw, block, 9, codec)
                        assert decode(data, codec) == raw
                    model = copy.deepcopy(registry["models"][identity])
                    assert entry["source_sha256"] in [model["sha256"], *model.get("previous_sha256", [])]
                    model["sha256"] = sha(data)
                    model["previous_sha256"] = []
                    models[identity] = model
                    fixture["profiles"][model["profile"]] = registry["profiles"][model["profile"]]
                    appearance["runtime_sha256"] = sha(data)
                    payloads["models/" + appearance["variant"] + ".scn"] = data
                    for row in manifest["appearances"]:
                        if row["variant"] == appearance["variant"]:
                            row["runtime_sha256"] = sha(data)
                            row["bytes"] = len(data)
            if block is not None:
                asset["version"] += offset
                manifest["version"] = asset["version"]
                target = directory / (asset["species_id"] + "-" + asset["form_id"] + ".zip")
                write_zip(target, manifest, payloads)
                asset["sha256"] = sha(target.read_bytes())
                asset["size_bytes"] = target.stat().st_size
                asset["object_key"] = f"optional-assets/pokemon_3d/{asset['species_id']}/{asset['form_id']}/v{asset['version']}-{asset['sha256']}.zip"
            else:
                target = archive.resolve()
            fixture["routes"]["/" + asset["object_key"]] = str(target)
            assets.append(asset)
            assert sha(archive.read_bytes()) == original_asset["sha256"]
        stage_index = {"schema": 1, "kind": index["kind"], "catalog_revision": "lossless-fixture-" + label,
                       "runtime_contract": index["runtime_contract"], "assets": assets}
        index_path = directory / "asset-index.json"
        write_json(index_path, stage_index)
        write_json(directory / "runtime-fixture.json", {"models": models,
            "profiles": fixture["profiles"], "prototype_only": True, "production_approved": False})
        key = "test-index/" + label + ".json"
        fixture["routes"]["/" + key] = str(index_path)
        fixture["stages"].append({"label": label, "index_path": str(index_path), "models": models,
            "descriptor": {"schema": 1, "kind": "pokeaether-release-asset-index", "revision": stage_index["catalog_revision"],
                "object_key": key, "sha256": sha(index_path.read_bytes()), "sizeBytes": index_path.stat().st_size,
                "requiredAssetIds": [a["asset_id"] for a in assets]},
            "archive_bytes": sum(a["size_bytes"] for a in assets)})
    # An outer-hash-valid ZIP with an invalid manifest must fail inside the store.
    native_index = json.loads(Path(fixture["stages"][-1]["index_path"]).read_text())
    bad_asset = copy.deepcopy(native_index["assets"][0])
    bad_asset["version"] += 1
    native_path = Path(fixture["routes"]["/" + bad_asset["object_key"]])
    with zipfile.ZipFile(native_path) as archive:
        manifest = json.loads(archive.read("bundle.json"))
        payloads = {p: archive.read(p) for p in archive.namelist() if p != "bundle.json"}
    manifest["version"] = bad_asset["version"]
    manifest["species_id"] = "invalid-fixture-species"
    bad_path = output / "bad-manifest.zip"
    write_zip(bad_path, manifest, payloads)
    bad_asset["sha256"] = sha(bad_path.read_bytes())
    bad_asset["size_bytes"] = bad_path.stat().st_size
    bad_asset["object_key"] = f"optional-assets/pokemon_3d/{bad_asset['species_id']}/{bad_asset['form_id']}/v{bad_asset['version']}-{bad_asset['sha256']}.zip"
    native_index["assets"][0] = bad_asset
    fixture["bad_manifest_index"] = native_index
    fixture["routes"]["/" + bad_asset["object_key"]] = str(bad_path)
    first = json.loads(Path(fixture["stages"][-1]["index_path"]).read_text())["assets"][0]
    corrupt = bytearray(Path(fixture["routes"]["/" + first["object_key"]]).read_bytes())
    corrupt[0] ^= 255
    corrupt_path = output / "corrupt.zip"
    corrupt_path.write_bytes(corrupt)
    fixture["routes"]["/fault/corrupt.zip"] = str(corrupt_path)
    fixture["failure_asset_id"] = first["asset_id"]
    write_json(output / "fixture.json", fixture)
    print("NATIVE_BUNDLE_FIXTURE_READY", len(selected), "pairs", flush=True)


if __name__ == "__main__":
    main()
