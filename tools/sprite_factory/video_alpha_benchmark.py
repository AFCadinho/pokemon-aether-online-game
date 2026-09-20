"""Benchmark VP9/WebM alpha as a non-production temporal-codec reference."""

from __future__ import annotations

import argparse
import json
import statistics
import subprocess
import time
from pathlib import Path

from PIL import Image, ImageChops

from catalog_compaction_benchmark import SPECIES, frame_images, load_catalog, visible_psnr


def decode(command: list[str], width: int, height: int) -> tuple[list[Image.Image], float]:
    started = time.perf_counter()
    raw = subprocess.check_output(command)
    elapsed = (time.perf_counter() - started) * 1000
    size = width * height * 4
    if len(raw) % size:
        raise ValueError("Invalid decoded raw-video size")
    return [Image.frombytes("RGBA", (width, height), raw[index:index + size])
            for index in range(0, len(raw), size)], elapsed


def encode_variant(frames: list[Image.Image], output: Path, crf: int) -> dict:
    width, height = frames[0].size
    command = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgba",
               "-s", f"{width}x{height}", "-r", "60", "-i", "pipe:0", "-an", "-c:v", "libvpx-vp9",
               "-pix_fmt", "yuva420p", "-crf", str(crf), "-b:v", "0", "-deadline", "good",
               "-cpu-used", "4", "-row-mt", "1", "-auto-alt-ref", "0", str(output)]
    started = time.perf_counter()
    subprocess.run(command, input=b"".join(frame.tobytes() for frame in frames), check=True)
    encode_ms = (time.perf_counter() - started) * 1000
    base_decode = ["ffmpeg", "-loglevel", "error", "-c:v", "libvpx-vp9", "-i", str(output)]
    decoded, decode_ms = decode(base_decode + ["-f", "rawvideo", "-pix_fmt", "rgba", "pipe:1"], width, height)
    if len(decoded) != len(frames):
        raise ValueError("VP9 decoded frame count differs")
    psnr = [visible_psnr(a, b) for a, b in zip(frames, decoded)]
    alpha_differences = [ImageChops.difference(a.getchannel("A"), b.getchannel("A")) for a, b in zip(frames, decoded)]
    started = time.perf_counter()
    subprocess.run(base_decode + ["-frames:v", "1", "-f", "null", "-"], check=True)
    start_ms = (time.perf_counter() - started) * 1000
    midpoint = len(frames) / 120.0
    started = time.perf_counter()
    subprocess.run(["ffmpeg", "-loglevel", "error", "-ss", str(midpoint), "-c:v", "libvpx-vp9",
                    "-i", str(output), "-frames:v", "1", "-f", "null", "-"], check=True)
    seek_ms = (time.perf_counter() - started) * 1000
    return {
        "bytes": output.stat().st_size, "encode_ms": round(encode_ms, 2),
        "decode_all_ms": round(decode_ms, 2), "action_start_process_ms": round(start_ms, 2),
        "mid_seek_process_ms": round(seek_ms, 2), "minimum_visible_psnr_db": round(min(psnr), 3),
        "mean_visible_psnr_db": round(statistics.mean(psnr), 3),
        "alpha_exact": all(diff.getbbox() is None for diff in alpha_differences),
        "alpha_max_delta": max(diff.getextrema()[1] for diff in alpha_differences),
        "streaming_ram_bytes": width * height * 4, "steady_vram_bytes": width * height * 4,
        "godot_46_core_runtime": False,
    }


def run(packaged_path: Path, source_path: Path, output: Path) -> Path:
    packaged, source = load_catalog(packaged_path), load_catalog(source_path)
    output.mkdir(parents=True, exist_ok=False)
    report = {"schema": 1, "codec": "VP9 WebM yuva420p", "fps": 60, "entries": {}}
    for species in SPECIES:
        key = f"{species}:normal"
        packaged_manifest_path = Path(packaged["entries"][key]["path"])
        source_manifest_path = Path(source["entries"][key]["path"])
        packed = json.loads(packaged_manifest_path.read_text())
        original = json.loads(source_manifest_path.read_text())
        front = packed["views"]["front"]
        sizes = {action: sum((packaged_manifest_path.parent / page["file"]).stat().st_size
                             for page in spec["pages"]) for action, spec in front.items()}
        for action in sorted({"idle", max(sizes, key=sizes.get)}):
            spec = front[action]
            full = frame_images(source_manifest_path, original["views"]["front"][action])
            x, y, width, height = map(int, spec["stored_cell_rect"])
            frames = [frame.crop((x, y, x + width, y + height)) for frame in full]
            root = output / species / action
            root.mkdir(parents=True)
            variants = {}
            for crf in (4, 10):
                variants[f"crf{crf}"] = encode_variant(frames, root / f"vp9-alpha-crf{crf}.webm", crf)
                variants[f"crf{crf}"]["ratio_vs_current_q95"] = round(variants[f"crf{crf}"]["bytes"] / sizes[action], 4)
            report["entries"][f"{species}/front/{action}"] = {
                "frames": len(frames), "current_q95_bytes": sizes[action], "variants": variants,
            }
    target = output / "report.json"
    target.write_text(json.dumps(report, indent=2) + "\n")
    return target


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("packaged_catalog", type=Path)
    parser.add_argument("source_catalog", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    print(run(args.packaged_catalog.resolve(), args.source_catalog.resolve(), args.output.resolve()))
