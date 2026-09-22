"""Analyze temporal redundancy and benchmark non-production sprite encodings."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import statistics
import tempfile
import time
import zlib
from pathlib import Path

from PIL import Image, ImageChops, ImageStat

SPECIES = ("dragonite", "roaring-moon", "jigglypuff", "diglett")
FPS = 60
KEYFRAME_INTERVAL = 30


def load_catalog(path: Path) -> dict:
    value = json.loads(path.read_text())
    if value.get("schema") != 1 or value.get("mode") not in ("preview", "approved"):
        raise ValueError("Expected a schema-1 rendered sprite catalog")
    return value


def frame_images(manifest_path: Path, spec: dict) -> list[Image.Image]:
    x, y, width, height = map(int, spec.get("stored_cell_rect", [0, 0, 512, 512]))
    frames = []
    for page in spec["pages"]:
        path = manifest_path.parent / page["file"]
        if hashlib.sha256(path.read_bytes()).hexdigest() != page["sha256"]:
            raise ValueError(f"Hash mismatch: {path}")
        with Image.open(path) as opened:
            atlas = opened.convert("RGBA")
        columns = int(page["columns"])
        for index in range(int(page["count"])):
            left = (index % columns) * width
            top = (index // columns) * height
            frames.append(atlas.crop((left, top, left + width, top + height)))
    if len(frames) != int(spec["count"]):
        raise ValueError("Frame count mismatch")
    return frames


def exact_period(hashes: list[str]) -> int | None:
    count = len(hashes)
    for period in range(1, count):
        if all(value == hashes[index % period] for index, value in enumerate(hashes)):
            return period
    return None


def visible_psnr(left: Image.Image, right: Image.Image) -> float:
    background = Image.new("RGBA", left.size, (12, 16, 28, 255))
    a = Image.alpha_composite(background, left).convert("RGB")
    b = Image.alpha_composite(background, right).convert("RGB")
    stat = ImageStat.Stat(ImageChops.difference(a, b))
    mse = sum(value * value for value in stat.rms) / 3.0
    return 99.0 if mse == 0 else 10.0 * math.log10(65025.0 / mse)


def action_metrics(manifest_path: Path, spec: dict, frames: list[Image.Image], reference: list[Image.Image]) -> dict:
    width, height = frames[0].size
    hashes = [hashlib.sha256(frame.tobytes()).hexdigest() for frame in frames]
    runs = 1 + sum(hashes[index] != hashes[index - 1] for index in range(1, len(hashes)))
    adjacent = [visible_psnr(frames[index - 1], frames[index]) for index in range(1, len(frames))]
    alpha_histogram = [0] * 256
    for frame in frames:
        histogram = frame.getchannel("A").histogram()
        alpha_histogram = [a + b for a, b in zip(alpha_histogram, histogram)]
    pixels = width * height * len(frames)
    tight_pixels = 0
    for frame in frames:
        bounds = frame.getchannel("A").getbbox()
        if bounds:
            tight_pixels += (bounds[2] - bounds[0]) * (bounds[3] - bounds[1])
    baseline_psnr = [visible_psnr(a, b) for a, b in zip(reference, frames)]
    disk_bytes = sum((manifest_path.parent / page["file"]).stat().st_size for page in spec["pages"])
    gpu_bytes = sum(
        int(page["columns"]) * width
        * math.ceil(int(page["count"]) / int(page["columns"])) * height * 4
        for page in spec["pages"]
    )
    period = exact_period(hashes) if spec.get("loop", False) else None
    endpoint_duplicate = bool(spec.get("loop", False) and len(hashes) > 1 and hashes[0] == hashes[-1])
    exact_stored = period or runs
    return {
        "frames": len(frames), "duration_seconds": round(len(frames) / FPS, 3),
        "stored_rect": [width, height], "disk_bytes": disk_bytes,
        "decoded_rgba_bytes": gpu_bytes, "logical_rgba_bytes": pixels * 4,
        "per_frame_tight_rgba_bytes": tight_pixels * 4,
        "per_frame_tight_ratio_vs_action_union": round(tight_pixels / pixels, 6),
        "transparent_pixel_fraction": round(alpha_histogram[0] / pixels, 6),
        "partially_transparent_pixel_fraction": round(sum(alpha_histogram[1:255]) / pixels, 6),
        "unique_exact_frames": len(set(hashes)), "consecutive_exact_runs": runs,
        "lossless_equivalent_stored_frames": exact_stored,
        "lossless_equivalent_frame_reduction": len(frames) - exact_stored,
        "exact_loop_period": period, "loop_endpoint_duplicates_first": endpoint_duplicate,
        "adjacent_psnr_median_db": round(statistics.median(adjacent), 3) if adjacent else 99.0,
        "adjacent_pairs_psnr_ge_50": sum(value >= 50 for value in adjacent),
        "adjacent_pairs_psnr_ge_45": sum(value >= 45 for value in adjacent),
        "current_q95_minimum_visible_psnr_db": round(min(baseline_psnr), 3),
        "current_q95_mean_visible_psnr_db": round(statistics.mean(baseline_psnr), 3),
        "current_q95_alpha_exact": all(a.getchannel("A").tobytes() == b.getchannel("A").tobytes()
                                       for a, b in zip(reference, frames)),
    }


def delta_zlib_benchmark(frames: list[Image.Image]) -> dict:
    payloads = []
    previous = None
    started = time.perf_counter()
    for index, frame in enumerate(frames):
        keyframe = index % KEYFRAME_INTERVAL == 0
        image = frame if keyframe else ImageChops.subtract_modulo(frame, previous)
        payloads.append((keyframe, zlib.compress(image.tobytes(), 9)))
        previous = frame
    encode_ms = (time.perf_counter() - started) * 1000

    started = time.perf_counter()
    previous = None
    decoded = []
    for index, (keyframe, payload) in enumerate(payloads):
        image = Image.frombytes("RGBA", frames[0].size, zlib.decompress(payload))
        if not keyframe:
            image = ImageChops.add_modulo(previous, image)
        decoded.append(image)
        previous = image
    decode_ms = (time.perf_counter() - started) * 1000
    if any(a.tobytes() != b.tobytes() for a, b in zip(frames, decoded)):
        raise ValueError("Delta candidate is not exact")

    target = len(frames) // 2
    key = target - target % KEYFRAME_INTERVAL
    started = time.perf_counter()
    previous = None
    for index in range(key, target + 1):
        is_key, payload = payloads[index]
        image = Image.frombytes("RGBA", frames[0].size, zlib.decompress(payload))
        previous = image if is_key else ImageChops.add_modulo(previous, image)
    seek_ms = (time.perf_counter() - started) * 1000
    width, height = frames[0].size
    return {
        "bytes": sum(len(payload) + 12 for _, payload in payloads), "encode_ms": round(encode_ms, 2),
        "decode_all_ms": round(decode_ms, 2), "action_start_ms": round(_zlib_first(payloads, frames[0].size), 2),
        "mid_seek_ms": round(seek_ms, 2), "exact_to_current_q95": True,
        "streaming_ram_bytes": width * height * 4 * 2, "steady_vram_bytes": width * height * 4,
        "keyframe_interval": KEYFRAME_INTERVAL,
    }


def _zlib_first(payloads, size) -> float:
    started = time.perf_counter()
    Image.frombytes("RGBA", size, zlib.decompress(payloads[0][1]))
    return (time.perf_counter() - started) * 1000


def animated_webp_benchmark(frames: list[Image.Image], output: Path, lossless: bool) -> dict:
    durations = [17 if index % 3 != 1 else 16 for index in range(len(frames))]
    started = time.perf_counter()
    frames[0].save(output, "WEBP", save_all=True, append_images=frames[1:], duration=durations,
                   loop=0, lossless=lossless, quality=100 if lossless else 95, method=4, exact=True)
    encode_ms = (time.perf_counter() - started) * 1000
    started = time.perf_counter()
    with Image.open(output) as opened:
        opened.seek(0)
        first = opened.convert("RGBA")
    action_start_ms = (time.perf_counter() - started) * 1000
    started = time.perf_counter()
    decoded = []
    with Image.open(output) as opened:
        for index in range(opened.n_frames):
            opened.seek(index)
            decoded.append(opened.convert("RGBA"))
    decode_ms = (time.perf_counter() - started) * 1000
    target = len(frames) // 2
    started = time.perf_counter()
    with Image.open(output) as opened:
        opened.seek(target)
        opened.convert("RGBA")
    seek_ms = (time.perf_counter() - started) * 1000
    psnr = [visible_psnr(a, b) for a, b in zip(frames, decoded)]
    alpha_exact = all(a.getchannel("A").tobytes() == b.getchannel("A").tobytes() for a, b in zip(frames, decoded))
    width, height = frames[0].size
    return {
        "bytes": output.stat().st_size, "encode_ms": round(encode_ms, 2),
        "decode_all_ms": round(decode_ms, 2), "action_start_ms": round(action_start_ms, 2),
        "mid_seek_ms": round(seek_ms, 2), "alpha_exact": alpha_exact,
        "minimum_visible_psnr_db": round(min(psnr), 3), "mean_visible_psnr_db": round(statistics.mean(psnr), 3),
        "streaming_ram_bytes": width * height * 4, "steady_vram_bytes": width * height * 4,
        "timing_ms_pattern": [17, 16, 17], "godot_46_core_runtime": False,
    }


def shiny_sharing(normal_path: Path, shiny_path: Path, normal: dict, shiny: dict) -> dict:
    result = {}
    for view in normal["views"]:
        for action, normal_spec in normal["views"][view].items():
            shiny_spec = shiny["views"][view][action]
            normal_frames = frame_images(normal_path, normal_spec)
            shiny_frames = frame_images(shiny_path, shiny_spec)
            same_alpha = sum(a.getchannel("A").tobytes() == b.getchannel("A").tobytes()
                             for a, b in zip(normal_frames, shiny_frames))
            alpha_normal = zlib.compress(b"".join(frame.getchannel("A").tobytes() for frame in normal_frames), 9)
            alpha_shiny = zlib.compress(b"".join(frame.getchannel("A").tobytes() for frame in shiny_frames), 9)
            residual = []
            for a, b in zip(normal_frames, shiny_frames):
                residual.append(ImageChops.subtract_modulo(b, a).tobytes())
            result[f"{view}/{action}"] = {
                "frames": len(normal_frames), "alpha_identical_frames": same_alpha,
                "alpha_identical_fraction": round(same_alpha / len(normal_frames), 6),
                "separate_alpha_zlib_bytes": len(alpha_normal) + len(alpha_shiny),
                "shared_alpha_zlib_bytes": len(alpha_normal) if same_alpha == len(normal_frames) else None,
                "normal_to_shiny_rgba_residual_zlib_bytes": len(zlib.compress(b"".join(residual), 9)),
                "shiny_q95_bytes": sum((shiny_path.parent / page["file"]).stat().st_size for page in shiny_spec["pages"]),
            }
    return result


def run(catalog_path: Path, source_catalog_path: Path, output: Path) -> Path:
    catalog = load_catalog(catalog_path)
    source_catalog = load_catalog(source_catalog_path)
    output.mkdir(parents=True, exist_ok=False)
    report = {"schema": 1, "fps": FPS, "resolution": [512, 512], "species": {}, "candidates": {}, "normal_shiny": {}}
    for species in SPECIES:
        key = f"{species}:normal"
        manifest_path = Path(catalog["entries"][key]["path"])
        source_manifest_path = Path(source_catalog["entries"][key]["path"])
        manifest = json.loads(manifest_path.read_text())
        source_manifest = json.loads(source_manifest_path.read_text())
        species_report = {}
        front_sizes = {}
        cached = {}
        for view, actions in manifest["views"].items():
            for action, spec in actions.items():
                frames = frame_images(manifest_path, spec)
                source_full = frame_images(source_manifest_path, source_manifest["views"][view][action])
                x, y, width, height = map(int, spec["stored_cell_rect"])
                reference = [frame.crop((x, y, x + width, y + height)) for frame in source_full]
                cached[(view, action)] = frames
                cached[(view, action, "source")] = reference
                species_report[f"{view}/{action}"] = action_metrics(manifest_path, spec, frames, reference)
                if view == "front":
                    front_sizes[action] = species_report[f"{view}/{action}"]["disk_bytes"]
        report["species"][key] = species_report
        selected = {"idle", max(front_sizes, key=front_sizes.get)}
        for action in sorted(selected):
            frames = cached[("front", action)]
            source_frames = cached[("front", action, "source")]
            root = output / species / action
            root.mkdir(parents=True)
            baseline = species_report[f"front/{action}"]["disk_bytes"]
            lossless = animated_webp_benchmark(source_frames, root / "animated-lossless.webp", True)
            q95 = animated_webp_benchmark(source_frames, root / "animated-q95.webp", False)
            delta = delta_zlib_benchmark(frames)
            for value in (lossless, q95, delta):
                value["ratio_vs_current_q95"] = round(value["bytes"] / baseline, 4)
            report["candidates"][f"{species}/front/{action}"] = {
                "current_q95": {"bytes": baseline,
                    "decoded_rgba_bytes": species_report[f"front/{action}"]["decoded_rgba_bytes"],
                    "minimum_visible_psnr_db": species_report[f"front/{action}"]["current_q95_minimum_visible_psnr_db"],
                    "mean_visible_psnr_db": species_report[f"front/{action}"]["current_q95_mean_visible_psnr_db"],
                    "alpha_exact": species_report[f"front/{action}"]["current_q95_alpha_exact"]},
                "animated_webp_lossless": lossless, "animated_webp_q95": q95, "delta_zlib_key30": delta,
            }
    if "dragonite:shiny" in catalog["entries"]:
        normal_path = Path(catalog["entries"]["dragonite:normal"]["path"])
        shiny_path = Path(catalog["entries"]["dragonite:shiny"]["path"])
        report["normal_shiny"]["dragonite"] = shiny_sharing(
            normal_path, shiny_path, json.loads(normal_path.read_text()), json.loads(shiny_path.read_text()))
    target = output / "report.json"
    target.write_text(json.dumps(report, indent=2) + "\n")
    return target


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("catalog", type=Path)
    parser.add_argument("source_catalog", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    print(run(args.catalog.resolve(), args.source_catalog.resolve(), args.output.resolve()))
