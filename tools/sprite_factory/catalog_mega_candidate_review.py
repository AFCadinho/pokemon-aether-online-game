"""Render hash-bound Mega candidate SCNs; never grant visual/battle approval."""
import argparse
import json
import os
from pathlib import Path
import subprocess

from catalog_mega_3d_production import HERE, SLOT, WORKSPACE, sha, write


HTML = r'''<!doctype html><html lang="nl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Mega kandidaten — Godot review</title><style>
:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#101820;color:#e8eff7;font:16px system-ui}header{position:sticky;top:0;background:#172534;padding:12px 18px;z-index:2}h1{font-size:22px;margin:0 0 8px}p{margin:8px 0}select,input,button{background:#23374a;color:inherit;border:1px solid #58728c;border-radius:5px;padding:7px;font:inherit}main{padding:14px;display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,560px),1fr));gap:14px}.card{background:#1c2b3a;border:1px solid #405770;border-radius:9px;padding:12px}.card h2{margin:0 0 8px;font-size:20px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:8px}figure{margin:0}img.model{width:100%;cursor:zoom-in;background:#202020}figcaption{padding:4px}.refs{display:flex;gap:10px;margin:8px 0}.refs img{width:90px;height:90px;object-fit:contain}.note{font-size:13px;color:#c9d5e1}dialog{max-width:98vw;width:1500px;background:#172534;color:inherit;border:1px solid #58728c}dialog::backdrop{background:#000b}dialog img.model{cursor:auto}a{color:#80cbff}.controls{display:flex;flex-wrap:wrap;gap:8px;align-items:center}
</style><header><h1>Laatste Mega-kandidaten — normal en shiny</h1><p>Dit zijn beelden van de zelfstandige Godot-modellen. Controleer kleuren, ogen, onderdelen en poses. De camera kadert elk model automatisch; battle-grootte en plaatsing volgen apart. Klik op een model voor de grote vergelijking. <a href="../animated-review-v2/">Animaties afspelen en modellen draaien</a>.</p><div class="controls"><select id="pose"><option value="idle-front">Stilstand</option><option value="idle-back">Achterkant</option><option value="physical_attack-front">Fysieke aanval</option><option value="special_attack-front">Speciale aanval</option><option value="damage-front">Schade</option><option value="sleep-front">Slaap / rust</option><option value="faint_start-front">Flauw</option><option value="faint_loop-front">Blijft flauw</option></select><input id="search" placeholder="Zoek Pokémon"><label><input id="refs" type="checkbox" checked>Broniconen</label><span id="count"></span></div><p class="note" id="holds"></p></header><main></main><dialog><button id="close">Sluiten</button><h2></h2><div id="large"></div></dialog><script id="data" type="application/json">__DATA__</script><script>
const data=JSON.parse(document.querySelector('#data').textContent),$=id=>document.getElementById(id),main=document.querySelector('main');let selected=null;
function pair(row){const div=document.createElement('div');div.className='pair';for(const variant of ['normal','shiny']){const figure=document.createElement('figure'),label=document.createElement('figcaption'),image=document.createElement('img');label.textContent=variant==='normal'?'Normal':'Shiny';image.className='model';image.loading='lazy';image.alt=row.name+' '+label.textContent;image.src=row.variants[variant][$('pose').value];image.onclick=()=>{selected=row;document.querySelector('dialog h2').textContent=row.name;$('large').replaceChildren(pair(row));document.querySelector('dialog').showModal()};figure.append(label,image);div.append(figure)}return div}
function render(){let count=0;main.replaceChildren();for(const row of data.entries){if(!row.name.toLowerCase().includes($('search').value.toLowerCase()))continue;count++;const card=document.createElement('article');card.className='card';const title=document.createElement('h2');title.textContent=row.name;card.append(title,pair(row));if($('refs').checked){const refs=document.createElement('div');refs.className='refs';for(const v of ['normal','shiny']){const image=document.createElement('img');image.src=row.icons[v];image.alt='Bronicoon '+v;refs.append(image)}card.append(refs)}const note=document.createElement('p');note.className='note';note.textContent=row.notes;card.append(note);main.append(card)}$('count').textContent=count+' / '+data.entries.length+' Pokémon';if(selected&&document.querySelector('dialog').open)$('large').replaceChildren(pair(selected))}
for(const id of ['pose','refs'])$(id).onchange=render;$('search').oninput=render;$('close').onclick=()=>document.querySelector('dialog').close();$('holds').textContent=data.holds;render();
</script></html>'''


def prepare(status: Path, source: Path, output: Path, expected_count: int):
    batch = json.loads(status.read_text())
    if batch["total"] != expected_count or batch["processed"] != expected_count:
        raise ValueError("Incomplete candidate batch")
    if batch["held"]:
        raise ValueError("Resolve production holds before the combined final review")
    audit = json.loads((HERE / "catalog_mega_25_source_audit.json").read_text())
    mappings = {row["showdown_id"]: row for row in audit["entries"]}
    rows, display = [], []
    for candidate in batch["entries"]:
        if candidate["status"] != "runtime_candidate":
            raise ValueError("Standalone runtime candidate missing")
        identity = candidate["showdown_id"]
        mapping = mappings[identity]
        scenes = {row["species"]: row for row in candidate["runtime_scenes"]}
        variants, icons = {}, {}
        for variant, model in candidate["variants"].items():
            species = identity + ("-shiny" if variant == "shiny" else "")
            scene = scenes[species]
            if sha(Path(model["path"])) != model["sha256"] or scene["glb_sha256"] != model["sha256"]:
                raise ValueError("Changed candidate GLB: " + species)
            if sha(Path(scene["runtime_path"])) != scene["runtime_sha256"]:
                raise ValueError("Changed standalone candidate: " + species)
            poses = [[name, 1 if name == "faint_start" else 0 if name == "idle" else .5, "front"]
                     for name in candidate["actions"]]
            poses.append(["idle", .5, "back"])
            rows.append({**scene, "status": "exported_for_review", "animations": candidate["actions"],
                         "review_poses": poses, "material_limitations": "Static native material tables; own Mega rest loop as sleep. Not battle-qualified."})
            variants[variant] = {action + "-" + view: species + "-" + action + "-" + view + ".png"
                                 for action, _, view in poses}
            marker = mapping.get("source_icon_variant_marker") or ""
            code = "0" if variant == "normal" else "1"
            icon_name = candidate["identity"] + "_00_" + code + marker + ".png"
            icon = source / candidate["identity"][:6] / candidate["identity"] / "icon" / icon_name
            evidence = next(item for item in audit["source_resources"][candidate["identity"]]["normal_and_shiny_icon_evidence"]
                            if Path(item["archive_member"]).name == icon_name)
            if sha(icon) != evidence["sha256"]:
                raise ValueError("Changed source reference icon")
            icons[variant] = Path(os.path.relpath(icon, output)).as_posix()
        name = mapping["species"].replace("-", " ").title()
        notes = "Slaap gebruikt de eigen Mega-rusthouding. Bron bevat één fysieke aanval."
        if identity.startswith("tatsugiri"):
            notes += " Gedeeld bronmodel met alle drie de vissen; vergelijk met het bijbehorende bronicoon."
        display.append({"id": identity, "name": name, "variants": variants, "icons": icons, "notes": notes})
    output.mkdir(parents=True, exist_ok=False)
    write(output / "catalog.json", {"entries": rows, "runtime_approved": False,
          "source_status_sha256": sha(status), "source_audit_sha256": sha(HERE / "catalog_mega_25_source_audit.json")})
    write(output / "page-data.json", {"entries": display,
          "holds": "Mega Meowstic (vrouwelijk): bronkoppeling nog niet bevestigd. Geen van deze kandidaten is al battle-goedgekeurd of geüpload."})
    project = output / "render-project"
    project.mkdir()
    (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Mega candidate review"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    (project / "tools").symlink_to(HERE.parent, target_is_directory=True)


def finish(output: Path):
    report = json.loads((output / "godot-review.json").read_text())
    catalog = json.loads((output / "catalog.json").read_text())
    if {r["species"] for r in report["entries"]} != {r["species"] for r in catalog["entries"]}:
        raise ValueError("Incomplete native pose review")
    failures = {r["species"]: r.get("errors", ["No pose evidence"]) for r in report["entries"] if r.get("errors") or not r.get("clips")}
    if failures:
        raise ValueError("Native pose/timing errors: " + json.dumps(failures))
    data = json.loads((output / "page-data.json").read_text())
    for row in data["entries"]:
        for variant in row["variants"].values():
            for image in variant.values():
                if not (output / image).is_file():
                    raise ValueError("Missing review capture " + image)
    payload = json.dumps(data, ensure_ascii=False).replace("<", "\\u003c")
    (output / "index.html").write_text(HTML.replace("__DATA__", payload))
    write(output / "review-manifest.json", {"appearance_approved": False, "runtime_approved": False,
          "pair_count": len(data["entries"]), "variant_count": len(report["entries"]),
          "catalog_sha256": sha(output / "catalog.json"), "native_pose_report_sha256": sha(output / "godot-review.json"),
          "captures": {p.name: sha(p) for p in sorted(output.glob("*.png"))}})
    print("Native pose/timing review passed:", len(report["entries"]), "variants; page:", output / "index.html")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--status", type=Path, required=True)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--expected-count", type=int, default=24)
    args = parser.parse_args()
    output = args.output.resolve()
    prepare(args.status.resolve(), args.source_root.resolve(), output, args.expected_count)
    env = {**os.environ, "POKEAETHER_PHASE5_REVIEW": str(output)}
    with (output / "renderer.log").open("w") as log:
        subprocess.run([str(WORKSPACE / "ops/worktrees/slot-env"), SLOT.name, "--", "godot",
                        "--path", str(output / "render-project"), "--script",
                        "res://tools/sprite_factory/catalog_mega_candidate_runtime_review.gd"],
                       env=env, stdout=log, stderr=subprocess.STDOUT, timeout=1800, check=True)
    finish(output)
