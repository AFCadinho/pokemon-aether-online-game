#!/usr/bin/env python3
"""Require pixel-exact candidate frames against original or repeat-original controls."""
import argparse
import hashlib
import json
import os
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--render", type=Path, required=True)
    args = parser.parse_args()
    if os.environ.get("POKEAETHER_SLOT") != ROOT.parent.name:
        parser.error("Run through assigned slot-env")
    directory = args.render.resolve()
    directory.relative_to(ROOT / ".tmp")
    target = directory / "pixel-comparison.json"
    assert not target.exists()
    report = json.loads((directory / "report.json").read_bytes())
    frames = []
    for row in report["records"]:
        controls = [row[k] for k in ("source", "repeat_source", "candidate")]
        assert all(control["camera_size"] == controls[0]["camera_size"] for control in controls)
        assert all(control["response_schema"] == controls[0]["response_schema"] for control in controls)
        keys = set(controls[0]["frames"])
        assert len(keys) == 10 and all(set(control["frames"]) == keys for control in controls)
        for key in sorted(keys):
            images, pixels = [], []
            for control in controls:
                path = next(Path(p) for p in control["paths"] if Path(p).stem == key).resolve()
                path.relative_to(directory)
                with Image.open(path) as file:
                    image = file.copy()
                assert image.mode in {"RGB", "RGBA"}
                assert image.size == (512, 512)
                data = image.tobytes()
                assert hashlib.sha256(data).hexdigest() == control["frames"][key]
                images.append(image)
                pixels.append(data)
            assert all(image.mode == images[0].mode for image in images)
            delta = ImageChops.difference(images[0], images[2])
            frames.append({"identity": row["identity"], "frame": key,
                           "candidate_equals_source": pixels[2] == pixels[0],
                           "candidate_equals_repeat_source": pixels[2] == pixels[1],
                           "source_equals_repeat_source": pixels[0] == pixels[1],
                           "maximum_channel_delta_vs_first_source": max(pair[1] for pair in delta.getextrema())})
    assert frames and len(frames) == len(report["records"]) * 10
    success = all(row["candidate_equals_source"] or row["candidate_equals_repeat_source"] for row in frames)
    target.write_text(json.dumps({"schema": 1, "prototype_only": True, "success": success,
                                  "frames": frames}, indent=2) + "\n")
    print("MODEL_PAIR_PIXELS", "OK" if success else "FAIL", "frames=" + str(len(frames)),
          "first_source_exact=" + str(sum(row["candidate_equals_source"] for row in frames)))
    if not success:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
