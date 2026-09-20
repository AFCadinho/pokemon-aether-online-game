"""Benchmark normal/shiny sharing through material IDs and compact colour LUTs.

This consumes disposable material-ID renders plus approved normal/shiny frames.
It does not alter a runtime catalog or production assets.
"""

from __future__ import annotations

import argparse
import io
import json
import math
import statistics
import time
import zlib
from collections import Counter, defaultdict
from pathlib import Path

from PIL import Image

from catalog_compaction_benchmark import frame_images, load_catalog, visible_psnr


ACTIONS = ("idle", "special_attack")
LUT_SIZE = 32


def _restore(frames: list[Image.Image], spec: dict) -> list[Image.Image]:
    x, y, width, height = map(int, spec.get("stored_cell_rect", [0, 0, 512, 512]))
    if (x, y, width, height) == (0, 0, 512, 512):
        return frames
    restored = []
    for frame in frames:
        image = Image.new("RGBA", (512, 512))
        image.paste(frame, (x, y))
        restored.append(image)
    return restored


def _material_centers(mask_paths: list[Path], expected: int) -> list[int]:
    counts = Counter()
    for path in mask_paths[:: max(1, len(mask_paths) // 12)]:
        with Image.open(path) as opened:
            image = opened.convert("RGBA")
        red, alpha = image.getchannel("R"), image.getchannel("A")
        counts.update(value for value, a in zip(red.get_flattened_data(), alpha.get_flattened_data())
                      if a == 255 and value)
    groups = []
    for value in sorted(counts):
        if not groups or value - groups[-1][-1] > 3:
            groups.append([value])
        else:
            groups[-1].append(value)
    ranked = sorted(groups, key=lambda group: sum(counts[value] for value in group), reverse=True)[:expected]
    centers = sorted(round(sum(value * counts[value] for value in group) /
                           sum(counts[value] for value in group)) for group in ranked)
    if len(centers) != expected:
        raise ValueError(f"Expected {expected} stable material IDs, found {centers}")
    return centers


def _label_mask(mask: Image.Image, centers: list[int]) -> Image.Image:
    red, alpha = mask.getchannel("R"), mask.getchannel("A")
    values = []
    for value, coverage in zip(red.get_flattened_data(), alpha.get_flattened_data()):
        if coverage < 16:
            values.append(0)
        else:
            values.append(1 + min(range(len(centers)), key=lambda index: abs(value - centers[index])))
    result = Image.new("L", mask.size)
    result.putdata(values)
    return result


def _bin(rgb: tuple[int, int, int]) -> int:
    scale = LUT_SIZE - 1
    r, g, b = (round(value * scale / 255) for value in rgb)
    return (r * LUT_SIZE + g) * LUT_SIZE + b


def _train(normal: list[Image.Image], shiny: list[Image.Image], labels: list[Image.Image], materials: int):
    sums = [defaultdict(lambda: [0, 0, 0, 0]) for _ in range(materials + 1)]
    global_sums = defaultdict(lambda: [0, 0, 0, 0])
    for normal_frame, shiny_frame, label_frame in zip(normal, shiny, labels):
        bounds = normal_frame.getchannel("A").getbbox()
        if not bounds:
            continue
        n = normal_frame.crop(bounds).get_flattened_data()
        s = shiny_frame.crop(bounds).get_flattened_data()
        m = label_frame.crop(bounds).get_flattened_data()
        for source, target, material in zip(n, s, m):
            if source[3] < 240 or target[3] < 240 or material == 0:
                continue
            index = _bin(source[:3])
            bucket = sums[material][index]
            bucket[0] += target[0]
            bucket[1] += target[1]
            bucket[2] += target[2]
            bucket[3] += 1
            bucket = global_sums[index]
            bucket[0] += target[0]
            bucket[1] += target[1]
            bucket[2] += target[2]
            bucket[3] += 1
    tables = []
    for material in range(materials + 1):
        table = []
        for r in range(LUT_SIZE):
            for g in range(LUT_SIZE):
                for b in range(LUT_SIZE):
                    index = (r * LUT_SIZE + g) * LUT_SIZE + b
                    bucket = sums[material].get(index) if material else global_sums.get(index)
                    if not bucket:
                        bucket = global_sums.get(index)
                    if bucket:
                        table.append(tuple(round(bucket[channel] / bucket[3]) for channel in range(3)))
                    else:
                        table.append(tuple(round(value * 255 / (LUT_SIZE - 1)) for value in (r, g, b)))
        tables.append(table)
    return tables


def _reconstruct(normal: Image.Image, labels: Image.Image, tables: list[list[tuple[int, int, int]]]) -> Image.Image:
    result = normal.copy()
    bounds = normal.getchannel("A").getbbox()
    if not bounds:
        return result
    source = normal.load()
    target = result.load()
    material = labels.load()
    for y in range(bounds[1], bounds[3]):
        for x in range(bounds[0], bounds[2]):
            rgba = source[x, y]
            label = material[x, y]
            if rgba[3] == 0 or label == 0:
                continue
            rgb = tables[label][_bin(rgba[:3])]
            target[x, y] = (*rgb, rgba[3])
    return result


def _encode_masks(labels: list[Image.Image], page_specs: list[dict], output: Path) -> dict:
    output.mkdir(parents=True, exist_ok=True)
    offset = 0
    formats = {"png_l8": [], "webp_lossless": []}
    timings = {name: {"encode_ms": 0.0, "decode_ms": 0.0, "bytes": 0} for name in formats}
    for page_index, page in enumerate(page_specs):
        count, columns = int(page["count"]), int(page["columns"])
        batch = labels[offset:offset + count]
        x, y, width, height = map(int, page.get("stored_cell_rect", [0, 0, 512, 512]))
        rows = math.ceil(count / columns)
        atlas = Image.new("L", (columns * width, rows * height))
        for index, frame in enumerate(batch):
            cell = frame.crop((x, y, x + width, y + height))
            atlas.paste(cell, ((index % columns) * width, (index // columns) * height))
        for name in formats:
            stream = io.BytesIO()
            started = time.perf_counter()
            if name == "png_l8":
                atlas.save(stream, "PNG", optimize=True, compress_level=9)
            else:
                atlas.save(stream, "WEBP", lossless=True, quality=100, method=4, exact=True)
            timings[name]["encode_ms"] += (time.perf_counter() - started) * 1000
            payload = stream.getvalue()
            path = output / f"{page_index:03d}-{'mask.png' if name == 'png_l8' else 'mask.webp'}"
            path.write_bytes(payload)
            formats[name].append(str(path.resolve()))
            timings[name]["bytes"] += len(payload)
            started = time.perf_counter()
            with Image.open(io.BytesIO(payload)) as opened:
                opened.load()
            timings[name]["decode_ms"] += (time.perf_counter() - started) * 1000
        offset += count
    for name, paths in formats.items():
        timings[name].update({
            "files": paths,
            "encode_ms": round(timings[name]["encode_ms"], 2),
            "decode_ms": round(timings[name]["decode_ms"], 2),
        })
    return timings


def run(packaged_catalog: Path, source_catalog: Path, mask_root: Path, mask_report: Path, output: Path) -> Path:
    packaged, source = load_catalog(packaged_catalog), load_catalog(source_catalog)
    normal_path = Path(packaged["entries"]["dragonite:normal"]["path"])
    shiny_path = Path(packaged["entries"]["dragonite:shiny"]["path"])
    source_normal_path = Path(source["entries"]["dragonite:normal"]["path"])
    source_shiny_path = Path(source["entries"]["dragonite:shiny"]["path"])
    normal_manifest = json.loads(normal_path.read_text())
    shiny_manifest = json.loads(shiny_path.read_text())
    source_normal = json.loads(source_normal_path.read_text())
    source_shiny = json.loads(source_shiny_path.read_text())
    material_ids = json.loads(mask_report.read_text())["material_ids"]
    output.mkdir(parents=True, exist_ok=False)
    report = {"schema": 1, "candidate": f"normal Q95 + L8 material mask + per-material {LUT_SIZE}^3 RGB LUT", "actions": {}}
    for action in ACTIONS:
        normal_spec = normal_manifest["views"]["front"][action]
        shiny_spec = shiny_manifest["views"]["front"][action]
        normal_frames = _restore(frame_images(normal_path, normal_spec), normal_spec)
        shiny_q95 = _restore(frame_images(shiny_path, shiny_spec), shiny_spec)
        shiny_source = frame_images(source_shiny_path, source_shiny["views"]["front"][action])
        normal_source = frame_images(source_normal_path, source_normal["views"]["front"][action])
        mask_paths = sorted((mask_root / "front" / action).glob("*.png"))
        if len(mask_paths) != len(normal_frames):
            raise ValueError(f"Mask count mismatch for {action}")
        centers = _material_centers(mask_paths, len(material_ids))
        labels = []
        for path in mask_paths:
            with Image.open(path) as opened:
                labels.append(_label_mask(opened.convert("RGBA"), centers))
        started = time.perf_counter()
        tables = _train(normal_frames, shiny_source, labels, len(material_ids))
        train_ms = (time.perf_counter() - started) * 1000
        lut_raw = bytes(channel for table in tables[1:] for rgb in table for channel in rgb)
        reconstructed = []
        started = time.perf_counter()
        for normal_frame, label_frame in zip(normal_frames, labels):
            reconstructed.append(_reconstruct(normal_frame, label_frame, tables))
        reconstruct_ms = (time.perf_counter() - started) * 1000
        proposed_psnr = [visible_psnr(a, b) for a, b in zip(shiny_source, reconstructed)]
        baseline_psnr = [visible_psnr(a, b) for a, b in zip(shiny_source, shiny_q95)]
        alpha_pair_psnr = [visible_psnr(a, b) for a, b in zip(normal_source, shiny_source)]
        encodings = _encode_masks(labels, [{**page, "stored_cell_rect": normal_spec["stored_cell_rect"]}
                                            for page in normal_spec["pages"]], output / action)
        normal_bytes = sum((normal_path.parent / page["file"]).stat().st_size for page in normal_spec["pages"])
        shiny_bytes = sum((shiny_path.parent / page["file"]).stat().st_size for page in shiny_spec["pages"])
        proposed_bytes = encodings["png_l8"]["bytes"] + len(zlib.compress(lut_raw, 9))
        report["actions"][action] = {
            "frames": len(normal_frames),
            "material_ids": material_ids,
            "rendered_id_centers": centers,
            "current_normal_q95_bytes": normal_bytes,
            "current_shiny_q95_bytes": shiny_bytes,
            "mask_encodings": encodings,
            "lut_raw_bytes": len(lut_raw),
            "lut_zlib_bytes": len(zlib.compress(lut_raw, 9)),
            "incremental_variant_bytes": proposed_bytes,
            "incremental_ratio_vs_shiny_q95": round(proposed_bytes / shiny_bytes, 4),
            "normal_plus_variant_ratio_vs_two_full_variants": round((normal_bytes + proposed_bytes) / (normal_bytes + shiny_bytes), 4),
            "train_ms": round(train_ms, 2),
            "cpu_reconstruct_all_ms": round(reconstruct_ms, 2),
            "cpu_reconstruct_per_frame_ms": round(reconstruct_ms / len(normal_frames), 3),
            "baseline_q95_min_psnr_db": round(min(baseline_psnr), 3),
            "baseline_q95_mean_psnr_db": round(statistics.mean(baseline_psnr), 3),
            "candidate_min_psnr_db": round(min(proposed_psnr), 3),
            "candidate_mean_psnr_db": round(statistics.mean(proposed_psnr), 3),
            "normal_shiny_geometry_min_psnr_db": round(min(alpha_pair_psnr), 3),
            "alpha_exact_to_shiny_frames": sum(a.getchannel("A").tobytes() == b.getchannel("A").tobytes()
                                                 for a, b in zip(normal_frames, shiny_source)),
            "mask_decoded_l8_bytes": sum(
                int(page["columns"]) * int(normal_spec["stored_cell_rect"][2])
                * math.ceil(int(page["count"]) / int(page["columns"])) * int(normal_spec["stored_cell_rect"][3])
                for page in normal_spec["pages"]
            ),
        }
        reconstructed[len(reconstructed) // 2].save(output / action / "candidate-mid.png")
        shiny_source[len(shiny_source) // 2].save(output / action / "reference-mid.png")
    result = output / "report.json"
    result.write_text(json.dumps(report, indent=2) + "\n")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("packaged_catalog", type=Path)
    parser.add_argument("source_catalog", type=Path)
    parser.add_argument("mask_root", type=Path)
    parser.add_argument("mask_report", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    print(run(*(value.resolve() for value in vars(args).values())))
