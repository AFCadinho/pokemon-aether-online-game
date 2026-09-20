"""Benchmark per-frame tight WebP cells as a non-production transparency probe."""

from __future__ import annotations

import argparse
import io
import json
import statistics
import time
from pathlib import Path

from PIL import Image

from catalog_compaction_benchmark import SPECIES, frame_images, load_catalog, visible_psnr


def run(packaged_path: Path, source_path: Path, output: Path) -> Path:
    packaged, source = load_catalog(packaged_path), load_catalog(source_path)
    report = {"schema": 1, "format": "individually tight WebP Q95", "entries": {}}
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
            source_frames = [frame.crop((x, y, x + width, y + height))
                             for frame in frame_images(sp, original["views"]["front"][action])]
            payloads, positions, encoded_sizes = [], [], []
            started = time.perf_counter()
            for frame in source_frames:
                bounds = frame.getchannel("A").getbbox() or (0, 0, 1, 1)
                bounds = (max(0, bounds[0] - 4), max(0, bounds[1] - 4),
                          min(width, bounds[2] + 4), min(height, bounds[3] + 4))
                cropped = frame.crop(bounds)
                stream = io.BytesIO()
                cropped.save(stream, "WEBP", quality=95, method=4, exact=True)
                payloads.append(stream.getvalue())
                positions.append(bounds[:2])
                encoded_sizes.append(cropped.size)
            encode_ms = (time.perf_counter() - started) * 1000
            started = time.perf_counter()
            decoded = []
            for payload, position in zip(payloads, positions):
                with Image.open(io.BytesIO(payload)) as opened:
                    cell = opened.convert("RGBA")
                frame = Image.new("RGBA", (width, height))
                frame.paste(cell, position)
                decoded.append(frame)
            decode_ms = (time.perf_counter() - started) * 1000
            psnr = [visible_psnr(a, b) for a, b in zip(source_frames, decoded)]
            started = time.perf_counter()
            with Image.open(io.BytesIO(payloads[0])) as opened:
                opened.convert("RGBA")
            start_ms = (time.perf_counter() - started) * 1000
            total = sum(map(len, payloads)) + len(payloads) * 16
            report["entries"][f"{species}/front/{action}"] = {
                "frames": len(source_frames), "current_q95_bytes": sizes[action], "bytes_with_index": total,
                "ratio_vs_current_q95": round(total / sizes[action], 4), "encode_ms": round(encode_ms, 2),
                "decode_all_ms": round(decode_ms, 2), "action_start_decode_ms": round(start_ms, 2),
                "minimum_visible_psnr_db": round(min(psnr), 3), "mean_visible_psnr_db": round(statistics.mean(psnr), 3),
                "alpha_exact": all(a.getchannel("A").tobytes() == b.getchannel("A").tobytes()
                                   for a, b in zip(source_frames, decoded)),
                "mean_frame_rgba_bytes": round(statistics.mean(w * h * 4 for w, h in encoded_sizes)),
                "maximum_frame_rgba_bytes": max(w * h * 4 for w, h in encoded_sizes),
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
