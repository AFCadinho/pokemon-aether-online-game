"""Traceable battle contacts and a complete result for the original 109 holds."""
from pathlib import Path
import argparse
from collections import Counter
from PIL import Image, ImageDraw
from alternate_forms_recovery import ROOT, HERE, WORK, read, write, sha


def contacts(directory, only=None):
    directory.mkdir(parents=True,exist_ok=False)
    names=[]
    for path in sorted((WORK/'status/battle').glob('*.json')):
        row=read(path)
        if only and row['species'] not in only:continue
        if row['status']=='measured' and not row['species'].startswith(('minior-','cramorant-')):
            names.append(row['species'])
    pages=[]
    for start in range(0,len(names),8):
        canvas=Image.new('RGB',(1600,1440),'#202430');draw=ImageDraw.Draw(canvas);records=[]
        for i,name in enumerate(names[start:start+8]):
            report=WORK/'battle'/name/'final/battle-review.json'
            variants=[r for r in read(report)['entries'] if 'clips' in r]
            assert len(variants)==2
            draw.text((4,i*180+2),name,fill='white')
            for v,row in enumerate(variants):
                shots=[s for s in row['shots'] if s['action']=='idle']
                assert {(s['arena_camera'],int(s['side'])) for s in shots}=={(c,s) for c in ('classic','stadium') for s in (0,1)}
                for j,shot in enumerate(shots):
                    path=report.parent/shot['image'];im=Image.open(path).convert('RGB')
                    x,y,w,h=shot['screen_rect'];im=im.crop((max(0,int(x)-20),max(0,int(y)-20),min(im.width,int(x+w)+21),min(im.height,int(y+h)+21)))
                    im.thumbnail((196,148));column=v*4+j
                    canvas.paste(im,(column*200+2,i*180+19));draw.text((column*200+2,i*180+165),('shiny ' if v else 'normal ')+shot['arena_camera']+' '+str(int(shot['side'])),fill='white')
                    records.append({'species':row['species'],'report':str(report),'report_sha256':sha(report),'path':str(path),'sha256':sha(path)})
        output=directory/f'battle-{start//8+1:02}.jpg';canvas.save(output,quality=95)
        pages.append({'path':str(output),'sha256':sha(output),'entries':records})
    write(directory/'index.json',{'reviewed':False,'scope':'Idle, both battle cameras and both sides, normal and shiny; full action appearance review is separate','pages':pages})
    print('BATTLE_CONTACTS',len(names),len(pages))


def result():
    receipt=read(HERE/'alternate_forms_recovery_qualification.json')
    assert receipt['admitted_registry_check_passed']
    approved=set(receipt['forms']);entries=[]
    old=read(HERE/'alternate_forms_batch_result.json')
    for row in old['entries']:
        if row['status']!='held':continue
        row=dict(row);name=row['species']
        if name in approved:
            row.update(status='prepared_not_selected',reason='Normal and shiny qualified locally; awaiting a selected model release.',stage='recovery-qualified')
        elif name.startswith('minior-'):
            row.update(stage='source-visibility',reason='Native scalar/colour palette decoded. The Blue-core trial exported own archived actions but also renders meteor shell/fragments. This source route lacks verified form visibility; the other Minior forms remain held without appearance approval.')
        elif name.startswith('cramorant-'):
            row.update(stage='source-visibility',reason='Identical base/form skeleton and sleep compatibility proved. Archived export renders both Arrokuda and Pikachu; matching visibility/eye animation is missing. No appearance approval.')
        elif name=='greninja-ash':
            row.update(stage='source-motion',reason='Own pm0725_ash.blend found with model_skeleton rig, but no complete battle/sleep/faint action set in inspected archive.')
        elif name.endswith('-totem') or name in ('eevee-starter','pikachu-starter','rockruff-dusk'):
            row.update(stage='source-identity-scale',reason='No verified shared-base identity and scale mapping for this form. Base geometry alone is insufficient for admission.')
        elif name.startswith('ogerpon-'):
            row.update(stage='source-variant-binding',reason='Tera configuration and related 99-resource geometry exist; exact form geometry, motion and shader-state bindings remain unverified.')
        elif name in ('poltchageist-artisan','sinistcha-masterpiece'):
            row.update(stage='source-variant-binding',reason='DLC geometry exists, but complete motion resources and positive variant/stamp binding are missing from the inspected route.')
        elif name.startswith('pikachu-') or name=='pichu-spiky-eared':
            row.update(stage='source-model',reason='No matching costume or Spiky-eared source model found in the inspected Biochao, SCVI and Z-A archives.')
        elif name=='xerneas-neutral':
            row.update(stage='source-state-material',reason='Own Z-A resources found; neutral/default versus battle material-increment and back-effect state binding remains unverified.')
        elif name in ('groudon-primal','kyogre-primal'):
            row.update(stage='source-motion',reason='Own native Z-A geometry and battle motions found, but no complete own-source sleep/rest motion in the inspected banks. Base-form motion compatibility is unverified.')
        elif name.startswith('castform-') or name in ('eternatus-eternamax','necrozma-ultra'):
            row.update(stage='source-motion',reason='Own archived rig exists, but inspected actions do not provide the required complete battle, sleep and faint set.')
        elif name in ('necrozma-dawn-wings','necrozma-dusk-mane'):
            row.update(stage='source-effect-animation',reason='Own archived rig and actions exist; corresponding native effect-material animation binding remains incomplete.')
        elif name.startswith(('burmy-','wormadam-')) or name=='cherrim-sunshine':
            row.update(stage='source-shiny-material',reason='Own geometry, motions and normal material source exist; shiny material reconstruction has not been verified.')
        elif name=='rotom-fan':
            row.update(stage='source-shader',reason='Detailed base and mask textures use different native resolutions. A separately sampled effect shader and its runtime validation are required; texture resampling is not accepted as lossless.')
        elif name=='zygarde-10':
            row.update(stage='source-shader',reason='Native Fresnel/probe texture binding is unverified; a static colour substitution cannot preserve the authored material.')
        elif name.startswith(('pumpkaboo-','gourgeist-','unown-','silvally-','squawkabilly-','sawsbuck-')):
            path=WORK/'status/delivery'/(name+'.json')
            row.update(stage='recovery-delivery',reason=read(path).get('reason','Qualification not complete') if path.exists() else 'Qualification not complete')
        row['status']='prepared_not_selected' if name in approved else 'held'
        entries.append(row)
    assert len(entries)==109 and approved=={r['species'] for r in entries if r['status']=='prepared_not_selected'}
    summary=dict(Counter(r['status'] for r in entries))
    output={'schema':1,'scope':'All original 109 holds reconsidered; local integration only',
            'previous_result_sha256':sha(HERE/'alternate_forms_batch_result.json'),
            'qualification_sha256':sha(HERE/'alternate_forms_recovery_qualification.json'),
            'summary':summary,'entries':entries}
    write(HERE/'alternate_forms_recovery_result.json',output)
    print('RECOVERY_RESULT',summary)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('phase',choices=['contacts','result']);p.add_argument('--output',type=Path);p.add_argument('--only')
    a=p.parse_args()
    if a.phase=='contacts':
        if not a.output:p.error('--output required')
        contacts(a.output.resolve(),set(a.only.split(',')) if a.only else None)
    else:result()
