#!/usr/bin/env python3
"""Check complete release bindings and reject corrupt index/approval/pin tuples."""
import copy
import json
from pathlib import Path
from package_approved_3d_release_v11 import ROOT, outputs, validate_local, BINDING, REGISTRIES
from package_launcher_release import _build_asset_bundle_index


def main():
    metadata=validate_local()
    index=json.loads((ROOT/'release/approved_3d_bundles_v11_index.json').read_bytes())
    binding=json.loads((ROOT/BINDING).read_bytes())
    registries=[json.loads((ROOT/n).read_bytes()) for n in REGISTRIES]
    pin=metadata['index']
    item=f"{metadata['revision']}:{pin['object_key']}:{pin['size_bytes']}:{pin['sha256']}"
    descriptor=_build_asset_bundle_index(item,'https://updates.pokeaether.com')
    assert len(descriptor['requiredAssetIds'])==1200
    for variant in ['index_hash','source_hash','cache_cost','missing_model']:
        bad_index=copy.deepcopy(index); bad_binding=copy.deepcopy(binding); bad_reg=copy.deepcopy(registries)
        identity=bad_index['assets'][0]['appearances'][0]['runtime_identity']
        if variant=='index_hash': bad_index['assets'][0]['appearances'][0]['runtime_sha256']='0'*64
        elif variant=='source_hash': bad_binding['models'][identity]['source_sha256']='0'*64
        elif variant=='cache_cost': bad_reg[0]['models'][identity]['cache_source_bytes']=1; bad_reg[1]=copy.deepcopy(bad_reg[0])
        else: bad_binding['models'].pop(identity)
        try: outputs(bad_index,bad_binding,bad_reg)
        except AssertionError: pass
        else: raise AssertionError('Invalid binding accepted: '+variant)
    try: _build_asset_bundle_index(item[:-64]+'0'*64,'https://updates.pokeaether.com')
    except SystemExit: pass
    else: raise AssertionError('Wrong packaged pin accepted')
    report=ROOT/'.tmp/lossless-release-binding-v1/packaged-descriptor.json'
    report.parent.mkdir(parents=True,exist_ok=True)
    report.write_text(json.dumps(descriptor)+'\n')
    print('PACKAGE_APPROVED_3D_V11_OK assets=1200 bindings=2400 cache_costs=true invalid_bindings_rejected=4 bad_pin_rejected=true')


if __name__=='__main__': main()
