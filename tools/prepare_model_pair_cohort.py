#!/usr/bin/env python3
"""Derive owned diagnostic scenes from exact approved archives or retained sources."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/sprite_factory"))
from native_resource_compression_probe import Zstd, decode, encode


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archives", type=Path, required=True)
    parser.add_argument("--retained-input", type=Path)
    parser.add_argument("--species", nargs="+", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if os.environ.get("POKEAETHER_SLOT") != ROOT.parent.name:
        parser.error("Run through assigned slot-env")
    output = args.output.resolve()
    output.relative_to(ROOT / ".tmp")
    output.mkdir(parents=True, exist_ok=False)
    binding = json.loads((ROOT / "release/approved_3d_lossless_binding.json").read_bytes())
    index_bytes = (ROOT / "release/approved_3d_bundles_v10_index.json").read_bytes()
    assert sha(index_bytes) == binding["source_index_sha256"]
    entries = {entry["appearances"][0]["runtime_identity"]: entry
               for entry in json.loads(index_bytes)["assets"]}
    archives = {}
    for path in sorted(args.archives.rglob("*.zip")):
        archives.setdefault(path.name, path)
    retained = {}
    if args.retained_input:
        args.retained_input.resolve().relative_to(ROOT / ".tmp")
        retained = {row["identity"]: row for row in json.loads(args.retained_input.read_bytes())["models"]}
    assert len(args.species) == len(set(args.species)) and args.species
    codec = Zstd()
    result = {"schema": 1, "models": []}
    receipt = {"schema": 1, "prototype_only": True, "source_index_sha256": sha(index_bytes), "sources": []}
    for species in args.species:
        entry = entries[species]
        archive = archives.get(Path(entry["object_key"]).name)
        if archive:
            archive_bytes = archive.read_bytes()
            assert len(archive_bytes) == entry["size_bytes"] and sha(archive_bytes) == entry["sha256"]
            with zipfile.ZipFile(archive) as zipped:
                manifest = json.loads(zipped.read("bundle.json"))
                assert manifest["asset_id"] == entry["asset_id"] and manifest["dependencies"] == entry["dependencies"]
                assert set(zipped.namelist()) == {"bundle.json", "models/normal.scn", "models/shiny.scn"}
                assert len(manifest["appearances"]) == 2
                sources = {}
                for row in manifest["appearances"]:
                    name = "models/" + row["variant"] + ".scn"
                    assert row["runtime_path"] == name
                    data = zipped.read(name)
                    assert sha(data) == row["runtime_sha256"] and len(data) == row["bytes"]
                    sources[row["runtime_identity"]] = data
            origin = {"kind": "approved_archive", "archive_sha256": entry["sha256"], "object_key": entry["object_key"]}
        else:
            sources = {}
            for identity in (species, species + "@shiny"):
                row = retained[identity]
                source_path = Path(row["path"]).resolve()
                source_path.relative_to(ROOT / ".tmp")
                data = source_path.read_bytes()
                assert sha(data) == row["sha256"]
                sources[identity] = data
            origin = {"kind": "owned_retained_source"}
        assert set(sources) == {species, species + "@shiny"}
        for identity, data in sources.items():
            pin = binding["models"][identity]
            assert sha(data) in {pin["source_sha256"], pin["candidate_sha256"]}
            raw = data[4:] if data[:4] == b"RSRC" else decode(data, codec)
            assert sha(raw) == pin["decoded_sha256"]
            # v11 deliberately retained uncompressed RSRC resources unchanged.
            candidate = data if data[:4] == b"RSRC" else encode(raw, 262144, 9, codec)
            restored = candidate[4:] if candidate[:4] == b"RSRC" else decode(candidate, codec)
            assert sha(candidate) == pin["candidate_sha256"] and restored == raw
            path = output / (identity.replace("@", "-") + ".scn")
            path.write_bytes(candidate)
            result["models"].append({"identity": identity, "path": str(path), "sha256": sha(candidate)})
            receipt["sources"].append({"identity": identity, **origin, "input_sha256": sha(data),
                                       "candidate_sha256": sha(candidate), "decoded_sha256": sha(raw)})
        print("COHORT_SOURCE_OK", species, origin["kind"], flush=True)
    (output / "input.json").write_text(json.dumps(result, indent=2) + "\n")
    (output / "sources.json").write_text(json.dumps(receipt, indent=2) + "\n")


if __name__ == "__main__":
    main()
