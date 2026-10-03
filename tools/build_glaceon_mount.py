"""Build the approved native-size Glaceon follower mount (v10).

No creature or player resampling. The far side ear stays behind the rider;
the near head and flap use a pixel-contour foreground and matching mask.
"""
from pathlib import Path

from PIL import Image

from import_player_layered_sprites import write_texture_import

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/mounts/glaceon"
FRAME = 224
ORIGIN = (80, 84)


def side_head(x: int, y: int, row: int, col: int) -> bool:
    u = (x if row == 1 else 63 - x) // 2
    v = y // 2 - col % 2
    limit = 20 if v <= 19 else 17 if v <= 21 else 15 if v == 22 else 14
    far_ear = u >= 14 and v <= 14
    return 11 <= v <= 25 and u <= limit and not far_ear


def build_variant(source: Image.Image, assets: Path) -> None:
    assert source.size == (256, 256)
    assets.mkdir(parents=True, exist_ok=True)
    sheets = {name: Image.new("RGBA", (FRAME * 4, FRAME * 4))
              for name in ("mount", "foreground", "rider_mask")}
    for row in range(4):
        for col in range(4):
            sprite = source.crop((col * 64, row * 64, (col + 1) * 64, (row + 1) * 64))
            mount = Image.new("RGBA", (FRAME, FRAME))
            mount.paste(sprite, ORIGIN)
            foreground = Image.new("RGBA", mount.size)
            for y in range(64):
                for x in range(64):
                    if (row == 0 and y >= 32) or (row in (1, 2) and side_head(x, y, row, col)):
                        foreground.putpixel((ORIGIN[0] + x, ORIGIN[1] + y), sprite.getpixel((x, y)))
            mask = Image.new("RGBA", mount.size, (255, 255, 255, 0))
            mask.putalpha(foreground.getchannel("A"))
            for name, tile in (("mount", mount), ("foreground", foreground), ("rider_mask", mask)):
                sheets[name].paste(tile, (col * FRAME, row * FRAME))
    # A compact icon avoids shrinking the creature to fit its padded riding canvas.
    sheets["icon"] = source.crop((0, 0, 64, 64))
    for name, sheet in sheets.items():
        path = assets / f"{name}.png"
        sheet.save(path)
        write_texture_import(ROOT, path.relative_to(ROOT))
    print(f"Built {assets.name}: unchanged 1x follower pixels, v10 head contour and compact icon.")


def build() -> None:
    normal = Image.open(ROOT / "assets/followers/GLACEON.png").convert("RGBA")
    shiny = Image.open(ROOT / "assets/followers_shiny/GLACEON.png").convert("RGBA")
    assert normal.size == shiny.size == (256, 256)
    assert normal.getchannel("A").tobytes() == shiny.getchannel("A").tobytes()
    build_variant(normal, ASSETS)
    build_variant(shiny, ASSETS.with_name("glaceon_shiny"))


if __name__ == "__main__":
    build()
