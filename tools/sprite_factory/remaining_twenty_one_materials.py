"""Source-table palettes and explicitly authored older-source shiny previews."""
from io import BytesIO
from pathlib import Path
import argparse
import re
import colorsys
import struct
from PIL import Image, ImageDraw
from remaining_twenty_one import ROOT,HERE,WORK,OLD,MODELS,read,write,sha,native_specs
from catalog_remaining_eye_bake import chunks,append_png,write_glb
from catalog_shiny_151_material_probe import rebuild
from catalog_dlc_layer_emission import restore
from scvi_material_probe import inspect_materials


def project(name, directory, ident):
    out=WORK/'palettes'/name;out.mkdir(parents=True,exist_ok=True)
    pins={}
    tables=[directory/(ident+'.trmtr'),directory/(ident+'_rare.trmtr')]
    required=set()
    for p in tables:
        if p.exists():
            for r in inspect_materials(p):
                required.update(Path(n).with_suffix('.png').name for k,n in r['textures'].items() if k!='LocalReflectionMap' and not Path(n).stem.endswith('_prb'))
    files=list(directory.glob('*.trmtr'))
    for n in required:
        matches=list(directory.parent.rglob(n));assert matches,'Missing texture '+n
        assert len({sha(p) for p in matches})==1,'Ambiguous texture '+n
        files.append(matches[0])
    for p in files:
        t=out/p.name
        if not t.exists():t.symlink_to(p)
        assert sha(t)==sha(p)
        pins[str(p)]=sha(p)
    write(out/'pins.json',pins)
    return out


def native(name):
    place=WORK/'native'/name
    if name in ['necrozma-dawn-wings','necrozma-dusk-mane']:
        ident='pm0865_'+('13' if name.endswith('wings') else '12')+'_00'
        info={'resource':ident,'directory':str(MODELS/'pm0865'/ident)}
        place.mkdir(parents=True,exist_ok=True)
        write(place/'source.json',info)
        source=WORK/'legacy'/name/'model.glb'
    else:
        info=read(place/'source.json');source=place/'export/model.glb'
    ident=info['resource']
    projection=project(name,Path(info['directory']),ident)
    doc,blob=chunks(source)
    rows={r['name']:r for r in inspect_materials(projection/(ident+'.trmtr'))}
    for m in doc['materials']:
        m['name']=re.sub(r'\.\d{3}$','',m['name']);r=rows[m['name']]
        tex=projection/Path(r['textures']['BaseColorMap']).with_suffix('.png').name
        pbr=m.setdefault('pbrMetallicRoughness',{})
        pbr['baseColorTexture']={**pbr.get('baseColorTexture',{}),'index':append_png(doc,blob,tex.read_bytes(),tex.stem,0)}
    seed=place/'source-bound.glb';write_glb(seed,doc,blob)
    results=[]
    for variant in ['normal','shiny']:
        table=projection/(ident+('_rare' if variant=='shiny' else '')+'.trmtr')
        if not table.exists():table=projection/(ident+'.trmtr')
        out=WORK/'models'/name/variant;out.mkdir(parents=True,exist_ok=True)
        rec=rebuild(seed,out/'albedo.glb',table)
        # restore expects already normalized exact material names.
        emission=restore(out/'albedo.glb',out/'model.glb',table)
        results.append({'variant':variant,'path':str(out/'model.glb'),'sha256':sha(out/'model.glb'),
            'table_sha256':sha(table),'materials':rec,'emission':emission})
    write(place/'material.json',{'runtime_approved':False,'entries':results})
    print('MATERIAL',name,flush=True)


def legacy(name):
    source=WORK/'legacy'/name/'model.glb'
    baked=WORK/'graph-bake'/name/'model.glb'
    if baked.exists():
        assert read(baked.parent/'result.json')['source_glb_sha256']==sha(source),'Stale graph bake'
        source=baked
    doc,blob=chunks(source)
    # Only proposals: native older colour maps are retained for normal. The
    # explicitly listed shiny palette masks are applied without resizing pixels.
    for variant in ['normal','shiny']:
        d,b=chunks(source); edits=[]
        for m in d['materials']:
            pbr=m.get('pbrMetallicRoughness',{});binding=pbr.get('baseColorTexture') or m.get('emissiveTexture')
            if not binding:continue
            t=d['textures'][binding['index']]; image=d['images'][t['source']];v=d['bufferViews'][image['bufferView']]
            im=Image.open(BytesIO(b[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']])).convert('RGBA')
            if name=='greninja-ash':
                im=ash_atlas(d,b,m,im)
            label=m['name'].lower(); pixels=[];changed=0
            for r,g,blue,a in im.getdata():
                rgb=(r,g,blue);h,s,val=colorsys.rgb_to_hsv(r/255,g/255,blue/255)
                if variant=='shiny':
                    if name=='greninja-ash' and .48<h<.77 and s>.25:rgb=tuple(round(x*255) for x in colorsys.hsv_to_rgb(.47,.30,val*.35))
                    elif name=='eternatus-eternamax' and .52<h<.82 and s>.25:rgb=tuple(round(x*255) for x in colorsys.hsv_to_rgb(.91,.85,val*.72))
                    elif name=='necrozma-ultra' and .08<h<.22 and s>.15:rgb=tuple(round(x*255) for x in colorsys.hsv_to_rgb(.55,s*.45,min(1,val*1.05)))
                    elif name=='castform-sunny':
                        if 'bodyb' in label and s<.2 and val>.3:rgb=tuple(round(x*255) for x in colorsys.hsv_to_rgb(.87,.22,val*.90))
                        elif 'bodya' in label and .02<h<.14 and s>.45:rgb=tuple(round(x*255) for x in colorsys.hsv_to_rgb(.97,s,val*.85))
                    elif name=='castform-rainy' and 'bodya' in label and .45<h<.72 and s>.2:rgb=tuple(round(x*255) for x in colorsys.hsv_to_rgb(.34,s,val))
                    elif name=='castform-snowy' and 'bodya' in label and val>.3:
                        if s<.2:rgb=tuple(round(x*255) for x in colorsys.hsv_to_rgb(.16,.55,val))
                        elif .45<h<.72:rgb=tuple(round(x*255) for x in colorsys.hsv_to_rgb(.65,max(s,.60),val))
                changed+=rgb!=(r,g,blue);pixels.append((*rgb,a))
            if (variant=='shiny' and changed) or name=='greninja-ash':
                im.putdata(pixels);buf=BytesIO();im.save(buf,format='PNG');idx=append_png(d,b,buf.getvalue(),m['name']+'-authored-shiny',t.get('sampler',0))
                pbr['baseColorTexture']={**binding,'index':idx};m['pbrMetallicRoughness']=pbr
                if m.get('emissiveTexture',{}).get('index')==binding['index']:m['emissiveTexture']={**binding,'index':idx}
            edits.append({'material':m['name'],'pixels_changed':changed,'size':list(im.size)})
        out=WORK/'models'/name/variant;out.mkdir(parents=True,exist_ok=True);write_glb(out/'model.glb',d,b)
        write(out/'palette.json',{'runtime_approved':False,'authored_palette':variant=='shiny','authored_missing_atlas':name=='greninja-ash','changes':edits,'source_sha256':sha(source)})
    print('LEGACY_MATERIAL',name,flush=True)


def ash_atlas(doc, blob, material, image):
    """Explicit new paint in the source UV layout; never source texture recovery."""
    im=image.copy();draw=ImageDraw.Draw(im);w,h=im.size;name=material['name']
    if 'Eye' in name:
        draw.rectangle((0,0,w,h),fill=(245,245,225,255))
        # Each quarter-width cell contains one eye, with four expression rows.
        for x in [0,.25,.5,.75]:
            for y in [0,.25,.5,.75]:
                draw.ellipse(((x+.07)*w,(y+.04)*h,(x+.18)*w,(y+.21)*h),fill=(171,18,36,255))
                draw.ellipse(((x+.108)*w,(y+.061)*h,(x+.143)*w,(y+.19)*h),fill=(8,12,17,255))
                draw.ellipse(((x+.095)*w,(y+.055)*h,(x+.121)*w,(y+.086)*h),fill='white')
    elif 'BodyB' in name:
        # Four isolated limb pads occupy the outside corners of this atlas.
        for lo,hi in [(0,.143),(.855,1)]:
            draw.rectangle((lo*w,0,hi*w,.307*h),fill=(225,235,221,255))
    elif 'BodyA' in name:
        def access(index):
            a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
            n={'SCALAR':1,'VEC2':2,'VEC3':3}[a['type']];fmt={5126:'f',5123:'H',5125:'I'}[a['componentType']]
            size=struct.calcsize(fmt)*n;offset=v.get('byteOffset',0)+a.get('byteOffset',0)
            return [struct.unpack_from('<'+fmt*n,blob,offset+i*v.get('byteStride',size)) for i in range(a['count'])]
        for mesh in doc['meshes']:
            for p in mesh['primitives']:
                if doc['materials'][p['material']] is not material:continue
                positions=access(p['attributes']['POSITION']);uv=access(p['attributes']['TEXCOORD_0']);indices=[x[0] for x in access(p['indices'])]
                for i in range(0,len(indices),3):
                    tri=indices[i:i+3];x,y,z=[sum(positions[j][k] for j in tri)/3 for k in range(3)]
                    if y>1.4 and abs(x)<.105 and z>.04:
                        draw.polygon([(uv[j][0]*w,(uv[j][1]%1)*h) for j in tri],fill=(188,28,51,255))
    return im

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('phase',choices=['native','legacy']);p.add_argument('--only');a=p.parse_args()
    names=[r['species'] for r in native_specs()]+['necrozma-dawn-wings','necrozma-dusk-mane'] if a.phase=='native' else ['castform-sunny','castform-rainy','castform-snowy','greninja-ash','eternatus-eternamax','necrozma-ultra']
    if a.only:names=[n for n in names if n in a.only.split(',')]
    errors=[]
    for n in names:
        try:(native if a.phase=='native' else legacy)(n)
        except Exception as e:errors.append({'species':n,'error':str(e)});print('MATERIAL_FAIL',n,str(e),flush=True)
    write(WORK/(a.phase+'-material-status.json'),{'errors':errors,'runtime_approved':False})
    if errors:raise SystemExit(1)
