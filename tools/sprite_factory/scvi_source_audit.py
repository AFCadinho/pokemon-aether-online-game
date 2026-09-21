"""Read-only fixed-cohort skeleton and channel audit. Never emits approval."""
import argparse
import json
import sys
from collections import Counter
from pathlib import Path

from scvi_identity import sha
from scvi_tracm import _Buffer
from material_profiles import read_profiles
from scvi_material_probe import inspect_materials


def plain(value):
    if isinstance(value, (str, int, float, bool, type(None))):
        return value
    if isinstance(value, bytes):
        return value.decode('utf-8')
    if isinstance(value, (list, tuple)):
        return [plain(v) for v in value]
    return {k: plain(v) for k, v in vars(value).items()}


def differences(a, b, path=''):
    if type(a) != type(b):
        return [{'path': path, 'model': a, 'romfs': b}]
    if isinstance(a, dict):
        if a.keys() != b.keys():
            return [{'path': path, 'model': sorted(a), 'romfs': sorted(b)}]
        return [d for k in a for d in differences(a[k], b[k], path + '/' + k)]
    if isinstance(a, list):
        if len(a) != len(b):
            return [{'path': path + '/length', 'model': len(a), 'romfs': len(b)}]
        return [d for i, (x, y) in enumerate(zip(a,b)) for d in differences(x,y,path+'/'+str(i))]
    return [] if a == b else [{'path': path, 'model': a, 'romfs': b}]


def timeline_counts(path):
    b = _Buffer(Path(path).read_bytes())
    root = b.u32(0)
    tracks = b.tables(root, 1)
    return ([b.scalar(root, s, b.u8) for s in (2,3,4)],
            [sum(b.pointer(t,s) is not None for t in tracks) for s in (4,5,6)])


def visibility_families(path):
    b = _Buffer(Path(path).read_bytes())
    kinds = Counter()
    for track in b.tables(b.u32(0),1):
        visible = b.pointer(track,5)
        if visible is None:
            continue
        info = b.pointer(visible,2)
        kind = b.scalar(info,0,b.u8) if info is not None else 0
        kinds[{1:'fixed_bool',2:'dynamic_bool',3:'framed16_bool',4:'framed8_bool'}.get(kind,'unknown_'+str(kind))] += 1
    return kinds


def run(inventory, importer, dependencies):
    sys.path.insert(0, str(dependencies))
    sys.path.insert(0, str(importer))
    # Only generated schema modules, never the Blender add-on entry point.
    from Titan.Model.TRSKL import TRSKLT
    records, counts, visibility = [], Counter(), Counter()
    payload = json.loads(inventory.read_text())
    names = [row['species'] for row in payload['entries']]
    expected = {e['species'] for e in json.loads(Path(__file__).with_name('catalog_100_observation_batch.json').read_text())['entries']}
    if len(names) != 100 or set(names) != expected:
        raise ValueError('Audit requires the complete unique 100-species cohort')
    for row in payload['entries']:
        record = {'species': row['species'], 'runtime_approved': False}
        if not row.get('identity') or not row.get('model_dir'):
            record['status'] = 'identity_absent'
            records.append(record)
            continue
        rid = row['identity']
        model = Path(row['model_dir']) / (rid + '.trskl')
        source = Path(row['motion_dir']) / (rid + '.trskl')
        record.update(resource_id=rid, model_sha256=sha(model), romfs_sha256=sha(source))
        a, b = [plain(TRSKLT.InitFromPackedBuf(p.read_bytes())) for p in (model,source)]
        diff = differences(a,b)
        record.update(status='byte_equal' if model.read_bytes()==source.read_bytes() else 'source_review_required',
                      differences=diff, nodes=len(a['transformNodes']), bones=len(a['bones']))
        record['priority_nodes'] = [n['name'] for n in a['transformNodes'] if n['priority']]
        record['romfs_priority_nodes'] = [n['name'] for n in b['transformNodes'] if n['priority']]
        record['timelines'] = {'files':0, 'count_mismatches':[]}
        record['visibility_families'] = Counter()
        for p in sorted(Path(row['motion_dir']).glob('*.tracm')):
            declared, actual = timeline_counts(p)
            record['timelines']['files'] += 1
            counts['tracm_files'] += 1
            counts['count_matches'] += declared == actual
            kinds = visibility_families(p)
            visibility.update(kinds)
            record['visibility_families'].update(kinds)
            if declared != actual:
                record['timelines']['count_mismatches'].append({'file':p.name,'declared':declared,'actual':actual})
        material = Path(row['model_dir']) / (rid + '.trmtr')
        record['materials'] = read_profiles(material,sha(material))
        blocked = {m['material'] for m in record['materials'] if not m['export_supported']}
        record['unsupported_shader_signatures'] = [{'material':m['name'],'shaders':m['shaders']}
            for m in inspect_materials(material) if m['name'] in blocked]
        records.append(record)
    return {'schema':1,'scope':'source_diagnostic_not_equivalence_waiver', 'runtime_approved':False,
            'inventory_sha256':sha(inventory),'summary':dict(counts),'visibility_families':dict(visibility),
            'decoder_sha256':{str(p.relative_to(importer)):sha(p) for p in sorted((importer/'Titan/Model').glob('*.py'))},
            'importer_consumer_sha256':sha(importer/'PokemonSwitch.py'), 'entries':records}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('inventory','importer','dependencies','output'):
        p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args()
    result=run(a.inventory,a.importer,a.dependencies)
    with a.output.open('x') as out:
        json.dump(result,out,indent=2)
    print(json.dumps(result['summary']))


if __name__=='__main__': main()
