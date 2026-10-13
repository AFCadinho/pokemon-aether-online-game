"""Compose immutable render runs into one final review without overwriting either."""
from pathlib import Path
from final_twenty_one import ROOT,WORK,NAMES,read,write,sha


def compose():
    sources=[WORK/'review-final',WORK/'review-eyeplate-v3']
    out=WORK/'review-complete';out.mkdir(exist_ok=True)
    catalogs={};reviews={};origins={};evidence={}
    for source in sources:
        log=source.with_suffix('.log');text=log.read_text()
        assert 'ERROR:' not in text and 'SCRIPT ERROR' not in text
        for path in [source/'catalog.json',source/'godot-review.json',log]:evidence[str(path.relative_to(WORK))]=sha(path)
        for entry in read(source/'catalog.json')['entries']:catalogs[entry['species']]=entry;origins[entry['species']]=source
        for entry in read(source/'godot-review.json')['entries']:reviews[entry['species']]=entry
    assert set(catalogs)==set(reviews)==set(NAMES)|{n+'-shiny' for n in NAMES}
    artifacts={}
    for species,entry in catalogs.items():
        assert not reviews[species]['errors']
        assert sha(Path(entry['runtime_path']))==entry['runtime_sha256']
        source=origins[species]
        paths=[source/p['image'] for p in reviews[species]['poses']]+[source/(species+'-frames')]
        for path in paths:
            target=out/path.name
            if not target.exists():target.symlink_to(path.resolve(),target_is_directory=path.is_dir())
            assert target.resolve()==path.resolve()
            for file in sorted(path.glob('*.png')) if path.is_dir() else [path]:artifacts[str(file.relative_to(WORK))]=sha(file)
    write(out/'catalog.json',dict(read(sources[0]/'catalog.json'),entries=list(catalogs.values())))
    write(out/'godot-review.json',dict(read(sources[0]/'godot-review.json'),entries=list(reviews.values())))
    write(out/'composition.json',{'source_sha256':evidence,'artifacts_sha256':artifacts,'origins':{k:str(v.relative_to(WORK)) for k,v in origins.items()}})
    print('FINAL_REVIEW_COMPOSED',len(catalogs))



def gallery():
    import html,subprocess
    directory=WORK/'review-complete';catalog=read(directory/'catalog.json');cards=[]
    for name in NAMES:
        variants=[]
        for suffix,label in [('', 'Normaal'),('-shiny','Shiny')]:
            key=name+suffix;movie=directory/(key+'.mp4')
            if not movie.exists():subprocess.run(['ffmpeg','-v','error','-framerate','12','-i',str(directory/(key+'-frames/%04d.png')),'-an','-c:v','libx264','-threads','2','-crf','22','-pix_fmt','yuv420p','-movflags','+faststart',str(movie)],check=True)
            variants.append(f'<div><h3>{label}</h3><video controls loop muted preload="none" poster="{key}-idle-front.png" src="{key}.mp4"></video><p><a href="{key}-sleep-front.png">Slaap</a> · <a href="{key}-faint_start-front.png">Neervallen</a> · <a href="{key}-idle-back.png">Achterkant</a></p></div>')
        cards.append('<article><h2>'+html.escape(name)+'</h2><div class="pair">'+''.join(variants)+'</div></article>')
    (directory/'index.html').write_text('''<!doctype html><html lang="nl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>21 gereconstrueerde vormen</title><style>body{margin:32px auto;max-width:1200px;padding:0 20px;background:#101625;color:#e6edf8;font:16px system-ui}h1,h2{color:#c7afff}article{border-top:1px solid #465068;padding:20px 0}p{line-height:1.55}.pair{display:grid;grid-template-columns:1fr 1fr;gap:20px}video{width:100%}a{color:#97caff}@media(max-width:650px){.pair{grid-template-columns:1fr}}</style><h1>21 vormen · normal en shiny</h1><p>Definitieve lokale reconstructies voor de technische battle- en pakketcontrole. Kostuums, ontbrekende bewegingen, paletten en effecten bevatten eigen reconstructies. Deze beelden bewijzen geen gelijkheid met het oorspronkelijke spel. Publicatiestatus staat in het kwalificatierapport; deze pagina publiceert niets.</p><p>De filmpjes tonen een rondgang en 12 samples per animatie, op inspectiesnelheid. De battlecamera wordt apart getest.</p>'''+''.join(cards)+'</html>')

if __name__=='__main__':
    compose()
    gallery()
