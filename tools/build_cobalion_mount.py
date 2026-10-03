"""Build normal/shiny Cobalion from the supplied four-direction mount sheet."""
from pathlib import Path
from PIL import Image
from import_player_layered_sprites import write_texture_import
ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/mounts/cobalion"
FRAME = 224
ORIGIN = (80, 84)

# Based on the bundled shiny follower palette, with matching extra shade steps
# for the supplied mount artwork. Only RGB changes: poses and alpha stay intact.
SHINY_PALETTE = {
    (0, 0, 0): (0, 0, 0),
    (15, 39, 61): (24, 40, 64),
    (18, 32, 11): (0, 0, 0),
    (20, 48, 71): (29, 49, 74),
    (25, 93, 159): (32, 80, 128),
    (32, 104, 168): (39, 91, 137),
    (39, 126, 185): (24, 92, 152),
    (44, 44, 46): (30, 30, 28),
    (48, 40, 56): (34, 26, 38),
    (48, 136, 192): (33, 102, 159),
    (62, 62, 66): (48, 48, 48),
    (64, 163, 203): (24, 104, 176),
    (72, 64, 80): (58, 50, 62),
    (73, 73, 77): (59, 59, 59),
    (75, 171, 208): (35, 112, 181),
    (88, 96, 120): (53, 61, 85),
    (93, 58, 6): (104, 112, 56),
    (99, 99, 99): (64, 64, 64),
    (104, 68, 9): (115, 122, 59),
    (104, 96, 112): (69, 61, 77),
    (110, 110, 110): (75, 75, 75),
    (128, 128, 144): (92, 116, 112),
    (132, 91, 14): (112, 136, 64),
    (142, 102, 19): (122, 147, 69),
    (149, 140, 143): (144, 180, 164),
    (157, 157, 157): (112, 152, 136),
    (166, 166, 166): (121, 161, 145),
    (176, 176, 192): (172, 208, 196),
    (194, 194, 207): (200, 248, 232),
    (200, 200, 212): (206, 254, 237),
    (208, 208, 216): (214, 255, 241),
    (216, 145, 19): (152, 176, 88),
    (220, 154, 25): (156, 185, 94),
    (232, 232, 248): (244, 244, 250),
    (236, 236, 246): (248, 248, 248),
    (238, 238, 247): (250, 250, 249),
    (245, 202, 67): (200, 248, 120),
    (246, 207, 78): (201, 253, 131),
}

def side_head(x: int, y: int, row: int) -> bool:
    u = (x if row == 1 else 63 - x) // 2
    v = y // 2
    limit = 6 if v <= 4 else 12 if v <= 7 else 15 if v <= 11 else 13 if v <= 14 else 15 if v <= 17 else 14 if v <= 19 else 12
    return 2 <= v <= 21 and u <= limit

def build_variant(source: Image.Image, assets: Path) -> None:
    assert source.size == (256, 256)
    assets.mkdir(parents=True, exist_ok=True)
    sheets = {name: Image.new("RGBA", (FRAME*4, FRAME*4)) for name in ("mount", "foreground", "rider_mask")}
    for row in range(4):
        for col in range(4):
            sprite = source.crop((col*64,row*64,(col+1)*64,(row+1)*64))
            tile = Image.new("RGBA", (FRAME,FRAME)); tile.paste(sprite,ORIGIN)
            foreground=Image.new("RGBA",(FRAME,FRAME))
            for y in range(64):
                for x in range(64):
                    # Put Cobalion's complete front-facing sprite in front of
                    # the rider so its head does not get covered.
                    front = row == 0
                    if row in (1,2): front = side_head(x,y,row)
                    if front: foreground.putpixel((ORIGIN[0]+x,ORIGIN[1]+y),sprite.getpixel((x,y)))
            mask=Image.new("RGBA",(FRAME,FRAME),(255,255,255,0))
            mask_alpha = foreground.getchannel("A")
            # Occlude only pixels actually painted by the foreground layer.
            # Hair above or between the horns must remain visible.
            mask.putalpha(mask_alpha)
            for name,frame in (("mount",tile),("foreground",foreground),("rider_mask",mask)):
                sheets[name].paste(frame,(col*FRAME,row*FRAME))
    sheets["icon"] = source.crop((0,0,64,64))
    for name,sheet in sheets.items():
        path=assets/f"{name}.png";sheet.save(path);write_texture_import(ROOT,path.relative_to(ROOT))
    print(f"Built {assets.name}: native 1x source pixels, four directions and matching rider layers.")


def build() -> None:
    source = Image.open(ASSETS / "source.png").convert("RGBA")
    shiny = source.copy()
    shiny.putdata([
        (*SHINY_PALETTE[pixel[:3]], pixel[3]) if pixel[3] else pixel
        for pixel in source.getdata()
    ])
    assert source.getchannel("A").tobytes() == shiny.getchannel("A").tobytes()
    build_variant(source, ASSETS)
    build_variant(shiny, ASSETS.with_name("cobalion_shiny"))

if __name__ == "__main__": build()
