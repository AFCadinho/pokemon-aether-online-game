"""Offline model-coverage audit against local species data and the pinned v13 release.

Does not approve models, change runtime bindings, fetch assets, or access production.
Showdown equivalence diagnoses naming differences; it is not a runtime alias.
"""
import argparse
from collections import Counter, defaultdict
from datetime import date
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
ALIASES = {'meowstic-f-mega': 'meowstic-m-mega',
           'mr.-mime-galar': 'mr-mime-galar', 'mrmime-galar': 'mr-mime-galar'}


def read(path):
    return json.loads(path.read_bytes())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def revision(path):
    return subprocess.check_output(['git', '-C', str(path), 'rev-parse', 'HEAD'], text=True).strip()


def pair_present(models, key):
    return all(key + suffix in models for suffix in ('', '@shiny'))


def audit(backend):
    module_path = backend / 'account-service/pokedex_species.py'
    spec = importlib.util.spec_from_file_location('coverage_dex', module_path)
    dex = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(dex)
    all_species = dex._load_species_entries()
    visible = {n for n, _ in dex._species_entries_for_dex('national')}
    assert len(all_species) == len({n for n, _ in all_species})
    files = sorted((backend / 'pokemon-data/data/species').glob('*.json'))
    species_pins = {p.name: sha(p) for p in files}
    reviewed_path = ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json'
    reviewed = read(reviewed_path)['models']
    screened = read(ROOT / 'scripts/battle/battle_ui/screened_model_catalog.json')['models']
    assert reviewed_path.read_bytes() == (ROOT / 'launcher/data/reviewed_model_catalog.json').read_bytes()
    # Explicit aliases are a property of the current resolver, not guessed from anatomy.
    resolver = (ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.gd').read_text()
    assert 'base = "meowstic-m-mega"' in resolver and 'base = "mr-mime-galar"' in resolver
    release = read(ROOT / 'data/approved_3d_release_v13.json')
    index_path = ROOT / 'release/approved_3d_bundles_v13_index.json'
    assert sha(index_path) == release['index']['sha256']
    assert index_path.stat().st_size == release['index']['size_bytes']
    assert index_path.read_bytes() == (ROOT / 'data/approved_3d_bundles_v13_index.json').read_bytes()
    trusted = {}
    for path in ['data/model_pair_catalog.json', 'data/model_pair_geometry_catalog.json']:
        for asset in read(ROOT / path)['assets']:
            trusted[asset['asset_id']] = asset
    selected = read(index_path)['assets']
    assert set(release['requiredAssetIds']) == {a['asset_id'] for a in selected}
    active = {}
    for ref in selected:
        asset = trusted[ref['asset_id']] if ref.get('format') == 'model-pair-ref-v1' else ref
        assert asset['sha256'] == ref['sha256']
        for appearance in asset['appearances']:
            identity = appearance['runtime_identity']
            model = reviewed[identity]
            source = appearance.get('source_sha256', appearance['runtime_sha256'])
            assert source in [model['sha256'], *model.get('previous_sha256', [])]
            assert source not in model.get('revoked_runtime_sha256', [])
            assert identity not in active
            active[identity] = asset['asset_id']
    prepared = {}
    for relative in ['release/approved_3d_therian_index.json', 'release/approved_3d_urshifu_index.json']:
        for asset in read(ROOT / relative)['assets']:
            for appearance in asset['appearances']:
                identity = appearance['runtime_identity']
                assert appearance['source_sha256'] == reviewed[identity]['sha256']
                prepared[identity] = relative
    # Resolve species_id first: some stored showdown_id values discard real forms,
    # e.g. meloetta-pirouette -> meloetta. Never use those values to hide a gap.
    names = sorted({n for n, _ in all_species} | {n for n in reviewed if '@' not in n})
    js = '''const fs = require('fs'); const {Dex} = require('pokemon-showdown');
const result = {}; for (const name of JSON.parse(fs.readFileSync(0, 'utf8'))) {
 const s = Dex.species.get(name); result[name] = {exists:s.exists, id:s.id,
 name:s.name, base:s.baseSpecies, forme:s.forme, num:s.num}; }
process.stdout.write(JSON.stringify(result));'''
    showdown = json.loads(subprocess.check_output(['node', '-e', js], input=json.dumps(names),
        text=True, cwd=backend / 'showdown-api'))
    by_dex = defaultdict(list)
    for name in reviewed:
        if '@' not in name and pair_present(reviewed, name) and showdown[name]['exists']:
            by_dex[showdown[name]['id']].append(name)
    rows = []
    for name, data in all_species:
        key = ALIASES.get(name, name)
        sd = showdown[name]
        equivalent = sorted(by_dex.get(sd['id'], [])) if sd['exists'] else []
        if pair_present(active, key):
            status = 'selected_v13'
        elif pair_present(reviewed, key):
            status = 'prepared_not_selected' if pair_present(prepared, key) else 'reviewed_not_selected'
        elif equivalent:
            status = 'model_exists_under_other_name'
        else:
            status = 'missing_pair'
        rows.append({'species': name, 'name': data['name'], 'family': sd['base'],
            'visible_pokedex': name in visible, 'canonical_model_key': key,
            'status': status, 'equivalent_model_keys': equivalent if status == 'model_exists_under_other_name' else [],
            'normal_reviewed': key in reviewed, 'shiny_reviewed': key + '@shiny' in reviewed,
            'screened_only': key in screened or key + '@shiny' in screened,
            'showdown_id_from_species': sd['id'], 'stored_showdown_id': data.get('showdown_id'),
            'showdown_forme': sd['forme']})
    assert all(showdown[r['species']]['exists'] for r in rows if r['status'] == 'missing_pair'), 'Unresolved missing species need explicit review'
    assert species_pins == {p.name: sha(p) for p in files}, 'Species inputs changed during audit'
    pins = ['scripts/battle/battle_ui/reviewed_model_catalog.json',
        'scripts/battle/battle_ui/screened_model_catalog.json', 'scripts/battle/battle_ui/reviewed_model_catalog.gd',
        'scripts/services/model_pair_pilot.gd', 'data/approved_3d_release_v13.json',
        'release/approved_3d_bundles_v13_index.json', 'data/model_pair_catalog.json',
        'data/model_pair_geometry_catalog.json', 'release/approved_3d_therian_index.json',
        'release/approved_3d_urshifu_index.json']
    sdroot = backend / 'showdown-api/node_modules/pokemon-showdown'
    return {'schema': 1, 'snapshot_date': date.today().isoformat(), 'scope': 'Local species coverage; pinned selected v13, no live R2 check or visual review',
        'frontend_revision': revision(ROOT), 'backend_revision': revision(backend),
        'frontend_input_sha256': {p: sha(ROOT / p) for p in pins},
        'pokedex_module_sha256': sha(module_path), 'species_file_sha256': species_pins,
        'showdown_version': read(sdroot / 'package.json')['version'],
        'showdown_input_sha256': {p: sha(sdroot / p) for p in ['package.json', 'dist/data/pokedex.js', 'dist/data/aliases.js']},
        'summary': {'species_files': len(files), 'visible_pokedex': len(visible),
            'reviewed_pairs': len(reviewed) // 2, 'selected_v13_pairs': len(selected),
            'visible_status': dict(Counter(r['status'] for r in rows if r['visible_pokedex'])),
            'partial_reviewed_pairs': [r['species'] for r in rows if r['normal_reviewed'] != r['shiny_reviewed']]},
        'entries': rows}


def markdown(result):
    summary = result['summary']; rows = result['entries']
    missing = [r for r in rows if r['visible_pokedex'] and r['status'] == 'missing_pair']
    groups = defaultdict(list)
    for row in missing:
        groups[row['family']].append(row['species'])
    out = ['# Alternate-form model coverage audit', '', f"Snapshot: {result['snapshot_date']}.", '',
        'This audit compares all local Pokémon species files and the actual national Pokédex visibility '
        'filter against both normal/shiny model bindings, the compiled model aliases, and the hash-pinned '
        'selected v13 index. It expands shared-pack references through the same catalog/geometry precedence '
        'as the runtime. It does not access production or prove that source meshes do not exist on disk.', '',
        f"Inspected **{summary['species_files']} species files**, **{summary['visible_pokedex']} visible Pokédex entries**, "
        f"**{summary['reviewed_pairs']} reviewed model pairs**, and **{summary['selected_v13_pairs']} selected v13 pairs**.", '',
        '| Visible Pokédex status | Entries |', '| --- | ---: |']
    out += [f'| {k} | {v} |' for k, v in summary['visible_status'].items()]
    out += ['', f'**{len(missing)} visible form identities lack a reviewed pair or an equivalent reviewed model.** '
        'This is a count of missing form coverage, not necessarily distinct meshes: colours, type materials, '
        'sizes, cosmetic forms and Totem forms are included. Several can potentially share geometry. '
        'No partially reviewed normal/shiny pairs were found.', '',
        '## Recommended first batches', '',
        '- Rotom Heat/Wash/Frost/Fan/Mow (5): common battle variants with different appliances.',
        '- Enamorus Therian, Dialga/Palkia/Giratina Origin, Groudon/Kyogre Primal, '
        'Necrozma Dusk Mane/Dawn Wings/Ultra, Zygarde 10%/Complete.',
        '- Deoxys Attack/Defense/Speed, Hoopa Unbound, Shaymin Sky, Keldeo Resolute, '
        'Meloetta Pirouette, Lycanroc Dusk/Midnight, Toxtricity Low Key and Ursaluna Bloodmoon.',
        '- Then gender, seasonal, colour/pattern, type-material and other cosmetic variants. '
        'Batch ordering is an engineering recommendation, not measured usage frequency.', '',
        '## Prepared, awaiting model-release selection', '',
        'These forms have both palettes reviewed and a local candidate index, but are absent from the selected v13 index:', '']
    out += ['- `' + r['species'] + '`' for r in rows if r['status'] == 'prepared_not_selected']
    out += ['', 'Black/White Kyurem, crowned Zacian/Zamazenta and both Calyrex rider forms are already covered '
        'by selected v13. Ordinary regional forms and the current Mega forms need no new model in this audit '
        '(including the intentional shared female/male Mega Meowstic binding).', '',
        '## Naming differences: models exist', '',
        'These species-data names have an equivalent reviewed model under another key. Showdown identity '
        'equivalence proves inventory overlap; it does **not** add a frontend alias or prove every caller '
        'uses the right key. Test the actual emitted battle identity before changing these bindings.', '',
        '| Species-data identity | Existing model |', '| --- | --- |']
    out += [f"| {r['species']} | {', '.join(r['equivalent_model_keys'])} |" for r in rows if r['status'] == 'model_exists_under_other_name']
    out += ['', 'Meloetta Pirouette is a real gap: its species file currently stores `showdown_id=meloetta`. '
        'The audit resolves the explicit `species_id` first so this data inconsistency cannot incorrectly '
        'count the Aria model as Pirouette coverage. Hidden `greninja-bond` is reported in JSON but excluded '
        'from visible-form totals; the backend explicitly treats that hidden starting identity as Greninja.', '',
        '## Complete missing list by family', '', '| Family | Count | Missing species identities |', '| --- | ---: | --- |']
    out += [f"| {name} | {len(values)} | {', '.join(values)} |" for name, values in sorted(groups.items())]
    out += ['', '## Verification and limits', '',
        'The script checks game/launcher registry parity, the release index size/SHA and asset set, every '
        'expanded pack binding and accepted non-revoked source hash, candidate bindings, unique species IDs, '
        'and stable species inputs. JSON records individual rows and source hashes. No gameplay changes, '
        'model approvals, uploads, releases or visual qualifications are performed.', '',
        'This is coverage of species represented in this repository, not every form ever present in a '
        'Pokémon title. A listed form is not proof it is currently obtainable or allowed in every battle format. '
        'Missing identity coverage may trigger 2D when the exact missing key reaches the presenter. '
        'Source availability and whether an existing mesh/material can safely be reused require a separate intake.', '',
        'Reproduce from an assigned frontend worktree with the backend as a read-only input:', '', '```sh',
        'python3 tools/sprite_factory/audit_alternate_model_coverage.py --backend /path/to/pokemon-aether-backend', '```', '']
    return '\n'.join(out)


if __name__ == '__main__':
    sys.dont_write_bytecode = True
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--backend', type=Path, required=True)
    args = parser.parse_args()
    result = audit(args.backend.resolve())
    (ROOT / 'tools/sprite_factory/alternate_model_coverage_audit.json').write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
    (ROOT / 'docs/alternate-model-coverage-audit.md').write_text(markdown(result))
    print(json.dumps(result['summary'], indent=2))
