"""Build a local, interactive normal/shiny Mega review; no approval is recorded."""
import argparse
import hashlib
import json
import os
from pathlib import Path


HTML = r'''<!doctype html><html lang="nl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Mega Pokémon — 3D review</title><link rel="icon" href="data:,"><style>
:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#101820;color:#e8eff7;font:15px system-ui}header{position:sticky;top:0;z-index:3;background:#172534;padding:12px 18px;border-bottom:1px solid #40556b}h1{margin:0 0 7px;font-size:21px}.controls{display:flex;gap:8px;align-items:center;flex-wrap:wrap}select,input,button{background:#23374a;color:#eef5fc;border:1px solid #58728c;border-radius:5px;padding:7px;font:inherit}main{max-width:1700px;margin:auto;padding:14px;display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,620px),1fr));gap:14px}.card{background:#1c2b3a;border:1px solid #405770;border-radius:9px;padding:12px}.card h2{font-size:18px;margin:0}.meta{color:#bbcad9;font-size:13px;margin:4px 0 8px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:8px}.variant{min-width:0}.label{font-weight:650;padding:4px 2px}.viewer{height:235px;background:#171b20;border:1px solid #263746;border-radius:5px;position:relative;overflow:hidden}.viewer canvas{display:block;width:100%;height:100%}.loading{position:absolute;inset:0;display:grid;place-items:center;color:#bdcbd9;background:#171b20d9;z-index:1}.badges{font-size:12px;color:#e5c38b;margin-top:8px}.error{color:#ffa8a8}.note{max-width:1000px;color:#c9d5e1;margin:0 0 8px}.count{margin-left:auto;color:#c5d1dc}.holds{max-width:1500px;margin:10px auto 30px;padding:16px;border:1px solid #796544;background:#28251e;border-radius:8px}.holds h2{margin-top:0}.holds ul{columns:3;padding-left:22px}.holds li{padding:2px}@media(max-width:650px){main{display:block}.card{margin-bottom:12px}.viewer{height:200px}.holds ul{columns:1}}
</style><header><h1>3D review — Mega Pokémon</h1><p class="note">Normal en shiny naast elkaar. Gebruik de poseknoppen om de bronanimaties te bekijken en sleep op een model om het te draaien. Het model wordt automatisch in beeld gekaderd; deze pagina beoordeelt kleuren, onderdelen en beweging, niet de definitieve grootte in battle. Niets is door deze pagina goedgekeurd of geüpload.</p><div class="controls"><label>Pose <select id="pose"><option value="idle">Stilstand</option><option value="physical_attack">Fysieke aanval</option><option value="physical_attack_2">Tweede fysieke aanval</option><option value="special_attack">Speciale aanval</option><option value="sleep">Slaap</option><option value="damage">Schade</option><option value="faint_start">Flauw</option><option value="faint_loop">Blijft flauw</option></select></label><label><input type="checkbox" id="spin"> langzaam draaien</label><label><input type="checkbox" id="detail"> Ogen dichtbij</label><label><input type="search" id="search" placeholder="Zoek Mega" aria-label="Zoek Mega"></label><span id="count" class="count"></span></div></header><main id="grid"></main><section class="holds"><h2>Bronnen en bestaande dekking</h2><p id="approved"></p><p>Voor deze vormen staat in de aangesloten Legends ZA-dump geen Mega-model. Ze blijven op 2.5D tot er een passende bron gevonden is.</p><ul id="missing"></ul></section>
<script type="importmap">{"imports":{"three":"./node_modules/three/build/three.module.js"}}</script>
<script id="data" type="application/json">__DATA__</script><script type="module">
import * as THREE from 'three';
import {GLTFLoader} from './node_modules/three/examples/jsm/loaders/GLTFLoader.js';
import {OrbitControls} from './node_modules/three/examples/jsm/controls/OrbitControls.js';
const data=JSON.parse(document.querySelector('#data').textContent),grid=document.querySelector('#grid'),pose=document.querySelector('#pose'),live=new Map(),loader=new GLTFLoader();
function esc(s){return s.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
for(const row of data.entries){const card=document.createElement('article');card.className='card';card.dataset.id=row.id;card.dataset.name=(row.name+' '+row.form).toLowerCase();card.innerHTML=`<h2>${esc(row.form)}</h2><div class="meta">${esc(row.name)} · ${row.actions.includes('physical_attack_2')?'2 fysieke aanvallen':'1 fysieke aanval in bron'}${row.cross_sleep?' · slaap gebruikt basisvormclip':row.native_rest?' · eigen Mega-rusthouding voor slaap':''}${row.dynamic_visibility?' · dynamische mesh-zichtbaarheid':''}</div><div class="pair">${['normal','shiny'].map(v=>`<section class="variant"><div class="label">${v==='normal'?'Normal':'Shiny'}</div><div class="viewer" data-id="${esc(row.id)}" data-variant="${v}"><div class="loading">Laden wanneer zichtbaar…</div></div></section>`).join('')}</div>${row.notes.length?`<div class="badges">Controlepunten: ${esc(row.notes.join(' · '))}</div>`:''}`;grid.append(card)}
function dispose(el){const r=live.get(el);if(!r)return;r.controls.dispose();r.renderer.dispose();r.mixer.stopAllAction();r.scene.traverse(o=>{if(o.geometry)o.geometry.dispose();if(o.material){for(const k of Object.keys(o.material))if(o.material[k]?.isTexture)o.material[k].dispose();o.material.dispose()}});el.replaceChildren();live.delete(el)}
async function mount(el){if(live.has(el))return;el.querySelector('.loading')?.remove();const row=data.byId[el.dataset.id],variant=el.dataset.variant,entry=row.variants[variant];const overlay=document.createElement('div');overlay.className='loading';overlay.textContent='Model laden…';el.append(overlay);const scene=new THREE.Scene();scene.background=new THREE.Color(0x171b20);const camera=new THREE.PerspectiveCamera(33,1,.01,1000);const renderer=new THREE.WebGLRenderer({antialias:true,alpha:false});renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1;el.append(renderer.domElement);scene.add(new THREE.HemisphereLight(0xffffff,0x536173,2));const key=new THREE.DirectionalLight(0xffffff,3);key.position.set(3,6,5);scene.add(key);const fill=new THREE.DirectionalLight(0xc3ddff,1.3);fill.position.set(-5,2,-3);scene.add(fill);const controls=new OrbitControls(camera,renderer.domElement);controls.enableDamping=true;controls.target.set(0,.5,0);let gltf;try{gltf=await loader.loadAsync(entry.url)}catch(err){overlay.textContent='Model kon niet worden geladen';overlay.classList.add('error');console.error(entry.url,err);return}const actor=gltf.scene;scene.add(actor);const bounds=new THREE.Box3().setFromObject(actor),size=bounds.getSize(new THREE.Vector3()),center=bounds.getCenter(new THREE.Vector3());actor.position.x-=center.x;actor.position.z-=center.z;actor.position.y-=bounds.min.y;const max=Math.max(size.x,size.y,size.z,.1);controls.target.set(0,size.y*.5,0);camera.position.set(max*1.55,max*.65,max*2.5);camera.near=Math.max(.005,max*.001);camera.far=max*80;camera.updateProjectionMatrix();controls.update();const mixer=new THREE.AnimationMixer(actor);const clips=Object.fromEntries(gltf.animations.map(c=>[c.name,c]));const nodeMap=new Map();actor.traverse(o=>nodeMap.set(o.name,o));function frame(follow=false){actor.updateMatrixWorld(true);const box=new THREE.Box3();actor.traverse(o=>{const materials=Array.isArray(o.material)?o.material:[o.material];if(o.isMesh&&materials.some(m=>m&&/eye/i.test(m.name)))box.expandByObject(o,true)});if(document.querySelector('#detail').checked&&!box.isEmpty()){const c=box.getCenter(new THREE.Vector3()),s=box.getSize(new THREE.Vector3()),m=Math.max(s.x,s.y,s.z,.12);if(follow){camera.position.add(c.clone().sub(controls.target));controls.target.copy(c)}else{controls.target.copy(c);camera.position.copy(c).add(new THREE.Vector3(m*1.1,m*.2,m*3.2))}}else{const visible=new THREE.Box3();actor.traverse(o=>{if(!o.isMesh)return;let shown=true;for(let p=o;p;p=p.parent){if(!p.visible){shown=false;break}}if(shown)visible.expandByObject(o,true)});if(!visible.isEmpty()){const c=visible.getCenter(new THREE.Vector3()),s=visible.getSize(new THREE.Vector3()),m=Math.max(s.x,s.y,s.z,.1);controls.target.copy(c);camera.position.copy(c).add(new THREE.Vector3(m*1.1,m*.5,m*1.9))}}controls.update()}
let action=null,raf=0,last=performance.now();function applyVisibility(name,time){const clip=row.visibility.clips[name];if(!clip)return;for(const track of clip.tracks){const node=nodeMap.get(track.mesh);if(!node)continue;let value=track.keys[0]?.[1]??true;for(const key of track.keys){if(key[0]<=time+1e-5)value=key[1];else break}node.visible=value}}
function select(){const wanted=pose.value;mixer.stopAllAction();const clip=clips[wanted];if(!clip){overlay.textContent='Deze bron heeft deze pose niet';el.append(overlay);return}action=mixer.clipAction(clip);action.reset();action.enabled=true;action.setLoop((wanted==='idle'||wanted==='sleep'||wanted==='faint_loop')?THREE.LoopRepeat:THREE.LoopOnce,(wanted==='idle'||wanted==='sleep'||wanted==='faint_loop')?Infinity:1);action.clampWhenFinished=true;action.play();applyVisibility(wanted,0);overlay.remove()}function onPose(){select()}el.addEventListener('mega-pose',onPose);
function resize(){const w=Math.max(1,el.clientWidth),h=Math.max(1,el.clientHeight);renderer.setSize(w,h,false);camera.aspect=w/h;camera.updateProjectionMatrix()}const ro=new ResizeObserver(resize);ro.observe(el);function draw(now){raf=requestAnimationFrame(draw);const delta=Math.min((now-last)/1000,.05);last=now;if(action){mixer.update(delta);applyVisibility(pose.value,action.time);if(document.querySelector('#spin').checked)actor.rotation.y+=delta*.18}if(document.querySelector('#detail').checked)frame(true);controls.update();renderer.render(scene,camera)}select();mixer.update(0);frame();resize();draw(last);live.set(el,{renderer,scene,camera,controls,mixer,ro,frame,dispose:()=>cancelAnimationFrame(raf)});el._megaDispose=()=>{cancelAnimationFrame(raf);ro.disconnect();el.removeEventListener('mega-pose',onPose);dispose(el)}}
const initial=new URLSearchParams(location.search);document.querySelector('#detail').checked=initial.get('detail')==='eyes';if(initial.get('q')){document.querySelector('#search').value=initial.get('q');for(const c of grid.children)c.hidden=data.byId[initial.get('q')]?c.dataset.id!==initial.get('q'):!c.dataset.name.includes(initial.get('q').toLowerCase())}
document.querySelector('#detail').addEventListener('change',()=>{for(const state of live.values())state.frame()});
const io=new IntersectionObserver(entries=>{for(const e of entries){const el=e.target;if(e.isIntersecting){mount(el)}else if(e.boundingClientRect.bottom< -900||e.boundingClientRect.top>innerHeight+900){el._megaDispose?.()}}},{rootMargin:'500px'});document.querySelectorAll('.viewer').forEach(v=>io.observe(v));
pose.addEventListener('change',()=>{for(const el of document.querySelectorAll('.viewer'))if(live.has(el))el.dispatchEvent(new Event('mega-pose'))});
document.querySelector('#search').addEventListener('input',e=>{let n=0;for(const c of grid.children){c.hidden=!c.dataset.name.includes(e.target.value.trim().toLowerCase());if(!c.hidden)n++}document.querySelector('#count').textContent=`${n} / ${data.entries.length} reviewparen`});document.querySelector('#count').textContent=`${[...grid.children].filter(c=>!c.hidden).length} / ${data.entries.length} reviewparen`;document.querySelector('#approved').textContent='Al goedgekeurd: '+(data.approvedExisting.length?data.approvedExisting.join(', '):'geen');for(const name of data.heldNames){const li=document.createElement('li');li.textContent=name;document.querySelector('#missing').append(li)}
</script></html>'''


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build(status_path: Path, output: Path):
    status = json.loads(status_path.read_text())
    entries, seen = [], set()
    for row in status["entries"]:
        if row.get("status") not in ("runtime_candidate", "export_candidate"):
            continue
        identity = row["showdown_id"]
        if identity in seen:
            raise ValueError("Duplicate Mega form " + identity)
        seen.add(identity)
        variants = {}
        for variant in ("normal", "shiny"):
            model = row["variants"][variant]
            path = Path(model["path"])
            if not path.is_file() or digest(path) != model["sha256"]:
                raise ValueError("Model or hash missing: " + identity + "/" + variant)
            variants[variant] = {"url": Path(os.path.relpath(path, output)).as_posix(),
                                 "sha256": model["sha256"]}
        notes = []
        if row.get("cross_bank_sleep_review_required"):
            notes.append("slaapclip van basisvorm")
        if row.get("native_rest_sleep_review_required"):
            notes.append("slaap: eigen Mega-rusthouding, visueel te beoordelen")
        if row.get("visibility", {}).get("dynamic_visibility_review_required"):
            notes.append("dynamische mesh-zichtbaarheid")
        inherited = [w for w in row.get("warnings", []) if w.startswith("inherited_eyelid_pose:")]
        if inherited:
            notes.append("oogleden: bronwaarschuwing")
        material = [w for w in row.get("warnings", []) if w.startswith("unapplied_tracm_material:")]
        if material:
            notes.append("bronmateriaal-animatie niet overgezet")
        actions = sorted(row["actions"])
        entries.append({"id": identity, "name": row["showdown_id"],
                        "form": row["showdown_id"].replace("mega", " Mega ").replace("-", " ").title(),
                        "actions": actions, "animations": row["actions"],
                        "variants": variants, "visibility": row["visibility"],
                        "cross_sleep": bool(row.get("cross_bank_sleep_review_required")),
                        "native_rest": bool(row.get("native_rest_sleep_review_required")),
                        "dynamic_visibility": bool(row.get("visibility", {}).get("dynamic_visibility_review_required")),
                        "notes": notes})
    intake = json.loads(Path(__file__).with_name("catalog_mega_3d_source_intake.json").read_text())
    held_rows = [row for row in intake["entries"] if not row.get("source_resource_id")]
    approved_existing = [row["name"].replace("-", " ").title() for row in intake["entries"]
                         if row.get("approved_3d_bundle")]
    data = {"entries": entries, "held": len(held_rows),
            "heldNames": [row["name"].replace("-", " ").title() for row in held_rows],
            "approvedExisting": approved_existing}
    data["byId"] = {r["id"]: r for r in entries}
    payload = json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("<", "\\u003c")
    output.mkdir(parents=True, exist_ok=False)
    (output / "index.html").write_text(HTML.replace("__DATA__", payload))
    manifest = {"runtime_approved": False, "appearance_approved": False,
                "entry_count": len(entries), "source_hold_count": data["held"],
                "status_sha256": digest(status_path),
                "models": {f"{r['id']}:{v}": r["variants"][v]["sha256"]
                           for r in entries for v in ("normal", "shiny")}}
    (output / "review-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"review_pairs": len(entries), "source_holds": data["held"],
                      "page": str(output / "index.html")}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--status", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    build(args.status.resolve(), args.output.resolve())
