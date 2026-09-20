"""Benchmark exact temporal encodings for the dual-plane alpha stream."""

from __future__ import annotations

import argparse
import json
import statistics
import subprocess
import time
import zlib
from pathlib import Path

from PIL import Image

from catalog_compaction_benchmark import SPECIES, frame_images, load_catalog


KEY_INTERVAL = 30


def _zlib_delta(frames: list[Image.Image]) -> dict:
    payloads = []
    previous = None
    started = time.perf_counter()
    for index, frame in enumerate(frames):
        data = frame.getchannel("A").tobytes()
        key = index % KEY_INTERVAL == 0
        if key:
            delta = data
        else:
            prior = previous
            delta = bytes((value - prior[offset]) & 255 for offset, value in enumerate(data))
        payloads.append((key, zlib.compress(delta, 9)))
        previous = data
    encode_ms = (time.perf_counter() - started) * 1000
    started = time.perf_counter()
    previous = None
    decoded = []
    for key, payload in payloads:
        value = zlib.decompress(payload)
        if not key:
            value = bytes((previous[offset] + item) & 255 for offset, item in enumerate(value))
        decoded.append(value)
        previous = value
    decode_ms = (time.perf_counter() - started) * 1000
    references = [frame.getchannel("A").tobytes() for frame in frames]
    if decoded != references:
        raise ValueError("zlib alpha delta is not exact")
    target = len(frames) // 2
    key_index = target - target % KEY_INTERVAL
    started = time.perf_counter()
    previous = None
    for index in range(key_index, target + 1):
        is_key, payload = payloads[index]
        value = zlib.decompress(payload)
        previous = value if is_key else bytes(
            (previous[offset] + item) & 255 for offset, item in enumerate(value))
    seek_ms = (time.perf_counter() - started) * 1000
    started = time.perf_counter()
    zlib.decompress(payloads[0][1])
    start_ms = (time.perf_counter() - started) * 1000
    return {
        "bytes": sum(len(payload) + 12 for _key, payload in payloads),
        "encode_ms": round(encode_ms, 2),
        "decode_all_ms": round(decode_ms, 2),
        "action_start_ms": round(start_ms, 2),
        "mid_seek_ms": round(seek_ms, 2),
        "exact": True,
        "keyframe_interval": KEY_INTERVAL,
    }


def _animated_webp(frames: list[Image.Image], output: Path) -> dict:
    alpha_frames = []
    for frame in frames:
        image = Image.new("RGBA", frame.size, (255, 255, 255, 255))
        image.putalpha(frame.getchannel("A"))
        alpha_frames.append(image)
    durations = [17 if index % 3 != 1 else 16 for index in range(len(frames))]
    started = time.perf_counter()
    alpha_frames[0].save(output, "WEBP", save_all=True, append_images=alpha_frames[1:],
                         duration=durations, loop=0, lossless=True, quality=100,
                         method=4, exact=True)
    encode_ms = (time.perf_counter() - started) * 1000
    started = time.perf_counter()
    decoded = []
    with Image.open(output) as opened:
        for index in range(opened.n_frames):
            opened.seek(index)
            decoded.append(opened.convert("RGBA").getchannel("A").tobytes())
    decode_ms = (time.perf_counter() - started) * 1000
    references = [frame.getchannel("A").tobytes() for frame in frames]
    target = len(frames) // 2
    started = time.perf_counter()
    with Image.open(output) as opened:
        opened.seek(target)
        opened.convert("RGBA")
    seek_ms = (time.perf_counter() - started) * 1000
    started = time.perf_counter()
    with Image.open(output) as opened:
        opened.seek(0)
        opened.convert("RGBA")
    start_ms = (time.perf_counter() - started) * 1000
    return {
        "bytes": output.stat().st_size,
        "encode_ms": round(encode_ms, 2),
        "decode_all_ms": round(decode_ms, 2),
        "action_start_ms": round(start_ms, 2),
        "mid_seek_ms": round(seek_ms, 2),
        "exact": decoded == references,
        "godot_46_core_runtime": False,
    }


def _ffmpeg_lossless(frames: list[Image.Image], output: Path, codec: str) -> dict:
    width, height = frames[0].size
    raw = b"".join(frame.getchannel("A").tobytes() for frame in frames)
    if codec == "ffv1":
        options = ["-c:v", "ffv1", "-level", "3", "-coder", "1", "-context", "1", "-g", "30", "-pix_fmt", "gray"]
    elif codec == "vp9-lossless":
        options = ["-c:v", "libvpx-vp9", "-lossless", "1", "-deadline", "good", "-cpu-used", "4",
                   "-row-mt", "1", "-g", "30", "-pix_fmt", "yuv420p"]
    else:
        raise ValueError(codec)
    command = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "gray",
               "-s", f"{width}x{height}", "-r", "60", "-i", "pipe:0", "-an"] + options + [str(output)]
    started = time.perf_counter()
    subprocess.run(command, input=raw, check=True)
    encode_ms = (time.perf_counter() - started) * 1000
    decode_command = ["ffmpeg", "-loglevel", "error", "-i", str(output), "-f", "rawvideo", "-pix_fmt", "gray", "pipe:1"]
    started = time.perf_counter()
    decoded = subprocess.check_output(decode_command)
    decode_ms = (time.perf_counter() - started) * 1000
    stride = width * height
    frames_decoded = [decoded[index:index + stride] for index in range(0, len(decoded), stride)]
    references = [frame.getchannel("A").tobytes() for frame in frames]
    started = time.perf_counter()
    subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(output), "-frames:v", "1", "-f", "null", "-"], check=True)
    start_ms = (time.perf_counter() - started) * 1000
    midpoint = len(frames) / 120.0
    started = time.perf_counter()
    subprocess.run(["ffmpeg", "-loglevel", "error", "-ss", str(midpoint), "-i", str(output),
                    "-frames:v", "1", "-f", "null", "-"], check=True)
    seek_ms = (time.perf_counter() - started) * 1000
    return {
        "bytes": output.stat().st_size,
        "encode_ms": round(encode_ms, 2),
        "decode_all_ms": round(decode_ms, 2),
        "action_start_ms": round(start_ms, 2),
        "mid_seek_ms": round(seek_ms, 2),
        "exact": frames_decoded == references,
        "godot_46_core_runtime": False,
    }


def run(packaged_path: Path, source_path: Path, rgb_report_path: Path, output: Path) -> Path:
    packaged, source = load_catalog(packaged_path), load_catalog(source_path)
    rgb_report = json.loads(rgb_report_path.read_text())
    output.mkdir(parents=True, exist_ok=False)
    report = {"schema": 1, "format": "exact temporal alpha", "entries": {}}
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
            x, y, width, height = map(int, spec["stored_cell_rect"])
            frames = [frame.crop((x, y, x + width, y + height))
                      for frame in frame_images(source_manifest_path, original["views"]["front"][action])]
            root = output / species / action
            root.mkdir(parents=True)
            variants = {
                "zlib-delta-key30": _zlib_delta(frames),
                "animated-webp-lossless": _animated_webp(frames, root / "alpha-lossless.webp"),
                "ffv1-gray": _ffmpeg_lossless(frames, root / "alpha-ffv1.mkv", "ffv1"),
                "vp9-lossless-gray": _ffmpeg_lossless(frames, root / "alpha-vp9.webm", "vp9-lossless"),
            }
            rgb_entry = rgb_report["entries"][f"{species}/front/{action}"]
            rgb_bytes = rgb_entry["variants"]["av1-444-crf8"]["video_bytes"]
            for value in variants.values():
                value["combined_av1_444_bytes"] = rgb_bytes + value["bytes"]
                value["combined_ratio_vs_q95"] = round(value["combined_av1_444_bytes"] / sizes[action], 4)
            report["entries"][f"{species}/front/{action}"] = {
                "frames": len(frames),
                "stored_rect": [width, height],
                "current_q95_bytes": sizes[action],
                "av1_444_rgb_bytes": rgb_bytes,
                "variants": variants,
            }
    totals = {}
    for entry in report["entries"].values():
        for label, value in entry["variants"].items():
            bucket = totals.setdefault(label, {"q95_bytes": 0, "alpha_bytes": 0, "combined_bytes": 0,
                                               "decode_ms": [], "start_ms": [], "seek_ms": [], "exact": True})
            bucket["q95_bytes"] += entry["current_q95_bytes"]
            bucket["alpha_bytes"] += value["bytes"]
            bucket["combined_bytes"] += value["combined_av1_444_bytes"]
            bucket["decode_ms"].append(value["decode_all_ms"])
            bucket["start_ms"].append(value["action_start_ms"])
            bucket["seek_ms"].append(value["mid_seek_ms"])
            bucket["exact"] = bucket["exact"] and value["exact"]
    for value in totals.values():
        value["combined_ratio_vs_q95"] = round(value["combined_bytes"] / value["q95_bytes"], 4)
        value["combined_reduction"] = round(value["q95_bytes"] / value["combined_bytes"], 3)
        value["median_alpha_decode_ms"] = round(statistics.median(value.pop("decode_ms")), 2)
        value["median_alpha_start_ms"] = round(statistics.median(value.pop("start_ms")), 2)
        value["median_alpha_seek_ms"] = round(statistics.median(value.pop("seek_ms")), 2)
    report["totals"] = totals
    result = output / "report.json"
    result.write_text(json.dumps(report, indent=2) + "\n")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("packaged_catalog", type=Path)
    parser.add_argument("source_catalog", type=Path)
    parser.add_argument("rgb_report", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    print(run(args.packaged_catalog.resolve(), args.source_catalog.resolve(),
              args.rgb_report.resolve(), args.output.resolve()))
