"""Build conservative shiny GLB diagnostics for the remaining Biochao cohort.

Only an unchanged official rare material table with BaseColorMap substitutions
is accepted. Every replaced normal image must match the official source pixels.
This never approves a model or changes the game catalog.
"""

import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import struct

from PIL import Image, ImageChops

from catalog_shiny_production import replacements
from phase5_variant_parity import compare


JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read_glb(path):
    data = path.read_bytes()
    if (len(data) < 28 or data[:4] != b"glTF" or
            struct.unpack_from("<II", data, 4) != (2, len(data))):
        raise ValueError("Invalid normal GLB header")
    json_length, json_type = struct.unpack_from("<II", data, 12)
    if json_type != JSON_CHUNK:
        raise ValueError("Missing GLB JSON chunk")
    binary_header = 20 + json_length
    if binary_header + 8 > len(data):
        raise ValueError("Truncated GLB")
    binary_length, binary_type = struct.unpack_from("<II", data, binary_header)
    if binary_type != BIN_CHUNK or binary_header + 8 + binary_length != len(data):
        raise ValueError("Expected exactly one GLB binary chunk")
    doc = json.loads(data[20:binary_header])
    if len(doc.get("buffers", [])) != 1 or doc["buffers"][0].get("uri"):
        raise ValueError("GLB needs one embedded buffer")
    binary = data[binary_header + 8:]
    return doc, binary


def image_pixels_equal(embedded, source):
    with Image.open(io.BytesIO(embedded)) as image, Image.open(source) as official:
        image = image.convert("RGBA")
        official = official.convert("RGBA")
        return image.size == official.size and ImageChops.difference(image, official).getbbox() is None


def replacement_views(doc, binary, pairs):
    images = doc.get("images", [])
    views = doc.get("bufferViews", [])
    by_name = {}
    for index, image in enumerate(images):
        by_name.setdefault(image.get("name"), []).append(index)
    base_color_images = set()
    other_images = set()
    textures = doc.get("textures", [])
    for material in doc.get("materials", []):
        pbr = material.get("pbrMetallicRoughness", {})
        base = pbr.get("baseColorTexture")
        if base is not None:
            base_color_images.add(textures[base["index"]]["source"])
        for field in (material.get("normalTexture"), material.get("occlusionTexture"),
                      material.get("emissiveTexture"), pbr.get("metallicRoughnessTexture")):
            if field is not None:
                other_images.add(textures[field["index"]]["source"])
    selected = {}
    for pair in pairs:
        if pair.get("material_bindings") or pair.get("unrepresented_channel"):
            raise ValueError("Rare texture needs material-specific review")
        image_name = Path(pair["normal"]).stem
        indices = by_name.get(image_name, [])
        if len(indices) != 1 or indices[0] not in base_color_images or indices[0] in other_images:
            raise ValueError("Official normal albedo lacks a unique GLB base-color binding")
        image = images[indices[0]]
        if image.get("mimeType") != "image/png" or "bufferView" not in image:
            raise ValueError("Normal albedo is not an embedded PNG")
        view_index = image["bufferView"]
        view = views[view_index]
        if view.get("buffer", 0) != 0:
            raise ValueError("External image buffer")
        start = view.get("byteOffset", 0)
        end = start + view["byteLength"]
        if end > len(binary) or not image_pixels_equal(binary[start:end], pair["normal"]):
            raise ValueError("Embedded normal pixels differ from official source")
        if sha(pair["normal"]) != pair["normal_sha256"] or sha(pair["rare"]) != pair["rare_sha256"]:
            raise ValueError("Official texture changed during export")
        if view_index in selected:
            raise ValueError("Shared albedo view needs review")
        selected[view_index] = Path(pair["rare"]).read_bytes()
    if not selected:
        raise ValueError("No official rare albedo substitutions")
    return selected


def write_variant(path, doc, binary, selected):
    views = doc["bufferViews"]
    spans = sorted((views[index].get("byteOffset", 0),
                    views[index].get("byteOffset", 0) + views[index]["byteLength"], index)
                   for index in selected)
    if any(start < previous_end for (previous_start, previous_end, _), (start, _, _)
           in zip(spans, spans[1:])):
        raise ValueError("Overlapping replaced image views")
    for start, end, index in spans:
        if start < 0 or end > len(binary):
            raise ValueError("Image view outside GLB buffer")
        for other_index, view in enumerate(views):
            if other_index == index:
                continue
            other_start = view.get("byteOffset", 0)
            other_end = other_start + view["byteLength"]
            if other_start < end and start < other_end:
                raise ValueError("Replaced image shares bytes with another buffer view")
    result = bytearray()
    cursor = 0
    shifts = []
    for start, end, index in spans:
        result.extend(binary[cursor:start])
        new_start = len(result)
        result.extend(selected[index])
        result.extend(b"\0" * (-len(result) % 4))
        views[index]["byteOffset"] = new_start
        views[index]["byteLength"] = len(selected[index])
        shifts.append((end, len(result) - end))
        cursor = end
    result.extend(binary[cursor:])
    replaced = set(selected)
    for index, view in enumerate(views):
        if index in replaced:
            continue
        old_offset = view.get("byteOffset", 0)
        shift = next((delta for end, delta in reversed(shifts) if end <= old_offset), 0)
        view["byteOffset"] = old_offset + shift
    doc["buffers"][0]["byteLength"] = len(result)
    json_bytes = json.dumps(doc, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    json_bytes += b" " * (-len(json_bytes) % 4)
    result.extend(b"\0" * (-len(result) % 4))
    total = 12 + 8 + len(json_bytes) + 8 + len(result)
    path.write_bytes(struct.pack("<4sII", b"glTF", 2, total) +
                     struct.pack("<II", len(json_bytes), JSON_CHUNK) + json_bytes +
                     struct.pack("<II", len(result), BIN_CHUNK) + result)


def export_one(row, normal_root, material_root, output):
    species = row["species"]
    if row["status"] != "normal_technical_candidate":
        return {"species": species, "status": "held", "stage": row.get("stage", "source"),
                "reason": row.get("reason", "Default-form source missing")}
    try:
        member = row["source"]["member"]
        match = re.search(r"(pm\d{4})(?:_00)?\.blend$", member)
        if not match:
            raise ValueError("No pinned Biochao resource identity")
        base = match[1]
        resource = base + "_00_00"
        table = material_root / base / resource / (resource + ".trmtr")
        if not table.is_file():
            raise ValueError("Official normal/rare material tables absent for this source")
        pairs, rare_table_sha = replacements(table)
        normal_dir = normal_root / f"{row['national_dex']:04d}-{species}"
        normal = normal_dir / "model.glb"
        if sha(normal) != row["normal_glb_sha256"]:
            raise ValueError("Normal GLB differs from pinned candidate")
        original_report = json.loads((normal_dir / "export.json").read_text())
        original_job = json.loads((normal_dir / "job.json").read_text())
        if (original_report["glb_sha256"] != row["normal_glb_sha256"] or
                original_job["source_sha256"] != row["source_sha256"] or
                original_job["species"] != species):
            raise ValueError("Normal export provenance differs")
        doc, binary = read_glb(normal)
        selected = replacement_views(doc, binary, pairs)
        directory = output / species
        directory.mkdir(parents=True, exist_ok=True)
        variant = directory / "model.glb"
        write_variant(variant, doc, binary, selected)
        parity = compare(normal, variant)
        exported = {**original_report, "path": str(variant), "glb_sha256": sha(variant),
                    "source_warnings": original_report.get("source_warnings", []),
                    "official_rare_material_sha256": rare_table_sha,
                    "official_albedo_replacements": pairs,
                    "geometry_motion_sha256": parity,
                    "runtime_approved": False}
        (directory / "export.json").write_text(json.dumps(exported, indent=2) + "\n")
        (directory / "job.json").write_text(json.dumps({
            "species": species, "source_sha256": row["source_sha256"],
            "variant": "shiny", "material_source": str(table),
            "material_source_sha256": sha(table), "runtime_approved": False}, indent=2) + "\n")
        return {"species": species, "status": "exported", "variant": "shiny",
                "report": str(directory / "export.json"), "normal_glb_sha256": row["normal_glb_sha256"],
                "shiny_glb_sha256": exported["glb_sha256"],
                "geometry_motion_sha256": parity}
    except (OSError, ValueError, KeyError, IndexError, TypeError) as error:
        return {"species": species, "status": "held", "stage": "shiny_material",
                "reason": str(error)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidates", type=Path, required=True)
    parser.add_argument("--normal-root", type=Path, required=True)
    parser.add_argument("--material-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        parser.error("--output must name a new directory")
    rows = json.loads(args.candidates.read_text())["entries"]
    output.mkdir(parents=True)
    results = []
    for row in rows:
        result = export_one(row, args.normal_root.resolve(), args.material_root.resolve(), output)
        results.append(result)
        print(result["species"], result["status"], flush=True)
    report = {"schema": 1, "scope": "local_shiny_diagnostics_not_catalog_approval",
              "runtime_approved": False, "total": len(rows),
              "exported": sum(row["status"] == "exported" for row in results),
              "held": sum(row["status"] == "held" for row in results), "entries": results}
    (output / "status.json").write_text(json.dumps(report, indent=2) + "\n")
    print("SHINY_DIAGNOSTICS_COMPLETE", report["exported"], "exported,",
          report["held"], "held", flush=True)


if __name__ == "__main__":
    main()
