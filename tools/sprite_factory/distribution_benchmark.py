"""Benchmark lossless distribution formats for rendered Pokémon atlases.

The tool never changes a Sprite Factory build, review state, or runtime catalog.
It reads existing 512 px/60 FPS runtime manifests and writes disposable benchmark
artifacts beneath --output.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import math
import os
import shutil
import statistics
import time
from collections import defaultdict
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont


ACTIONS = (
    "idle",
    "physical_attack",
    "special_attack",
    "damage",
    "sleep",
    "faint_start",
    "faint_loop",
)
BACKGROUNDS = {
    "dark": (12, 16, 28, 255),
    "light": (238, 241, 247, 255),
    "colored": (58, 35, 91, 255),
}


def _load_catalog(path: Path, species: tuple[str, ...]) -> list[tuple[str, Path]]:
    payload = json.loads(path.read_text())
    entries = payload.get("entries", {})
    selected = []
    for name in species:
        entry = entries.get(f"{name}:normal")
        if not entry:
            raise ValueError(f"Catalog has no normal build for {name}")
        manifest = Path(entry["path"]).resolve()
        if not manifest.is_file():
            raise ValueError(f"Missing runtime manifest for {name}: {manifest}")
        selected.append((name, manifest))
    return selected


def _page_records(selected: list[tuple[str, Path]], padding: int) -> list[dict]:
    records = []
    for species, manifest_path in selected:
        manifest = json.loads(manifest_path.read_text())
        if manifest.get("cell_size") != 512 or manifest.get("fps") != 60:
            raise ValueError(f"{species} is not a 512 px/native-60-FPS build")
        root = manifest_path.parent
        for view in ("front", "back"):
            actions = manifest["views"][view]
            for action in ACTIONS:
                data = actions[action]
                x, y, width, height = map(int, data["visual_bounds"])
                x0 = max(0, x - padding)
                y0 = max(0, y - padding)
                x1 = min(512, x + width + padding)
                y1 = min(512, y + height + padding)
                crop = [x0, y0, x1, y1]
                for page_index, page in enumerate(data["pages"]):
                    source = (root / page["file"]).resolve()
                    if not source.is_file():
                        raise ValueError(f"Missing atlas page: {source}")
                    records.append({
                        "species": species,
                        "view": view,
                        "action": action,
                        "page_index": page_index,
                        "source": str(source),
                        "source_file": page["file"],
                        "count": int(page["count"]),
                        "columns": int(page["columns"]),
                        "crop": crop,
                    })
    return records


def _relative(record: dict, extension: str) -> Path:
    return Path(record["species"], record["view"], record["action"], f"{record['page_index']:03d}.{extension}")


def _save_webp(image: Image.Image, path: Path, lossless: bool) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(
        path,
        "WEBP",
        lossless=lossless,
        quality=100 if lossless else 95,
        method=4,
        exact=True,
    )


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _link_or_copy(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    target.unlink(missing_ok=True)
    try:
        os.link(source, target)
    except OSError:
        shutil.copy2(source, target)


def _write_review_catalog(args) -> Path:
    """Build an opt-in runtime catalog from the existing trimmed Q95 output."""
    output = args.output.resolve()
    selected = _load_catalog(args.catalog.resolve(), tuple(args.species))
    review_root = output / "game-review-trimmed-webp-q95"
    entries = {}
    for species, source_manifest_path in selected:
        manifest = json.loads(source_manifest_path.read_text())
        source_root = source_manifest_path.parent
        species_root = review_root / species
        for view in ("front", "back"):
            for action in ACTIONS:
                action_data = manifest["views"][view][action]
                x, y, width, height = map(int, action_data["visual_bounds"])
                x0 = max(0, x - args.padding)
                y0 = max(0, y - args.padding)
                x1 = min(512, x + width + args.padding)
                y1 = min(512, y + height + args.padding)
                action_data["stored_cell_rect"] = [x0, y0, x1 - x0, y1 - y0]
                for page_index, page in enumerate(action_data["pages"]):
                    source = output / "trimmed-webp-q95" / species / view / action / f"{page_index:03d}.webp"
                    if not source.is_file():
                        raise ValueError(f"Missing trimmed Q95 page; run the benchmark first: {source}")
                    relative = Path(view) / f"{action}-{page_index:03d}.webp"
                    target = species_root / relative
                    _link_or_copy(source, target)
                    page["file"] = relative.as_posix()
                    page["sha256"] = _sha256(target)

            preview = manifest["views"][view]["idle"].get("preview_frame", {})
            preview_source = source_root / preview.get("file", "")
            if not preview_source.is_file():
                raise ValueError(f"Missing preview frame: {preview_source}")
            preview_target = species_root / view / "idle-preview.webp"
            with Image.open(preview_source) as opened:
                _save_webp(opened.convert("RGBA"), preview_target, False)
            preview["file"] = f"{view}/idle-preview.webp"
            preview["sha256"] = _sha256(preview_target)

        manifest["runtime_packaging"] = {
            "version": 2,
            "format": "trimmed-webp-q95",
            "quality": 95,
            "trim_padding": args.padding,
            "review_only": True,
            "source_manifest": str(source_manifest_path),
            "source_sha256": _sha256(source_manifest_path),
        }
        target_manifest = species_root / "manifest.json"
        target_manifest.parent.mkdir(parents=True, exist_ok=True)
        target_manifest.write_text(json.dumps(manifest, indent=2) + "\n")
        entries[f"{species}:normal"] = {
            "path": str(target_manifest.resolve()),
            "sha256": _sha256(target_manifest),
        }

    catalog_path = review_root / "preview-catalog.json"
    catalog_path.parent.mkdir(parents=True, exist_ok=True)
    catalog_path.write_text(json.dumps({"schema": 1, "mode": "preview", "entries": entries}, indent=2) + "\n")
    print(catalog_path)
    return catalog_path


def _trim_page(image: Image.Image, record: dict) -> Image.Image:
    x0, y0, x1, y1 = record["crop"]
    cell_width = x1 - x0
    cell_height = y1 - y0
    columns = record["columns"]
    rows = math.ceil(record["count"] / columns)
    trimmed = Image.new("RGBA", (columns * cell_width, rows * cell_height))
    for index in range(record["count"]):
        source_x = (index % columns) * 512 + x0
        source_y = (index // columns) * 512 + y0
        cell = image.crop((source_x, source_y, source_x + cell_width, source_y + cell_height))
        trimmed.paste(cell, ((index % columns) * cell_width, (index // columns) * cell_height))
    return trimmed


def _restore_trimmed(image: Image.Image, record: dict, source_size: tuple[int, int]) -> Image.Image:
    restored = Image.new("RGBA", source_size)
    x0, y0, x1, y1 = record["crop"]
    cell_width = x1 - x0
    cell_height = y1 - y0
    columns = record["columns"]
    for index in range(record["count"]):
        source_x = (index % columns) * cell_width
        source_y = (index // columns) * cell_height
        cell = image.crop((source_x, source_y, source_x + cell_width, source_y + cell_height))
        restored.paste(cell, ((index % columns) * 512 + x0, (index // columns) * 512 + y0))
    return restored


def _quality(reference: Image.Image, candidate: Image.Image) -> dict:
    alpha_diff = ImageChops.difference(reference.getchannel("A"), candidate.getchannel("A"))
    alpha_extrema = alpha_diff.getextrema()
    result = {
        "alpha_max_delta": alpha_extrema[1],
        "backgrounds": {},
    }
    for label, color in BACKGROUNDS.items():
        background = Image.new("RGBA", reference.size, color)
        left = Image.alpha_composite(background, reference).convert("RGB")
        right = Image.alpha_composite(background, candidate).convert("RGB")
        diff = ImageChops.difference(left, right)
        histogram = diff.histogram()
        samples = reference.width * reference.height * 3
        squared_error = sum((index % 256) ** 2 * count for index, count in enumerate(histogram))
        maximum = max(channel[1] for channel in diff.getextrema())
        result["backgrounds"][label] = {
            "squared_error": squared_error,
            "samples": samples,
            "max_delta": maximum,
        }
    return result


def _encode_record(args: tuple[dict, str]) -> dict:
    record, output_text = args
    output = Path(output_text)
    source = Path(record["source"])
    started = time.perf_counter()
    with Image.open(source) as opened:
        original = opened.convert("RGBA")
    trimmed = _trim_page(original, record)
    paths = {
        "trimmed_png": output / "trimmed-png" / _relative(record, "png"),
        "webp_lossless": output / "webp-lossless" / _relative(record, "webp"),
        "webp_q95": output / "webp-q95" / _relative(record, "webp"),
        "trimmed_webp_lossless": output / "trimmed-webp-lossless" / _relative(record, "webp"),
        "trimmed_webp_q95": output / "trimmed-webp-q95" / _relative(record, "webp"),
    }
    paths["trimmed_png"].parent.mkdir(parents=True, exist_ok=True)
    trimmed.save(paths["trimmed_png"], "PNG", compress_level=9)
    _save_webp(original, paths["webp_lossless"], True)
    _save_webp(original, paths["webp_q95"], False)
    _save_webp(trimmed, paths["trimmed_webp_lossless"], True)
    _save_webp(trimmed, paths["trimmed_webp_q95"], False)

    sizes = {"png_baseline": source.stat().st_size}
    sizes.update({label: path.stat().st_size for label, path in paths.items()})
    dimensions = {
        "png_baseline": list(original.size),
        "webp_lossless": list(original.size),
        "webp_q95": list(original.size),
        "trimmed_png": list(trimmed.size),
        "trimmed_webp_lossless": list(trimmed.size),
        "trimmed_webp_q95": list(trimmed.size),
    }
    quality = {}
    if record["page_index"] == 0:
        for label in ("webp_lossless", "webp_q95", "trimmed_png", "trimmed_webp_lossless", "trimmed_webp_q95"):
            with Image.open(paths[label]) as opened:
                decoded = opened.convert("RGBA")
            if label.startswith("trimmed_"):
                decoded = _restore_trimmed(decoded, record, original.size)
            quality[label] = _quality(original, decoded)

    hashes = []
    for index in range(record["count"]):
        x = (index % record["columns"]) * 512
        y = (index // record["columns"]) * 512
        hashes.append(hashlib.sha256(original.crop((x, y, x + 512, y + 512)).tobytes()).hexdigest())
    return {
        "key": [record["species"], record["view"], record["action"], record["page_index"]],
        "paths": {label: str(path.resolve()) for label, path in paths.items()},
        "sizes": sizes,
        "dimensions": dimensions,
        "quality": quality,
        "frame_hashes": hashes,
        "elapsed_seconds": time.perf_counter() - started,
    }


def _aggregate(records: list[dict], encoded: list[dict]) -> dict:
    totals = defaultdict(lambda: defaultdict(lambda: defaultdict(int)))
    decoded = defaultdict(lambda: defaultdict(lambda: defaultdict(int)))
    quality = defaultdict(lambda: {
        "alpha_max_delta": 0,
        "backgrounds": {label: {"squared_error": 0, "samples": 0, "max_delta": 0} for label in BACKGROUNDS},
    })
    hashes = defaultdict(list)
    by_key = {tuple(item["key"]): item for item in encoded}
    for record in records:
        key = (record["species"], record["view"], record["action"], record["page_index"])
        item = by_key[key]
        group = f"{record['view']}/{record['action']}"
        for candidate, size in item["sizes"].items():
            totals[candidate][record["species"]][group] += size
            width, height = item["dimensions"][candidate]
            decoded[candidate][record["species"]][group] += width * height * 4
        for candidate, candidate_quality in item["quality"].items():
            target = quality[candidate]
            target["alpha_max_delta"] = max(target["alpha_max_delta"], candidate_quality["alpha_max_delta"])
            for background, metrics in candidate_quality["backgrounds"].items():
                aggregate = target["backgrounds"][background]
                aggregate["squared_error"] += metrics["squared_error"]
                aggregate["samples"] += metrics["samples"]
                aggregate["max_delta"] = max(aggregate["max_delta"], metrics["max_delta"])
        hashes[record["species"]].extend(item["frame_hashes"])

    candidates = {}
    for candidate, species_groups in totals.items():
        candidates[candidate] = {"species": {}, "total_bytes": 0, "decoded_rgba_bytes": 0}
        for species, groups in species_groups.items():
            size = sum(groups.values())
            rgba = sum(decoded[candidate][species].values())
            candidates[candidate]["species"][species] = {
                "bytes": size,
                "decoded_rgba_bytes": rgba,
                "actions": dict(sorted(groups.items())),
            }
            candidates[candidate]["total_bytes"] += size
            candidates[candidate]["decoded_rgba_bytes"] += rgba
    quality_summary = {}
    for candidate, candidate_quality in quality.items():
        quality_summary[candidate] = {"alpha_max_delta": candidate_quality["alpha_max_delta"], "backgrounds": {}}
        for background, metrics in candidate_quality["backgrounds"].items():
            mse = metrics["squared_error"] / max(1, metrics["samples"])
            psnr = None if mse == 0 else 10 * math.log10((255 * 255) / mse)
            quality_summary[candidate]["backgrounds"][background] = {
                "psnr_db": psnr,
                "max_delta": metrics["max_delta"],
            }
    duplicate_summary = {}
    for species, values in hashes.items():
        unique = len(set(values))
        duplicate_summary[species] = {
            "frames": len(values),
            "unique_exact_rgba_frames": unique,
            "duplicate_frames": len(values) - unique,
            "maximum_exact_dedup_ratio": len(values) / unique,
        }
    return {
        "candidates": candidates,
        "quality": quality_summary,
        "exact_frame_deduplication": duplicate_summary,
    }


def _font(size: int):
    for path in ("/usr/share/fonts/TTF/DejaVuSans.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        if Path(path).is_file():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def _preview(records: list[dict], encoded: list[dict], output: Path) -> Path:
    lookup = {tuple(item["key"]): item for item in encoded}
    chosen = [record for record in records if record["view"] == "front" and record["action"] == "idle" and record["page_index"] == 0]
    candidates = ("png_baseline", "webp_lossless", "webp_q95", "trimmed_png", "trimmed_webp_lossless", "trimmed_webp_q95")
    cell = 224
    label_height = 28
    header = 42
    rows = [(record, background) for record in chosen for background in BACKGROUNDS]
    sheet = Image.new("RGB", (len(candidates) * cell, header + len(rows) * (cell + label_height)), (28, 31, 43))
    draw = ImageDraw.Draw(sheet)
    font = _font(15)
    small = _font(13)
    for column, candidate in enumerate(candidates):
        draw.text((column * cell + 8, 12), candidate.replace("_", " "), fill=(240, 242, 248), font=small)
    for row, (record, background_label) in enumerate(rows):
        item = lookup[(record["species"], record["view"], record["action"], record["page_index"])]
        for column, candidate in enumerate(candidates):
            if candidate == "png_baseline":
                path = Path(record["source"])
            else:
                path = Path(item["paths"][candidate])
            with Image.open(path) as opened:
                atlas = opened.convert("RGBA")
            if candidate.startswith("trimmed_"):
                atlas = _restore_trimmed(atlas, record, (record["columns"] * 512, math.ceil(record["count"] / record["columns"]) * 512))
            frame = atlas.crop((0, 0, 512, 512)).resize((cell, cell), Image.Resampling.LANCZOS)
            background = Image.new("RGBA", (cell, cell), BACKGROUNDS[background_label])
            composite = Image.alpha_composite(background, frame).convert("RGB")
            y = header + row * (cell + label_height)
            sheet.paste(composite, (column * cell, y))
            draw.text((column * cell + 8, y + cell + 5), f"{record['species']} / {background_label}", fill=(240, 242, 248), font=font)
    target = output / "visual-comparison.png"
    sheet.save(target, "PNG", compress_level=9)
    return target


def _refresh_preview(args) -> None:
    output = args.output.resolve()
    selected = _load_catalog(args.catalog.resolve(), tuple(args.species))
    records = _page_records(selected, args.padding)
    encoded = []
    for record in records:
        paths = {
            "trimmed_png": output / "trimmed-png" / _relative(record, "png"),
            "webp_lossless": output / "webp-lossless" / _relative(record, "webp"),
            "webp_q95": output / "webp-q95" / _relative(record, "webp"),
            "trimmed_webp_lossless": output / "trimmed-webp-lossless" / _relative(record, "webp"),
            "trimmed_webp_q95": output / "trimmed-webp-q95" / _relative(record, "webp"),
        }
        encoded.append({
            "key": [record["species"], record["view"], record["action"], record["page_index"]],
            "paths": {label: str(path.resolve()) for label, path in paths.items()},
        })
    print(_preview(records, encoded, output))


def build(args) -> None:
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    selected = _load_catalog(args.catalog.resolve(), tuple(args.species))
    records = _page_records(selected, args.padding)
    started = time.perf_counter()
    jobs = [(record, str(output)) for record in records]
    encoded = []
    with concurrent.futures.ProcessPoolExecutor(max_workers=args.workers) as executor:
        for index, item in enumerate(executor.map(_encode_record, jobs), 1):
            encoded.append(item)
            if index % 50 == 0 or index == len(records):
                print(f"encoded {index}/{len(records)} atlas pages", flush=True)
    summary = _aggregate(records, encoded)
    baseline = summary["candidates"]["png_baseline"]["total_bytes"]
    for candidate in summary["candidates"].values():
        candidate["disk_reduction_vs_png"] = baseline / candidate["total_bytes"]
        candidate["rgba_reduction_vs_png"] = summary["candidates"]["png_baseline"]["decoded_rgba_bytes"] / candidate["decoded_rgba_bytes"]
        candidate["estimated_runtime_vram_bytes"] = candidate["decoded_rgba_bytes"]
        candidate["hypothetical_block_compressed_vram_bytes"] = candidate["decoded_rgba_bytes"] // 4
    preview = _preview(records, encoded, output)
    godot_jobs = []
    for record in records:
        item = next(value for value in encoded if tuple(value["key"]) == (record["species"], record["view"], record["action"], record["page_index"]))
        relative = _relative(record, "res")
        godot_jobs.append({
            "key": item["key"],
            "source": item["paths"]["trimmed_png"],
            "output": str((output / "basis-uastc" / relative).resolve()),
            "sample": record["view"] == "front" and record["action"] == "idle" and record["page_index"] == 0,
        })
    godot_config = {
        "schema": 1,
        "mode": "encode",
        "uastc_level": 0,
        "jobs": godot_jobs,
        "result": str((output / "godot-encode-result.json").resolve()),
    }
    (output / "godot-encode-config.json").write_text(json.dumps(godot_config, indent=2) + "\n")
    report = {
        "schema": 1,
        "catalog": str(args.catalog.resolve()),
        "species": args.species,
        "constraints": {"cell_size": 512, "fps": 60, "actions": list(ACTIONS), "views": ["front", "back"], "trim_padding": args.padding},
        "encoder_settings": {"webp_method": 4, "lossless_quality": 100, "visually_lossless_quality": 95},
        "atlas_pages": len(records),
        "elapsed_seconds": time.perf_counter() - started,
        "worker_page_seconds": {
            "median": statistics.median(item["elapsed_seconds"] for item in encoded),
            "maximum": max(item["elapsed_seconds"] for item in encoded),
        },
        **summary,
        "visual_comparison": str(preview.resolve()),
        "godot_encode_config": str((output / "godot-encode-config.json").resolve()),
    }
    (output / "report-python.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({
        "pages": len(records),
        "elapsed_seconds": report["elapsed_seconds"],
        "visual_comparison": report["visual_comparison"],
        "godot_encode_config": report["godot_encode_config"],
        "disk": {name: {"mib": value["total_bytes"] / 1048576, "reduction": value["disk_reduction_vs_png"]} for name, value in report["candidates"].items()},
    }, indent=2))


def _merge_godot_results(args) -> None:
    output = args.output.resolve()
    report_path = output / "report-python.json"
    godot_path = output / "godot-encode-result.json"
    if not report_path.is_file() or not godot_path.is_file():
        raise ValueError("Run the Python build and Godot encode phases first")
    report = json.loads(report_path.read_text())
    for candidate in report["candidates"].values():
        candidate["estimated_runtime_vram_bytes"] = candidate["decoded_rgba_bytes"]
        candidate["hypothetical_block_compressed_vram_bytes"] = candidate["decoded_rgba_bytes"] // 4
        candidate.pop("estimated_block_compressed_vram_bytes", None)
    godot = json.loads(godot_path.read_text())
    basis = {
        "species": defaultdict(lambda: {"bytes": 0, "decoded_rgba_bytes": 0, "estimated_block_compressed_vram_bytes": 0, "actions": defaultdict(int)}),
        "total_bytes": 0,
        "decoded_rgba_bytes": 0,
        "estimated_block_compressed_vram_bytes": 0,
    }
    sample_quality = defaultdict(list)
    for job in godot["jobs"]:
        species, view, action, _page = job["key"]
        encoded = job["basis_uastc"]
        size = int(encoded["bytes"])
        rgba = int(job["width"]) * int(job["height"]) * 4
        vram = int(encoded["stored_data_bytes"])
        group = f"{view}/{action}"
        target = basis["species"][species]
        target["bytes"] += size
        target["decoded_rgba_bytes"] += rgba
        target["estimated_block_compressed_vram_bytes"] += vram
        target["actions"][group] += size
        basis["total_bytes"] += size
        basis["decoded_rgba_bytes"] += rgba
        basis["estimated_block_compressed_vram_bytes"] += vram
        if "decoded_path" in encoded:
            with Image.open(job["source"]) as reference_open, Image.open(encoded["decoded_path"]) as decoded_open:
                sample_quality["basis_uastc_level0"].append(_quality(reference_open.convert("RGBA"), decoded_open.convert("RGBA")))
        for label, sample in job.get("samples", {}).items():
            if "decoded_path" not in sample:
                continue
            with Image.open(job["source"]) as reference_open, Image.open(sample["decoded_path"]) as decoded_open:
                sample_quality[label].append(_quality(reference_open.convert("RGBA"), decoded_open.convert("RGBA")))
    basis["species"] = {
        name: {**values, "actions": dict(sorted(values["actions"].items()))}
        for name, values in basis["species"].items()
    }
    baseline = report["candidates"]["png_baseline"]
    basis["disk_reduction_vs_png"] = baseline["total_bytes"] / basis["total_bytes"]
    basis["rgba_reduction_vs_png"] = baseline["decoded_rgba_bytes"] / basis["decoded_rgba_bytes"]
    basis["estimated_runtime_vram_bytes"] = basis["estimated_block_compressed_vram_bytes"]
    report["candidates"]["basis_uastc_trimmed"] = basis

    def summarize_quality(values: list[dict]) -> dict:
        result = {"samples": len(values), "alpha_max_delta": max(value["alpha_max_delta"] for value in values), "backgrounds": {}}
        for background in BACKGROUNDS:
            squared_error = sum(value["backgrounds"][background]["squared_error"] for value in values)
            samples = sum(value["backgrounds"][background]["samples"] for value in values)
            mse = squared_error / max(1, samples)
            result["backgrounds"][background] = {
                "psnr_db": None if mse == 0 else 10 * math.log10((255 * 255) / mse),
                "max_delta": max(value["backgrounds"][background]["max_delta"] for value in values),
            }
        return result

    report["godot"] = {
        "version": godot["godot_version"],
        "renderer": godot["renderer"],
        "uastc_level": godot["uastc_level"],
        "sample_quality": {label: summarize_quality(values) for label, values in sample_quality.items()},
        "sample_profiles": {
            label: {
                "bytes": sum(int(job["samples"][label]["bytes"]) for job in godot["jobs"] if label in job.get("samples", {})),
                "encode_usec": sum(int(job["samples"][label]["encode_usec"]) for job in godot["jobs"] if label in job.get("samples", {})),
            }
            for label in ("basis_uastc_level4", "bptc", "astc", "etc2")
        },
    }
    report["godot"]["sample_profiles"]["basis_uastc_level0"] = {
        "bytes": sum(int(job["basis_uastc"]["bytes"]) for job in godot["jobs"] if "decoded_path" in job["basis_uastc"]),
        "encode_usec": sum(int(job["basis_uastc"]["encode_usec"]) for job in godot["jobs"] if "decoded_path" in job["basis_uastc"]),
    }
    report["godot"]["visual_comparison"] = str(_gpu_preview(godot, output).resolve())
    (output / "report-formats.json").write_text(json.dumps(report, indent=2) + "\n")
    _write_runtime_config(args, report)
    print(json.dumps({
        "basis_mib": basis["total_bytes"] / 1048576,
        "basis_reduction": basis["disk_reduction_vs_png"],
        "basis_vram_mib": basis["estimated_block_compressed_vram_bytes"] / 1048576,
        "runtime_config": str((output / "godot-runtime-config.json").resolve()),
    }, indent=2))


def _gpu_preview(godot: dict, output: Path) -> Path:
    samples = [job for job in godot["jobs"] if "decoded_path" in job["basis_uastc"]]
    candidates = ("source", "basis_uastc_level0", "basis_uastc_level4", "bptc", "astc", "etc2")
    cell = 224
    label_height = 28
    header = 42
    rows = [(job, background) for job in samples for background in BACKGROUNDS]
    sheet = Image.new("RGB", (len(candidates) * cell, header + len(rows) * (cell + label_height)), (28, 31, 43))
    draw = ImageDraw.Draw(sheet)
    font = _font(14)
    for column, candidate in enumerate(candidates):
        draw.text((column * cell + 8, 12), candidate.replace("_", " "), fill=(240, 242, 248), font=font)
    for row, (job, background_label) in enumerate(rows):
        paths = {
            "source": job["source"],
            "basis_uastc_level0": job["basis_uastc"]["decoded_path"],
            **{label: value["decoded_path"] for label, value in job["samples"].items()},
        }
        for column, candidate in enumerate(candidates):
            with Image.open(paths[candidate]) as opened:
                frame = opened.convert("RGBA").crop((0, 0, int(job["width"] / 4), int(job["height"] / 2)))
            frame.thumbnail((cell, cell), Image.Resampling.LANCZOS)
            centered = Image.new("RGBA", (cell, cell))
            centered.alpha_composite(frame, ((cell - frame.width) // 2, (cell - frame.height) // 2))
            background = Image.new("RGBA", (cell, cell), BACKGROUNDS[background_label])
            composite = Image.alpha_composite(background, centered).convert("RGB")
            y = header + row * (cell + label_height)
            sheet.paste(composite, (column * cell, y))
            draw.text((column * cell + 8, y + cell + 5), f"{job['key'][0]} / {background_label}", fill=(240, 242, 248), font=font)
    target = output / "visual-comparison-gpu.png"
    sheet.save(target, "PNG", compress_level=9)
    return target


def _write_runtime_config(args, report: dict) -> None:
    output = args.output.resolve()
    selected = _load_catalog(args.catalog.resolve(), tuple(args.species))
    records = _page_records(selected, args.padding)
    candidate_specs = (
        ("png_baseline", "png", None, "png"),
        ("webp_lossless", "webp", "webp-lossless", "webp"),
        ("webp_q95", "webp", "webp-q95", "webp"),
        ("trimmed_png", "png", "trimmed-png", "png"),
        ("trimmed_webp_lossless", "webp", "trimmed-webp-lossless", "webp"),
        ("trimmed_webp_q95", "webp", "trimmed-webp-q95", "webp"),
        ("basis_uastc_trimmed", "resource", "basis-uastc", "res"),
    )
    candidates = []
    for label, kind, directory, extension in candidate_specs:
        groups = []
        grouped = defaultdict(list)
        for record in records:
            path = Path(record["source"]) if directory is None else output / directory / _relative(record, extension)
            grouped[(record["species"], record["view"], record["action"])].append((record["page_index"], str(path.resolve())))
        for key, values in sorted(grouped.items()):
            groups.append({
                "label": "/".join(key),
                "files": [path for _index, path in sorted(values)],
            })
        playback_records = [record for record in records if record["species"] == "dragonite" and record["view"] == "front" and record["action"] == "physical_attack"]
        playback_records.sort(key=lambda value: value["page_index"])
        if directory is None:
            playback_files = [record["source"] for record in playback_records]
        else:
            playback_files = [str((output / directory / _relative(record, extension)).resolve()) for record in playback_records]
        x0, y0, x1, y1 = playback_records[0]["crop"]
        trimmed = label.startswith("trimmed_") or label.startswith("basis_")
        candidates.append({
            "label": label,
            "kind": kind,
            "groups": groups,
            "playback": {
                "files": playback_files,
                "frame_count": sum(record["count"] for record in playback_records),
                "frames_per_page": 8,
                "columns": 4,
                "cell_width": x1 - x0 if trimmed else 512,
                "cell_height": y1 - y0 if trimmed else 512,
            },
        })
    config = {
        "schema": 1,
        "candidates": candidates,
        "result": str((output / "godot-runtime-result.json").resolve()),
    }
    (output / "godot-runtime-config.json").write_text(json.dumps(config, indent=2) + "\n")
    for candidate in candidates:
        isolated = {
            "schema": 1,
            "candidates": [candidate],
            "result": str((output / f"godot-runtime-{candidate['label']}.json").resolve()),
        }
        (output / f"godot-runtime-config-{candidate['label']}.json").write_text(json.dumps(isolated, indent=2) + "\n")


def _merge_runtime_results(args) -> None:
    output = args.output.resolve()
    report = json.loads((output / "report-formats.json").read_text())
    results = []
    for label in report["candidates"]:
        path = output / f"godot-runtime-{label}.json"
        if not path.is_file():
            raise ValueError(f"Missing isolated runtime result: {path}")
        payload = json.loads(path.read_text())
        results.extend(payload["candidates"])
    merged = {
        "schema": 1,
        "godot_version": payload["godot_version"],
        "display_server": payload["display_server"],
        "renderer": payload["renderer"],
        "rendering_device": payload["rendering_device"],
        "candidates": results,
    }
    (output / "report-runtime.json").write_text(json.dumps(merged, indent=2) + "\n")
    print(output / "report-runtime.json")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--species", nargs="+", default=["diglett", "jigglypuff", "dragonite", "roaring-moon"])
    parser.add_argument("--padding", type=int, default=4)
    parser.add_argument("--workers", type=int, default=max(1, min(8, os.cpu_count() or 1)))
    parser.add_argument("--finalize-godot", action="store_true")
    parser.add_argument("--refresh-preview", action="store_true")
    parser.add_argument("--merge-runtime", action="store_true")
    parser.add_argument("--write-review-catalog", action="store_true")
    args = parser.parse_args()
    if args.write_review_catalog:
        _write_review_catalog(args)
    elif args.merge_runtime:
        _merge_runtime_results(args)
    elif args.refresh_preview:
        _refresh_preview(args)
    elif args.finalize_godot:
        _merge_godot_results(args)
    else:
        build(args)


if __name__ == "__main__":
    main()
