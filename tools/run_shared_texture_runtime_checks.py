#!/usr/bin/env python3
"""Isolated native checks using linked source files, without app autoloads."""
import argparse
from pathlib import Path
import re
import subprocess
import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from probe_v13_compression import read, write, checked_bytes, unpack_pck
from study_lossless_texture_storage import sha
from probe_v13_compression import require
from study_lossless_texture_storage import ROOT
from resume_isolated_texture_audit import PROJECT


def project(output, scripts):
    folder=output/'native-project'
    folder.mkdir(parents=True,exist_ok=True)
    config=folder/'project.godot'
    settings=PROJECT.replace('PokeAether offline texture probe','PokeAether shared textures '+output.name)
    if config.exists(): require(config.read_text()==settings,'Changed probe configuration')
    else: config.write_text(settings)
    todo=[*scripts,'scripts/data/pokemon.gd',*[str(p.relative_to(ROOT)) for p in (ROOT/'data').glob('*.json')]]
    seen=set()
    required_binary=set()
    while todo:
        name=todo.pop()
        if name in seen: continue
        source=ROOT/name
        if not source.is_file(): continue
        if source.suffix in ['.glb','.gltf','.fbx','.blend'] and name not in required_binary: continue
        seen.add(name)
        target=folder/name
        target.parent.mkdir(parents=True,exist_ok=True)
        if target.is_symlink(): require(target.resolve()==source.resolve(),'Changed source link')
        else:
            require(not target.exists(),'Unexpected probe copy')
            target.symlink_to(source)
        sidecar=source.with_name(source.name+'.uid')
        if sidecar.is_file():
            linked=target.with_name(target.name+'.uid')
            if not linked.exists(): linked.symlink_to(sidecar)
        if source.suffix=='.glb':
            import struct
            data=source.read_bytes()
            length,kind=struct.unpack_from('<II',data,12)
            require(kind==0x4e4f534a,'Unsupported GLB source')
            gltf=json.loads(data[20:20+length])
            for entry in [*gltf.get('images',[]),*gltf.get('buffers',[])]:
                uri=entry.get('uri','')
                if not uri or uri.startswith('data:'): continue
                external=(source.parent/uri).resolve()
                require(external.is_relative_to(ROOT),'External GLB URI left slot')
                todo.append(str(external.relative_to(ROOT)))
        if source.suffix in ['.gd','.tres','.tscn','.gdshader']:
            text=source.read_text()
            # Static resources and dynamically named checked-in files.
            for match in re.finditer(r'["\'](res://[^"\']+)["\']',text):
                relative=match[1][6:]
                if source.suffix in ['.tres','.tscn'] or ('preload("'+match[1]+'")') in text:
                    required_binary.add(relative)
                todo.append(relative)
            for match in re.finditer(r'(?:preload|load)\(["\']([^"\']+)["\']\)',text):
                if not match[1].startswith('res://'):
                    todo.append(str((Path(name).parent/match[1])))
    # The tracked FBX embeds its exporter-era Unity texture path. Recreate
    # that source alias in this probe project using the game's matching PNG.
    # No import options or caches are copied from the normal project.
    png=ROOT/'assets/models/battle/substitute/ob0301_00_body_col.png'
    alias=folder/'assets/models/New Unity Project/Assets/ob0301_00_body_col.png'
    alias.parent.mkdir(parents=True,exist_ok=True)
    if not alias.exists(): alias.symlink_to(png)
    return folder


def run(folder, script, output, args=()):
    output.mkdir(parents=True,exist_ok=False)
    log=output/'stdout.log'
    with log.open('w') as stream:
        result=subprocess.run(['godot','--audio-driver','Dummy','--rendering-method','gl_compatibility',
            '--path',str(folder),'--log-file',str(output/'engine.log'),'--script','res://'+script,'--',*map(str,args)],
            stdout=stream,stderr=subprocess.STDOUT,timeout=600)
    text=log.read_text()
    require(result.returncode==0 and 'ERROR:' not in text and 'SCRIPT ERROR' not in text,f'Native check failed: {log}')
    return text


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',required=True,type=Path)
    parser.add_argument('--pilot',type=Path,default=ROOT/'.tmp/shared-texture-runtime-v1/configuration.json')
    args=parser.parse_args()
    output=args.output.resolve()
    require(output.is_relative_to(ROOT/'.tmp'),'Checks must stay in assigned slot')
    output.mkdir(parents=True,exist_ok=False)
    scripts=['tests/shared_texture_contract_check.gd','tests/shared_texture_runtime_check.gd','tests/approved_3d_release_v15_check.gd']
    folder=project(output,scripts)
    inputs={str(p.relative_to(folder)): {'source':str(p.resolve().relative_to(ROOT)), 'sha256':sha(p)}
            for p in folder.rglob('*') if p.is_symlink()}
    code=['tools/run_shared_texture_runtime_checks.py','tools/prepare_shared_texture_runtime_pilot.py',
          'tools/probe_v13_compression.py','tools/study_shared_form_textures.py','tools/study_lossless_texture_storage.py']
    driver_inputs={p:sha(ROOT/p) for p in code}
    with (output/'import.log').open('w') as stream:
        imported=subprocess.run(['godot','--headless','--editor','--path',str(folder),'--log-file',str(output/'import-engine.log'),'--import'],stdout=stream,stderr=subprocess.STDOUT,timeout=180)
    require(imported.returncode==0 and 'ERROR:' not in (output/'import.log').read_text(),'Isolated project import failed')
    text=run(folder,scripts[0],output/'contract')
    require('SHARED_TEXTURE_CONTRACT_OK' in text,'Native contract did not complete')
    print(text,flush=True)
    legacy=run(folder,scripts[2],output/'legacy-v15')
    require('APPROVED_3D_V15_OK' in legacy,'Legacy v15 bindings failed')
    print(legacy,flush=True)
    fixture=read(args.pilot)
    require(sha(ROOT/'data/model_texture_pilot_catalog.json')==fixture['catalog_sha256'],'Pilot catalog changed')
    parent=read(ROOT/'release/shared_form_texture_study_v15.json')
    source=read(Path(parent['report_path']).parent/'source/report.json')
    require(sha(Path(parent['report_path']).parent/'source/report.json')==parent['source_report_sha256'],'Changed source native proof')
    paths={j['asset']['object_key']:Path(j['path']) for j in [fixture['pool'],*fixture['jobs']]}
    catalog=ROOT/'data/model_texture_pilot_catalog.json'
    pin_sha=sha(catalog)
    paths['optional-assets/pokemon_3d/index/pilot-'+pin_sha+'.json']=catalog
    pool_key=fixture['pool']['asset']['object_key']
    requests=[]
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            key=self.path.removeprefix('/')
            path=paths.get(key)
            requests.append(key)
            if key==pool_key and requests.count(key)==1:
                self.send_error(503,'Injected pool failure');return
            if path is None: self.send_error(404);return
            data=path.read_bytes()
            self.send_response(200);self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
        def log_message(self,*_args): pass
    server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
    thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
    input_path=output/'runtime-input.json'
    write(input_path,{'origin':f'http://127.0.0.1:{server.server_port}/',**fixture,'source_models':source['models']})
    try:
        for mode in ['cold','restart']:
            text=run(folder,scripts[1],output/mode,[input_path,output/mode,mode])
            require('SHARED_TEXTURE_RUNTIME_OK' in text,'Runtime did not complete')
            print(text,flush=True)
    finally:
        server.shutdown();server.server_close();thread.join()
        write(output/'http-requests.json',requests)
    require(inputs=={str(p.relative_to(folder)): {'source':str(p.resolve().relative_to(ROOT)), 'sha256':sha(p)}
            for p in folder.rglob('*') if p.is_symlink()},'Linked inputs changed during qualification')
    require(driver_inputs=={p:sha(ROOT/p) for p in code},'Driver inputs changed during qualification')
    for job in [fixture['pool'],*fixture['jobs']]: unpack_pck(checked_bytes(job['path'],job['asset']),job['asset'])
    cold=read(output/'cold/report.json');restart=read(output/'restart/report.json')
    require(cold['models']==restart['models']==source['models'],'Native source/restart state changed')
    require(cold['complete'] and restart['complete'] and len(cold['models'])==16 and
            len(cold['battles'])==len(restart['battles'])==8 and
            cold['pool_http_requests']==3 and restart['pool_http_requests']==0,'Incomplete runtime coverage')
    total=sum(j['asset']['size_bytes'] for j in [fixture['pool'],*fixture['jobs']])
    before=parent['pilot_before_bytes']
    baseline=read(ROOT/'release/full_texture_storage_audit_v15.json')
    combined=baseline['selected_collection_bytes']-before+total
    reports={mode:{name:sha(output/mode/name) for name in ['stdout.log','engine.log','report.json']}
             for mode in ['cold','restart']}
    screenshots={str(p.relative_to(output)):sha(p) for p in output.glob('*/*.png')}
    receipt={'schema':1,'complete':True,'prototype_only':True,'production_approved':False,
        'qualification':'linux-shared-texture-pilot','pilot_pairs':8,'looks':16,'motion_samples':420,
        'battles_per_process':8,'preview_looks_per_process':16,'cold_and_restart':True,
        'pool_http_failures_rejected':1,'pool_corruption_repaired':True,'restart_http_requests':0,
        'launcher_handoff_verified':True,'runtime_evicted_texture_resources':cold['runtime_evicted_texture_resources'],
        'max_lru_entries':max(b['cache_entries'] for b in cold['battles']),
        'max_lru_admission_bytes':max(b['cache_source_bytes'] for b in cold['battles']),
        'pilot_before_bytes':before,'pilot_after_bytes':total,'combined_prototype_collection_bytes':combined,
        'under_7_decimal_gb':combined<7000000000,'reports':reports,'screenshots':screenshots,
        'inputs':inputs,'driver_inputs':driver_inputs,'input_sha256':sha(input_path),
        'fixture_path':str(args.pilot.resolve()),'fixture_sha256':sha(args.pilot),
        'checks_path':str(output),'godot':cold['godot'],'renderer':cold['renderer'],'device':cold['device'],
        'contract_log_sha256':sha(output/'contract/stdout.log'),'legacy_v15_log_sha256':sha(output/'legacy-v15/stdout.log'),
        'import_log_sha256':sha(output/'import.log'),'project_sha256':sha(folder/'project.godot'),
        'http_log_sha256':sha(output/'http-requests.json'),'production_revision_unchanged':'v15',
        'full_collection_runtime_qualified':False,'other_platforms_qualified':False}
    write(output/'qualification.json',receipt)
    print('SHARED_TEXTURE_RUNTIME_CHECKS_COMPLETE',combined,flush=True)
