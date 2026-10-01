"""DLC own-rig authored proposals from pinned local assets; never native admission."""
from concurrent.futures import ThreadPoolExecutor, as_completed
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import re

from catalog_shiny_za_17_probe import run_flatpak
from catalog_shiny_151_material_probe import rebuild
from phase5_variant_parity import compare
from scvi_material_probe import inspect_materials

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
IMPORTER=ROOT.parent/'.tmp/scvi-importer'
DEPS=ROOT.parent/'.tmp/scvi-python-deps'
SOURCE=Path('/home/adinho/Documents/3d_models/Pokémon SCVI Base + DLC Model Dump').resolve()


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def write(path,data):path.write_text(json.dumps(data,indent=2)+'\n')


def process(row,output):
    name=row['species'];directory=output/name;directory.mkdir(exist_ok=False)
    try:
        model=SOURCE/row['models'][0];identity=model.stem
        if not re.fullmatch(r'pm\d{4}_\d{2}_00',identity) or not model.is_file():
            raise ValueError('Pinned DLC identity model missing')
        icon=Path(row['icon_path'])
        if not icon.is_file() or sha(icon)!=row['icon_sha256']:
            raise ValueError('Pinned source icon missing or changed')
        if row['resource_id'] != identity[:6]:
            raise ValueError('Model does not match reviewed resource identity')
        assets={str(p):sha(p) for p in model.parent.iterdir() if p.is_file() and p.suffix in ['.png','.trmdl','.trmsh','.trmbf','.trmtr','.trskl','.trmmt']}
        table_rows=inspect_materials(model.with_suffix('.trmtr'))
        restore_lids=any(r['shaders'] and r['shaders'][0]['name']=='EyeClearCoat'
                         and all(s['name'] in ['EyeClearCoat','Eye'] and s['values'].get('EyelidType') in ['All','Upper'] for s in r['shaders']) for r in table_rows)
        prepared=directory/'prepared.blend';report=directory/'import.json'
        job={'species':name,'identity':identity,'variant':'normal','model_dir':str(model.parent),
             'motions':{},'motion_channels':{},'output':str(prepared),'report':str(report),
             'restore_all_eyelids':restore_lids,'importer':str(IMPORTER),'python_deps':str(DEPS),
             'importer_commit':'b0c98d9fcaab85a04ad35e2d111bae4cad6c1e04',
             'shader_sha256':sha(IMPORTER/'SCVIShader.blend'),'source_files':assets}
        write(directory/'import-job.json',job)
        run_flatpak(HERE/'scvi_import_worker.py',directory/'import-job.json',
                    [(SOURCE,':ro'),(IMPORTER,':ro'),(DEPS,':ro'),(HERE,':ro'),(directory,'')],directory/'import.log')
        imported=json.loads(report.read_text())
        if sha(prepared)!=imported['prepared_sha256']:raise ValueError('Imported source changed')
        exported=directory/'export';exported.mkdir();isolated=exported/'input.blend'
        shutil.copyfile(prepared,isolated)
        actions={a:'PAO_MISSING_'+a for a in ['idle','physical_attack','special_attack','damage','sleep','faint_start']}
        job={'species':name,'source':str(isolated),'source_sha256':sha(isolated),
             'actions':actions,'authored_motion_review':list(actions),'output':str(exported),'scvi_pbr_probe':False}
        write(exported/'job.json',job)
        run_flatpak(HERE/'phase5_godot_export_worker.py',exported/'job.json',[(exported,''),(HERE,':ro')],exported/'export.log')
        receipt=json.loads((exported/'export.json').read_text());raw=exported/'model.glb'
        variants={}
        for variant in ['normal','shiny']:
            table=model.parent/(identity+('_rare' if variant=='shiny' else '')+'.trmtr')
            target=directory/variant/'model.glb'
            records=rebuild(raw,target,table,aliases=row.get("material_aliases"))
            variants[variant]={'path':str(target),'glb_sha256':sha(target),'table_sha256':sha(table),'materials':records}
        return {'species':name,'status':'authored_motion_review_candidate','runtime_approved':False,
                'native_motion':False,'authored_motion_review':receipt['authored_motion_review'],
                'identity':identity,'source_icon_sha256':row['icon_sha256'],'animations':receipt['animations'],
                'variants':variants,'geometry_motion_sha256':compare(Path(variants['normal']['path']),Path(variants['shiny']['path'])),
                'import_report_sha256':sha(report),'export_report_sha256':sha(exported/'export.json')}
    except Exception as error:
        logs=[p.read_text(errors='replace') for p in directory.glob('**/*.log')]
        details=re.findall(r'(?:ValueError|RuntimeError|AssertionError): ([^\n]+)','\n'.join(logs))
        return {'species':name,'status':'held','reason':details[-1] if details else str(error),'runtime_approved':False}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--inventory',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--retry-held',type=Path);args=parser.parse_args()
    output=args.output.resolve();output.mkdir(exist_ok=False)
    rows=json.loads(args.inventory.read_text())['entries'];results=[]
    if args.retry_held:
        held={r['species'] for r in json.loads(args.retry_held.read_text())['entries'] if r['status']=='held'}
        rows=[r for r in rows if r['species'] in held]
    with ThreadPoolExecutor(max_workers=2) as pool:
        jobs=[pool.submit(process,row,output) for row in rows]
        for future in as_completed(jobs):
            result=future.result();results.append(result)
            write(output/'status.json',{'total':len(rows),'processed':len(results),'runtime_approved':False,'entries':results})
            print(result['species'],result['status'],result.get('reason',''),flush=True)
