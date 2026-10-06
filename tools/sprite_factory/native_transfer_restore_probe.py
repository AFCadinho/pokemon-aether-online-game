#!/usr/bin/env python3
"""Offline transfer-only restoration fixture; not a launcher installation format.

Only writes a fresh directory under this checkout's .tmp. Each restored native
file must match the existing approved file's SHA-256 before atomic replacement.
The exact compressor version is part of the fixture contract. Publication,
signing, manifest trust and a platform installer are deliberately out of scope.
"""
import argparse
import json
import os
from pathlib import Path
import tempfile
import time

from native_resource_compression_probe import Zstd, decode, encode, sha


def restore(payload, target, receipt, codec):
    if codec.version != receipt["codec_version"]:
        raise ValueError("Restoration codec version differs from receipt")
    if len(payload) != receipt["transfer_bytes"] or sha(payload) != receipt["transfer_sha256"]:
        raise ValueError("Transfer payload failed integrity check")
    raw = decode(payload, codec)
    if len(raw) != receipt["raw_bytes"] or sha(raw) != receipt["raw_sha256"]:
        raise ValueError("Native resource stream failed integrity check")
    original = encode(raw, 4096, 3, codec)
    if len(original) != receipt["installed_bytes"] or sha(original) != receipt["installed_sha256"]:
        raise ValueError("Restored resource differs from approved original")
    # All checks precede replacement. An existing valid file survives failure.
    pending = None
    try:
        with tempfile.NamedTemporaryFile(dir=target.parent, prefix=".restore-", delete=False) as file:
            pending = Path(file.name)
            file.write(original)
            file.flush()
            os.fsync(file.fileno())
        if pending.stat().st_size != receipt["installed_bytes"] or sha(pending.read_bytes()) != receipt["installed_sha256"]:
            raise ValueError("Restored file failed disk integrity check")
        os.replace(pending, target)
    finally:
        if pending is not None and pending.exists():
            pending.unlink()


def receipt_for(entry, version):
    return {"codec_version": version, "transfer_sha256": entry["candidate_sha256"],
            "transfer_bytes": Path(entry["candidate_path"]).stat().st_size,
            "raw_bytes": entry["raw_bytes"], "raw_sha256": entry["raw_sha256"],
            "installed_bytes": entry["source_bytes"], "installed_sha256": entry["source_sha256"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True, help="Existing native compression report")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    output.relative_to(root / ".tmp")
    output.mkdir(parents=True, exist_ok=False)
    source_bytes = args.input.read_bytes()
    source = json.loads(source_bytes)
    if not source.get("complete") or not source["entries"]:
        raise ValueError("Incomplete source experiment")
    codec = Zstd()
    report = {"prototype_only": True, "production_approved": False, "complete": False,
              "source_report_sha256": sha(source_bytes), "libzstd": codec.version,
              "source_script_sha256": sha(Path(__file__).read_bytes()), "entries": []}
    for entry in source["entries"]:
        identity = entry["identity"]
        if Path(identity).name != identity or identity in (".", ".."):
            raise ValueError("Invalid fixture identity")
        payload = Path(entry["candidate_path"]).read_bytes()
        receipt = receipt_for(entry, source["libzstd"])
        target = output / (identity + ".scn")
        elapsed = []
        for _cycle in range(2):
            started = time.perf_counter()
            restore(payload, target, receipt, codec)
            elapsed.append((time.perf_counter() - started) * 1000)
            if sha(target.read_bytes()) != entry["source_sha256"]:
                raise ValueError("Committed file failed integrity check")
        report["entries"].append({"identity": identity, "receipt": receipt,
            "installation_and_replacement_ms": elapsed, "approved_file_exact": True,
            "installed_path": str(target)})
        print("NATIVE_RESTORED_EXACT", identity, flush=True)
    report["complete"] = True
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
