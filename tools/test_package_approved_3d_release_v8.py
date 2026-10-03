#!/usr/bin/env python3
"""Regression check for the locally staged full-catalog v8 release index."""
from __future__ import annotations

import json
from pathlib import Path
import tempfile

from package_approved_3d_release_v8 import build
from publish_approved_3d_index_v8 import validate_local

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="pao-v8-index-test-") as temporary:
        index_path = Path(temporary) / "index.json"
        metadata_path = Path(temporary) / "metadata.json"
        metadata = build(index_path, metadata_path)
        committed_index = json.loads((ROOT / "release/approved_3d_bundles_v8_index.json").read_text())
        generated_index = json.loads(index_path.read_text())
        committed_metadata = json.loads((ROOT / "release/approved_3d_bundles_v8.json").read_text())
        assert generated_index == committed_index
        assert metadata == committed_metadata
        assert len(generated_index["assets"]) == 1139
        assert sum(len(asset["appearances"]) for asset in generated_index["assets"]) == 2278
        assert generated_index["catalog_revision"] == "approved-pokemon-3d-v8"
        metadata, published_index, bundles = validate_local()
        assert metadata["revision"] == "approved-pokemon-3d-v8"
        assert len(published_index["assets"]) == len(bundles) == 1139
        print("PACKAGE_APPROVED_3D_V8_OK assets=1139 appearances=2278 receipts=18")


if __name__ == "__main__":
    main()
