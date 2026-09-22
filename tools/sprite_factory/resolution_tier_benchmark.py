"""Benchmark 384 px WebP tiers against the approved 512 px/60 FPS catalog.

The tool is deliberately non-production: it writes disposable atlases, visual
comparison sheets and a Godot runtime-benchmark config without changing the
catalog or runtime loader.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import statistics
import time
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageStat

from catalog_compaction_benchmark import frame_images, load_catalog

SPECIES = ("dragonite", "roaring-moon", "jigglypuff", "diglett")
QUALITIES = (95, 90)
SOURCE_SIZE = 512
TARGET_SIZE = 384
RATIO = TARGET_SIZE / SOURCE_SIZE
FPS = 60
BACKGROUNDS = ((12, 16, 28, 255), (238, 241, 247, 255), (58, 35, 91, 255))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _scaled_rect(bounds: list[int], padding: int = 3) -> tuple[int, int, int, int]:
    x, y, width, height = map(int, bounds)
    return (
        max(0, math.floor(x * RATIO) - padding),
        max(0, math.floor(y * RATIO) - padding),
        min(TARGET_SIZE, math.ceil((x + width) * RATIO) + padding),
        min(TARGET_SIZE, math.ceil((y + height) * RATIO) + padding),
    )


def _pack(frames: list[Image.Image], columns: int, rect: tuple[int, int, int, int]) -> Image.Image:
    x0, y0, x1, y1 = rect
    width, height = x1 - x0, y1 - y0
    rows = math.ceil(len(frames) / columns)
    atlas = Image.new("RGBA", (columns * width, rows * height))
    for index, frame in enumerate(frames):
        atlas.paste(frame.crop(rect), ((index % columns) * width, (index // columns) * height))
    return atlas


def _restore(atlas: Image.Image, count: int, columns: int, rect: tuple[int, int, int, int]) -> list[Image.Image]:
    x0, y0, x1, y1 = rect
    width, height = x1 - x0, y1 - y0
    result = []
    for index in range(count):
        cell = atlas.crop(((index % columns) * width, (index // columns) * height,
                           (index % columns + 1) * width, (index // columns + 1) * height))
        frame = Image.new("RGBA", (TARGET_SIZE, TARGET_SIZE))
        frame.paste(cell, (x0, y0))
        result.append(frame)
    return result


def _portrait_rect(bounds: tuple[float, float, float, float]) -> tuple[float, float, float, float]:
    x, y, width, height = bounds
    target_aspect = 170.0 / 112.0
    aspect = width / max(height, 1.0)
    if aspect > target_aspect:
        crop_height = width / target_aspect
        return x, y + (height - crop_height) * 0.5, width, crop_height
    crop_width = height * target_aspect
    return x + (width - crop_width) * 0.5, y, crop_width, height


def _context_crop_and_size(bounds: list[int], render_scale: float, context: str) -> tuple[tuple[float, float, float, float], tuple[int, int]]:
    rect = tuple(map(float, bounds))
    _x, _y, width, height = rect
    if context == "battle":
        scale = 2.0 * 0.85 * 1.3 / render_scale
        return rect, (max(1, round(width * scale)), max(1, round(height * scale)))
    if context.startswith("summary"):
        fit = min(235.0 / max(width / render_scale, 1.0), 155.0 / max(height / render_scale, 1.0))
        texture_scale = min(1.7 * 1.3, fit) / render_scale
        zoom = 2.0 if context.endswith("zoom") else 1.0
        return rect, (max(1, round(width * texture_scale * zoom)), max(1, round(height * texture_scale * zoom)))
    portrait = _portrait_rect(rect)
    zoom = 2.0 if context.endswith("zoom") else 1.0
    return portrait, (max(1, round(170 * zoom)), max(1, round(112 * zoom)))


def render_context(frame: Image.Image, bounds: list[int], render_scale: float, context: str) -> Image.Image:
    crop, output_size = _context_crop_and_size(bounds, render_scale, context)
    source_scale = frame.width / SOURCE_SIZE
    x, y, width, height = crop
    box = (round(x * source_scale), round(y * source_scale),
           round((x + width) * source_scale), round((y + height) * source_scale))
    box = (max(0, box[0]), max(0, box[1]), min(frame.width, box[2]), min(frame.height, box[3]))
    return frame.crop(box).resize(output_size, Image.Resampling.BILINEAR)


def visible_psnr(reference: Image.Image, candidate: Image.Image) -> tuple[float, int]:
    squared_error = 0.0
    samples = 0
    maximum = 0
    for color in BACKGROUNDS:
        background = Image.new("RGBA", reference.size, color)
        left = Image.alpha_composite(background, reference).convert("RGB")
        right = Image.alpha_composite(background, candidate).convert("RGB")
        difference = ImageChops.difference(left, right)
        stat = ImageStat.Stat(difference)
        squared_error += sum(value * value for value in stat.rms) * reference.width * reference.height
        samples += reference.width * reference.height * 3
        maximum = max(maximum, *(channel[1] for channel in difference.getextrema()))
    mse = squared_error / samples if samples else 0.0
    return (99.0 if mse == 0 else 10.0 * math.log10(65025.0 / mse), maximum)


def _sample_indices(count: int, samples: int = 6) -> set[int]:
    if count <= samples:
        return set(range(count))
    return {round(index * (count - 1) / (samples - 1)) for index in range(samples)}


def _sheet(rows: list[tuple[str, Image.Image, Image.Image, Image.Image]], target: Path) -> None:
    if not rows:
        return
    width = 760
    row_height = 190
    sheet = Image.new("RGB", (width, 34 + row_height * len(rows)), (34, 38, 52))
    draw = ImageDraw.Draw(sheet)
    draw.text((10, 10), "512 lossless reference   384 Q95                 384 Q90", fill="white")
    for row, (label, baseline, q95, q90) in enumerate(rows):
        top = 34 + row * row_height
        draw.text((10, top + 4), label, fill="white")
        for column, image in enumerate((baseline, q95, q90)):
            preview = Image.new("RGBA", (220, 155), (12, 16, 28, 255))
            scale = min(210 / image.width, 145 / image.height, 1.0)
            shown = image.resize((max(1, round(image.width * scale)), max(1, round(image.height * scale))), Image.Resampling.BILINEAR)
            preview.alpha_composite(shown, ((220 - shown.width) // 2, (155 - shown.height) // 2))
            sheet.paste(preview.convert("RGB"), (10 + column * 245, top + 27))
    target.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(target, "PNG")


def run(catalog_path: Path, source_catalog_path: Path, output: Path) -> Path:
    catalog = load_catalog(catalog_path)
    source_catalog = load_catalog(source_catalog_path)
    if output.exists():
        raise ValueError(f"Output already exists: {output}")
    output.mkdir(parents=True)
    report = {
        "schema": 1, "source_resolution": [512, 512], "candidate_resolution": [384, 384],
        "fps": FPS, "qualities": list(QUALITIES), "production_changed": False,
        "species": {}, "totals": {}, "quality_by_context": {},
    }
    runtime_candidates = {"512-q95": [], "384-q95": [], "384-q90": []}
    playback = {}
    contexts = ("battle", "summary", "summary_zoom", "pokedex", "pokedex_zoom")
    quality_values = {quality: {context: [] for context in contexts} for quality in QUALITIES}
    comparison_rows = []
    encode_started = time.perf_counter()
    for species in SPECIES:
        key = f"{species}:normal"
        packaged_manifest_path = Path(catalog["entries"][key]["path"])
        source_manifest_path = Path(source_catalog["entries"][key]["path"])
        packaged = json.loads(packaged_manifest_path.read_text())
        source = json.loads(source_manifest_path.read_text())
        species_report = {}
        for view, actions in source["views"].items():
            present = source["presentation"][view]
            for action, source_spec in actions.items():
                packaged_spec = packaged["views"][view][action]
                source_frames = frame_images(source_manifest_path, source_spec)
                resized = [frame.resize((TARGET_SIZE, TARGET_SIZE), Image.Resampling.LANCZOS) for frame in source_frames]
                rect = _scaled_rect(source_spec["visual_bounds"])
                action_key = f"{view}/{action}"
                baseline_files = [str((packaged_manifest_path.parent / page["file"]).resolve()) for page in packaged_spec["pages"]]
                baseline_bytes = sum(Path(path).stat().st_size for path in baseline_files)
                runtime_candidates["512-q95"].append({"label": f"{species}/{action_key}", "files": baseline_files})
                action_report = {"frames": len(source_frames), "duration_seconds": round(len(source_frames) / FPS, 3),
                                 "512_q95_bytes": baseline_bytes, "candidates": {}}
                decoded_by_quality: dict[int, list[Image.Image]] = {quality: [] for quality in QUALITIES}
                for quality in QUALITIES:
                    quality_root = output / f"384-q{quality}" / species / view
                    quality_root.mkdir(parents=True, exist_ok=True)
                    files = []
                    total_bytes = 0
                    decode_ms = 0.0
                    decoded_rgba_bytes = 0
                    alpha_exact = True
                    cursor = 0
                    for page_index, source_page in enumerate(source_spec["pages"]):
                        count = int(source_page["count"])
                        columns = int(source_page["columns"])
                        page_frames = resized[cursor:cursor + count]
                        packed_page = _pack(page_frames, columns, rect)
                        target = quality_root / f"{action}-{page_index:03d}.webp"
                        packed_page.save(target, "WEBP", quality=quality, method=4, exact=True)
                        started = time.perf_counter()
                        with Image.open(target) as opened:
                            decoded_atlas = opened.convert("RGBA")
                        decode_ms += (time.perf_counter() - started) * 1000
                        decoded_rgba_bytes += decoded_atlas.width * decoded_atlas.height * 4
                        restored = _restore(decoded_atlas, count, columns, rect)
                        alpha_exact = alpha_exact and all(
                            left.getchannel("A").tobytes() == right.getchannel("A").tobytes()
                            for left, right in zip(page_frames, restored)
                        )
                        decoded_by_quality[quality].extend(restored)
                        files.append(str(target.resolve()))
                        total_bytes += target.stat().st_size
                        cursor += count
                    runtime_candidates[f"384-q{quality}"].append({"label": f"{species}/{action_key}", "files": files})
                    action_report["candidates"][f"384-q{quality}"] = {
                        "bytes": total_bytes, "ratio_vs_512_q95": round(total_bytes / baseline_bytes, 4),
                        "decode_all_pages_ms_pillow": round(decode_ms, 3), "alpha_exact_after_resize": alpha_exact,
                        "stored_cell_rect": [rect[0], rect[1], rect[2] - rect[0], rect[3] - rect[1]],
                        "decoded_rgba_bytes": decoded_rgba_bytes,
                    }
                for index in sorted(_sample_indices(len(source_frames))):
                    for context in contexts:
                        reference = render_context(source_frames[index], source_spec["visual_bounds"], float(present["render_scale"]), context)
                        for quality in QUALITIES:
                            candidate = render_context(decoded_by_quality[quality][index], source_spec["visual_bounds"], float(present["render_scale"]), context)
                            psnr, maximum = visible_psnr(reference, candidate)
                            quality_values[quality][context].append((psnr, maximum, species, action_key, index))
                if view == "front" and action == "idle":
                    mid = len(source_frames) // 2
                    comparison_rows.append((species,
                        render_context(source_frames[mid], source_spec["visual_bounds"], float(present["render_scale"]), "summary_zoom"),
                        render_context(decoded_by_quality[95][mid], source_spec["visual_bounds"], float(present["render_scale"]), "summary_zoom"),
                        render_context(decoded_by_quality[90][mid], source_spec["visual_bounds"], float(present["render_scale"]), "summary_zoom")))
                    if species == "dragonite":
                        for label in ("512-q95", "384-q95", "384-q90"):
                            spec = packaged_spec if label == "512-q95" else action_report["candidates"][label]
                            files = baseline_files if label == "512-q95" else runtime_candidates[label][-1]["files"]
                            cell = packaged_spec["stored_cell_rect"] if label == "512-q95" else spec["stored_cell_rect"]
                            playback[label] = {"files": files, "frame_count": len(source_frames),
                                               "frames_per_page": 8, "columns": 4,
                                               "cell_width": int(cell[2]), "cell_height": int(cell[3])}
                species_report[action_key] = action_report
        report["species"][species] = species_report
    report["encode_wall_seconds"] = round(time.perf_counter() - encode_started, 2)
    baseline_total = sum(item["512_q95_bytes"] for species in report["species"].values() for item in species.values())
    report["totals"]["512-q95"] = {"bytes": baseline_total, "ratio": 1.0}
    for quality in QUALITIES:
        label = f"384-q{quality}"
        total = sum(item["candidates"][label]["bytes"] for species in report["species"].values() for item in species.values())
        ratio = total / baseline_total
        report["totals"][label] = {"bytes": total, "ratio": round(ratio, 4),
                                     "projected_full_catalog_gib_from_39_1": round(39.1 * ratio, 2)}
        report["quality_by_context"][label] = {}
        for context, values in quality_values[quality].items():
            worst = min(values, key=lambda value: value[0])
            report["quality_by_context"][label][context] = {
                "samples": len(values), "minimum_psnr_db": round(worst[0], 3),
                "mean_psnr_db": round(statistics.mean(value[0] for value in values), 3),
                "maximum_channel_delta": max(value[1] for value in values),
                "worst_sample": {"species": worst[2], "action": worst[3], "frame": worst[4]},
            }
    runtime_config = {"candidates": [], "result": str((output / "godot-runtime.json").resolve())}
    for label, groups in runtime_candidates.items():
        runtime_config["candidates"].append({"label": label, "kind": "webp", "groups": groups, "playback": playback[label]})
    (output / "runtime-config.json").write_text(json.dumps(runtime_config, indent=2) + "\n")
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    _sheet(comparison_rows, output / "summary-zoom-comparison.png")
    return output / "report.json"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("catalog", type=Path, help="Current packaged 512 Q95 catalog")
    parser.add_argument("source_catalog", type=Path, help="Approved lossless 512 source catalog")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    print(run(args.catalog, args.source_catalog, args.output))
