"""Build a non-runtime review catalog for primary and alternate physical attacks.

The input is an identity-gated SCVI inventory plus prepared Blender sources from
``scvi_batch.py``.  Results are suggestions and review media only: this tool
never edits the model registries or enables an alternate attack in game.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import html
import json
import subprocess
from pathlib import Path
from types import SimpleNamespace

from PIL import Image


FAMILIES = ("bite", "claw_slash", "punch", "kick", "body_charge", "tail",
            "wing", "generic", "unclear")
REGION_TO_FAMILY = {
    "jaw": "bite",
    "leg": "kick",
    "tail": "tail",
    "wing": "wing",
    "body": "body_charge",
}
REGION_TO_GROUP = {
    "jaw": "jaw-led",
    "wing": "wing-led",
    "arm": "forelimb-led",
    "leg": "leg-led",
    "tail": "tail-led",
    "body": "body-led",
}


def motion_group(region_scores: dict[str, float], named_coverage: float) -> str:
    scores = {key: max(0.0, float(value)) for key, value in region_scores.items()
              if key != "unknown"}
    ranked = sorted(scores.items(), key=lambda item: (-item[1], item[0]))
    total = sum(scores.values())
    if not ranked or total <= 1e-9 or named_coverage < 0.3:
        return "unknown"
    share = ranked[0][1] / total
    runner_up = ranked[1][1] / total if len(ranked) > 1 else 0.0
    if share < 0.38 or share - runner_up < 0.08:
        return "mixed"
    return REGION_TO_GROUP.get(ranked[0][0], "unknown")


def infer_family(region_scores: dict[str, float], named_coverage: float) -> dict:
    """Make only conservative suggestions from measured local bone motion.

    Arm motion deliberately stays unclear: skeletal motion cannot distinguish a
    punch from a claw/slash.  That distinction always enters the human queue.
    """
    scores = {key: max(0.0, float(value)) for key, value in region_scores.items()}
    ranked = sorted(scores.items(), key=lambda item: (-item[1], item[0]))
    total = sum(scores.values())
    if not ranked or total <= 1e-9 or named_coverage < 0.45:
        return {"family": "unclear", "confidence": 0.0,
                "reason": "insufficient_named_bone_motion", "review_required": True}
    region, value = ranked[0]
    share = value / total
    runner_up = ranked[1][1] / total if len(ranked) > 1 else 0.0
    if region == "arm":
        return {"family": "unclear", "confidence": round(share, 4),
                "reason": "forelimb_motion_cannot_distinguish_claw_from_punch",
                "review_required": True}
    family = REGION_TO_FAMILY.get(region)
    if family is None or share < 0.52 or share - runner_up < 0.18:
        return {"family": "unclear", "confidence": round(share, 4),
                "reason": "mixed_motion_regions", "review_required": True}
    confidence = min(0.99, share * min(1.0, named_coverage / 0.7))
    return {"family": family, "confidence": round(confidence, 4),
            "reason": "dominant_" + region + "_motion", "review_required": False}


def classify_report(report: dict) -> dict:
    clips = {}
    for action in ("physical_attack", "physical_attack_2"):
        metrics = report.get("motion_analysis", {}).get(action)
        if not metrics:
            clips[action] = {"family": "unclear", "confidence": 0.0,
                             "reason": "missing_clip", "review_required": True,
                             "motion_group": "unknown"}
            continue
        clips[action] = infer_family(metrics.get("region_scores", {}),
                                     float(metrics.get("named_coverage", 0.0)))
        clips[action]["motion_group"] = motion_group(
            metrics.get("region_scores", {}), float(metrics.get("named_coverage", 0.0)))
    alternate = clips["physical_attack_2"]
    primary = clips["physical_attack"]
    reasons = []
    # The primary clip is comparison context. Only uncertainty in the alternate
    # blocks its semantic suggestion; a separately reviewed primary label is
    # not required to triage physical_attack_2.
    if alternate["review_required"]:
        reasons.append("alternate_uncertain")
    if (primary["family"] != "unclear" and
            primary["family"] == alternate["family"]):
        reasons.append("same_family_suggestion")
    return {"clips": clips, "queue": "needs_human_review" if reasons else "auto_suggested",
            "queue_reasons": reasons}


def _encode_loop(directory: Path, action: str, timeline: dict) -> str | None:
    frames = sorted((directory / "frames" / action).glob("*.png"))
    if not frames:
        return None
    images = []
    try:
        for path in frames:
            with Image.open(path) as source:
                images.append(source.convert("RGB"))
        durations = timeline.get(action, {}).get("durations_ms", [80] * len(images))
        if len(durations) != len(images):
            raise ValueError("Animation timeline does not match rendered frames")
        target = directory / (action + ".webp")
        images[0].save(target, format="WEBP", save_all=True, append_images=images[1:],
                       lossless=True, method=4, loop=0, duration=durations)
        return target.name
    finally:
        for image in images:
            image.close()
        # These are disposable encoder inputs inside a newly-created review
        # directory. The lossless WebP and analysis JSON are the retained data.
        for path in frames:
            path.unlink()
        frame_dir = directory / "frames" / action
        if frame_dir.exists():
            frame_dir.rmdir()


def _run_entry(entry: dict, prepared: Path, output: Path, worker: Path) -> dict:
    species = entry["species"]
    directory = output / "review" / species
    existing_report = directory / "review.json"
    existing_loops = [directory / (action + ".webp")
                      for action in ("physical_attack", "physical_attack_2")]
    if existing_report.is_file() and all(path.is_file() for path in existing_loops):
        report = json.loads(existing_report.read_text())
        if report.get("classification") and report.get("loops"):
            report["classification"] = classify_report(report)
            existing_report.write_text(json.dumps(report, indent=2) + "\n")
            return {"species": species, "status": "review_ready",
                    "report": str(existing_report.relative_to(output)),
                    "classification": report["classification"], "loops": report["loops"]}
    directory.mkdir(parents=True, exist_ok=True)
    for frame in (directory / "frames").glob("*/*.png"):
        frame.unlink()
    if entry.get("review_route") != "scvi_candidate":
        return {"species": species, "status": "blocked",
                "error": entry.get("identity_error", "identity is not verified")}
    source_dir = prepared / "sources" / species / "normal"
    source = source_dir / (entry["identity"] + "-ready.blend")
    imported = source_dir / "import.json"
    if not source.is_file() or not imported.is_file():
        return {"species": species, "status": "blocked", "error": "prepared source is missing"}
    import_data = json.loads(imported.read_text())
    actions = {name: value["name"] if value else None
               for name, value in import_data.get("actions", {}).items()}
    if not actions.get("physical_attack") or not actions.get("physical_attack_2"):
        return {"species": species, "status": "blocked",
                "error": "prepared source does not contain both physical attack clips"}
    job = {"schema": 1, "species": species, "source": str(source),
           "prepared_sha256": import_data.get("prepared_sha256"), "actions": actions,
           "output": str(directory)}
    job_path = directory / "job.json"
    job_path.write_text(json.dumps(job, indent=2) + "\n")
    command = ["flatpak", "run", "--unshare=network", "--nofilesystem=host",
               "--filesystem=" + str(prepared) + ":ro",
               "--filesystem=" + str(worker.parent) + ":ro",
               "--filesystem=" + str(output), "org.blender.Blender", "--background",
               "--factory-startup", "--disable-autoexec", "--python-exit-code", "1",
               "--python", str(worker), "--", str(job_path)]
    with (directory / "review.log").open("w") as stream:
        result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, timeout=900)
    if result.returncode:
        return {"species": species, "status": "blocked", "error": "Blender review failed"}
    report_path = directory / "review.json"
    report = json.loads(report_path.read_text())
    loops = {action: _encode_loop(directory, action, report.get("timeline", {}))
             for action in ("physical_attack", "physical_attack_2")}
    frames_root = directory / "frames"
    if frames_root.exists():
        frames_root.rmdir()
    classification = classify_report(report)
    report["classification"] = classification
    report["loops"] = loops
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    return {"species": species, "status": "review_ready",
            "report": str(report_path.relative_to(output)), "classification": classification,
            "loops": loops}


def _option(value: str, selected: str) -> str:
    return '<option value="' + value + '"' + (' selected' if value == selected else '') + '>' + value + '</option>'


def build_gallery(output: Path, catalog: dict) -> None:
    rows = []
    template = {"schema": 1, "scope": "physical_attack_semantics_review_only",
                "runtime_approved": False, "entries": {}}
    ordered = sorted(catalog["entries"], key=lambda item: (
        item.get("classification", {}).get("clips", {}).get(
            "physical_attack_2", {}).get("motion_group", "unknown"), item["species"]))
    for entry in ordered:
        species = entry["species"]
        if entry["status"] != "review_ready":
            rows.append('<article class="card blocked"><h2>' + html.escape(species) +
                        '</h2><p>Blocked: ' + html.escape(entry.get("error", "unknown")) + '</p></article>')
            continue
        classification = entry["classification"]
        queued = classification["queue"] == "needs_human_review"
        cells = []
        decisions = {}
        for action, title in (("physical_attack", "Physical attack 1"),
                              ("physical_attack_2", "Physical attack 2")):
            suggestion = classification["clips"][action]
            relative = Path("review") / species / entry["loops"][action]
            select = ''.join(_option(family, suggestion["family"]) for family in FAMILIES)
            cells.append('<section><h3>' + title + '</h3><img loading="lazy" src="' +
                         relative.as_posix() + '" alt="' + html.escape(species + ' ' + title) +
                         '"><label>Classificatie <select data-action="' + action + '">' + select +
                         '</select></label><small>Suggestie: ' + html.escape(suggestion["family"]) +
                         ' · confidence ' + str(suggestion["confidence"]) + '<br>' +
                         html.escape(suggestion["reason"]) + '<br>Motion group: ' +
                         html.escape(suggestion.get("motion_group", "unknown")) + '</small></section>')
            decisions[action] = {"family": suggestion["family"], "source": "automatic_suggestion",
                                 "confirmed": False}
        template["entries"][species] = {"status": "pending_human_confirmation",
                                         "clips": decisions, "note": ""}
        rows.append('<article class="card ' + ('queued' if queued else 'suggested') +
                    '" data-species="' + species + '" data-queue="' + classification["queue"] +
                    '" data-group="' + classification["clips"]["physical_attack_2"].get("motion_group", "unknown") +
                    '"><header><h2>' + html.escape(species) + '</h2><span>' +
                    html.escape(classification["queue"].replace('_', ' ')) + '</span></header><div class="clips">' +
                    ''.join(cells) + '</div><label class="confirm"><input type="checkbox" data-confirm> '
                    'Beide labels visueel bevestigd</label><label>Notitie <input data-note></label></article>')
    (output / "review-decisions.template.json").write_text(json.dumps(template, indent=2) + "\n")
    counts = {key: sum(1 for item in catalog["entries"] if item.get("classification", {}).get("queue") == key)
              for key in ("needs_human_review", "auto_suggested")}
    groups = sorted({item.get("classification", {}).get("clips", {}).get(
        "physical_attack_2", {}).get("motion_group", "unknown") for item in catalog["entries"]})
    group_options = ''.join('<option value="' + html.escape(group) + '">' +
                            html.escape(group) + '</option>' for group in groups)
    embedded_template = json.dumps(template, separators=(",", ":"))
    page = '''<!doctype html><html lang="nl"><meta charset="utf-8"><title>Physical attack review</title>
<style>body{margin:0;background:#0b111a;color:#e8f0fa;font:15px system-ui}main{max-width:1500px;margin:auto;padding:24px}
.toolbar{position:sticky;top:0;z-index:3;background:#101a28ee;padding:14px;border:1px solid #29445d;border-radius:10px}
button,select,input{background:#101c2b;color:#e8f0fa;border:1px solid #397099;border-radius:5px;padding:7px}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(570px,1fr));gap:16px;margin-top:18px}
.card{background:#111d2b;border:1px solid #29445d;border-radius:10px;padding:14px}.card header{display:flex;justify-content:space-between}.clips{display:grid;grid-template-columns:1fr 1fr;gap:12px}.clips section{display:grid;gap:7px}.clips img{width:100%;background:#222;border-radius:7px}.clips small{color:#9db2c7}.confirm{display:block;margin:12px 0}.hidden{display:none}.blocked{border-color:#8d3c48}</style>
<main><h1>Physical attack semantics — review only</h1><p>De loops zijn <b>idle → attack → idle</b>. Automatische labels zijn suggesties; niets wordt hiermee in de game geactiveerd.</p>
<div class="toolbar"><b>''' + str(counts["needs_human_review"]) + ''' handmatige gevallen</b> · ''' + str(counts["auto_suggested"]) + ''' duidelijke suggesties
 <label><input id="onlyQueue" type="checkbox" checked> Alleen handmatige wachtrij</label>
 <label>Bewegingsgroep <select id="group"><option value="">alle</option>''' + group_options + '''</select></label>
 <label>Zoek <input id="search" placeholder="Pokémon"></label>
 <button id="download">Download review-decisions.json</button></div><div class="grid">''' + ''.join(rows) + '''</div></main>
<script>const seed=''' + embedded_template + ''',q=document.getElementById('onlyQueue'),g=document.getElementById('group'),s=document.getElementById('search');function filter(){document.querySelectorAll('.card[data-queue]').forEach(c=>c.classList.toggle('hidden',(q.checked&&c.dataset.queue!=='needs_human_review')||(g.value&&c.dataset.group!==g.value)||(s.value&&!c.dataset.species.includes(s.value.toLowerCase()))))}q.onchange=filter;g.onchange=filter;s.oninput=filter;filter();document.getElementById('download').onclick=()=>{let d=structuredClone(seed);document.querySelectorAll('.card[data-species]').forEach(c=>{let e=d.entries[c.dataset.species],ok=c.querySelector('[data-confirm]').checked;e.status=ok?'confirmed':'pending_human_confirmation';e.note=c.querySelector('[data-note]').value;c.querySelectorAll('select[data-action]').forEach(s=>{e.clips[s.dataset.action]={family:s.value,source:'human_review',confirmed:ok}})});let a=document.createElement('a');a.href=URL.createObjectURL(new Blob([JSON.stringify(d,null,2)+'\\n'],{type:'application/json'}));a.download='review-decisions.json';a.click()};</script></html>'''
    (output / "index.html").write_text(page)


def build(inventory_path: Path, prepared: Path, output: Path, species: set[str] | None,
          jobs: int = 2, resume: bool = False) -> dict:
    if (output.exists() or output.is_symlink()) and not resume:
        raise ValueError("Output directory must not already exist")
    inventory = json.loads(inventory_path.read_text())
    entries = inventory.get("entries", [])
    if species is not None:
        known = {entry["species"] for entry in entries}
        if species - known:
            raise ValueError("Unknown requested species: " + ", ".join(sorted(species - known)))
        entries = [entry for entry in entries if entry["species"] in species]
    if not entries:
        raise ValueError("No review entries selected")
    output.mkdir(parents=True, exist_ok=resume)
    worker = Path(__file__).with_name("physical_attack_review_worker.py").resolve()
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as executor:
        results = list(executor.map(lambda entry: _run_entry(entry, prepared, output, worker), entries))
    catalog = {"schema": 1, "scope": "review_only_not_runtime_mapping",
               "runtime_approved": False, "entries": results}
    (output / "catalog.json").write_text(json.dumps(catalog, indent=2) + "\n")
    build_gallery(output, catalog)
    return catalog


def prepare_sources(inventory_path: Path, prepared: Path, species: set[str] | None,
                    importer: Path, python_deps: Path, model_root: Path,
                    motion_root: Path, jobs: int) -> None:
    """Create only the identity-bound Blender inputs needed by this review."""
    from scvi_batch import import_one
    entries = json.loads(inventory_path.read_text()).get("entries", [])
    if species is not None:
        entries = [entry for entry in entries if entry["species"] in species]
    prepared.mkdir(parents=True, exist_ok=True)

    def prepare(entry):
        if entry.get("review_route") != "scvi_candidate":
            return entry["species"], entry.get("identity_error", "identity is not verified")
        try:
            import_one(SimpleNamespace(output=prepared, species=entry["species"], variant="normal",
                                       identity_entry=entry, importer=importer,
                                       python_deps=python_deps, model_root=model_root,
                                       motion_root=motion_root,
                                       categories=("idle", "physical_attack", "physical_attack_2")))
            return entry["species"], None
        except Exception as error:
            return entry["species"], str(error)

    failures = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as executor:
        for name, error in executor.map(prepare, entries):
            if error:
                failures[name] = error
                print("PREPARE BLOCKED", name, error, flush=True)
            else:
                print("PREPARED", name, flush=True)
    if failures:
        # The review build will retain these as explicit blocked rows. Do not
        # abort successful independent entries or substitute another source.
        (prepared / "prepare-blocks.json").write_text(json.dumps(
            {"schema": 1, "scope": "review_only", "entries": failures}, indent=2) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inventory", required=True, type=Path)
    parser.add_argument("--prepared", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--only", help="comma-separated species subset")
    parser.add_argument("--screened-registry", type=Path,
                        help="select the exact species keys from a screened-model registry")
    parser.add_argument("--jobs", type=int, default=2, choices=range(1, 5))
    parser.add_argument("--resume", action="store_true",
                        help="reuse complete review rows and rerun only interrupted/missing rows")
    parser.add_argument("--prepare-missing", action="store_true",
                        help="identity-bind/import missing Blender review sources first")
    parser.add_argument("--importer", type=Path)
    parser.add_argument("--python-deps", type=Path)
    parser.add_argument("--model-root", type=Path)
    parser.add_argument("--motion-root", type=Path)
    args = parser.parse_args()
    if args.only and args.screened_registry:
        parser.error("use either --only or --screened-registry")
    if args.screened_registry:
        registry = json.loads(args.screened_registry.read_text())
        selected = set(registry.get("models", {}))
        if not selected:
            parser.error("screened registry contains no models")
    else:
        selected = {value.strip() for value in args.only.split(",") if value.strip()} if args.only else None
    inventory = args.inventory.resolve()
    prepared = args.prepared.resolve()
    if args.prepare_missing:
        missing = [name for name in ("importer", "python_deps", "model_root", "motion_root")
                   if getattr(args, name) is None]
        if missing:
            parser.error("--prepare-missing requires " + ", ".join("--" + name.replace("_", "-")
                                                                    for name in missing))
        prepare_sources(inventory, prepared, selected, args.importer.resolve(),
                        args.python_deps.resolve(), args.model_root.resolve(),
                        args.motion_root.resolve(), args.jobs)
    catalog = build(inventory, prepared, args.output.resolve(), selected, args.jobs, args.resume)
    ready = sum(entry["status"] == "review_ready" for entry in catalog["entries"])
    print("PHYSICAL ATTACK REVIEW", ready, "/", len(catalog["entries"]))
    print("REVIEW INDEX", args.output.resolve() / "index.html")


if __name__ == "__main__":
    main()
