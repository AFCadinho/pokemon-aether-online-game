"""Finish the authorized 21 reconstruction candidates and qualify local delivery."""
import argparse
import os
import subprocess
from io import BytesIO
from pathlib import Path
from PIL import Image,ImageDraw
from catalog_galar_birds_candidates import read,write,sha
from catalog_remaining_eye_bake import chunks
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).parent
WORK=ROOT/'.tmp/finish-twenty-one-v1'
PREVIEW=ROOT/'.tmp/remaining-twenty-one-v2/review-v5'
NAMES=read(HERE/'remaining_fourteen_qualification.json')['remaining_species']
DEX={'castform':351,'eternatus':890,'greninja':658,'groudon':383,'kyogre':382,'necrozma':800,'ogerpon':1017,'pichu':172,'pikachu':25}


def context():
    assert os.environ.get('POKEAETHER_SLOT')==ROOT.parent.name
    import alternate_forms_batch as batch
    batch.WORK=WORK;batch.INTAKE=WORK/'intake.json';batch.cohort_rows=lambda:read(batch.INTAKE)['entries']


def run(label,args,env=None):
    WORK.mkdir(exist_ok=True)
    data=ROOT.parent/'.runtime/final-twenty-one'/label/'xdg-data';data.mkdir(parents=True,exist_ok=True)
    cmd=[str(ROOT.parents[2]/'ops/worktrees/slot-env'),ROOT.parent.name,'--','env','XDG_DATA_HOME='+str(data),'/home/adinho/.local/bin/godot']
    log=WORK/(label+'.log')
    with log.open('w') as f:subprocess.run(cmd+['--log-file',str(data.parent/'godot.log')]+args,env=env,stdout=f,stderr=subprocess.STDOUT,check=True,timeout=1800)
    assert 'ERROR:' not in log.read_text() and 'SCRIPT ERROR' not in log.read_text(),str(log)


def eyes(entry):
    n=entry['base_species']
    if n.startswith('pikachu-') or n in ['pichu-spiky-eared','necrozma-ultra','eternatus-eternamax']:return {}
    doc,binary=chunks(Path(entry['path']));result={}
    for mat in doc['materials']:
        if 'eye' not in mat['name'].lower():continue
        tex=mat.get('pbrMetallicRoughness',{}).get('baseColorTexture')
        if not tex:continue
        image=doc['images'][doc['textures'][tex['index']]['source']];v=doc['bufferViews'][image['bufferView']];start=v.get('byteOffset',0)
        old=Image.open(BytesIO(binary[start:start+v['byteLength']])).convert('RGBA')
        update=entry.get('surface_updates',{}).get(mat['name'])
        if update and update['property']=='albedo_texture':old=Image.open(update['path']).convert('RGBA')
        # New authored closed expression at the original texture dimensions.
        # Native Pikachu/Pichu sleeping eyelids remain untouched.
        w,h=old.size;bg=old.getpixel((0,0));cols=2 if n.startswith('castform-') else 4 if n=='greninja-ash' else 1
        rows=4 if n=='greninja-ash' else 1
        if n=='groudon-primal':bg=(145,32,27,255)
        if n=='kyogre-primal':bg=(47,56,111,255)
        if n.startswith('necrozma-'):bg=(35,38,42,255)
        new=Image.new('RGBA',(w,h),bg);draw=ImageDraw.Draw(new)
        for x in range(cols):
            for y in range(rows):
                a,b=w/cols,h/rows
                draw.arc((a*(x+.18),b*(y+.26),a*(x+.82),b*(y+.65)),0,180,fill=(12,15,19,255),width=max(1,round(min(a,b)*.04)))
        path=WORK/'eyes'/entry['species']/(mat['name']+'.png');path.parent.mkdir(parents=True,exist_ok=True);new.save(path)
        result[mat['name']]={'path':str(path),'sha256':sha(path),'size':[w,h],'authored':True}
    return result


def castform_palette(entry):
    """Authored shiny recipes matched to the local HOME reference by surface role."""
    name=entry['base_species'];doc,binary=chunks(PREVIEW.parent/'models'/name/'normal/model.glb');updates={}
    for mat in doc['materials']:
        tex=mat['pbrMetallicRoughness'].get('baseColorTexture')
        if not tex:continue
        v=doc['bufferViews'][doc['images'][doc['textures'][tex['index']]['source']]['bufferView']];start=v.get('byteOffset',0)
        im=Image.open(BytesIO(binary[start:start+v['byteLength']])).convert('RGBA');pixels=[];label=mat['name'].split('-')[-1]
        for r,g,b,a in im.getdata():
            maximum=max(r,g,b);minimum=min(r,g,b)
            if name=='castform-sunny':
                if label=='BodyADodo':r,g,b=round(maximum*.94),round(maximum*.66),round(maximum*.78)
                elif label in ['BodyANon','Mouth','BodyAUniranNon','BodyAUniran00'] and r>g*1.15 and g>b*1.05:
                    r,g,b=(maximum,round(maximum*.76),round(maximum*.43)) if g>r*.75 else (maximum,round(maximum*.19),round(maximum*.33))
                elif label=='Eye' and maximum-minimum>25:r,g,b=maximum,round(maximum*.76),round(maximum*.43)
            elif name=='castform-rainy':
                if label=='BodyDodo':r,g,b=round(maximum*.32),round(maximum*.46),round(maximum*.56)
                elif label in ['BodyANon','Eye','Mouth'] and b>r*1.1:r,g,b=round(maximum*.43),maximum,round(maximum*.35)
                elif label.startswith('BodyAPowalen') and b>r*1.1:r,g,b=round(maximum*.23),round(maximum*.76),maximum
            elif name=='castform-snowy':
                if label=='Eye' and maximum>50:r,g,b=round(maximum*.97),maximum,round(maximum*.39)
                elif label in ['BodyANon','Mouth','BodyAUniran00','BodyAUniran02'] and b>g*1.1:
                    r,g,b=(round(maximum*.97),maximum,round(maximum*.39)) if g>b*.76 else (round(maximum*.18),round(maximum*.27),maximum)
            pixels.append((r,g,b,a))
        im.putdata(pixels);path=WORK/'palette'/entry['species']/(mat['name']+'.png');path.parent.mkdir(parents=True,exist_ok=True);im.save(path)
        updates[mat['name']]={'path':str(path),'sha256':sha(path),'property':'albedo_texture','authored':True,'preserve_alpha':name=='castform-snowy' and label=='BodyAUniran01'}
    return updates


def setup():
    receipt=read(HERE/'remaining_twenty_one_result.json');catalog=read(PREVIEW/'catalog.json')
    assert len(catalog['entries'])==42
    for e in catalog['entries']:
        r=next(x for x in receipt['entries'] if x['species']==e['species'])
        assert sha(Path(e['runtime_path']))==e['runtime_sha256']==r['runtime_sha256']
        if e['base_species']=='eternatus-eternamax':e['placement']={'scale':.001,'yaw_degrees':0.0}
        if e['base_species']=='necrozma-ultra':e['placement']={'scale':10.0,'yaw_degrees':0.0}
        e['surface_updates']={}
        if e['base_species'].startswith('castform-') and e['variant']=='shiny':e['surface_updates']=castform_palette(e)
        if e['species']=='necrozma-ultra-shiny':
            doc,binary=chunks(Path(e['path']))
            for mat in doc['materials']:
                tex=mat.get('emissiveTexture')
                if not tex:continue
                v=doc['bufferViews'][doc['images'][doc['textures'][tex['index']]['source']]['bufferView']];start=v.get('byteOffset',0)
                im=Image.open(BytesIO(binary[start:start+v['byteLength']])).convert('RGBA');pixels=[];changed=0
                for r,g,b,a in im.getdata():
                    if r>g*.7 and g>b*1.3 and g>40:r,b=int(g*.55),g;g=int(g*.82);changed+=1
                    pixels.append((r,g,b,a))
                im.putdata(pixels)
                path=WORK/'palette'/e['species']/(mat['name']+'.png');path.parent.mkdir(parents=True,exist_ok=True);im.save(path)
                e['surface_updates'][mat['name']]={'path':str(path),'sha256':sha(path),'property':'emission_texture','authored':True,'changed_pixels':changed}
        e['closed_eyes']=eyes(e)
        e['material_limitations']='Authorized reconstruction; original-engine visual parity is not claimed.'
    write(WORK/'stage.json',catalog)
    write(WORK/'intake.json',{'entries':[{'species':n,'national_dex':DEX[n.split('-')[0]]} for n in NAMES]})
    for n in NAMES:
        write(WORK/'candidates'/(n+'.json'),{'entries':[e for e in catalog['entries'] if e['base_species']==n]})
        write(WORK/'status/appearance'/(n+'.json'),{'species':n,'status':'rendered'})
    project=WORK/'runtime-project';project.mkdir(exist_ok=True)
    for n in ['tools','scripts','resources','data']:
        p=project/n
        if not p.exists():p.symlink_to(ROOT/n,target_is_directory=True)
    (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Final forms qualification"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    write(WORK/'authorization.json',{'user_statement':'oke maak het af','scope':'Finish the authorized reconstructions and run local battle/delivery qualification. No publication authorization inferred.','preview_receipt_sha256':sha(HERE/'remaining_twenty_one_result.json')})


def check_ui(name, renderer):
    out = WORK/'ui'/name/renderer
    label = 'ui-'+name+'-'+renderer
    test = ROOT/'tests/battle_3d_final_forms_check.gd'
    fixture = WORK/'delivery'/name/'runtime-fixture.json'
    report = out/'report.json'
    valid = report.exists() and read(report).get('complete') and read(report).get('ui_check_sha256') == sha(test) and read(report).get('fixture_sha256') == sha(fixture)
    if not valid:
        if out.exists():
            import time
            out.rename(out.with_name(renderer+'-superseded-'+str(time.time_ns())))
        log = WORK/(label+'.log')
        if log.exists():
            import time
            log.rename(log.with_name(label+'-superseded-'+str(time.time_ns())+'.log'))
        env=dict(os.environ,POKEAETHER_FORM_BUNDLE_WORK=str(WORK/'delivery'/name),POKEAETHER_FOURTEEN_UI_OUTPUT=str(out),POKEAETHER_FOURTEEN_NATIVE=str(WORK/'runtime-jobs'/name/'native/report.json'))
        run(label,['--path',str(ROOT),'--rendering-method',renderer,'--script','res://tests/battle_3d_final_forms_check.gd'],env)
    result=read(report)
    assert result['complete'] and result['ui_check_sha256']==sha(test) and result['fixture_sha256']==sha(fixture)
    log=(WORK/(label+'.log')).read_text()
    assert 'FINAL_FORMS_BATTLE_UI_OK' in log and 'ERROR:' not in log
    print('UI_OK',name,renderer,flush=True)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('phase',choices=['setup','prepare','battle','delivery','ui']);p.add_argument('--only',nargs='+',choices=NAMES);a=p.parse_args();context();names=a.only or NAMES
    if a.phase=='setup':setup()
    elif a.phase=='prepare':
        for n in names:
            folder=WORK/'runtime-jobs'/n/'native'
            if (folder/'report.json').exists():
                assert 'ERROR:' not in (WORK/('prepare-'+n+'.log')).read_text()
                continue
            run('prepare-'+n,['--rendering-method','gl_compatibility','--path',str(WORK/'runtime-project'),'--script','res://tools/sprite_factory/final_twenty_one_prepare.gd','--',str(WORK/'candidates'/(n+'.json')),str(folder)])
            print('PREPARED',n,flush=True)
    elif a.phase=='battle':
        import alternate_forms_recovery_battle
        alternate_forms_recovery_battle.main(only=set(names))
        assert all(read(WORK/'status/battle'/(n+'.json'))['status']=='measured' for n in names)
    elif a.phase=='delivery':
        import alternate_forms_delivery
        for n in names:
            result=alternate_forms_delivery.qualify(n);write(WORK/'status/delivery'/(n+'.json'),result);print('DELIVERY_OK',n,flush=True)
    elif a.phase=='ui':
        for n in names:
            for renderer in ['gl_compatibility','mobile']:
                check_ui(n,renderer)

if __name__=='__main__':main()
