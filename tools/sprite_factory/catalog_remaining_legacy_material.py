"""Hash-bound material evidence for Biochao models absent from the SCVI catalog."""

import hashlib
import json
from pathlib import Path
import re

from catalog_shiny_production import replacements


PINNED_MANIFEST_SHA256 = "6b8920cddc15716af61a8e1d1f718ad55fab0701c1162cc8a4d90512441cfc42"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def canonical_overrides(rows):
    return sorted(rows, key=lambda row: (row["material"], row["key"]))


def validate(job):
    """Keep this review-only route tied to a previously converted normal GLB."""
    if job.get("legacy_material_diagnostic") is not True:
        raise ValueError("Legacy material diagnostic flag missing")
    manifest_path = Path(job["legacy_candidate_manifest"]).resolve()
    if (manifest_path != Path(__file__).with_name("catalog_remaining_normal_candidates.json").resolve() or
            sha(manifest_path) != PINNED_MANIFEST_SHA256 or
            job["legacy_candidate_manifest_sha256"] != PINNED_MANIFEST_SHA256):
        raise ValueError("Remaining candidate manifest changed")
    rows = json.loads(manifest_path.read_text())["entries"]
    found = [row for row in rows if row["species"] == job["species"]]
    if len(found) != 1 or found[0]["status"] != "normal_technical_candidate":
        raise ValueError("Species is not a pinned normal candidate")
    row = found[0]
    member = row["source"]["member"]
    match = re.search(r"(pm\d{4})(?:_00)?\.blend$", member)
    if not match:
        raise ValueError("Unmapped Biochao member")
    resource = match[1] + "_00_00"
    source = Path(job["source"]).resolve()
    expected_name = Path(member).name
    if re.fullmatch(r"pm\d{4}\.blend", expected_name):
        expected_name = expected_name[:-6] + "_00.blend"
    if source.name != expected_name or sha(source) != row["source_sha256"] or job["source_sha256"] != row["source_sha256"]:
        raise ValueError("Biochao source differs from pinned normal export")
    normal_root = Path(job["legacy_normal_root"]).resolve()
    normal_dir = normal_root / f"{row['national_dex']:04d}-{row['species']}"
    normal_glb = normal_dir / "model.glb"
    normal_job = json.loads((normal_dir / "job.json").read_text())
    normal_export = json.loads((normal_dir / "export.json").read_text())
    if (sha(normal_glb) != row["normal_glb_sha256"] or
            normal_export["glb_sha256"] != row["normal_glb_sha256"] or
            normal_job["source_sha256"] != row["source_sha256"] or
            normal_job["species"] != row["species"] or
            job["actions"] != normal_job["actions"]):
        raise ValueError("Normal model, clips, or source proof changed")
    material_root = Path(job["legacy_material_root"]).resolve()
    expected_table = material_root / match[1] / resource / (resource + ".trmtr")
    if Path(job["material_source"]).resolve() != expected_table or sha(expected_table) != job["material_source_sha256"]:
        raise ValueError("Official normal material table differs")
    rare = expected_table.with_name(resource + "_rare.trmtr")
    if (Path(job["official_rare_material_source"]).resolve() != rare or
            sha(rare) != job["official_rare_material_sha256"]):
        raise ValueError("Official rare material table differs")
    pairs, rare_hash, floats, colors = replacements(
        expected_table, review_queue=True, include_float_overrides=True,
        include_color_overrides=True, material_scoped=True)
    if (rare_hash != job["official_rare_material_sha256"] or
            pairs != job["verified_texture_replacements"] or
            canonical_overrides(floats) != canonical_overrides(job["verified_rare_float_overrides"]) or
            canonical_overrides(colors) != canonical_overrides(job["verified_rare_color_overrides"])):
        raise ValueError("Rare material changes differ from official tables")
    return row
