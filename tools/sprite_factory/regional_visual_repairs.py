"""Review-only regional material/atlas corrections, with source hashes and parity.

These recipes address inspected discrepancies against the local HOME references.
They never approve a model. Black pupils, highlights, texture alpha, mesh data and
native skeletal motion are retained. Source atlas cells supply the sleep eyes.
"""
import colorsys
from functools import lru_cache
from io import BytesIO
import json
from pathlib import Path
from PIL import Image
from catalog_remaining_eye_bake import chunks, append_png, write_glb
from catalog_sleep_atlas_proposals import texture
from phase5_variant_parity import compare
from catalog_galar_birds_candidates import sha

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / '.tmp/regional-production-v1'
FIX = {'corsola-galar', 'darmanitan-galar', 'darumaka-galar',
       'linoone-galar', 'zigzagoon-galar', 'ponyta-galar'}


def adjust(name, material, pixel, shiny):
    if not shiny or pixel[3] < 16:
        return pixel
    h,s,v = colorsys.rgb_to_hsv(*(x/255 for x in pixel[:3]))
    if v < .10:
        return pixel
    changed = False
    if name == 'corsola-galar':
        if material in {'Body00', 'Mouth', 'Eye'} and s < .15:
            v *= .73; changed = True
        if material == 'Eye' and s > .2 and .8 < h < .98:
            h = .73; changed = True
    elif name == 'darmanitan-galar' and material == 'Eye' and s > .2 and .5 < h < .72:
        h = .30; changed = True
    elif name == 'darumaka-galar' and material in {'Eye', 'Mouth'} and s > .2 and .5 < h < .72:
        h = .46; changed = True
    elif name in {'linoone-galar', 'zigzagoon-galar'}:
        if .83 < h < .98 and s > .3:
            h = .51; changed = True
        if 'Eye' in material and s < .3 and .11 < v < .35:
            h,s,v = .95,.82,min(.85,v*4.3); changed = True
        if name == 'linoone-galar' and material.startswith('Body') and s < .12 and .48 < v < .62:
            h,s,v = .51,.60,min(1,v*1.4); changed = True
    elif name == 'ponyta-galar' and material in {'Eye', 'BodyA'} and s > .45 and .68 < h < .87:
        h = .65; changed = True
    if not changed:
        return pixel
    return tuple(round(c*255) for c in colorsys.hsv_to_rgb(h,s,v))+(pixel[3],)


def repair(row, output):
    name = row['species'].removesuffix('-shiny'); shiny = row['species'].endswith('-shiny')
    source = Path(row['path']); assert sha(source) == row['glb_sha256']
    doc,binary = chunks(source); binary = bytearray(binary)
    native_doc,native_binary = chunks(WORK/'legacy/native-materials'/name/'model.glb')
    native = {m['name']: m for m in native_doc['materials']}; changes=[]
    for material in doc['materials']:
        m = material['name']; pbr = material['pbrMetallicRoughness']
        if name == 'corsola-galar' and m == 'Feeler01':
            pbr.update(metallicFactor=0,roughnessFactor=.8)
            material.pop('extensions',None); changes.append(m+': nonmetallic coral')
        # Recolour these independently from the broad sprite palette transfer.
        selected = ('Eye' in m or name == 'corsola-galar' or
                    name == 'darumaka-galar' and m == 'Mouth' or
                    name in {'linoone-galar','zigzagoon-galar'} or
                    name == 'ponyta-galar' and m == 'BodyA')
        if not shiny or not selected:
            continue
        original,info = texture(native_doc,native_binary,native[m])
        current,_ = texture(doc,binary,material)
        assert original.size == current.size
        @lru_cache(maxsize=100000)
        def colour(p): return adjust(name,m,p,True)
        # Keep the existing broad body transfer wherever the targeted recipe
        # leaves the original pixel unchanged.
        pixels=[colour(a) if colour(a)!=a else b for a,b in zip(original.get_flattened_data(),current.get_flattened_data())]
        result=Image.new('RGBA',original.size);result.putdata(pixels)
        assert result.getchannel('A').tobytes()==original.getchannel('A').tobytes()
        if result.tobytes()==current.tobytes():continue
        stream=BytesIO();result.save(stream,format='PNG')
        pbr['baseColorTexture']={**pbr['baseColorTexture'],'index':append_png(doc,binary,stream.getvalue(),m+'_review_colour',0)}
        # Coloured eye emission must follow the same palette as its albedo.
        if 'Eye' in m and material.get('emissiveTexture'):
            material['emissiveTexture']={**pbr['baseColorTexture']}
            material['emissiveFactor']=[.15,.15,.15]
        changes.append(m)
    target=output/(row['species']+'.glb');write_glb(target,doc,binary)
    result=dict(row,path=str(target),glb_sha256=sha(target),runtime_approved=False)
    result.pop('runtime_path',None);result.pop('runtime_sha256',None)
    result['regional_visual_repair']={'source_sha256':sha(source),'changes':changes,
        'geometry_motion_parity':compare(source,target) if sha(source)!=sha(target) else 'unchanged',
        'reference':str(ROOT/'assets/sprites/pokemon/pokemon_home_shiny'/(name+'.png')),
        'reference_sha256':sha(ROOT/'assets/sprites/pokemon/pokemon_home_shiny'/(name+'.png')),
        'approval':False}
    return result


# Explicit cells inspected in the native baked atlas: (columns, rows, closed
# row per column). Paired columns include mirrored eyes in the source UV map.
CELLS={'darmanitan-galar':(2,4,[2,2]), 'darumaka-galar':(2,4,[2,2]),
       'linoone-galar':(4,4,[1,3,3,1]), 'zigzagoon-galar':(2,4,[2,2]),
       'ponyta-galar':(4,4,[1,3,3,1]), 'rapidash-galar':(4,4,[1,3,3,1]),
       'rattata-alola':(4,4,[3,1,1,3]),
       'raticate-alola':(8,4,[2,1,1,2,2,1,1,2]),
       'raticate-alola-totem':(8,4,[2,1,1,2,2,1,1,2])}


def sleep_states(row, output):
    name=row['species'].removesuffix('-shiny')
    if name not in CELLS:return {}
    doc,binary=chunks(Path(row['path']));states={};cols,rows,indices=CELLS[name]
    for material in doc['materials']:
        if 'eye' not in material['name'].lower():continue
        original,_=texture(doc,binary,material);closed=Image.new('RGBA',original.size)
        for col,source_row in enumerate(indices):
            cell=original.crop((round(col*original.width/cols),round(source_row*original.height/rows),round((col+1)*original.width/cols),round((source_row+1)*original.height/rows)))
            for r in range(rows):closed.paste(cell,(round(col*original.width/cols),round(r*original.height/rows)))
        p=output/row['species']/(material['name']+'.png');p.parent.mkdir(parents=True,exist_ok=True);closed.save(p)
        states[material['name']]={'path':str(p),'sha256':sha(p),'disable_emission_on_sleep':True,
            'source_glb_sha256':row['glb_sha256'],'source_cell_grid':[cols,rows],'source_rows':indices,
            'policy':'inspected closed cells from the same native eye atlas; visual proposal'}
    return states


def main():
    out=WORK/'visual-repairs-v1';out.mkdir(exist_ok=False)
    stage=json.loads((WORK/'stage-v3.json').read_text());result=[]
    for row in stage:
        name=row['species'].removesuffix('-shiny')
        if name in FIX:row=repair(row,out)
        row['eye_states']=sleep_states(row,out/'sleep')
        result.append(row)
    (out/'stage.json').write_text(json.dumps(result,indent=2)+'\n')
    print('Review candidates',len(result),'sleep materials',sum(len(r['eye_states'])for r in result))


if __name__=='__main__':main()
