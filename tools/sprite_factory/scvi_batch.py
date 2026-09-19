"""Local, review-only SCVI intake for one deliberately small Pokémon batch.

This is a source adapter, not a replacement for the Sprite Factory or its
approval gate. It never downloads assets, approves builds, or changes defaults.
"""

import argparse
import concurrent.futures
import hashlib
import html
import json
import math
import subprocess
import traceback
from pathlib import Path


CATEGORIES = {
    "idle": ("battlewait01_loop", "defaultwait01_loop"),
    "physical_attack": ("attack01",),
    "special_attack": ("rangeattack01",),
    "damage": ("damage01",),
    "sleep": ("sleep01_loop",),
    "faint_start": ("down01_start",),
    "faint_loop": ("down01_loop",),
}
PREFIX_PRIORITY = ("2", "0", "1")
LOOPS = {"idle", "sleep", "faint_loop"}
SPEED = {"idle": 1.0, "physical_attack": 1.5, "special_attack": 1.5,
         "damage": 1.0, "sleep": 1.0, "faint_start": 2.0, "faint_loop": 1.0}
EXPECTED_IMPORTER = "b0c98d9fcaab85a04ad35e2d111bae4cad6c1e04"


def digest(path):
    sha = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            sha.update(chunk)
    return sha.hexdigest()


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def compact_action_report(actions):
    """Keep review-relevant action provenance without duplicating frame arrays."""
    return {
        name: {
            "source_action": action["action"],
            "frame_count": len(action["frames"]),
            "source_fps": action["source_fps"],
            "loop": action["loop"],
            "speed": action["speed"],
            "review": action["review"],
        }
        for name, action in actions.items() if action is not None
    }


def source_entry(entry, model_root, motion_root):
    identity = f"pm{entry['pm']:04d}_00_00"
    model = model_root / f"pm{entry['pm']:04d}" / identity
    motion = motion_root / f"pm{entry['pm']:04d}" / identity
    files = sorted(motion.glob(identity + "_*.tranm"))
    chosen = {}
    alternatives = {}
    for category, names in CATEGORIES.items():
        matches = [file for file in files if any(file.stem.endswith("_" + name) for name in names)]
        matches.sort(key=lambda file: (
            next((i for i, name in enumerate(names) if file.stem.endswith("_" + name)), 99),
            next((i for i, prefix in enumerate(PREFIX_PRIORITY)
                  if file.name[len(identity) + 1:].startswith(prefix)), 99),
            file.name,
        ))
        override = entry.get("motion_overrides", {}).get(category)
        if override:
            exact = [file for file in matches if file.name == identity + "_" + override + ".tranm"]
            if len(exact) != 1:
                raise ValueError(f"Configured motion override missing: {identity} {category} {override}")
            chosen[category] = str(exact[0])
        else:
            chosen[category] = str(matches[0]) if matches else None
        alternatives[category] = [file.name for file in matches]
    model_file = model / (identity + ".trmdl")
    icon_file = model / (identity + "_00_big.png")
    rare = sorted(model.glob("*_rare_alb.png"))
    warnings = []
    if not model_file.is_file():
        warnings.append("missing_model")
    if not icon_file.is_file():
        warnings.append("missing_identity_icon")
    if not files:
        warnings.append("missing_all_motions")
    if not rare or not (model / (identity + "_rare.trmtr")).is_file():
        warnings.append("missing_official_rare_albedo")
    warnings += ["missing_action:" + name for name, value in chosen.items() if value is None]
    channels = {}
    for category, value in chosen.items():
        companion = Path(value).with_suffix(".tracm") if value else None
        channels[category] = str(companion) if companion and companion.is_file() else None
    baseline = None
    baseline_suffix = entry.get("facial_baseline_motion")
    if baseline_suffix:
        candidate = motion / (identity + "_" + baseline_suffix + ".tranm")
        if not candidate.is_file():
            raise ValueError(f"Configured facial baseline motion missing: {candidate}")
        baseline = str(candidate)
    return {**entry, "identity": identity, "model_dir": str(model),
            "motion_dir": str(motion), "motions_available": len(files),
            "identity_icon": str(icon_file),
            "motions": chosen, "motion_channels": channels,
            "facial_baseline": baseline, "alternatives": alternatives,
            "rare_albedo_count": len(rare), "warnings": warnings,
            "status": "candidate_needs_action_and_camera_review"}


def inventory(args):
    entries = json.loads(args.batch.read_text())["entries"]
    report = [source_entry(item, args.model_root, args.motion_root) for item in entries]
    write_json(args.output / "intake.json", {"schema": 1, "entries": report})
    for item in report:
        missing = ",".join(item["warnings"]) or "none"
        print(f"{item['species']}: {item['identity']} motions={item['motions_available']} "
              f"rare_albedos={item['rare_albedo_count']} warnings={missing}")


def import_one(args):
    if subprocess.check_output(["git", "-C", str(args.importer), "rev-parse", "HEAD"],
                               text=True).strip() != EXPECTED_IMPORTER:
        raise ValueError("Importer commit does not match the reviewed pin")
    entries = json.loads((args.output / "intake.json").read_text())["entries"]
    item = next((value for value in entries if value["species"] == args.species), None)
    if item is None:
        raise ValueError("Species not present in explicit review batch")
    if any(value in item["warnings"] for value in
           ("missing_model", "missing_identity_icon", "missing_all_motions")):
        raise ValueError("Model, identity icon, or motions missing; no source substitution")
    if args.variant == "shiny" and "missing_official_rare_albedo" in item["warnings"]:
        raise ValueError("Official rare albedo missing; no recolouring")
    destination = args.output / "sources" / item["species"] / args.variant
    blend = destination / (item["identity"] + "-ready.blend")
    report = destination / "import.json"
    if blend.exists() or report.exists():
        if not blend.is_file() or not report.is_file():
            raise ValueError("Partial source output; inspect it before retrying")
        previous = json.loads(report.read_text())
        if previous.get("importer_commit") != EXPECTED_IMPORTER or previous.get("variant") != args.variant:
            raise ValueError("Existing import identity differs")
        if {key: value["name"] if value else None for key, value in previous["actions"].items()} != {
                key: Path(value).stem if value else None for key, value in item["motions"].items()}:
            raise ValueError("Existing import action selection differs; archive it before reimport")
        previous_baseline = previous.get("facial_baseline", {})
        if previous_baseline.get("source") != item["facial_baseline"]:
            if previous_baseline.get("configured") or item["facial_baseline"] is not None:
                raise ValueError("Existing facial baseline differs; archive it before reimport")
        for path, expected in previous.get("source_files", {}).items():
            if not Path(path).is_file() or digest(Path(path)) != expected:
                raise ValueError("Existing imported source no longer matches raw input")
        print(f"EXISTING {item['species']} {args.variant}: {blend}")
        return
    source_files = {}
    for path in sorted(Path(item["model_dir"]).iterdir()):
        if path.is_file() and path.name != "desktop.ini":
            source_files[str(path)] = digest(path)
    for path in item["motions"].values():
        if path is not None:
            source_files[path] = digest(Path(path))
    for path in item["motion_channels"].values():
        if path is not None:
            source_files[path] = digest(Path(path))
    if item["facial_baseline"] is not None:
        source_files[item["facial_baseline"]] = digest(Path(item["facial_baseline"]))
        companion = Path(item["facial_baseline"]).with_suffix(".tracm")
        if companion.is_file():
            source_files[str(companion)] = digest(companion)
    job = {"species": item["species"], "identity": item["identity"],
           "model_dir": item["model_dir"], "motions": item["motions"],
           "motion_channels": item["motion_channels"],
           "facial_baseline": item["facial_baseline"],
           "facial_baseline_frame": item.get("facial_baseline_frame", 0),
           "facial_baseline_categories": item.get(
               "facial_baseline_categories",
               ["idle", "physical_attack", "special_attack", "damage"]),
           "variant": args.variant, "output": str(blend), "report": str(report),
           "importer": str(args.importer), "python_deps": str(args.python_deps),
           "importer_commit": EXPECTED_IMPORTER,
           "shader_sha256": digest(args.importer / "SCVIShader.blend"),
           "source_files": source_files}
    job_path = destination / "job.json"
    write_json(job_path, job)
    worker = Path(__file__).with_name("scvi_import_worker.py").resolve()
    command = ["flatpak", "run", "--unshare=network", "--nofilesystem=host",
               "--filesystem=" + str(args.model_root) + ":ro",
               "--filesystem=" + str(args.motion_root) + ":ro",
               "--filesystem=" + str(args.importer) + ":ro",
               "--filesystem=" + str(args.python_deps) + ":ro",
               "--filesystem=" + str(worker.parent) + ":ro",
               "--filesystem=" + str(args.output), "org.blender.Blender",
               "--background", "--factory-startup", "--disable-autoexec",
               "--python", str(worker), "--", str(job_path)]
    with (destination / "import.log").open("w") as log:
        completed = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=False)
    if completed.returncode or not blend.is_file() or not report.is_file():
        raise RuntimeError(f"Import failed; inspect {destination / 'import.log'}")
    print(f"IMPORTED {item['species']} {args.variant}: {blend}")


def draft_one(args):
    entries = json.loads((args.output / "intake.json").read_text())["entries"]
    item = next((value for value in entries if value["species"] == args.species), None)
    if item is None:
        raise ValueError("Species not in review batch")
    destination = args.output / "sources" / item["species"] / args.variant
    report = json.loads((destination / "import.json").read_text())
    blend = destination / (item["identity"] + "-ready.blend")
    cameras = {}
    presentation = {}
    for view, direction in {"front": [3, -7, 2], "back": [-3, 7, 2]}.items():
        extents = list(report["projected_bounds"][view].values())
        if not extents:
            raise ValueError("No animated geometry bounds")
        left = min(extent[0] for extent in extents)
        bottom = min(extent[1] for extent in extents)
        right = max(extent[2] for extent in extents)
        top = max(extent[3] for extent in extents)
        size = max(right - left, top - bottom)
        if size <= 0:
            raise ValueError("Empty projected bounds")
        ortho = max(0.25, size * 1.25)  # 20% transparent margin across full motion.
        center_x, center_y = (left + right) / 2, (bottom + top) / 2
        dx, dy, dz = direction
        magnitude = math.sqrt(dx * dx + dy * dy + dz * dz)
        forward = [dx / magnitude, dy / magnitude, dz / magnitude]
        right_axis = [-dy / math.hypot(dx, dy), dx / math.hypot(dx, dy), 0]
        up_axis = [forward[1] * right_axis[2] - forward[2] * right_axis[1],
                   forward[2] * right_axis[0] - forward[0] * right_axis[2],
                   forward[0] * right_axis[1] - forward[1] * right_axis[0]]
        target = [right_axis[i] * center_x + up_axis[i] * center_y for i in range(3)]
        position = [target[i] + direction[i] for i in range(3)]
        cameras[view] = {"position": position, "target": target, "ortho_scale": ortho}
        # Framing protects every action; gameplay size is anchored to idle so
        # a lunging attack does not make the resting Pokémon unnaturally tiny.
        idle_extent = report["projected_bounds"][view].get("idle")
        observed_height = (idle_extent[3] - idle_extent[1]) if idle_extent else top - bottom
        master_height = observed_height / ortho * 512
        render_scale = max(1.0, master_height * 1.7 / item["target_game_height_px"])
        anchor = [round(256 - center_x / ortho * 512), round(256 + center_y / ortho * 512)]
        presentation[view] = {"render_scale": round(render_scale, 5), "anchor": anchor,
                              "ground_point": [0, 0, 0], "position_offset": [-10, 7] if view == "front" else [-12, 0],
                              "min_visible_height": item["target_game_height_px"] * 0.7,
                              "max_visible_height": item["target_game_height_px"] * 1.4}
    cameras.update(item.get("camera_override", {}))
    presentation.update(item.get("presentation_override", {}))
    actions = {}
    for category, spec in report["actions"].items():
        if (args.idle_only and category != "idle") or category in item.get("disabled_actions", []):
            actions[category] = None
            continue
        if spec is None:
            actions[category] = None
            continue
        lo, hi = [int(round(value)) for value in spec["range"]]
        actions[category] = {"action": spec["name"], "frames": list(range(lo, hi + 1)),
                             "source_fps": 60, "loop": category in LOOPS,
                             "speed": SPEED[category], "review": "needs_review"}
        if category == "idle" and item.get("idle_neutral_bones"):
            actions[category]["neutral_bones"] = item["idle_neutral_bones"]
    lighting = item.get("light_override", {})
    manifest = {"schema": 1, "species": item["species"], "form": "base",
                "source": {"filename": blend.name, "sha256": digest(blend),
                           "version": "scvi-raw-review-batch-01:" + EXPECTED_IMPORTER,
                           "blender": report["blender"], "accepted_warnings": [],
                           "inspection_note": "Draft only. Action semantics, eyes, lighting, camera and scale need human review. Raw file hashes in import.json."},
                "rig": report["rig"], "review": {"status": "configured"},
                "variants": {"normal": {"available": args.variant == "normal", "material_overrides": {}},
                             "shiny": {"available": args.variant == "shiny", "material_overrides": {}}},
                "render": {"resolution": [512, 512], "fps": 60,
                           "view_transform": "Standard", "look": "Medium High Contrast",
                           "light_target": lighting.get("target", [0, 0, cameras["front"]["target"][2]]),
                           "lights": [{"position": lighting.get("key_position", [3.5, -4.5, 5.5]), "energy": lighting.get("key_energy", 650), "size": 5},
                                      {"position": lighting.get("fill_position", [-4, 3, 3.5]), "energy": lighting.get("fill_energy", 350), "size": 5},
                                      {"position": lighting.get("rim_position", [2, 4, 5]), "energy": lighting.get("rim_energy", 450), "size": 4}],
                           "world_color": lighting.get("world_color", [0.14, 0.14, 0.14])},
                "cameras": cameras, "presentation": presentation, "actions": actions,
                "qc": {"safe_margin": 8, "bounds_jump": 80}}
    path = destination / ("draft-idle-manifest.json" if args.idle_only else "draft-manifest.json")
    if path.exists():
        previous = json.loads(path.read_text())
        accepted = previous.get("source", {}).get("accepted_warnings", [])
        if accepted:
            inspected = destination / "inspection.json"
            if (not inspected.is_file() or accepted != json.loads(inspected.read_text())["warnings"]
                    or not all(w.startswith("unused_empty_texture_node:") for w in accepted)):
                raise ValueError(f"Existing warning acceptance no longer matches inspection: {path}")
            manifest["source"]["accepted_warnings"] = accepted
            manifest["source"]["inspection_note"] += (
                " Inspection confirmed these empty image nodes do not feed active material output."
                " Their output remains subject to visual review.")
        if previous != manifest:
            raise ValueError(f"Existing manifest differs; edit or archive it deliberately: {path}")
    write_json(path, manifest)
    print(f"DRAFT {item['species']} {args.variant}: {path}")


def run_intake(args):
    entries = json.loads((args.output / "intake.json").read_text())["entries"]
    status = {"schema": 1, "variant": args.variant, "idle_only": args.idle_only,
              "entries": {}}
    for item in entries:
        args.species = item["species"]
        try:
            import_one(args)
            draft_one(args)
            source_dir = args.output / "sources" / args.species / args.variant
            blend = source_dir / (item["identity"] + "-ready.blend")
            inspection = source_dir / "inspection.json"
            if not inspection.exists():
                subprocess.run(["python", str(Path(__file__).with_name("factory.py")),
                                "inspect", "--source", str(blend), "--output", str(inspection)],
                               check=True)
            inspected = json.loads(inspection.read_text())
            state = {"status": "configured_needs_review", "blend": str(blend),
                     "inspection": str(inspection), "warnings": inspected["warnings"]}
        except Exception as exc:
            state = {"status": "blocked", "error": str(exc),
                     "traceback": traceback.format_exc(limit=3)}
            print("BLOCKED", item["species"], exc, flush=True)
        status["entries"][args.species] = state
        write_json(args.output / ("intake-status-" + args.variant + ".json"), status)
    print("INTAKE COMPLETE", sum(value["status"] == "configured_needs_review"
                                 for value in status["entries"].values()), "/", len(entries))


def run_builds(args):
    source_status = json.loads((args.output / ("intake-status-" + args.variant + ".json")).read_text())
    entries = json.loads((args.output / "intake.json").read_text())["entries"]
    output = args.output / ("builds-idle" if args.idle_only else "builds-full")
    status_path = args.output / ("build-status-" + args.variant +
                                 ("-idle" if args.idle_only else "-full") + ".json")
    status = json.loads(status_path.read_text()) if status_path.exists() else {
        "schema": 1, "variant": args.variant, "idle_only": args.idle_only, "entries": {}}
    selected = set(args.only.split(",")) if args.only else None
    if selected and not selected <= {item["species"] for item in entries}:
        raise ValueError("--only includes a species outside the explicit batch")
    factory = Path(__file__).with_name("factory.py")

    def build_one(item):
        species = item["species"]
        intake_state = source_status["entries"].get(species, {})
        if intake_state.get("status") != "configured_needs_review":
            return species, {"status": "blocked_intake"}
        source_dir = args.output / "sources" / species / args.variant
        blend = source_dir / (item["identity"] + "-ready.blend")
        manifest = source_dir / ("draft-idle-manifest.json" if args.idle_only else "draft-manifest.json")
        try:
            warnings = intake_state.get("warnings", [])
            if warnings:
                if not args.accept_unused_nodes or not all(
                        warning.startswith("unused_empty_texture_node:") for warning in warnings):
                    raise ValueError("Inspection warnings require explicit manifest review: " + str(warnings))
                config = json.loads(manifest.read_text())
                if config["source"]["accepted_warnings"] != warnings:
                    config["source"]["accepted_warnings"] = warnings
                    config["source"]["inspection_note"] += (
                        " Inspection confirmed these empty image nodes do not feed active material output."
                        " Their output remains subject to visual review.")
                    write_json(manifest, config)
            existing = [path for path in (output / species / args.variant).glob("*/state.json")
                        if json.loads(path.read_text()).get("status") == "needs_review"]
            if existing:
                if len(existing) != 1:
                    raise ValueError("Ambiguous existing builds; inspect manually")
                build = existing[0].parent
                built_manifest = json.loads((build / "provenance.json").read_text())["identity"]["manifest"]
                if built_manifest != json.loads(manifest.read_text()):
                    raise ValueError("Existing build manifest differs from current draft; review and rebuild deliberately")
                subprocess.run(["python", str(factory), "verify", str(build)], check=True,
                               stdout=subprocess.DEVNULL)
            else:
                log_path = args.output / ("build-" + species + "-" + args.variant +
                                          ("-idle" if args.idle_only else "-full") + ".log")
                with log_path.open("w") as log:
                    result = subprocess.run(["python", str(factory), "build", "--manifest", str(manifest),
                                             "--source", str(blend), "--output", str(output),
                                             "--variant", args.variant], stdout=log,
                                            stderr=subprocess.STDOUT, check=False)
                if result.returncode:
                    raise RuntimeError(f"Factory build failed; inspect {log_path}")
                builds = list((output / species / args.variant).glob("*/state.json"))
                if len(builds) != 1:
                    raise RuntimeError("Expected exactly one build")
                build = builds[0].parent
                subprocess.run(["python", str(factory), "verify", str(build)], check=True,
                               stdout=subprocess.DEVNULL)
            qc = json.loads((build / "qc.json").read_text())
            state = {"status": "qc_failed" if qc["errors"] else "needs_review", "build": str(build),
                     "qc_errors": qc["errors"], "qc_warnings": qc["warnings"]}
            print("BUILT", species, "errors", len(qc["errors"]),
                  "warnings", len(qc["warnings"]), flush=True)
        except Exception as exc:
            state = {"status": "blocked", "error": str(exc)}
            print("BLOCKED", species, exc, flush=True)
        return species, state

    pending = [item for item in entries if not selected or item["species"] in selected]
    # Each worker owns a distinct species directory/log. The parent alone
    # updates the shared resumable status file after a completed result.
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as executor:
        futures = [executor.submit(build_one, item) for item in pending]
        for future in concurrent.futures.as_completed(futures):
            species, state = future.result()
            status["entries"][species] = state
            write_json(status_path, status)
    builds = [value["build"] for value in status["entries"].values()
              if value["status"] == "needs_review" and not value["qc_errors"]]
    if builds:
        catalog = args.output / ("preview-" + args.variant +
                                 ("-idle" if args.idle_only else "-full") + ".json")
        subprocess.run(["python", str(factory), "catalog", *builds, "--preview",
                        "--output", str(catalog)], check=True)
        print("PREVIEW CATALOG", catalog)


def preview_catalog(args):
    factory = Path(__file__).with_name("factory.py")
    batch_entries = {entry["species"]: entry for entry in json.loads(args.batch.read_text())["entries"]}
    chosen = {}
    for variant in ("normal", "shiny"):
        for stage in ("idle", "full"):
            path = args.output / f"build-status-{variant}-{stage}.json"
            if not path.exists():
                continue
            report = json.loads(path.read_text())
            for species, item in report["entries"].items():
                if item["status"] == "needs_review" and not item["qc_errors"]:
                    chosen[(species, variant)] = item["build"]
    if not chosen:
        raise ValueError("No verified review builds are available")
    for species in {key[0] for key in chosen}:
        if (species, "normal") in chosen and (species, "shiny") in chosen:
            normal = json.loads((Path(chosen[(species, "normal")]) / "provenance.json").read_text())["identity"]["manifest"]
            shiny = json.loads((Path(chosen[(species, "shiny")]) / "provenance.json").read_text())["identity"]["manifest"]
            for field in ("cameras", "presentation", "actions"):
                if normal[field] != shiny[field]:
                    raise ValueError(f"Normal/shiny {field} differ for {species}; review before cataloguing")
    builds = [chosen[key] for key in sorted(chosen)]
    catalog = args.output / "preview-batch.json"
    subprocess.run(["python", str(factory), "catalog", *builds, "--preview",
                    "--output", str(catalog)], check=True)
    rows = []
    action_report = {"schema": 1, "catalog": str(catalog), "entries": {}}
    expected_actions = ("idle", "physical_attack", "special_attack", "damage",
                        "sleep", "faint_start", "faint_loop")
    for (species, variant), build in sorted(chosen.items()):
        qc = json.loads((Path(build) / "qc.json").read_text())
        manifest = json.loads((Path(build) / "provenance.json").read_text())["identity"]["manifest"]
        actions = manifest["actions"]
        compact_actions = compact_action_report(actions)
        missing = [name for name in expected_actions if not actions.get(name)]
        action_report["entries"][f"{species}:{variant}"] = {
            "species": species,
            "variant": variant,
            "status": "needs_review",
            "build": str(build),
            "actions": compact_actions,
            "missing_actions": missing,
            "qc_errors": qc["errors"],
            "qc_warnings": qc["warnings"],
        }
        preview = Path(build) / "previews" / "index.html"
        overview = Path(build) / "previews" / "overview.png"
        mapping = "<br>".join(
            html.escape(f"{name}: {value['source_action']} ({value['frame_count']}f @ "
                        f"{value['source_fps']} FPS)")
            for name, value in compact_actions.items())
        if missing:
            mapping += "<br><strong>fallback:</strong> " + html.escape(", ".join(missing))
        rows.append("<tr><td>" + html.escape(species) + "</td><td>" + variant +
                    "</td><td><a href='" + html.escape(str(preview)) + "'><img src='" +
                    html.escape(str(overview)) + "' alt='front/back overzicht' width='360'></a><br>" +
                    "<a href='" + html.escape(str(preview)) + "'>Bekijk animaties</a></td>" +
                    "<td>" + mapping + "</td>" +
                    "<td>" + html.escape("; ".join(filter(None, [batch_entries[species].get("review_warning", ""),
                                                       ", ".join(qc["warnings"])])) or "geen") + "</td></tr>")
    write_json(args.output / "action-mappings.json", action_report)
    page = ("<!doctype html><html lang='nl'><meta charset='utf-8'><title>Pokémon reviewbatch 01</title>"
            "<style>body{font:16px system-ui;background:#141722;color:#eee;margin:2rem}"
            "a{color:#8bd4ff}td,th{padding:.6rem;border:1px solid #555}table{border-collapse:collapse}</style>"
            "<h1>Pokémon reviewbatch 01</h1><p>Alleen lokale needs_review-assets. "
            "Open PokeAether met POKEAETHER_RENDERED_PREVIEW_CATALOG=preview-batch.json. "
            "Geen asset is hiermee goedgekeurd of gepubliceerd.</p>"
            "<p><a href='action-mappings.json'>Machineleesbare action mappings</a></p>"
            "<table><tr><th>Pokémon</th><th>Variant</th><th>Previews</th><th>Action mapping</th>"
            "<th>QC-waarschuwingen</th></tr>" +
            "".join(rows) + "</table></html>")
    (args.output / "review-index.html").write_text(page)
    print("PREVIEW CATALOG", catalog)
    print("REVIEW INDEX", args.output / "review-index.html")


def run_probes(args):
    """Render one full-quality idle pose per view for every configured candidate.

    Probes are composition/facial triage only and never enter a game catalog.
    """
    status = json.loads((args.output / ("intake-status-" + args.variant + ".json")).read_text())
    entries = json.loads((args.output / "intake.json").read_text())["entries"]
    factory = Path(__file__).with_name("factory.py")
    probe_root = args.output / "probes" / args.variant
    results = {}
    rows = []
    for item in entries:
        species = item["species"]
        try:
            if status["entries"][species]["status"] != "configured_needs_review":
                raise ValueError("Intake is blocked")
            complete = [p.parent for p in (args.output / "builds-idle" / species / args.variant).glob("*/state.json")
                        if json.loads(p.read_text()).get("status") == "needs_review"]
            if len(complete) > 1:
                raise ValueError("Ambiguous full idle builds")
            if complete:
                build = complete[0]
            else:
                source_dir = args.output / "sources" / species / args.variant
                draft = json.loads((source_dir / "draft-idle-manifest.json").read_text())
                warnings = status["entries"][species]["warnings"]
                if warnings:
                    if not args.accept_unused_nodes or not all(
                            w.startswith("unused_empty_texture_node:") for w in warnings):
                        raise ValueError("Source warnings require explicit review: " + str(warnings))
                    draft["source"]["accepted_warnings"] = warnings
                    draft["source"]["inspection_note"] += " Single-frame probe: disconnected image nodes acknowledged for review."
                draft["actions"]["idle"]["frames"] = draft["actions"]["idle"]["frames"][:1]
                manifest = probe_root / "manifests" / (species + ".json")
                write_json(manifest, draft)
                source = source_dir / (item["identity"] + "-ready.blend")
                log = probe_root / "logs" / (species + ".log")
                log.parent.mkdir(parents=True, exist_ok=True)
                with log.open("w") as stream:
                    process = subprocess.run(["python", str(factory), "build", "--manifest", str(manifest),
                                              "--source", str(source), "--output", str(probe_root / "builds"),
                                              "--variant", args.variant], stdout=stream, stderr=subprocess.STDOUT)
                if process.returncode:
                    raise RuntimeError("Probe failed: " + str(log))
                builds = list((probe_root / "builds" / species / args.variant).glob("*/state.json"))
                if len(builds) != 1:
                    raise ValueError("Expected exactly one probe build")
                build = builds[0].parent
            subprocess.run(["python", str(factory), "verify", str(build)], check=True,
                           stdout=subprocess.DEVNULL)
            qc = json.loads((build / "qc.json").read_text())
            results[species] = {"status": "needs_review" if not qc["errors"] else "qc_failed",
                                "build": str(build), "qc_errors": qc["errors"],
                                "qc_warnings": qc["warnings"]}
            overview = build / "previews" / "overview.png"
            note = item.get("review_warning", "")
            rows.append("<tr><td>" + html.escape(species) + "</td><td><a href='" +
                        html.escape(str(overview)) + "'><img src='" + html.escape(str(overview)) +
                        "' width='480' alt='front and back'></a></td><td>" +
                        html.escape(note or "; ".join(qc["warnings"]) or "Geen waarschuwing; visueel beoordelen") +
                        "</td></tr>")
            print("PROBED", species, "errors", len(qc["errors"]), flush=True)
        except Exception as exc:
            results[species] = {"status": "blocked", "error": str(exc)}
            print("PROBE BLOCKED", species, exc, flush=True)
        write_json(probe_root / "status.json", {"schema": 1, "entries": results})
    page = ("<!doctype html><html lang='nl'><meta charset='utf-8'><title>Pokémon compositieproeven</title>"
            "<style>body{font:16px system-ui;background:#141722;color:#eee;margin:2rem}"
            "a{color:#8bd4ff}td,th{padding:.6rem;border:1px solid #555}table{border-collapse:collapse}</style>"
            "<h1>Front/back idle-triage</h1><p>Een pose of een eerder volledig idle-resultaat per soort. "
            "Deze technische previews zijn geen goedgekeurde battle-assets.</p>"
            "<table><tr><th>Pokémon</th><th>Beeld</th><th>Reviewpunt</th></tr>" +
            "".join(rows) + "</table></html>")
    (probe_root / "index.html").write_text(page)
    print("PROBE INDEX", probe_root / "index.html")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["inventory", "import-one", "draft-one", "run-intake", "run-builds", "run-probes", "preview-catalog"])
    parser.add_argument("--batch", type=Path, default=Path(__file__).with_name("review_batch_01.json"))
    parser.add_argument("--model-root", type=Path, required=True)
    parser.add_argument("--motion-root", type=Path, required=True)
    parser.add_argument("--importer", type=Path, required=True)
    parser.add_argument("--python-deps", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--species")
    parser.add_argument("--only", help="Comma-separated explicit subset for run-builds; preserves other build statuses")
    parser.add_argument("--jobs", type=int, default=1,
                        help="Independent species builds to run concurrently (1-4)")
    parser.add_argument("--variant", choices=["normal", "shiny"], default="normal")
    parser.add_argument("--idle-only", action="store_true",
                        help="Build a first composition review without rendering other actions")
    parser.add_argument("--accept-unused-nodes", action="store_true",
                        help="Explicitly acknowledge only disconnected empty texture nodes")
    args = parser.parse_args()
    args.output = args.output.resolve()
    args.model_root = args.model_root.resolve()
    args.motion_root = args.motion_root.resolve()
    args.importer = args.importer.resolve()
    args.python_deps = args.python_deps.resolve()
    if not 1 <= args.jobs <= 4:
        parser.error("--jobs must be between 1 and 4")
    if args.command not in ("inventory", "run-intake", "run-builds", "run-probes", "preview-catalog") and not args.species:
        parser.error("--species is required")
    {"inventory": inventory, "import-one": import_one, "draft-one": draft_one,
     "run-intake": run_intake, "run-builds": run_builds,
     "run-probes": run_probes,
     "preview-catalog": preview_catalog}[args.command](args)


if __name__ == "__main__":
    main()
