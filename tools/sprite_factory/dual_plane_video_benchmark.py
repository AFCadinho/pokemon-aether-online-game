"""Benchmark temporal RGB video plus a separate exact L8 alpha plane.

The outputs are research artifacts only.  Godot's production runtime and sprite
catalog remain unchanged.
"""

from __future__ import annotations

import argparse
import io
import json
import math
import statistics
import subprocess
import time
from pathlib import Path

from PIL import Image

from catalog_compaction_benchmark import SPECIES, frame_images, load_catalog, visible_psnr


def _alpha_atlases(frames: list[Image.Image], pages: list[dict], root: Path) -> dict:
    root.mkdir(parents=True, exist_ok=True)
    offset = 0
    paths, total, encode_ms, decode_ms = [], 0, 0.0, 0.0
    decoded_l8 = 0
    for page_index, page in enumerate(pages):
        count, columns = int(page["count"]), int(page["columns"])
        batch = frames[offset:offset + count]
        width, height = frames[0].size
        rows = math.ceil(count / columns)
        atlas = Image.new("L", (columns * width, rows * height))
        for index, frame in enumerate(batch):
            atlas.paste(frame.getchannel("A"), ((index % columns) * width, (index // columns) * height))
        stream = io.BytesIO()
        started = time.perf_counter()
        atlas.save(stream, "PNG", optimize=True, compress_level=9)
        encode_ms += (time.perf_counter() - started) * 1000
        payload = stream.getvalue()
        path = root / f"alpha-{page_index:03d}.png"
        path.write_bytes(payload)
        paths.append(str(path.resolve()))
        total += len(payload)
        decoded_l8 += atlas.width * atlas.height
        started = time.perf_counter()
        with Image.open(io.BytesIO(payload)) as opened:
            opened.load()
        decode_ms += (time.perf_counter() - started) * 1000
        offset += count
    started = time.perf_counter()
    with Image.open(paths[0]) as opened:
        opened.load()
    start_ms = (time.perf_counter() - started) * 1000
    return {
        "bytes": total,
        "files": paths,
        "encode_ms": round(encode_ms, 2),
        "decode_all_ms": round(decode_ms, 2),
        "action_start_ms": round(start_ms, 2),
        "decoded_l8_bytes": decoded_l8,
    }


def _decode_rgb(command: list[str], width: int, height: int) -> tuple[list[Image.Image], float]:
    started = time.perf_counter()
    raw = subprocess.check_output(command)
    elapsed = (time.perf_counter() - started) * 1000
    stride = width * height * 3
    if len(raw) % stride:
        raise ValueError("Invalid decoded RGB stream size")
    return [Image.frombytes("RGB", (width, height), raw[index:index + stride])
            for index in range(0, len(raw), stride)], elapsed


def _codec_command(label: str, output: Path) -> list[str]:
    common = ["-an", "-g", "30"]
    if label == "vp9-444-crf4":
        return common + ["-c:v", "libvpx-vp9", "-pix_fmt", "yuv444p", "-crf", "4", "-b:v", "0",
                         "-deadline", "good", "-cpu-used", "4", "-row-mt", "1", str(output)]
    if label == "av1-444-crf8":
        return common + ["-c:v", "libaom-av1", "-pix_fmt", "yuv444p", "-crf", "8", "-b:v", "0",
                         "-cpu-used", "6", "-row-mt", "1", str(output)]
    if label == "av1-444-crf4":
        return common + ["-c:v", "libaom-av1", "-pix_fmt", "yuv444p", "-crf", "4", "-b:v", "0",
                         "-cpu-used", "6", "-row-mt", "1", str(output)]
    if label == "av1-420-crf4":
        return common + ["-c:v", "libaom-av1", "-pix_fmt", "yuv420p", "-crf", "4", "-b:v", "0",
                         "-cpu-used", "6", "-row-mt", "1", str(output)]
    raise ValueError(label)


def _encode_video(label: str, frames: list[Image.Image], alpha: list[Image.Image], output: Path) -> dict:
    width, height = frames[0].size
    command = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
               "-s", f"{width}x{height}", "-r", "60", "-i", "pipe:0"] + _codec_command(label, output)
    payload = b"".join(frame.convert("RGB").tobytes() for frame in frames)
    started = time.perf_counter()
    subprocess.run(command, input=payload, check=True)
    encode_ms = (time.perf_counter() - started) * 1000
    base = ["ffmpeg", "-loglevel", "error", "-i", str(output)]
    decoded, decode_ms = _decode_rgb(base + ["-f", "rawvideo", "-pix_fmt", "rgb24", "pipe:1"], width, height)
    if len(decoded) != len(frames):
        raise ValueError(f"{label} decoded {len(decoded)} of {len(frames)} frames")
    reconstructed = []
    for rgb, source in zip(decoded, alpha):
        rgba = rgb.convert("RGBA")
        rgba.putalpha(source.getchannel("A"))
        reconstructed.append(rgba)
    psnr = [visible_psnr(reference, candidate) for reference, candidate in zip(frames, reconstructed)]
    started = time.perf_counter()
    subprocess.run(base + ["-frames:v", "1", "-f", "null", "-"], check=True)
    start_ms = (time.perf_counter() - started) * 1000
    midpoint = len(frames) / 120.0
    started = time.perf_counter()
    subprocess.run(["ffmpeg", "-loglevel", "error", "-ss", str(midpoint), "-i", str(output),
                    "-frames:v", "1", "-f", "null", "-"], check=True)
    seek_ms = (time.perf_counter() - started) * 1000
    return {
        "video_bytes": output.stat().st_size,
        "encode_ms": round(encode_ms, 2),
        "decode_all_ms": round(decode_ms, 2),
        "action_start_process_ms": round(start_ms, 2),
        "mid_seek_process_ms": round(seek_ms, 2),
        "minimum_visible_psnr_db": round(min(psnr), 3),
        "mean_visible_psnr_db": round(statistics.mean(psnr), 3),
        "alpha_exact": True,
        "streaming_ram_bytes": width * height * 4,
        "steady_vram_bytes": width * height * 4,
        "godot_46_core_runtime": False,
    }


def run(packaged_path: Path, source_path: Path, output: Path, codecs: tuple[str, ...]) -> Path:
    packaged, source = load_catalog(packaged_path), load_catalog(source_path)
    output.mkdir(parents=True, exist_ok=False)
    report = {
        "schema": 1,
        "format": "temporal RGB video + exact L8 PNG alpha atlases",
        "fps": 60,
        "resolution_policy": "unchanged trimmed 512x512 frame coordinates",
        "entries": {},
    }
    for species in SPECIES:
        key = f"{species}:normal"
        packaged_path_entry = Path(packaged["entries"][key]["path"])
        source_path_entry = Path(source["entries"][key]["path"])
        packed = json.loads(packaged_path_entry.read_text())
        original = json.loads(source_path_entry.read_text())
        front = packed["views"]["front"]
        sizes = {action: sum((packaged_path_entry.parent / page["file"]).stat().st_size
                             for page in spec["pages"]) for action, spec in front.items()}
        for action in sorted({"idle", max(sizes, key=sizes.get)}):
            spec = front[action]
            x, y, width, height = map(int, spec["stored_cell_rect"])
            frames = [frame.crop((x, y, x + width, y + height))
                      for frame in frame_images(source_path_entry, original["views"]["front"][action])]
            root = output / species / action
            root.mkdir(parents=True)
            alpha = _alpha_atlases(frames, spec["pages"], root / "alpha")
            variants = {}
            for label in codecs:
                extension = "webm" if label.startswith("vp9") else "mkv"
                value = _encode_video(label, frames, frames, root / f"{label}.{extension}")
                value["alpha_plane"] = {key: item for key, item in alpha.items() if key != "files"}
                value["total_bytes"] = value["video_bytes"] + alpha["bytes"]
                value["ratio_vs_current_q95"] = round(value["total_bytes"] / sizes[action], 4)
                variants[label] = value
            report["entries"][f"{species}/front/{action}"] = {
                "frames": len(frames),
                "stored_rect": [width, height],
                "current_q95_bytes": sizes[action],
                "variants": variants,
            }
    result = output / "report.json"
    result.write_text(json.dumps(report, indent=2) + "\n")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("packaged_catalog", type=Path)
    parser.add_argument("source_catalog", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--codecs", nargs="+", default=("vp9-444-crf4", "av1-444-crf8", "av1-420-crf4"))
    args = parser.parse_args()
    print(run(args.packaged_catalog.resolve(), args.source_catalog.resolve(), args.output.resolve(), tuple(args.codecs)))
