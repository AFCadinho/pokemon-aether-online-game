"""Source-pinned normal/shiny appearance candidates for six recovered forms.

The supplied Biochao scenes have native animations but no matching rare
material tables. Existing game normal/shiny HOME art is the colour reference.
These GLBs are review candidates; this tool never approves catalog content.
"""

import argparse
from io import BytesIO
import hashlib
import json
from pathlib import Path

from PIL import Image

from catalog_remaining_eye_bake import append_png, write_glb
from catalog_remaining_shiny_glb import read_glb
from phase5_variant_parity import compare


POLICY = "remaining-six-home-palette-review-v1"
EXPECTED = {
    "unown": "a09ac738d15e9b4a7f77b450f01ca6aaa78f61a4b61090d3b954f0f6870eb6ad",
    "darmanitan-standard": "0c075586b639ebb39cf8f1f04b05a0cc7b605aa06b06f8b5445f7356b90b10dd",
    "wishiwashi": "de814f26d9125d007fda6fc8a50fff07d05e8892afa558b3996b7cc01ba982a7",
    "silvally": "f115ae3f73508346263dc776879eafe6f480ba593402ed92bbdd9ba26778d7c2",
    "obstagoon": "273dedfe46f3c800c768c099bf542500bd70efcc210ff6343a7fba2d23f8eb42",
    "cursola": "633fa7381c52a97c063b2b5183051e88c80f3a80bef9f916151a5916d0af0fa0",
}


def convert_pixel(species, variant, material, color):
    r, g, b, a = color
    if species == "unown" and variant == "normal":
        if material == "body":
            # The archived Unown body is blue, matching its shiny HOME art.
            # Its normal HOME art uses charcoal with the same shading.
            return (round(r * .36), round(g * .35), round(b * .29), a)
        if material == "eye" and b > r * 1.25 and b > g * 1.2:
            return (round(r * .36), round(g * .35), round(b * .29), a)
    if variant != "shiny":
        return color
    if species == "darmanitan-standard":
        if material == "BodyB":
            return (r, round(g * .4), min(255, round(b * 2.4)), a)
        if material != "Eye" and r > g * 1.35 and r > b * 1.2 and r > 70 and g < 130 and b < 135:
            return (round(r * .75), round(g * .55), round(max(b * .9, r * .4)), a)
    elif species == "wishiwashi":
        if material == "Eye" and b > r * 1.2 and g > r * 1.15:
            return (min(255, round(max(140, b * .92))), round(g * .95), round(b * .55), a)
        if material != "Eye" and max(r, g, b) - min(r, g, b) < 55 and max(r, g, b) > 100:
            return (min(255, round(r * 1.03)), round(g * .98), round(b * .72), a)
    elif species == "silvally":
        if material != "Eye11" and r > g * 1.4 and r > b * 1.3 and r > 70:
            return (round(g * .75), min(255, round(r * .93)), round(g * .86), a)
        if material != "Eye11" and max(r, g, b) - min(r, g, b) < 40 and min(r, g, b) > 125:
            return (min(255, round(r * 1.04)), min(255, round(g * 1.02)), round(b * .79), a)
    elif species == "obstagoon":
        if material in ("REye", "LEye") and r > g * 1.2:
            return (round(r * .15), round(r * .75), round(r * .76), a)
        if material not in ("REye", "LEye"):
            bright = max(r, g, b)
            if bright - min(r, g, b) < 40 and bright >= 110:
                return (round(bright * .13), round(bright * .73), round(bright * .75), a)
            if bright <= 110 and bright - min(r, g, b) < 40:
                return (min(255, round(r * 1.5 + 25)), round(g * .6 + 5), round(b * .9 + 35), a)
    elif species == "cursola":
        # The dark shiny regions are the inner core and base, not the coral.
        # Feeler*/Missile materials retain their white colour and transparency.
        if material == "Eye":
            if r > g * 1.2 and r > b * 1.15:
                return (round(r * .65), round(g * .7), min(255, round(b * 1.2)), a)
            return (round(r * .24), round(g * .24), round(b * .26), a)
        if material in ("BodyA", "BodyB", "Mouth"):
            return (round(r * .24), round(g * .24), round(b * .26), a)
    return color


def variant(source, target, species, kind):
    expected = EXPECTED[species]
    if hashlib.sha256(source.read_bytes()).hexdigest() != expected:
        raise ValueError(f"{species}: normal source GLB changed")
    document, original = read_glb(source)
    binary = bytearray(original)
    changed = []
    for material in document["materials"]:
        name = material["name"]
        info = material.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if info is None:
            continue
        texture = document["textures"][info["index"]]
        embedded = document["images"][texture["source"]]
        view = document["bufferViews"][embedded["bufferView"]]
        start = view.get("byteOffset", 0)
        image = Image.open(BytesIO(original[start:start + view["byteLength"]])).convert("RGBA")
        transformed = Image.new("RGBA", image.size)
        transformed.putdata([convert_pixel(species, kind, name, pixel)
                             for pixel in image.get_flattened_data()])
        if transformed.tobytes() == image.tobytes():
            continue
        packed = BytesIO()
        transformed.save(packed, "PNG")
        index = append_png(document, binary, packed.getvalue(),
                           f"{species}_{kind}_{name}", texture.get("sampler", 0))
        info["index"] = index
        changed.append(name)
    if not changed and (species, kind) != ("unown", "shiny"):
        raise ValueError(f"{species} {kind}: no visible material changed")
    write_glb(target, document, binary)
    return {"species": species, "variant": kind, "source_sha256": expected,
            "glb_sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
            "policy": POLICY, "changed_materials": changed,
            "runtime_approved": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    rows = json.loads(args.catalog.read_text())["entries"]
    results = []
    for row in rows:
        species = row["species"]
        if species not in EXPECTED:
            continue
        source = Path(row["path"])
        for kind in (("normal", "shiny") if species == "unown" else ("shiny",)):
            target = args.output / f"{species}-{kind}.glb"
            result = variant(source, target, species, kind)
            baseline = (args.output / "unown-normal.glb"
                        if species == "unown" and kind == "shiny" else source)
            result["geometry_motion_sha256"] = compare(baseline, target)
            results.append(result)
            print(species, kind, result["glb_sha256"], flush=True)
    (args.output / "status.json").write_text(json.dumps({"schema": 1,
        "runtime_approved": False, "entries": results}, indent=2) + "\n")


if __name__ == "__main__":
    main()
