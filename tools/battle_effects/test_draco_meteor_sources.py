#!/usr/bin/env python3
"""Check Draco subset provenance, decoder boundaries and reproducible packaging."""
import argparse
import hashlib
import json
import tempfile
from pathlib import Path
from extract_sv_ember import inspect_particle, subset_bntx, legacy_bntx
from package_sv_fire_bubbles import package
from sv_draco_meteor import PARTS, TEXTURES

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def check(source, extracted):
    manifest = json.loads((extracted / 'manifest.json').read_text())
    total = 0
    for part in PARTS:
        path = source / (part + '.ptcl')
        before = sha(path)
        info, bntx = inspect_particle(path.read_bytes())
        assert before == manifest['parts'][part]['source_sha256']
        total += len(info['emitters'])
        assert bntx == (extracted / part / 'source.bntx').read_bytes()
        legacy_bntx(subset_bntx(bntx,TEXTURES[part]),allow_bc5=True)
        try:
            subset_bntx(bntx,['missing_texture'])
            raise AssertionError('Missing texture accepted')
        except ValueError:
            pass
        if part != 'ew0434_charge':
            for unsupported in ['upt_ew414_normal_n','cpt_4_circle0001_m']:
                try:
                    legacy_bntx(subset_bntx(bntx,[unsupported]),allow_bc5=True)
                    raise AssertionError('Unsupported texture accepted')
                except ValueError:
                    pass
        assert sha(path)==before
    assert total==38
    runtime = Path(__file__).resolve().parents[2]/'assets/battles/moves_3d/sv_dracometeor'
    with tempfile.TemporaryDirectory(dir=extracted.parent) as folder:
        package(extracted,Path(folder))
        for path in runtime.iterdir():
            if path.suffix in ['.png','.json']:
                assert path.read_bytes()==(Path(folder)/path.name).read_bytes(),path.name
    print('DRACO_SOURCE_OK emitters=38 textures=9 source_hashes=true unsupported_maps_rejected=true reproducible=true')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--extracted',type=Path,required=True)
    args=parser.parse_args()
    check(args.source,args.extracted)
