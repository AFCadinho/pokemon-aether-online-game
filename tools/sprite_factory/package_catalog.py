"""Package a reviewed sprite catalog as trimmed WebP Q95 runtime data.

This is a local, deterministic packaging boundary. It never mutates source
builds, review state, runtime defaults, or delivery configuration.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import copy
import hashlib
import json
import math
import os
import shutil
import tempfile
from pathlib import Path

from PIL import Image, ImageChops, ImageStat

QUALITY_WARNING_PSNR_DB = 40.0


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, allow_nan=False) + "\n")


def crop_rect(bounds: list[int], padding: int) -> tuple[int, int, int, int]:
    x, y, width, height = map(int, bounds)
    if width <= 0 or height <= 0:
        raise ValueError(f"Invalid visual bounds: {bounds}")
    return max(0, x - padding), max(0, y - padding), min(512, x + width + padding), min(512, y + height + padding)


def encode_page(source: Path, target: Path, page: dict, rect: tuple[int, int, int, int]) -> dict:
    if sha256(source) != page["sha256"]:
        raise ValueError(f"Page hash mismatch: {source}")
    count, columns = int(page["count"]), int(page["columns"])
    rows = math.ceil(count / columns)
    with Image.open(source) as opened:
        image = opened.convert("RGBA")
    if image.size != (columns * 512, rows * 512):
        raise ValueError(f"Unexpected atlas dimensions: {source}: {image.size}")
    x0, y0, x1, y1 = rect
    cell_width, cell_height = x1 - x0, y1 - y0
    packed = Image.new("RGBA", (columns * cell_width, rows * cell_height))
    references = []
    for index in range(count):
        x, y = (index % columns) * 512, (index // columns) * 512
        cell = image.crop((x + x0, y + y0, x + x1, y + y1))
        references.append(cell)
        packed.paste(cell, ((index % columns) * cell_width, (index // columns) * cell_height))
    target.parent.mkdir(parents=True, exist_ok=True)
    packed.save(target, "WEBP", quality=95, method=4, exact=True)
    with Image.open(target) as opened:
        decoded = opened.convert("RGBA")
    if decoded.size != packed.size or decoded.getchannel("A").tobytes() != packed.getchannel("A").tobytes():
        raise ValueError(f"WebP changed dimensions or alpha: {target}")
    squared_error = 0.0
    samples = 0
    backgrounds = ((12, 16, 28, 255), (238, 241, 247, 255), (58, 35, 91, 255))
    for index, reference in enumerate(references):
        x, y = (index % columns) * cell_width, (index // columns) * cell_height
        candidate = decoded.crop((x, y, x + cell_width, y + cell_height))
        for color in backgrounds:
            backdrop = Image.new("RGBA", reference.size, color)
            visible_reference = Image.alpha_composite(backdrop, reference).convert("RGB")
            visible_candidate = Image.alpha_composite(backdrop, candidate).convert("RGB")
            stat = ImageStat.Stat(ImageChops.difference(visible_reference, visible_candidate))
            squared_error += sum(value * value for value in stat.rms) * cell_width * cell_height
            samples += cell_width * cell_height * 3
    mse = squared_error / samples if samples else 0.0
    psnr = 99.0 if mse == 0 else 10.0 * math.log10((255.0 * 255.0) / mse)
    return {"bytes": target.stat().st_size, "rgb_psnr_db": round(psnr, 3)}


def package_catalog(catalog_path: Path, output: Path, padding: int = 4, workers: int = 4) -> Path:
    catalog_path, output = catalog_path.resolve(), output.resolve()
    catalog = json.loads(catalog_path.read_text())
    if catalog.get("schema") != 1 or catalog.get("mode") not in ("preview", "approved"):
        raise ValueError("Expected a schema-1 preview or approved catalog")
    if output.exists():
        raise ValueError(f"Output already exists: {output}")
    output.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=output.name + ".staging-", dir=output.parent))
    report = {"profile": "trimmed-webp-q95", "quality": 95, "padding": padding,
              "quality_warning_psnr_db": QUALITY_WARNING_PSNR_DB, "entries": {}, "warnings": []}
    result = copy.deepcopy(catalog)
    try:
        for key, entry in sorted(catalog["entries"].items()):
            source_manifest = Path(entry["path"]).resolve()
            if sha256(source_manifest) != entry["sha256"]:
                raise ValueError(f"Manifest hash mismatch: {key}")
            manifest = json.loads(source_manifest.read_text())
            if manifest.get("cell_size") != 512 or manifest.get("fps") != 60:
                raise ValueError(f"{key} is not 512x512/native-60-FPS")
            target_root = staging / "entries" / key.replace(":", "--")
            measurements = []
            page_jobs = []
            for view, actions in manifest["views"].items():
                for action, spec in actions.items():
                    rect = crop_rect(spec["visual_bounds"], padding)
                    spec["stored_cell_rect"] = [rect[0], rect[1], rect[2] - rect[0], rect[3] - rect[1]]
                    for page_index, page in enumerate(spec["pages"]):
                        source = source_manifest.parent / page["file"]
                        relative = Path(view) / f"{action}-{page_index:03d}.webp"
                        page_jobs.append((page, source, target_root / relative, relative, rect, view, action, page_index))
                    if action == "idle" and spec.get("preview_frame"):
                        preview = spec["preview_frame"]
                        preview_source = source_manifest.parent / preview["file"]
                        if sha256(preview_source) != preview["sha256"]:
                            raise ValueError(f"Preview hash mismatch: {preview_source}")
                        preview_target = target_root / view / "idle-preview.webp"
                        preview_target.parent.mkdir(parents=True, exist_ok=True)
                        with Image.open(preview_source) as opened:
                            opened.convert("RGBA").save(preview_target, "WEBP", quality=95, method=4, exact=True)
                        preview.update(file=f"{view}/idle-preview.webp", sha256=sha256(preview_target))
            with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
                futures = [executor.submit(encode_page, source, target, page, rect)
                           for page, source, target, _relative, rect, _view, _action, _index in page_jobs]
                for job, future in zip(page_jobs, futures):
                    page, _source, target, relative, _rect, view, action, page_index = job
                    measurement = future.result()
                    measurement.update(view=view, action=action, page=page_index)
                    measurements.append(measurement)
                    page.update(file=relative.as_posix(), sha256=sha256(target))
            manifest["runtime_packaging"] = {
                "version": 3, "format": "trimmed-webp-q95", "quality": 95,
                "trim_padding": padding, "source_sha256": entry["sha256"],
            }
            target_manifest = target_root / "manifest.json"
            write_json(target_manifest, manifest)
            result["entries"][key] = {"path": str((output / target_manifest.relative_to(staging)).resolve()), "sha256": sha256(target_manifest)}
            worst = min(measurements, key=lambda item: item["rgb_psnr_db"])
            warnings = [dict(view=item["view"], action=item["action"], page=item["page"],
                             rgb_psnr_db=item["rgb_psnr_db"])
                        for item in measurements if item["rgb_psnr_db"] < QUALITY_WARNING_PSNR_DB]
            report["entries"][key] = {
                "pages": len(measurements), "bytes": sum(x["bytes"] for x in measurements),
                "minimum_rgb_psnr_db": worst["rgb_psnr_db"],
                "worst_page": {name: worst[name] for name in ("view", "action", "page", "rgb_psnr_db")},
                "warnings": warnings,
            }
            if warnings:
                report["warnings"].append({"entry": key, "pages_below_psnr_threshold": len(warnings)})
        result["packaging"] = {"profile": "trimmed-webp-q95", "quality": 95, "trim_padding": padding}
        write_json(staging / "catalog.json", result)
        write_json(staging / "quality-report.json", report)
        os.replace(staging, output)
    except Exception:
        shutil.rmtree(staging, ignore_errors=True)
        raise
    return output / "catalog.json"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("catalog", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--padding", type=int, default=4)
    parser.add_argument("--workers", type=int, default=min(8, os.cpu_count() or 1))
    args = parser.parse_args()
    if not 0 <= args.padding <= 64:
        parser.error("--padding must be between 0 and 64")
    if args.workers < 1:
        parser.error("--workers must be positive")
    print(package_catalog(args.catalog, args.output, args.padding, args.workers))
