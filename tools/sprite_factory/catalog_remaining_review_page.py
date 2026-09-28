"""One-page normal/shiny visual review for the remaining technical candidates."""

import argparse
import html
import json
from pathlib import Path

from PIL import Image, ImageChops


POSES = ("idle", "physical_attack", "physical_attack_2", "special_attack", "sleep", "faint_start")


def thumbnail(source, destination):
    with Image.open(source) as original:
        image = original.convert("RGB")
    background = image.getpixel((0, 0))
    difference = ImageChops.difference(image, Image.new("RGB", image.size, background))
    channels = difference.split()
    mask = ImageChops.lighter(ImageChops.lighter(channels[0], channels[1]), channels[2])
    bounds = mask.point(lambda value: 255 if value > 6 else 0).getbbox()
    if bounds is None:
        raise ValueError("Empty model screenshot: " + str(source))
    left, top, right, bottom = bounds
    padding = round(max(right - left, bottom - top) * 0.2)
    cropped = image.crop((max(0, left - padding), max(0, top - padding),
                          min(image.width, right + padding), min(image.height, bottom + padding)))
    side = max(cropped.size)
    square = Image.new("RGB", (side, side), background)
    square.paste(cropped, ((side - cropped.width) // 2, (side - cropped.height) // 2))
    square.resize((400, 400), Image.Resampling.LANCZOS).save(destination, "WEBP", quality=88)


def build(receipt, capture_root):
    rows = [row for row in receipt["entries"] if row["status"] == "normal_shiny_technical_candidate"]
    captures = {}
    for shard in range(1, 5):
        report = json.loads((capture_root / f"captures-{shard}" / "review.json").read_text())
        if report.get("capture_profile") != "quick_pair":
            raise ValueError("Unexpected capture profile")
        for entry in report["entries"]:
            species = entry["species"]
            if species in captures or entry["errors"] or len(entry["captures"]) != len(POSES):
                raise ValueError("Duplicate or incomplete capture: " + species)
            captures[species] = (shard, entry)
    if len(rows) != 156 or len(captures) != 312:
        raise ValueError("The complete normal/shiny cohort was not captured")
    thumbs = capture_root / "thumbs"
    thumbs.mkdir(exist_ok=True)
    cards = []
    for row in rows:
        species = row["species"]
        for variant in (species, species + "@shiny"):
            if variant not in captures:
                raise ValueError("Missing visual variant: " + variant)
            record = captures[variant][1]
            expected = row["normal_scene_sha256"] if variant == species else row["shiny_scene_sha256"]
            if record["runtime_sha256"] != expected or {c["action"] for c in record["captures"]} != set(POSES):
                raise ValueError("Capture is not bound to the technical scene: " + variant)
        warning = len(row["unrepresented_rare_parameters"])
        variants = []
        for variant, label in ((species, "Normal"), (species + "@shiny", "Shiny")):
            shard, record = captures[variant]
            images = {}
            for capture in record["captures"]:
                source = capture_root / f"captures-{shard}" / capture["image"]
                target = thumbs / (Path(capture["image"]).stem + ".webp")
                thumbnail(source, target)
                images[capture["action"]] = "thumbs/" + target.name
            first = f'<img loading="lazy" src="{html.escape(images["idle"], quote=True)}" alt="{html.escape(variant)} idle">'
            others = ''.join(
                f'<figure><img loading="lazy" src="{html.escape(images[action], quote=True)}" alt="{html.escape(variant + " " + action)}"><figcaption>{html.escape(action)}</figcaption></figure>'
                for action in POSES if action != "idle")
            variants.append(f'<section class="variant"><h3>{label}</h3>{first}<details><summary>Alle poses</summary><div class="poses">{others}</div></details></section>')
        badge = (f'<span class="warning">{warning} zeldzame-kleurinstellingen missen een broningang</span>'
                 if warning else '<span class="clean">Geen ontbrekende kleurinstellingen gemeten</span>')
        cards.append(f'<article class="card" data-name="{html.escape(species, quote=True)}" data-warning="{int(bool(warning))}">'
                     f'<h2>#{row["national_dex"]} {html.escape(species.title())}</h2>{badge}'
                     f'<div class="variants">{"".join(variants)}</div></article>')
    return '''<!doctype html><html lang="nl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Resterende Pokémon — 156 3D-paren</title><style>
body{margin:0;background:#111923;color:#edf3f8;font:16px system-ui,sans-serif}header{position:sticky;top:0;z-index:2;background:#172331;padding:16px 22px;border-bottom:1px solid #40556a}h1{font-size:1.3rem;margin:0 0 8px}p{margin:5px 0;color:#c6d2df}.controls{display:flex;gap:12px;align-items:center;flex-wrap:wrap;margin-top:10px}input,select{background:#26384a;color:white;border:1px solid #526c83;border-radius:6px;padding:8px;font:inherit}main{padding:18px;display:grid;grid-template-columns:repeat(auto-fit,minmax(440px,1fr));gap:14px}.card{background:#1d2b39;border:1px solid #40556a;border-radius:9px;padding:12px}.card h2{margin:0 0 6px;font-size:1.1rem}.variants{display:grid;grid-template-columns:1fr 1fr;gap:8px}.variant{text-align:center}.variant h3{font-size:.95rem;margin:8px 0}.variant>img{width:100%;max-height:250px;object-fit:contain;background:#222}.warning,.clean{font-size:.78rem;padding:3px 6px;border-radius:5px;display:inline-block}.warning{background:#684a1b;color:#ffe5ad}.clean{background:#214e3c;color:#c5ffe1}details{margin-top:5px;text-align:left}summary{cursor:pointer;padding:5px}.poses{display:grid;grid-template-columns:repeat(2,1fr);gap:4px}.poses figure{margin:0}.poses img{width:100%;background:#222}.poses figcaption{font-size:.75rem;color:#c6d2df}img{border-radius:4px}
</style><header><h1>156 nieuwe 3D-kandidaten — normal en shiny</h1><p>Visuele review op automatisch passend formaat. Battle-grootte en plaatsing volgen apart; deze pagina geeft geen goedkeuring.</p><div class="controls"><input id="search" type="search" placeholder="Zoek Pokémon"><select id="filter"><option value="all">Alle 156</option><option value="warning">Met materiaalwaarschuwing</option><option value="clean">Zonder materiaalwaarschuwing</option></select><span id="count"></span></div></header><main>''' + ''.join(cards) + '''</main><script>
const cards=[...document.querySelectorAll('.card')];const search=document.querySelector('#search');const filter=document.querySelector('#filter');const count=document.querySelector('#count');function update(){let shown=0;for(const card of cards){const q=search.value.trim().toLowerCase();const pass=card.dataset.name.includes(q)&&(filter.value==='all'||(filter.value==='warning')===(card.dataset.warning==='1'));card.hidden=!pass;if(pass)shown++}count.textContent=`${shown} / ${cards.length} Pokémon`};search.addEventListener('input',update);filter.addEventListener('change',update);update();
</script></html>'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--capture-root", type=Path, required=True)
    args = parser.parse_args()
    page = build(json.loads(args.receipt.read_text()), args.capture_root)
    path = args.capture_root / "index.html"
    path.write_text(page)
    print(path)


if __name__ == "__main__":
    main()
