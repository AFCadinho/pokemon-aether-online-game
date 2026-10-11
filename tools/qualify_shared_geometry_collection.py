#!/usr/bin/env python3
"""Run pinned Linux presenter/preview and exact GPU comparisons for schema-2 packs."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import time
import zipfile

from qualify_shared_model_catalog import compare

ROOT = Path(__file__).resolve().parents[1]
DEFAULT = ['garchomp:mega', 'gliscor:base', 'charmander:base', 'roaring-moon:base',
           'abomasnow:base', 'accelgor:base', 'armaldo:base', 'beheeyem:base', 'greninja:base',
           'dragonite:mega', 'toucannon:base', 'pikachu:base', 'gengar:mega', 'rayquaza:mega',
           'hydrapple:base', 'terapagos-stellar:base']


def sha(path):
    with Path(path).open('rb') as stream: return hashlib.file_digest(stream, 'sha256').hexdigest()
def read(path): return json.loads(Path(path).read_bytes())
def write(path, value): Path(path).write_text(json.dumps(value, indent=2, sort_keys=True)+'\n')


def frozen():
    paths = {Path(__file__), ROOT / 'project.godot'}
    for pattern in ('scripts/**/*.gd', 'launcher/scripts/*.gd', 'data/model_pair*.json',
                    'launcher/data/model_pair*.json', 'tools/sprite_factory/*.gd',
                    'resources/battle/model_animations/**/*', 'resources/battle/model_visibility/**/*',
                    'tests/shared_model_catalog_actor_check.gd'):
        paths.update(p for p in ROOT.glob(pattern) if p.is_file() and p.suffix != '.uid')
    return {str(p.relative_to(ROOT)): sha(p) for p in sorted(paths)}


def run(script, args, output):
    env = os.environ.copy(); env['POKEAETHER_SHARED_MODEL_GEOMETRY_TEST'] = '1'
    for name in ('DATA', 'CONFIG', 'CACHE'):
        target = output.parent / (output.stem + '-xdg-' + name.lower()); target.mkdir()
        env['XDG_' + name + '_HOME'] = str(target)
    command = ['godot', '--path', str(ROOT), '--rendering-method', 'mobile', '--resolution', '640x480',
               '--log-file', str(output.with_suffix('.engine.log')), '--script', script, '--', *map(str,args)]
    with output.open('w') as log:
        child = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, env=env)
        try: code = child.wait(timeout=1800)
        except BaseException:
            child.terminate()
            try: child.wait(timeout=10)
            except subprocess.TimeoutExpired: child.kill(); child.wait()
            raise
    text = output.read_text()
    if code or re.search(r'(?:SCRIPT ERROR|^ERROR:|CATALOG_.*_ABORT)', text, re.M):
        raise RuntimeError('GPU check failed: '+str(output)+'\n'+text[-2500:])


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--collection',type=Path,required=True);p.add_argument('--sources',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True);p.add_argument('--all',action='store_true')
    p.add_argument('--asset',action='append',default=[],help='Explicit asset IDs for a focused rerun')
    args=p.parse_args();assert os.environ.get('POKEAETHER_SLOT')==ROOT.parent.name
    output=args.output.resolve();output.relative_to(ROOT/'.tmp');output.mkdir(parents=True,exist_ok=False)
    collection=read(args.collection/'report.json');assert collection['complete']
    candidates={r['asset']['asset_id']:r for r in collection['records'] if r['smaller']}
    assert not (args.all and args.asset)
    selected=sorted(candidates) if args.all else args.asset or ['pokemon_3d:'+key for key in DEFAULT]
    assert len(selected)==len(set(selected))
    assert all(key in candidates for key in selected)
    compiled={a['asset_id']:a for a in read(ROOT/'data/model_pair_geometry_catalog.json')['assets']}
    assert all(compiled[key]==candidates[key]['asset'] for key in selected)
    sources=read(args.sources)['original_sources']
    originals={a['asset_id']:a for a in read(ROOT/'release/approved_3d_bundles_v11_index.json')['assets']}
    lock=(ROOT/'.tmp/diagnostic-project.lock').open('a+');fcntl.flock(lock,fcntl.LOCK_SH|fcntl.LOCK_NB)
    pins=frozen();started=time.monotonic();results=[];actors=[]
    def interrupt(_signal,_frame):raise KeyboardInterrupt
    signal.signal(signal.SIGTERM,interrupt)
    write(output/'configuration.json',{'inputs':pins,'selected':selected,'full_collection':args.all,'collection_sha256':sha(args.collection/'report.json')})
    for offset in range(0,len(selected),4):
        directory=output/f'batch-{offset:04}';directory.mkdir()
        fixture={'schema':1,'pairs':[],'models':[],'packs':[]}
        for key in selected[offset:offset+4]:
            row=candidates[key];asset=row['asset'];old=originals[key];archive=Path(sources[key])
            assert sha(archive)==old['sha256'] and sha(row['path'])==asset['sha256']
            identity=asset['appearances'][0]['runtime_identity'];fixture['pairs'].append(identity)
            fixture['packs'].append({'asset':asset,'path':row['path']})
            with zipfile.ZipFile(archive) as zip:
                for before,appearance in zip_pairs(old['appearances'],asset['appearances']):
                    payload=zip.read('models/'+before['variant']+'.scn')
                    assert hashlib.sha256(payload).hexdigest()==before['runtime_sha256']
                    path=directory/(appearance['runtime_identity']+'.scn');path.write_bytes(payload)
                    fixture['models'].append({'identity':appearance['runtime_identity'],'variant':appearance['variant'],
                        'source_path':str(path),'source_sha256':before['runtime_sha256'],'source_bytes':len(payload),
                        'candidate_path':asset['pair_manifest']['resource_root']+'/'+appearance['runtime_path'],
                        'candidate_sha256':appearance['runtime_sha256'],'candidate_bytes':appearance['bytes'],
                        'pair_asset':asset,'pack_path':row['path']})
        write(directory/'input.json',fixture)
        run('res://tools/sprite_factory/shared_model_catalog_render.gd',[directory/'input.json',directory/'render'],directory/'render.log')
        rendered=compare(directory/'render')
        results.extend(rendered)
        assert all(r['pixels_exact'] for r in rendered), 'Pixel differences require an explicit hold; inspect retained PNGs'
        run('res://tests/shared_model_catalog_actor_check.gd',[directory/'input.json',directory/'actors.json'],directory/'actors.log')
        actor=read(directory/'actors.json');assert actor['complete'];actors.append(actor)
        write(output/'progress.json',{'pairs':len(results)//2,'selected':len(selected)})
        print('GEOMETRY_GPU_CHECKED',len(results)//2,'/',len(selected),flush=True)
    assert frozen()==pins
    write(output/'report.json',{'complete':True,'prototype_only':True,'production_approved':False,
        'full_collection':args.all,'pairs':len(selected),'candidate_frames':sum(len(r['frames']) for r in results),
        'pixels_exact':all(r['pixels_exact'] for r in results),'battles':sum(a['battles'] for a in actors),
        'previews':sum(a['previews'] for a in actors),'inputs':pins,'records':results,'actors':actors,
        'elapsed_seconds':time.monotonic()-started})
    print('SHARED_GEOMETRY_GPU_OK pairs=',len(selected),flush=True)


def zip_pairs(a,b):
    for before,after in zip(a,b,strict=True):
        assert before['variant']==after['variant'] and before['runtime_identity']==after['runtime_identity']
        yield before,after

if __name__=='__main__':main()
