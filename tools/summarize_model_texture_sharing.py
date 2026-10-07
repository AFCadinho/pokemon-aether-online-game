#!/usr/bin/env python3
"""Compare offline duplicate sharing with the identical v11 lossless codec."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/sprite_factory"))
from native_resource_compression_probe import Zstd, decode, encode


def payload(path, codec):
    data = Path(path).read_bytes()
    return data[4:] if data[:4] == b"RSRC" else decode(data, codec)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--audit", type=Path, required=True)
    parser.add_argument("--candidates", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.relative_to(ROOT / ".tmp")
    output.mkdir(parents=True, exist_ok=False)
    audit = json.loads(args.audit.read_bytes())
    proof = json.loads(args.candidates.read_bytes())
    codec = Zstd()
    records = []
    binding = json.loads((ROOT / "release/approved_3d_lossless_binding.json").read_bytes())["models"]
    for row in audit["models"]:
        raw = payload(row["source_path"], codec)
        assert hashlib.sha256(raw).hexdigest() == binding[row["identity"]]["decoded_sha256"]
    for row in proof["models"]:
        record = {"identity": row["identity"]}
        for kind in ("source", "control", "candidate"):
            raw = payload(row[kind + "_path"], codec)
            encoded = encode(raw, 262144, 9, codec)
            assert decode(encoded, codec) == raw
            record[kind + "_raw_bytes"] = len(raw)
            record[kind + "_v11_bytes"] = len(encoded)
            if kind == "candidate":
                path = output / (row["identity"].replace("@", "-") + ".scn")
                path.write_bytes(encoded)
                row["candidate_path"] = str(path)
                row["candidate_sha256"] = hashlib.sha256(encoded).hexdigest()
        records.append(record)
    by_species = {}
    for row in audit["models"]:
        by_species.setdefault(row["identity"].removesuffix("@shiny"), []).append(row)
    pairs = []
    for species, rows in by_species.items():
        assert len(rows) == 2 and {r["identity"] for r in rows} == {species, species + "@shiny"}
        seen = set()
        duplicate = 0
        total = 0
        for row in rows:
            for texture in row["textures"]:
                total += texture["bytes"]
                key = texture["texture_signature"]
                if texture["shareable"]:
                    if key in seen:
                        duplicate += texture["bytes"]
                    seen.add(key)
        pairs.append({"species": species, "image_bytes": total, "strict_duplicate_bytes": duplicate,
                      "within_file_duplicate_bytes": sum(r["before"]["strict_shareable_duplicate_bytes"] for r in rows)})
    result = {"schema": 1, "prototype_only": True, "models": len(audit["models"]),
              "approved_decoded_bindings_exact": True, "pairs": pairs, "size_controls": records,
              "within_file_duplicate_bytes": sum(r["before"]["strict_shareable_duplicate_bytes"] for r in audit["models"]),
              "scope": "CPU image payload potential, not simultaneous GPU or installed bytes; saved candidates are offline only",
              "codec": {"libzstd": codec.version, "block_size": 262144, "level": 9}}
    (output / "summary.json").write_text(json.dumps(result, indent=2) + "\n")
    (output / "render-input.json").write_text(json.dumps(proof, indent=2) + "\n")
    print("Exact v11 decoded bindings:", result["models"], "; independent pair duplicate bytes:", sum(x["strict_duplicate_bytes"] for x in pairs))


if __name__ == "__main__":
    main()
