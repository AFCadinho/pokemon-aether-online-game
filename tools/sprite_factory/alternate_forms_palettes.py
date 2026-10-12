"""Apply explicit native form slots to colour fields, preserving all other bytes."""
import math
import struct
from pathlib import Path
from scvi_identity import Buffer
from scvi_tracm import _Buffer
from scvi_form_material import sample
from alternate_forms_batch import WORK, sha, write
from catalog_remaining_eye_bake import chunks


def validate_bindings(document, bindings):
    """A material-wide edit must cover every mesh using that parameter."""
    uses = {}
    for node in document['nodes']:
        if 'mesh' not in node:
            continue
        for primitive in document['meshes'][node['mesh']]['primitives']:
            material = document['materials'][primitive['material']]['name']
            uses.setdefault(material, set()).add(node['name'])
    targets = {}
    for mesh, material, parameter, _values in bindings:
        mesh = mesh.removesuffix('_shape')
        if mesh not in uses.get(material, set()):
            raise ValueError('Palette binding has no exported mesh/material use')
        targets.setdefault((material, parameter), set()).add(mesh)
    if any(meshes != uses[material] for (material, _), meshes in targets.items()):
        raise ValueError('Material-wide palette would alter an unbound mesh')


def colours(path, variant, index):
    if variant not in ('normal','rare') or type(index) is not int or not 0 <= index <= 17:
        raise ValueError('Invalid explicit form selector')
    view=_Buffer(path.read_bytes());matches=[v for v in view.tables(view.u32(0),2) if view.string(v,0)==variant]
    if len(matches)!=1:raise ValueError('Missing or ambiguous palette variant')
    result={};bindings=[]
    for prop in view.tables(matches[0],3):
        if view.string(prop,0)!='color':raise ValueError('Unhandled form selector property')
        mappings={tuple(view.string(m,i) for i in range(3)) for m in view.tables(prop,1)}
        embedded=view.pointer(prop,4);vector=view.pointer(embedded,0)
        clip=_Buffer(view.data[vector+4:vector+4+view.u32(vector)])
        found=set()
        for timeline in clip.tables(clip.u32(0),1):
            if clip.field(timeline,5) or clip.field(timeline,6):
                raise ValueError('Non-material form selector channel')
            mesh=clip.string(timeline,0)
            for material in clip.tables(clip.pointer(timeline,4),2):
                name=clip.string(material,0)
                for parameter in clip.tables(material,2):
                    key=clip.string(parameter,0)
                    if (mesh,name,key) not in mappings:continue # Not bound by this source selector.
                    found.add((mesh,name,key))
                    values=[];channels=clip.pointer(parameter,1)
                    for channel in range(4):
                        keys=[tuple(clip.scalar(k,i,lambda o:struct.unpack_from('<f',clip.data,o)[0]) for i in (0,1))
                              for k in clip.tables(clip.pointer(channels,channel),0)]
                        values.append(sample(keys,index))
                    if (name,key) in result and result[name,key]!=values:
                        raise ValueError('Mesh-specific material colours conflict')
                    result[name,key]=values;bindings.append([mesh,name,key,values])
        if found!=mappings:raise ValueError('Missing bound source palette channel')
    return result,bindings


def apply(source, selector, variant, index, output):
    selected,bindings=colours(selector,variant,index)
    original=source.read_bytes();data=bytearray(original);view=Buffer(original);changed=[]
    remaining=set(selected)
    for material in view.tables(view.number(0),1):
        name=view.string(material,0)
        for parameter in view.tables(material,7):
            key=(name,view.string(parameter,0))
            if key not in selected:continue
            offset=view.field(parameter,1)
            if offset is None:raise ValueError('Missing target palette vector')
            values=selected[key]
            if not all(math.isfinite(v) for v in values):raise ValueError('Nonfinite palette')
            struct.pack_into('<4f',data,offset,*values);remaining.remove(key)
            changed.extend(range(offset,offset+16))
    if remaining:raise ValueError('Palette refers to unknown native material fields')
    allowed=set(changed)
    assert len(data)==len(original) and all(a==b or i in allowed for i,(a,b) in enumerate(zip(original,data)))
    output.write_bytes(data)
    return {'source_sha256':sha(source),'selector_sha256':sha(selector),'variant':variant,'index':index,
        'output_sha256':sha(output),'bindings':bindings,'only_selected_colour_bytes_changed':True}


def project(row,directory):
    selector=Path(row['material_selector']['path']);index=row['material_selector']['index']
    if sha(selector)!=row['material_selector']['sha256']:raise ValueError('Palette source changed')
    output=WORK/'material-palettes'/row['species'];output.mkdir(parents=True,exist_ok=True)
    reports=[]
    document, _ = chunks(WORK/'export'/row['species']/'model.glb')
    for path in directory.iterdir():
        if path.suffix=='.trmtr':continue
        target=output/path.name
        if not target.exists():target.symlink_to(path)
    for variant in ('normal','rare'):
        name=row['resource']+('_rare' if variant=='rare' else '')+'.trmtr'
        report = apply(directory/name,selector,variant,index,output/name)
        validate_bindings(document, report['bindings'])
        reports.append(report)
    write(output/'palette-proof.json',reports)
    return output
