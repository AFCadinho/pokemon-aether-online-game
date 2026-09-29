"""Build a visual review page for the six recovered normal Biochao forms."""

import argparse
import html
from pathlib import Path

from catalog_remaining_review_page import thumbnail


SPECIES = (
    ("unown", "Unown A"),
    ("darmanitan-standard", "Darmanitan (standard)"),
    ("wishiwashi", "Wishiwashi (solo)"),
    ("silvally", "Silvally (Normal)"),
    ("obstagoon", "Obstagoon"),
    ("cursola", "Cursola"),
)
POSES = ("idle", "physical_attack", "physical_attack_2", "special_attack", "sleep", "faint_start")


def build(captures, unown, wishiwashi, output):
    output.mkdir(parents=True, exist_ok=True)
    cards = []
    for slug, label in SPECIES:
        source = unown if slug == "unown" else wishiwashi if slug == "wishiwashi" else captures
        figures = []
        for pose in POSES:
            path = source / f"{slug}-{pose}-{'100' if pose == 'faint_start' else '50'}.png"
            if not path.is_file():
                if pose == "physical_attack_2":
                    continue
                raise FileNotFoundError(path)
            target = output / f"{slug}-{pose}.webp"
            thumbnail(path, target)
            figures.append(f'<figure data-pose="{pose}"><img loading="lazy" src="{target.name}" '
                           f'alt="{html.escape(label)} {pose}"><figcaption>{pose}</figcaption></figure>')
        note = "Eigen rustige zwemanimatie; ogen blijven open." if slug == "wishiwashi" else (
            "Materiaal en transparantie extra controleren." if slug == "cursola" else "")
        cards.append(f'<article><h2>{html.escape(label)}</h2><p>{html.escape(note)}</p>'
                     f'<div class="poses">{"".join(figures)}</div></article>')
    page = '''<!doctype html><html lang="nl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Zes herstelde 3D-modellen — normal</title><style>
body{margin:0;background:#101820;color:#eef4f8;font:16px system-ui,sans-serif}header{position:sticky;top:0;background:#182838;padding:14px 20px;z-index:2;border-bottom:1px solid #496075}h1{font-size:1.35rem;margin:0 0 5px}p{margin:4px 0 10px;color:#cbd8e1}select{background:#263e50;color:white;font:inherit;padding:6px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(430px,1fr));gap:14px;padding:14px}article{background:#203140;border:1px solid #496075;border-radius:8px;padding:12px}h2{margin:0 0 4px;font-size:1.1rem}.poses{display:grid;grid-template-columns:repeat(2,1fr);gap:8px}figure{margin:0}img{display:block;width:100%;border-radius:5px;background:#202020}figcaption{text-align:center;font-size:.8rem;color:#cbd8e1}figure[hidden]{display:none}
</style><header><h1>Zes herstelde 3D-modellen — normal</h1><p>Bronbeelden voor visuele review. Shiny en battle moeten nog apart worden gekwalificeerd.</p><label>Pose <select id="pose"><option value="idle">Stilstand</option><option value="physical_attack">Fysieke aanval</option><option value="physical_attack_2">Tweede fysieke aanval</option><option value="special_attack">Speciale aanval</option><option value="sleep">Slaap</option><option value="faint_start">Flauw</option><option value="all">Alle poses</option></select></label></header><main>''' + ''.join(cards) + '''</main><script>
const select=document.querySelector('#pose');function update(){for(const figure of document.querySelectorAll('figure'))figure.hidden=select.value!=='all'&&figure.dataset.pose!==select.value}select.addEventListener('change',update);update();
</script></html>'''
    (output / "index.html").write_text(page)
    return output / "index.html"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--captures", type=Path, required=True)
    parser.add_argument("--unown", type=Path, required=True)
    parser.add_argument("--wishiwashi", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    print(build(args.captures, args.unown, args.wishiwashi, args.output))


if __name__ == "__main__":
    main()
