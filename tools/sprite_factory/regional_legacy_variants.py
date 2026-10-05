"""Native material-table pairs and explicitly labelled sprite-reference proposals."""
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
from pathlib import Path
from PIL import Image
from catalog_shiny_151_material_probe import rebuild
from catalog_dlc_layer_emission import restore
from catalog_reference_shiny_proposals import build as reference_build
from catalog_galar_birds_candidates import sha,read
from catalog_shiny_za_17_probe import write
from phase5_variant_parity import compare

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
WORK=ROOT/'.tmp/regional-production-v1/legacy'


def reference_images(name):
    slug={'darmanitan-galar-zen':'darmanitan-galarzen','raticate-alola-totem':'raticate-alola'}.get(name,name)
    result=[]
    output=WORK/'references'/name;output.mkdir(parents=True,exist_ok=True)
    for kind,folder in [('normal','front'),('shiny','shiny_front')]:
        source=ROOT/'assets/sprites/pokemon'/folder/slug
        meta=read(source/'animation.json')
        # The sprite sheets start at different animation times. These frames
        # have identical silhouettes (registration IoU 1.0).
        frame_index = (24 if kind == 'normal' else 11) if name == 'rattata-alola' else 0
        frame=meta['frames'][frame_index]
        target=output/(kind+'.png')
        with Image.open(source/meta['image'])as image:
            image.crop((frame['x'],frame['y'],frame['x']+frame['w'],frame['y']+frame['h'])).save(target)
        result.append(str(target))
    return result


def process(row):
    name=row['species'];out=WORK/'paired-materials'/name;out.mkdir(parents=True,exist_ok=True)
    native=read(WORK/'native-materials'/name/'export.json')
    raw=read(WORK/'normal-exports'/name/'export.json')
    table=Path(row['model_dir'])/(row['resource']+'.trmtr')
    variants=[]
    if table.exists():
        for kind in ['normal','shiny']:
            selected=table if kind=='normal'else table.with_stem(table.stem+'_rare')
            albedo=out/(kind+'-albedo.glb');target=out/(kind+'.glb')
            colours=rebuild(Path(raw['path']),albedo,selected)
            glow=restore(albedo,target,selected)
            variant={**raw,'path':str(target),'glb_sha256':sha(target),'material_receipt':colours,'layer_emission':glow,'material_table_sha256':sha(selected)}
            variants.append((kind,variant))
    else:
        variants.append(('normal',native))
        shiny_root=WORK/'reference-shiny';shiny_root.mkdir(exist_ok=True)
        target=shiny_root/name/'model.glb';receipt=target.with_suffix('.receipt.json')
        proposal=read(receipt)if receipt.exists()else reference_build({**native,'species':name,'reference_paths':reference_images(name),'reference_kind':'local_sprite'},shiny_root)
        if proposal['status']=='held':raise ValueError(proposal['reason'])
        variants.append(('shiny',{**native,**proposal}))
    entries=[]
    for kind,variant in variants:
        variant['action_timing'] = {a: {'frames': c['duration'] * 60, 'speed': 1,
                                      'loop': c['loop']} for a,c in variant['animations'].items()}
        variant.update(species=name+('-shiny'if kind=='shiny'else ''),status='exported_for_review',runtime_approved=False,
            appearance_approved=False,battle_approved=False,complete_pose_channels=True,
            placement={'scale':1,'yaw_degrees':0},
            review_poses=[['idle',0,'front'],['idle',.5,'back'],['idle',.5,'side'],['physical_attack',.5,'front'],['special_attack',.5,'front'],['sleep',.5,'front'],['faint_start',1,'front']])
        entries.append(variant)
    parity=compare(Path(entries[0]['path']),Path(entries[1]['path']))
    result={'species':name,'status':'review_candidate','runtime_approved':False,'variants':entries,'geometry_motion_parity':parity}
    write(out/'receipt.json',result)
    return result


def main():
    rows=read(WORK/'intake.json')['entries'];results=[]
    def one(row):
        try:return process(row)
        except Exception as e:
            import traceback;traceback.print_exc()
            return {'species':row['species'],'status':'held','reason':str(e),'runtime_approved':False}
    with ThreadPoolExecutor(max_workers=2)as pool:
        for f in as_completed([pool.submit(one,r)for r in rows]):
            r=f.result();results.append(r);write(WORK/'pair-status.json',{'schema':1,'entries':results,'runtime_approved':False});print(r['species'],r['status'],r.get('reason',''),flush=True)


if __name__=='__main__':main()
