"""Account for every original gap, including unresolved source qualification."""
from collections import Counter, defaultdict
from pathlib import Path
from alternate_forms_batch import ROOT, WORK, INTAKE, read, write, sha


def result():
    receipt=read(Path(__file__).with_name('alternate_forms_qualification.json'))
    admitted=set(receipt['forms'])
    legacy={r['species']:r for r in read(WORK/'legacy-intake.json')['entries']}
    alternatives={}
    for name in ('za','colour'):
        for row in read(Path(__file__).with_name(f'alternate_forms_{name}_intake.json'))['entries']:
            alternatives[row['species']]=row
    rows=[]
    for original in read(INTAKE)['entries']:
        name=original['species'];row={'species':name,'family':original['family'],'national_dex':original['national_dex']}
        source=alternatives.get(name,original)
        row['resource']=source.get('resource') or legacy.get(name,{}).get('resource')
        if name in admitted:
            row.update(status='prepared_not_selected',reason='Normal and shiny qualified locally; awaiting a selected model release.')
        else:
            row['status']='held'
            candidates=[]
            for stage in ('delivery','battle','appearance','runtime','material','legacy-material','legacy-export'):
                path=WORK/'status'/stage/(name+'.json')
                if path.exists():
                    state=read(path)
                    if state['status']=='held':candidates.append((stage,state.get('reason') or str(state.get('failures'))))
            if candidates:
                row['stage'],row['reason']=candidates[0]
            elif source.get('holds') and name in alternatives:
                row.update(stage='source-motion',reason='; '.join(source['holds']))
            else:
                fallback=legacy.get(name,original)
                row.update(stage=fallback['status'],reason=fallback.get('reason') or '; '.join(fallback.get('holds',[])))
            # A strict bank selector rejecting a variant does not prove the
            # archive lacks animation. Preserve that distinction in the report.
            if name.startswith('silvally-'):
                row.update(stage='source-binding',reason='Typed own rigs found. Archived actions use the base rig prefix; bone/skin compatibility and normal/shiny material bindings still need proof.')
            if name.startswith('unown-') or name in ('burmy-sandy','burmy-trash','wormadam-sandy','wormadam-trash','cherrim-sunshine'):
                row.update(stage='source-material',reason='Own geometry and animations exported. Matching verified normal/shiny material tables are unavailable in the inspected SCVI/ZA route; archived material reconstruction remains unqualified.')
            if name in ('kyogre-primal','groudon-primal'):
                row.update(stage='source-motion',reason='ZA source geometry and battle actions found; the required sleep action is absent from the selected native bank.')
            if name=='rotom-fan':
                row.update(stage='source-shader',reason='Detailed base and layer-mask textures use different resolutions. Exact native multi-texture shader sampling is required; downsampling is refused.')
            if name=='zygarde-10':
                row.update(stage='source-shader',reason='Native Fresnel/probe material remains unqualified: the source texture reference could not be resolved by the material pipeline.')
            assert row['reason'],name
        if name in legacy and legacy[name].get('source'):
            row['archive_source']={k:v for k,v in legacy[name]['source'].items() if k in ('archive','member','sha256','crc32')}
        rows.append(row)
    assert len(rows)==229 and len({r['species'] for r in rows})==229
    report={'schema':1,'scope':'Local batch qualification of all 229 gaps in the pinned audit; no R2 or production access.',
        'source_intake_sha256':sha(INTAKE),'qualification_sha256':sha(Path(__file__).with_name('alternate_forms_qualification.json')),
        'summary':dict(Counter(r['status'] for r in rows)), 'aliases_fixed':8,'entries':rows}
    coverage_path=WORK/'post-batch-audit.json'
    if coverage_path.exists():
        coverage=read(coverage_path)['summary']
        assert coverage['visible_status']['missing_pair']==229-len(admitted)
        assert not coverage['partial_reviewed_pairs']
        report['coverage_after_batch']=coverage
        report['coverage_evidence_sha256']=sha(coverage_path)
    write(Path(__file__).with_name('alternate_forms_batch_result.json'),report)
    groups=defaultdict(list)
    for row in rows:
        if row['status']=='held':groups[(row.get('stage'),row['reason'])].append(row['species'])
    lines=['# Alternate-form batch qualification','',
        f"All 229 audited gaps were included. {len(admitted)} forms ({len(admitted)*2} appearances) are prepared; {229-len(admitted)} remain held.",'',
        f"Prepared pair packs total {receipt['bundle_size_bytes']:,} bytes; their native scene inputs total {receipt['native_scene_bytes']:,} bytes.",'',
        'The prepared index is `release/approved_3d_alternate_forms_index.json`. The selected v13 index, R2 and production were not changed. Eight explicit naming aliases also resolve to existing reviewed pairs.','',
        '## Evidence','',
        f"The admitted set has {receipt['pixel_exact_frames']:,} exact comparison frames, {sum(r['transition_switches'] for r in receipt['entries']):,} animation switches, {sum(r['source_visibility_samples'] for r in receipt['entries']):,} source visibility samples and {sum(r['battle_views'] for r in receipt['entries']):,} battle camera views.",'',
        '- Linux Godot 4.6.2: native normal/shiny poses, back/side views, source visibility transitions, independently sampled 120 Hz floor clearance and both battle cameras.',
        '- Lossless decoded resource equality, physical pack installation, exact Mobile renderer comparisons and actual Team Preview/classic/stadium loading for every admitted pair.',
        '- Native geometry, source animation keys and texture resolution remain intact. Source visibility tracks use continuous nearest sampling to prevent stale accessory visibility on replay.',
        '- Static Arceus palettes come from pinned native form selectors. Alcremie uses the source strawberry visibility selection. Genesect uses its complete standing battle bank. Absent ZA low-detail visibility targets are excluded only when the exported highest-detail mesh exists.',
        '- Diagnostic images and pack files remain in the assigned worktree under `.tmp/alternate-forms-batch-v1`; qualification receipts pin them. Windows, macOS and physical Android were not tested in this batch.','',
        'Autumn, Summer and Winter Sawsbuck passed their source appearance and animation checks, but their shiny pack comparisons differ by a few pixels. For Winter, shared-texture and original-scene lossless packing both reproduced the discrepancy. These are strict render-comparison holds, not evidence of reduced geometry or texture resolution.','',
        '## Reproduction','',
        'Run scripts through `ops/worktrees/slot-env slot-c -- python3 ...` in this assigned task. The source intake pins the external source catalog/files and archive members; the importer revision is pinned by the export tooling. Use a fresh retained output revision when changing a source.','',
        'The native, legacy, ZA and colour intake scripts feed export → material → runtime → appearance → battle → delivery. `POKEAETHER_FORM_BATCH_COHORT` selects `native`, `legacy`, `za` or `colours`. Contact sheets require explicit visual review; existence or a successful export never grants approval. `alternate_forms_admission.py` verifies all evidence before catalog mutation, then checks every admitted model in the real game stages.','',
        '## Prepared forms','', ', '.join(sorted(admitted))+'.','',
        '## Remaining holds','',
        'A hold means this batch has not qualified the required source binding, material or motion. It does not imply no model exists anywhere. Each group below needs the stated evidence before admission.','']
    for (stage,reason),names in sorted(groups.items()):
        lines += [f'- **{stage}** — {reason}\n  Forms: '+', '.join(names)+'.']
    (ROOT/'docs/alternate-forms-batch.md').write_text('\n'.join(lines)+'\n')
    print('BATCH_RESULT',report['summary'])


if __name__=='__main__':result()
