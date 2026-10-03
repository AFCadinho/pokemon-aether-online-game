"""Build the Cobalion land mount from the supplied four-direction sheet."""
from pathlib import Path
from PIL import Image
from import_player_layered_sprites import write_texture_import
ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/mounts/cobalion"
FRAME = 224
ORIGIN = (80, 68)

def side_head(x: int, y: int, row: int) -> bool:
    u = (x if row == 1 else 63 - x) // 2
    v = y // 2
    limit = 6 if v <= 4 else 12 if v <= 7 else 15 if v <= 11 else 13 if v <= 14 else 15 if v <= 17 else 14 if v <= 19 else 12
    return 2 <= v <= 21 and u <= limit

def build() -> None:
    source = Image.open(ASSETS / "source.png").convert("RGBA")
    assert source.size == (256, 256)
    sheets = {name: Image.new("RGBA", (FRAME*4, FRAME*4)) for name in ("mount", "foreground", "rider_mask")}
    for row in range(4):
        for col in range(4):
            sprite = source.crop((col*64,row*64,(col+1)*64,(row+1)*64))
            tile = Image.new("RGBA", (FRAME,FRAME)); tile.paste(sprite,ORIGIN)
            foreground=Image.new("RGBA",(FRAME,FRAME))
            for y in range(64):
                for x in range(64):
                    # Keep Cobalion's horns behind the rider, but bring its
                    # eyes and muzzle forward so the face remains visible
                    # beneath the player's face in the front-facing pose.
                    front = row == 0 and y >= 24
                    if row in (1,2): front = side_head(x,y,row)
                    if front: foreground.putpixel((ORIGIN[0]+x,ORIGIN[1]+y),sprite.getpixel((x,y)))
            mask=Image.new("RGBA",(FRAME,FRAME),(255,255,255,0));mask.putalpha(foreground.getchannel("A"))
            for name,frame in (("mount",tile),("foreground",foreground),("rider_mask",mask)):
                sheets[name].paste(frame,(col*FRAME,row*FRAME))
    sheets["icon"] = source.crop((0,0,64,64))
    for name,sheet in sheets.items():
        path=ASSETS/f"{name}.png";sheet.save(path);write_texture_import(ROOT,path.relative_to(ROOT))
    print("Built Cobalion mount: native 1x follower pixels, four directions and matching rider layers.")
if __name__ == "__main__": build()
