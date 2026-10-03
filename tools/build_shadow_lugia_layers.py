"""Extract Shadow Lugia foreground layers without repainting source sprites."""
from pathlib import Path

from PIL import Image, ImageDraw
from import_player_layered_sprites import write_texture_import

ROOT = Path(__file__).resolve().parents[1]
HEAD_ROWS = {29: (31, 33), 30: (30, 34), 31: (30, 34),
             32: (29, 35), 33: (29, 35)}
# Logical 64px coordinates. Follow the near wing and shoulder, leaving the
# neck, far wing/body and tail behind the rider. In the raised pose the
# diagonal inner edge separates the near wing from the taller rear wing.
# Right-facing art is mirrored.
WING_POLYGONS = (
    [(39, 27), (48, 27), (48, 40), (38, 41), (34, 43), (29, 44),
     (27, 41), (28, 40), (29, 39), (30, 38), (31, 37), (32, 36),
     (33, 35), (34, 34), (35, 33), (35, 31), (36, 30), (37, 29), (38, 28)],
    [(31, 41), (36, 44), (33, 51), (34, 54), (37, 61), (34, 63),
     (24, 63), (24, 55), (26, 50), (28, 47), (28, 44)],
)


def build() -> None:
    for variant in ("shadow_lugia", "shadow_lugia_shiny"):
        folder = ROOT / "assets/mounts" / variant
        source = Image.open(folder / "mount.png").convert("RGBA")
        logical = source.resize((256, 256), Image.Resampling.NEAREST)
        assert logical.resize(source.size, Image.Resampling.NEAREST).tobytes() == source.tobytes()
        foreground = Image.new("RGBA", logical.size)
        mask = Image.new("RGBA", logical.size)
        for row, direction in enumerate(("down", "left", "right", "up")):
            for col in range(4):
                tile = logical.crop((col * 64, row * 64, (col + 1) * 64, (row + 1) * 64))
                selection = Image.new("L", (64, 64))
                draw = ImageDraw.Draw(selection)
                if direction == "down":
                    draw.rectangle((0, 34, 63, 63), fill=255)
                    for y, (left, right) in HEAD_ROWS.items():
                        draw.line((left, y, right - 1, y), fill=255)
                elif direction in ("left", "right"):
                    draw.polygon(WING_POLYGONS[col % 2], fill=255)
                    if direction == "right":
                        selection = selection.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                front = Image.new("RGBA", (64, 64))
                front.paste(tile, (0, 0), selection)
                silhouette = front.getchannel("A")
                # Retain the existing small far-leg occlusion at the saddle.
                if direction in ("left", "right"):
                    left = 29 if direction == "left" else 33
                    for y in range(38, 41):
                        for x in range(left, left + 2):
                            if tile.getpixel((x, y))[3]:
                                silhouette.putpixel((x, y), 255)
                rider_mask = Image.new("RGBA", (64, 64))
                rider_mask.putalpha(silhouette)
                foreground.alpha_composite(front, (col * 64, row * 64))
                mask.alpha_composite(rider_mask, (col * 64, row * 64))
        for name, sheet in (("foreground", foreground), ("rider_mask", mask)):
            path = folder / f"{name}.png"
            sheet.resize(source.size, Image.Resampling.NEAREST).save(path)
            write_texture_import(ROOT, path.relative_to(ROOT))
        print(f"Built {variant}: continuous head and pose-specific near wings.")


if __name__ == "__main__":
    build()
