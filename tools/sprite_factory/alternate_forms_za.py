"""Pin alternate forms from the independently supplied Z-A source archive."""
from alternate_forms_batch import *

FORMS = {'zygarde-10':'pm0770_11_00','zygarde-complete':'pm0770_13_00',
    'floette-eternal':'pm0714_16_00', 'kyogre-primal':'pm0382_51_00', 'groudon-primal':'pm0383_51_00'}
for offset,name in enumerate(['heart','star','diamond','debutante','matron','dandy','la-reine','kabuki','pharaoh'],12):
    FORMS['furfrou-'+name]=f'pm0701_{offset:02}_00'
for offset,name in enumerate(['douse','shock','burn','chill'],12):
    FORMS['genesect-'+name]=f'pm0649_{offset:02}_00'


def main():
    root=WORK/'za-sources'; original={r['species']:r for r in read(INTAKE)['entries']}
    rows=[]
    for name,resource in sorted(FORMS.items()):
        directory=root/resource[:6]/resource
        request={'species':name,'pm':int(resource[2:6]),'resource_id':resource}
        if name.startswith('genesect-'):
            request['motion_overrides']={'idle':'00001_battlewait01_loop'}
        source=source_entry(request,root,root)
        def pinned(path):return {'path':str(path),'bytes':path.stat().st_size,'sha256':sha(path)}
        files=[pinned(p) for p in sorted(directory.rglob('*')) if p.is_file() and p.name!='desktop.ini']
        motions=[Path(p) for p in [*source['motions'].values(),*source['motion_channels'].values()] if p]
        holds=[s for s in source['warnings'] if s.startswith(('missing_action:','motion_bank_hold:','missing_model'))]
        if any(source['motions'][a] and not source['motion_channels'][a] for a in source['motions']):holds.append('Missing material-motion companion')
        normal=directory/(resource+'.trmtr');rare=directory/(resource+'_rare.trmtr')
        if not normal.exists() or not rare.exists():holds.append('Missing normal/rare material table')
        rows.append({'species':name,'national_dex':original[name]['national_dex'],'resource':resource,
            'source_directory':str(directory),'scvi_files':files,'selected_motion_files':[pinned(p) for p in sorted(set(motions))],
            'actions':{a:Path(p).stem for a,p in source['motions'].items() if p},'rare_texture_replacements':[],
            'dynamic_visibility_review':True,'identical_source_variant_review':not holds and inspect_materials(normal)==inspect_materials(rare),
            'source_archive':'LegendsZAPkmnModelDumpWithDLC.rar','archive_resource_directory':str(directory.relative_to(root)),
            'status':'held' if holds else 'native_candidate','holds':holds,'runtime_approved':False,'identity_reviewed':False})
    write(HERE/'alternate_forms_za_intake.json',{'schema':1,'source_listing_sha256':sha(WORK/'za-listing.txt'),'entries':rows})
    print(dict(Counter(r['status'] for r in rows)))


if __name__=='__main__':main()
