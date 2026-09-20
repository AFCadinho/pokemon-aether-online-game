"""Benchmark static atlas WebP encoder effort/quality without changing runtime format."""

from __future__ import annotations

import argparse
import io
import json
import math
import statistics
import time
from pathlib import Path

from PIL import Image

from catalog_compaction_benchmark import SPECIES, frame_images, load_catalog, visible_psnr


def encode_action(frames: list[Image.Image], page_specs: list[dict], quality: int, method: int) -> dict:
    offset, total_bytes, encode_ms, decode_ms = 0, 0, 0.0, 0.0
    decoded = []
    for page in page_specs:
        count, columns = int(page["count"]), int(page["columns"])
        batch = frames[offset:offset + count]
        width, height = frames[0].size
        atlas = Image.new("RGBA", (columns * width, math.ceil(count / columns) * height))
        for index, frame in enumerate(batch):
            atlas.paste(frame, ((index % columns) * width, (index // columns) * height))
        stream = io.BytesIO()
        started = time.perf_counter()
        atlas.save(stream, "WEBP", quality=quality, method=method, exact=True)
        encode_ms += (time.perf_counter() - started) * 1000
        payload = stream.getvalue()
        total_bytes += len(payload)
        started = time.perf_counter()
        with Image.open(io.BytesIO(payload)) as opened:
            result = opened.convert("RGBA")
        decode_ms += (time.perf_counter() - started) * 1000
        for index in range(count):
            left, top = (index % columns) * width, (index // columns) * height
            decoded.append(result.crop((left, top, left + width, top + height)))
        offset += count
    psnr = [visible_psnr(a, b) for a, b in zip(frames, decoded)]
    return {
        "bytes": total_bytes, "encode_ms": round(encode_ms, 2), "decode_all_ms": round(decode_ms, 2),
        "minimum_visible_psnr_db": round(min(psnr), 3), "mean_visible_psnr_db": round(statistics.mean(psnr), 3),
        "alpha_exact": all(a.getchannel("A").tobytes() == b.getchannel("A").tobytes()
                           for a, b in zip(frames, decoded)),
    }


def run(packaged_path: Path, source_path: Path, output: Path) -> Path:
    packaged, source = load_catalog(packaged_path), load_catalog(source_path)
    report = {"schema": 1, "format": "static WebP atlas", "entries": {}}
    for species in SPECIES:
        key = f"{species}:normal"
        pp, sp = Path(packaged["entries"][key]["path"]), Path(source["entries"][key]["path"])
        packed, original = json.loads(pp.read_text()), json.loads(sp.read_text())
        front = packed["views"]["front"]
        sizes = {action: sum((pp.parent / page["file"]).stat().st_size for page in spec["pages"])
                 for action, spec in front.items()}
        for action in sorted({"idle", max(sizes, key=sizes.get)}):
            spec = front[action]
            x, y, width, height = map(int, spec["stored_cell_rect"])
            frames = [frame.crop((x, y, x + width, y + height))
                      for frame in frame_images(sp, original["views"]["front"][action])]
            variants = {}
            for quality, method in ((90, 4), (85, 4)):
                label = f"q{quality}_m{method}"
                variants[label] = encode_action(frames, spec["pages"], quality, method)
                variants[label]["ratio_vs_current_q95_m4"] = round(variants[label]["bytes"] / sizes[action], 4)
            report["entries"][f"{species}/front/{action}"] = {
                "frames": len(frames), "current_q95_m4_bytes": sizes[action], "variants": variants,
            }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n")
    return output


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("packaged_catalog", type=Path)
    parser.add_argument("source_catalog", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    print(run(args.packaged_catalog.resolve(), args.source_catalog.resolve(), args.output.resolve()))
