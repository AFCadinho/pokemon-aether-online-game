"""Build isolated, review-only Mega normal/shiny scenes from the ZA dump.

The intake map is explicit. This tool never approves, admits, or uploads a
candidate; incomplete motion sets and failed imports are recorded per form.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from catalog_shiny_za_17_probe import rebuild, restore_fresnel, run_flatpak
from phase5_variant_parity import compare
from scvi_batch import source_entry
from catalog_remaining_eye_bake import chunks
from scvi_tracm import inspect_tracm, inspect_visibility
from visibility_export import keys as visibility_keys
from visibility_variants import mesh_name
from catalog_mega_material_depth import repair as restore_material_depth
from scvi_material_probe import inspect_materials

HERE = Path(__file__).resolve().parent
FRONTEND = HERE.parents[1]
SLOT = FRONTEND.parent
WORKSPACE = FRONTEND.parents[2]
IMPORTER = SLOT / ".tmp/scvi-importer"
DEPS = SLOT / ".tmp/scvi-python-deps"
INTAKE = HERE / "catalog_mega_3d_source_intake.json"
WORK = FRONTEND / ".tmp/mega-production-v1"
REQUIRED = ("idle", "physical_attack", "special_attack", "damage",
            "faint_start", "faint_loop")
OPTIONAL = ("physical_attack_2",)
IMPORTER_COMMIT = "b0c98d9fcaab85a04ad35e2d111bae4cad6c1e04"


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def write(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def load_rows():
    return json.loads(INTAKE.read_text())["entries"]


def source_number(row, root: Path) -> int:
    """Keep catalog dex and source developer number separate, with audit evidence."""
    ident = row["source_resource_id"]
    if not re.fullmatch(r"pm\d{4}_\d{2}_\d{2}", ident):
        raise ValueError("Malformed explicit source resource ID")
    number = int(ident[2:6])
    evidence = row.get("source_mapping_audit")
    if evidence:
        audit_path = HERE / "catalog_mega_25_source_audit.json"
        if evidence.get("path") != audit_path.name or evidence.get("sha256") != sha(audit_path):
            raise ValueError("Source mapping audit provenance mismatch")
        audit = json.loads(audit_path.read_text())
        matches = [r for r in audit["entries"] if r["showdown_id"] == row["showdown_id"]]
        if len(matches) != 1:
            raise ValueError("Source mapping audit does not uniquely identify this form")
        match = matches[0]
        if (match["source_mapping_status"] != "candidate_identity_match"
                or match["source_resource_id"] != ident
                or int(match["pokedex_number"]) != int(row["pokedex_number"])
                or match["species"] != row["name"]
                or match["dev_number_mapping_evidence"]["developer_number"] != number
                or audit["source_archive"]["sha256"] != json.loads(INTAKE.read_text())["mega_model_source_archive_sha256"]):
            raise ValueError("Source identity differs from the audited catalog form")
        for icon in audit["source_resources"][ident]["normal_and_shiny_icon_evidence"]:
            path = root / icon["archive_member"]
            if not path.is_file() or sha(path) != icon["sha256"]:
                raise ValueError("Audited source identity icon missing or changed")
    elif number != int(row["pokedex_number"]):
        raise ValueError("Alternate developer number requires an explicit source mapping audit")
    return number


def material_aliases(row, raw: Path, table: Path):
    """Zygarde's shared energy/head surface exports twice for distinct UV sets."""
    if row["showdown_id"] != "zygardemega" or row["source_resource_id"] != "pm0770_51_00":
        return {}
    document, _ = chunks(raw)
    indices = [i for i, material in enumerate(document["materials"]) if material["name"] == "body_e"]
    if len(indices) != 2:
        raise ValueError("Zygarde shared surface does not match the investigated export")
    uses = {mesh["name"] for mesh in document["meshes"]
            for primitive in mesh["primitives"] if primitive.get("material") in indices}
    if uses != {"pm0770_51_00_energy_mesh_shape", "pm0770_51_00_head_mesh_shape"}:
        raise ValueError("Zygarde shared material has unexpected geometry bindings")
    source = next(r for r in inspect_materials(table) if r["name"] == "body_e")
    expected = Path(source["textures"]["BaseColorMap"]).stem
    bindings = []
    for index in indices:
        binding = document["materials"][index]["pbrMetallicRoughness"]["baseColorTexture"]
        texture = document["textures"][binding["index"]]
        image = document["images"][texture["source"]]
        if expected not in image.get("name", ""):
            raise ValueError("Zygarde shared surface does not bind its native albedo")
        bindings.append(binding)
    if bindings[0] != bindings[1]:
        raise ValueError("Zygarde shared surface albedo bindings differ")
    return {"body_e": "body_e"}


def prepare_source_dependencies(row, root: Path):
    """Stage native shared textures from the same Pokémon's source resources."""
    ident = row["source_resource_id"]
    directory = root / ident[:6] / ident
    dependencies = []
    for suffix in ("", "_rare"):
        table = directory / (ident + suffix + ".trmtr")
        for material in inspect_materials(table):
            for texture in material["textures"].values():
                filename = Path(texture).with_suffix(".png").name
                target = directory / filename
                if target.is_file():
                    continue
                match = re.match(r"(pm\d{4}_\d{2}_\d{2})_", filename)
                # Common importer-provided defaults are not model resources.
                if not match:
                    continue
                dependency_id = match.group(1)
                if dependency_id[:6] != ident[:6]:
                    raise ValueError("Shared texture points to a different Pokémon source number")
                origin = root / ident[:6] / dependency_id / filename
                if not origin.is_file():
                    raise ValueError("Native shared texture dependency missing: " + filename)
                expected = sha(origin)
                target.write_bytes(origin.read_bytes())
                if sha(target) != expected:
                    raise ValueError("Shared texture staging hash mismatch")
                dependencies.append({"filename": filename,
                    "source_resource": dependency_id, "sha256": expected})
    receipt = directory / "source-dependencies.json"
    if dependencies:
        write(receipt, {"identity": ident, "policy": "native_same_species_texture_references",
                        "dependencies": dependencies})
    if receipt.is_file():
        previous = json.loads(receipt.read_text())
        if previous["identity"] != ident:
            raise ValueError("Shared texture receipt identity mismatch")
        for item in previous["dependencies"]:
            origin = root / ident[:6] / item["source_resource"] / item["filename"]
            if sha(origin) != item["sha256"] or sha(directory / item["filename"]) != item["sha256"]:
                raise ValueError("Native shared texture dependency changed")
        return {"path": str(receipt), "sha256": sha(receipt),
                "count": len(previous["dependencies"])}
    return None


def restore_water_palette(row, target: Path, table: Path):
    """Review-only Greninja water palette translation; no native shader claim."""
    if row["showdown_id"] != "greninjamega" or row["source_resource_id"] != "pm0725_51_00":
        return None
    from io import BytesIO
    from PIL import Image
    from catalog_remaining_eye_bake import append_png, linear_to_srgb, write_glb
    from phase5_variant_parity import signature
    before = signature(target)
    document, binary = chunks(target)
    source = {r["name"]: r for r in inspect_materials(table)}
    restored = []
    for material in document["materials"]:
        if material["name"] not in ("body_c_00", "body_c_01"):
            continue
        native = source[material["name"]]
        albedo = table.parent / Path(native["textures"]["BaseColorMap"]).with_suffix(".png").name
        with Image.open(albedo) as palette:
            if palette.size != (16, 2) or native["alpha_type"] != "Opaque":
                raise ValueError("Greninja native water palette differs from the investigated source")
        # This tiny palette is not a complete UV-square albedo. A direct bake
        # otherwise paints its empty palette cells black across the water mesh.
        # Preserve the native blue layer as a static surface proposal instead.
        tint = native["colors"]["BaseColorLayer1"]
        colour = tuple(linear_to_srgb(v) for v in tint[:3]) + (255,)
        image = Image.new("RGBA", (2, 2), colour)
        output = BytesIO()
        image.save(output, format="PNG")
        binding = material["pbrMetallicRoughness"]["baseColorTexture"]
        previous = document["textures"][binding["index"]]
        binding["index"] = append_png(document, binary, output.getvalue(),
                                     material["name"] + "_native_water_colour", previous.get("sampler", 0))
        material["alphaMode"] = "OPAQUE"
        material["doubleSided"] = True
        restored.append(material["name"])
    if set(restored) != {"body_c_00", "body_c_01"}:
        raise ValueError("Greninja water surface coverage is incomplete")
    write_glb(target, document, binary)
    if signature(target) != before:
        raise ValueError("Water palette translation changed mesh, UV, skin or motion")
    return {"policy": "native_palette_colour_as_static_water", "materials": restored,
            "limitation": "Native tiny albedo palette/UV shader is represented by its source blue layer colour; visual approval required."}


def restore_crystal_detail(row, target: Path, table: Path):
    """Diancie review proposal: retain authored facets as a static PBR surface."""
    if row["showdown_id"] != "dianciemega" or row["source_resource_id"] != "pm0772_51_00":
        return None
    from io import BytesIO
    from PIL import Image, ImageChops
    from catalog_remaining_eye_bake import append_png, linear_to_srgb, write_glb
    from phase5_variant_parity import signature
    before = signature(target)
    document, binary = chunks(target)
    source = {r["name"]: r for r in inspect_materials(table)}
    records = []
    expected = {"body_d_00": "fresnel_a", "body_d_01": "fresnel_b",
                "body_d_02": "fresnel_b"}
    for material in document["materials"]:
        name = material["name"]
        if name not in expected:
            continue
        native = source[name]
        texture_name = Path(native["textures"]["BaseColorMap1"]).with_suffix(".png").name
        texture = table.parent / texture_name
        if (texture_name != row["source_resource_id"] + "_" + expected[name] + "_alb.png"
                or not any(s["name"] == "FresnelEffect" for s in native["shaders"])
                or native["alpha_type"] != "Opaque"
                or native["colors"]["UVScaleOffset1"] != [1, 1, 0, 0]):
            raise ValueError("Diancie native crystal layer differs from the investigated source")
        with Image.open(texture) as image:
            if image.size != (512, 512):
                raise ValueError("Unexpected Diancie crystal detail texture size")
            tint = tuple(linear_to_srgb(v) for v in native["colors"]["BaseColorLayer1"][:3])
            colour = ImageChops.multiply(image.convert("RGB"), Image.new("RGB", image.size, tint))
        packed = BytesIO()
        colour.save(packed, format="PNG")
        pbr = material["pbrMetallicRoughness"]
        previous = document["textures"][pbr["baseColorTexture"]["index"]]
        index = append_png(document, binary, packed.getvalue(), name + "_native_crystal_facets",
                           previous.get("sampler", 0))
        # UV1 contains the exporter's atlas, whereas this authored 512-square
        # image is a full crystal pattern. Use the original mesh UV0 for this
        # static approximation; native camera parallax is not reproduced.
        pbr["baseColorTexture"] = {"index": index, "texCoord": 0}
        pbr["baseColorFactor"] = [1, 1, 1, 1]
        material["alphaMode"] = "OPAQUE"
        records.append({"material": name, "texture": texture_name, "sha256": sha(texture)})
    if {r["material"] for r in records} != set(expected):
        raise ValueError("Diancie crystal detail coverage is incomplete")
    veil_index = next(i for i, m in enumerate(document["materials"]) if m["name"] == "body_c")
    veil_meshes = {mesh["name"] for mesh in document["meshes"]
                   for primitive in mesh["primitives"] if primitive.get("material") == veil_index}
    prefix = row["source_resource_id"]
    if (veil_meshes != {prefix + "_innerskirt_a_mesh_shape", prefix + "_veil_left_a_mesh_shape",
                       prefix + "_veil_right_a_mesh_shape"}
            or source["body_c"]["alpha_type"] != "Opaque"):
        raise ValueError("Diancie thin veil surface differs from the investigated export")
    # The veil is a thin sheet; culling its reverse-facing triangles leaves
    # apparently broken ribbons as the native animation bends each sheet.
    document["materials"][veil_index]["doubleSided"] = True
    write_glb(target, document, binary)
    if signature(target) != before:
        raise ValueError("Crystal detail translation changed mesh, UV, skin or motion")
    return {"policy": "native_facet_texture_static_pbr_uv0", "materials": records,
            "two_sided_thin_surface": {"material": "body_c", "meshes": sorted(veil_meshes)},
            "limitation": "Authored facet textures and layer colour retained; native view-dependent Fresnel/parallax is approximated statically. Visual approval required."}


def import_and_export(row, root: Path, folder: Path):
    ident = row["source_resource_id"]
    number = source_number(row, root)
    dependencies = prepare_source_dependencies(row, root)
    entry = source_entry({"species": row["showdown_id"], "pm": number,
                          "resource_id": ident, "target_game_height_px": 100}, root, root)
    fatal = [w for w in entry["warnings"]
             if w.startswith("motion_bank_hold:") and ":sleep:" not in w
             or w.startswith("missing_action:") and w != "missing_action:sleep"]
    if fatal:
        raise ValueError("; ".join(fatal))
    model_dir = Path(entry["model_dir"])
    # Missing Mega sleep clips must stay on their own rig. Base-form whole-body
    # tracks deform several Mega meshes and carry incompatible visibility.
    native_rest_sleep = False
    cross_bank_sleep = False
    if not entry["motions"].get("sleep"):
        selected = entry["motions"].get("faint_loop")
        if not selected:
            raise ValueError("Mega has no native sleep or rest-loop source")
        entry["motions"]["sleep"] = selected
        entry["motion_channels"]["sleep"] = entry["motion_channels"].get("faint_loop")
        native_rest_sleep = True
        entry["warnings"] = [w for w in entry["warnings"]
                             if w not in ("missing_action:sleep", "motion_bank_hold:sleep:missing")]
    baseline_candidates = sorted(model_dir.glob(ident + "_*_eye01.tranm"))
    baseline = baseline_candidates[0] if len(baseline_candidates) == 1 else None

    import_dir = folder / "import"
    import_dir.mkdir(parents=True, exist_ok=True)
    prepared = import_dir / "prepared.blend"
    report = import_dir / "import.json"
    core = [p for p in model_dir.iterdir() if p.is_file()]
    source_files = {str(p): sha(p) for p in core}
    for p in list(entry["motions"].values()) + list(entry["motion_channels"].values()):
        if p and Path(p).is_file():
            source_files[str(p)] = sha(Path(p))
    if baseline:
        source_files[str(baseline)] = sha(baseline)
        companion = baseline.with_suffix(".tracm")
        if companion.is_file():
            source_files[str(companion)] = sha(companion)
    job = {"species": row["showdown_id"], "identity": ident,
           "variant": "normal", "model_dir": str(model_dir),
           "motion_selection_policy": ("cross-bank-sleep-diagnostic-v1" if cross_bank_sleep
                                       else entry["motion_selection_policy"]),
           "motions": entry["motions"], "motion_channels": entry["motion_channels"],
           "facial_baseline": str(baseline) if baseline else None,
           "facial_baseline_categories": ["idle", "physical_attack", "physical_attack_2",
                                          "special_attack", "damage"],
           "restore_all_eyelids": False, "output": str(prepared), "report": str(report),
           "importer": str(IMPORTER), "python_deps": str(DEPS),
           "importer_commit": IMPORTER_COMMIT, "shader_sha256": sha(IMPORTER / "SCVIShader.blend"),
           "source_files": source_files}
    write(import_dir / "job.json", job)
    if not (prepared.is_file() and report.is_file()):
        run_flatpak(HERE / "scvi_import_worker.py", import_dir / "job.json",
                    [(root, ":ro"), (IMPORTER, ":ro"), (DEPS, ":ro"),
                     (HERE, ":ro"), (folder, "")], import_dir / "worker.log")
    imported = json.loads(report.read_text())
    if imported.get("prepared_sha256") != sha(prepared) or imported.get("importer_commit") != IMPORTER_COMMIT:
        raise ValueError("Prepared Blender provenance mismatch")
    for path, digest in imported.get("source_files", {}).items():
        if sha(Path(path)) != digest:
            raise ValueError("Imported source changed: " + path)

    export_dir = folder / "export"
    export_dir.mkdir(exist_ok=True)
    isolated = export_dir / "input.blend"
    if not isolated.exists():
        isolated.write_bytes(prepared.read_bytes())
    if sha(isolated) != sha(prepared):
        raise ValueError("Export input differs from prepared model")
    actions = {name: value["name"] for name, value in imported["actions"].items() if value}
    missing = set(REQUIRED) - set(actions)
    if missing:
        raise ValueError("Importer omitted required actions: " + ", ".join(sorted(missing)))
    export_job = {"species": row["showdown_id"], "source": str(isolated),
                  "source_sha256": sha(isolated), "actions": actions,
                  "output": str(export_dir), "scvi_pbr_probe": False,
                  "native_flatten_bone_hierarchy_diagnostic": True}
    write(export_dir / "job.json", export_job)
    export_report = export_dir / "export.json"
    if not (export_report.is_file() and (export_dir / "model.glb").is_file()):
        run_flatpak(HERE / "phase5_godot_export_worker.py", export_dir / "job.json",
                    [(export_dir, ""), (HERE, ":ro")], export_dir / "worker.log")
    exported = json.loads(export_report.read_text())
    raw = export_dir / "model.glb"
    if exported.get("status") != "exported_for_review" or exported.get("glb_sha256") != sha(raw):
        raise ValueError("Review GLB receipt mismatch")

    variants = {}
    water_translation = None
    crystal_translation = None
    for variant, suffix in (("normal", ""), ("shiny", "_rare")):
        table = model_dir / (ident + suffix + ".trmtr")
        if not table.is_file():
            raise ValueError("Official " + variant + " material table missing")
        target_dir = folder / variant
        target_dir.mkdir(exist_ok=True)
        target = target_dir / "model.glb"
        if not target.is_file():
            aliases = material_aliases(row, raw, table)
            rebuild(raw, target, table, aliases=aliases)
            restore_fresnel(target, table)
            restore_material_depth(target, target, table)
            water_translation = restore_water_palette(row, target, table)
            crystal_translation = restore_crystal_detail(row, target, table)
        compare(raw, target)
        variants[variant] = {"path": str(target), "sha256": sha(target),
                             "table": str(table), "table_sha256": sha(table)}
    if variants["normal"]["sha256"] == variants["shiny"]["sha256"]:
        raise ValueError("Normal/shiny material builds are identical")
    parity = compare(Path(variants["normal"]["path"]), Path(variants["shiny"]["path"]))
    result = {"identity": ident, "import": str(report), "import_sha256": sha(report),
            "export": str(export_report), "export_sha256": sha(export_report),
            "actions": exported["animations"], "variants": variants,
            "geometry_motion_sha256": parity,
            "cross_bank_sleep_review_required": cross_bank_sleep,
            "native_rest_sleep_review_required": native_rest_sleep,
            "warnings": imported.get("channel_warnings", []) + imported.get("facial_inheritance_warnings", [])}
    if row["showdown_id"] == "zygardemega":
        result["shared_material_binding"] = {"body_e": "native energy/head surface; two exported UV variants"}
    if dependencies:
        result["native_shared_texture_dependencies"] = dependencies
    if water_translation:
        result["water_surface_translation"] = water_translation
    if crystal_translation:
        result["crystal_surface_translation"] = crystal_translation
    result["visibility"] = visibility_manifest(raw, exported, job, ident)
    return result


def attach_visibility(row, result, folder: Path):
    import_job = json.loads((folder / "import/job.json").read_text())
    if result.get("cross_bank_sleep_review_required"):
        import_job["motion_selection_policy"] = "cross-bank-sleep-diagnostic-v1"
    export_report = json.loads((folder / "export/export.json").read_text())
    glb = folder / "export/model.glb"
    result["visibility"] = visibility_manifest(glb, export_report, import_job,
                                               row["source_resource_id"])
    return result


def visibility_manifest(glb: Path, export: dict, job: dict, mega_identity: str):
    """Translate native visibility side-channels to explicit SCN mesh tracks."""
    document, _ = chunks(glb)
    names = [node["name"] for node in document.get("nodes", []) if "mesh" in node]
    if len(names) != len(set(names)):
        raise ValueError("Duplicate exported mesh names make visibility ambiguous")
    targets = {name + "_shape" for name in names}
    base_identity = mega_identity[:6] + "_00_00"
    clips = {}
    dynamic_tracks = []
    for action, timing in export["animations"].items():
        channel = Path(job["motion_channels"][action])
        if not channel.is_file():
            raise ValueError("Native visibility side-channel missing: " + action)
        config = inspect_tracm(channel)
        duration = (config["frames"] - 1) / config["fps"]
        if abs(duration - timing["duration"]) > 1e-6 or bool(config["loop"]) != timing["loop"]:
            raise ValueError("Visibility/skeleton clocks disagree: " + action)
        source_tracks = inspect_visibility(channel)
        mapped = {}
        for track in source_tracks:
            target = track["target"]
            mapped_targets = []
            if target in targets:
                mapped_targets = [target]
            elif action == "sleep" and target.startswith(base_identity + "_"):
                suffix = target[len(base_identity):]
                candidate = mega_identity + suffix
                if candidate in targets:
                    mapped_targets = [candidate]
                elif suffix == "_fire_mesh_shape":
                    mapped_targets = [mega_identity + "_fire_a_mesh_shape",
                                      mega_identity + "_fire_b_mesh_shape"]
                    mapped_targets = [t for t in mapped_targets if t in targets]
            if not mapped_targets:
                # Ignore source LOD channels only when their base shape is
                # represented by the pinned non-LOD scene mesh.
                try:
                    base = mesh_name(target)
                except ValueError:
                    base = ""
                if re.search(r"_shape_lod[123]$", target) and base + "_shape" in targets:
                    continue
                continue
            for mapped_target in mapped_targets:
                mesh = mesh_name(mapped_target)
                if mesh in mapped:
                    raise ValueError(f"Duplicate visibility mapping for {action}/{mesh}")
                dynamic = track["encoding"] == "dynamic_bool"
                dynamic_tracks += [f"{action}:{target}"] if dynamic else []
                mapped[mesh] = {"mesh": mesh, "source_target": mapped_target,
                                "original_source_target": target,
                                "keys": visibility_keys(track, config["frames"], config["fps"],
                                                        dynamic_review=True, full_frame_review=True)}
        missing = set(names) - set(mapped)
        if missing and action == "sleep" and job.get("motion_selection_policy") == "cross-bank-sleep-diagnostic-v1":
            # Base sleep rigs can merge a Mega's multiple flame meshes. Give
            # unmapped Mega-only meshes their own Mega idle visibility state.
            idle_channel = Path(job["motion_channels"]["idle"])
            idle_config = inspect_tracm(idle_channel)
            for idle_track in inspect_visibility(idle_channel):
                target = idle_track["target"]
                if target in targets:
                    mesh = mesh_name(target)
                    if mesh in missing:
                        initial = visibility_keys(idle_track, idle_config["frames"], idle_config["fps"])[0][1]
                        dynamic = idle_track["encoding"] == "dynamic_bool"
                        dynamic_tracks += [f"idle:{target}"] if dynamic else []
                        mapped[mesh] = {"mesh": mesh, "source_target": target,
                                        "original_source_target": target,
                                        "keys": [[0.0, initial]],
                                        "sleep_mapping": "mega_idle_initial_visibility"}
            missing = set(names) - set(mapped)
        if missing:
            raise ValueError(f"Incomplete visibility coverage for {action}: {sorted(missing)}")
        clips[action] = {"duration": duration, "loop": bool(config["loop"]),
                         "source_sha256": sha(channel),
                         "tracks": [mapped[name] for name in names]}
    return {"schema": 1, "glb_sha256": sha(glb), "clips": clips,
            "dynamic_visibility_review_required": bool(dynamic_tracks),
            "dynamic_visibility_tracks": dynamic_tracks}


def convert_pair(row, result, root: Path, slot_env: Path, folder: Path,
                 runtime_name: str = "runtime"):
    stage = []
    for variant, model in result["variants"].items():
        entry = {"species": row["showdown_id"] + ("-shiny" if variant == "shiny" else ""),
                 "path": model["path"], "source_sha256": model["sha256"],
                 "placement": {"scale": 1.0, "yaw_degrees": 0.0},
                 "visibility": {**result["visibility"], "glb_sha256": model["sha256"]},
                 "runtime_approved": False,
                 "action_timing": {name: {"frames": round(clip["duration"] * 60, 6),
                                          "speed": 1.0, "loop": clip["loop"]}
                                   for name, clip in result["actions"].items()}}
        stage.append(entry)
    stage_path = folder / "runtime-stage.json"
    write(stage_path, stage)
    runtime = folder / runtime_name
    report_path = runtime / "report.json"
    if SLOT.name not in ("slot-a", "slot-b", "slot-c"):
        raise ValueError("Mega runtime conversion requires an assigned task slot")
    command = [str(slot_env), SLOT.name, "--", "godot", "--headless", "--path",
               str(FRONTEND), "--script", "tools/sprite_factory/prepare_battle_3d_runtime.gd"]
    env = os.environ.copy()
    env.update(POKEAETHER_3D_STAGE_REPORT=str(stage_path), POKEAETHER_3D_RUNTIME_OUTPUT=str(runtime))
    if not report_path.is_file():
        with (folder / "runtime.log").open("w") as log:
            subprocess.run(command, cwd=FRONTEND, env=env, stdout=log, stderr=subprocess.STDOUT,
                           timeout=600, check=True)
    runtime_rows = json.loads(report_path.read_text())
    if len(runtime_rows) != 2 or {r["species"] for r in runtime_rows} != {r["species"] for r in stage}:
        raise ValueError("Standalone scene report is incomplete")
    for entry in runtime_rows:
        if not Path(entry["runtime_path"]).is_file() or sha(Path(entry["runtime_path"])) != entry["runtime_sha256"]:
            raise ValueError("Standalone scene hash mismatch")
    result["runtime_scenes"] = runtime_rows
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, default=WORK / "source")
    parser.add_argument("--output", type=Path, default=WORK / "production-v1")
    parser.add_argument("--slot-env", type=Path, default=WORKSPACE / "ops/worktrees/slot-env")
    parser.add_argument("--only", help="Comma-separated exact intake showdown IDs")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--skip-runtime", action="store_true")
    parser.add_argument("--visibility-pass", action="store_true",
                        help="Attach side-channel visibility and rebuild scenes for an existing batch")
    args = parser.parse_args()
    if subprocess.check_output(["git", "-C", str(IMPORTER), "rev-parse", "HEAD"], text=True).strip() != IMPORTER_COMMIT:
        raise ValueError("SCVI importer checkout differs from pinned commit")
    rows = [r for r in load_rows() if r.get("source_resource_id")
            and r["showdown_id"] != "dragonitemega"]
    if args.only:
        selected = set(args.only.split(","))
        unknown = selected - {r["showdown_id"] for r in rows}
        if unknown:
            raise ValueError("Unknown source-ready IDs: " + ", ".join(sorted(unknown)))
        rows = [r for r in rows if r["showdown_id"] in selected]
    if args.limit:
        rows = rows[:args.limit]
    output, root = args.output.resolve(), args.source_root.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if args.visibility_pass:
        status_file = output / "status.json"
        batch = json.loads(status_file.read_text())
        updated = []
        by_id = {row["showdown_id"]: row for row in rows}
        for old in batch["entries"]:
            if old.get("status") != "runtime_candidate":
                updated.append(old)
                continue
            row = by_id[old["showdown_id"]]
            folder = output / row["showdown_id"]
            try:
                result = attach_visibility(row, old, folder)
                result = convert_pair(row, result, root, args.slot_env.resolve(), folder,
                                      runtime_name="runtime-with-visibility")
                result["status"] = "runtime_candidate"
                result["runtime_approved"] = False
                result["appearance_approved"] = False
                write(folder / "status.json", result)
                updated.append({"showdown_id": row["showdown_id"], **result})
                print(row["showdown_id"], "visibility_runtime_candidate", flush=True)
            except Exception as exc:
                held = {"showdown_id": row["showdown_id"], "status": "held",
                        "reason": f"visibility {type(exc).__name__}: {exc}",
                        "runtime_approved": False, "appearance_approved": False}
                updated.append(held)
                print(row["showdown_id"], "held", held["reason"], flush=True)
            batch["entries"] = updated + [e for e in batch["entries"]
                                           if e["showdown_id"] not in {x["showdown_id"] for x in updated}]
            batch["runtime_candidates"] = sum(x.get("status") == "runtime_candidate" for x in batch["entries"])
            batch["held"] = sum(x.get("status") == "held" for x in batch["entries"])
            write(status_file, batch)
        return
    results = []
    for row in rows:
        folder = output / row["showdown_id"]
        status_path = folder / "status.json"
        try:
            if status_path.is_file():
                previous = json.loads(status_path.read_text())
                if previous.get("status") == "runtime_candidate":
                    result = previous
                elif previous.get("status") == "held":
                    attempt = 1
                    archived = output / f"{row['showdown_id']}.failed-{attempt}"
                    while archived.exists():
                        attempt += 1
                        archived = output / f"{row['showdown_id']}.failed-{attempt}"
                    folder.rename(archived)
                    folder.mkdir(parents=True)
                    result = import_and_export(row, root, folder)
                    result.update({"status": "export_candidate", "runtime_approved": False,
                                   "appearance_approved": False})
                    if not args.skip_runtime:
                        result = convert_pair(row, result, root, args.slot_env.resolve(), folder)
                        result["status"] = "runtime_candidate"
                    write(status_path, result)
                else:
                    raise ValueError("Prior partial output exists; inspect it and use a fresh --output")
            else:
                folder.mkdir(parents=True, exist_ok=False)
                result = import_and_export(row, root, folder)
                result.update({"status": "export_candidate", "runtime_approved": False,
                               "appearance_approved": False})
                if not args.skip_runtime:
                    result = convert_pair(row, result, root, args.slot_env.resolve(), folder)
                    result["status"] = "runtime_candidate"
                write(status_path, result)
            results.append({"showdown_id": row["showdown_id"], **result})
            print(row["showdown_id"], result["status"], flush=True)
        except Exception as exc:
            result = {"showdown_id": row["showdown_id"], "status": "held",
                      "reason": f"{type(exc).__name__}: {exc}",
                      "runtime_approved": False, "appearance_approved": False}
            folder.mkdir(parents=True, exist_ok=True)
            write(status_path, result)
            results.append(result)
            print(row["showdown_id"], "held", result["reason"], flush=True)
        write(output / "status.json", {"schema": 1, "source_sha256": json.loads(INTAKE.read_text())["mega_model_source_archive_sha256"],
              "processed": len(results), "total": len(rows),
              "runtime_candidates": sum(x.get("status") == "runtime_candidate" for x in results),
              "held": sum(x.get("status") == "held" for x in results),
              "entries": results})


if __name__ == "__main__":
    main()
