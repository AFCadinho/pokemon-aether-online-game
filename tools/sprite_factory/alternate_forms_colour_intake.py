"""Pin source form slots for shared Arceus and Squawkabilly geometry."""
from alternate_forms_batch import *

TYPES=['normal','fighting','flying','poison','ground','rock','bug','ghost','steel','fire','water','grass','electric','psychic','ice','dragon','dark','fairy']
SELECTIONS={**{'arceus-'+t:('pm0493_11_00',i) for i,t in enumerate(TYPES) if i},
    **{'squawkabilly-'+t:('pm1064_11_00',i) for i,t in enumerate(['green','blue','yellow','white']) if i}}


def main():
    originals={r['species']:r for r in read(INTAKE)['entries']};rows=[]
    for name,(resource,index) in sorted(SELECTIONS.items()):
        original=originals[name];source=source_entry({'species':name,'pm':int(resource[2:6]),'resource_id':resource},MODELS,MOTIONS)
        directory=MODELS/resource[:6]/resource;selector=directory/(resource+'.trmmt')
        identity=[r for r in original['catalog_rows'] if r['form']==index and r['resource_id']==resource]
        assert len(identity)==1
        motions=[Path(p) for p in [*source['motions'].values(),*source['motion_channels'].values()] if p]
        holds=[s for s in source['warnings'] if s.startswith(('missing_action:','motion_bank_hold:','missing_model'))]
        row={'species':name,'national_dex':original['national_dex'],'resource':resource,
            'catalog_identity':identity[0],'material_selector':{'path':str(selector),'sha256':sha(selector),'index':index},
            'scvi_files':[pin(p) for p in sorted(directory.rglob('*')) if p.is_file() and p.name!='desktop.ini'],
            'selected_motion_files':[pin(p) for p in sorted(set(motions))],
            'actions':{a:Path(p).stem for a,p in source['motions'].items() if p},
            'rare_texture_replacements':[],'dynamic_visibility_review':True,'status':'held' if holds else 'native_candidate',
            'holds':holds,'runtime_approved':False,'identity_reviewed':False}
        rows.append(row)
    write(HERE/'alternate_forms_colour_intake.json',{'schema':1,'entries':rows,'runtime_approved':False})
    print(dict(Counter(r['status'] for r in rows)))


if __name__=='__main__':main()
