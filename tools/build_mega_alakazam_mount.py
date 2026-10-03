"""Build the approved V5 composition with the lower V9 rear rider.

The supplied source and unchanged player ride pose use exact 2x pixels.
Only the creature and psychic support are baked into runtime sheets.
"""
from pathlib import Path
import math

from PIL import Image, ImageDraw

from import_player_layered_sprites import write_texture_import

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/mounts/mega_alakazam"
FRAME = 112
NEAREST = Image.Resampling.NEAREST
DIRECTIONS = ("down", "left", "right", "up")
# Translate each complete preview layout to one common ground anchor, without
# changing the distance between rider, ring and Alakazam in any direction.
RIDER_POS = ((40, 30), (22, 16), (58, 16), (40, 6))
MOUNT_POS = ((28, 4), (37, 4), (19, 4), (28, 4))


def build() -> None:
    source = Image.open(ASSETS / "source.png").convert("RGBA")
    assert source.size == (512, 256)
    small = source.resize((256, 128), NEAREST)
    assert small.resize(source.size, NEAREST).tobytes() == source.tobytes()
    sheets = {name: Image.new("RGBA", (FRAME * 4, FRAME * 4))
              for name in ("mount", "foreground", "rider_mask")}
    for row in range(4):
        for col in range(4):
            phase = col * 4
            original = small.crop((col * 32, row * 32, (col + 1) * 32, (row + 1) * 32))
            normalized = Image.new("RGBA", (32, 32))
            normalized.alpha_composite(original, (0, -2 if col % 2 else 0))
            assert normalized.getchannel("A").histogram()[255] == original.getchannel("A").histogram()[255]
            sprite = normalized.resize((56, 56), NEAREST)
            creature = Image.new("RGBA", (FRAME, FRAME))
            mx, my = MOUNT_POS[row]
            mount_bob = round(math.sin(phase * math.tau / 16))
            creature.alpha_composite(sprite, (mx, my + mount_bob))
            assert creature.getchannel("A").histogram()[255] == sprite.getchannel("A").histogram()[255]
            foreground = Image.new("RGBA", creature.size)
            if row == 3:
                foreground = creature.copy()
                # Precisely exclude the floating spoons, including frame bob.
                foreground.paste((0, 0, 0, 0), (0, 0, FRAME, my + 12 + mount_bob))
            mask = Image.new("RGBA", creature.size, (255, 255, 255, 0))
            mask.putalpha(foreground.getchannel("A"))
            rx, ry = RIDER_POS[row]
            rider_bob = round(-2 * math.sin(phase * math.tau / 16))
            cx, cy = rx + 16, ry + 30 + rider_bob
            ring = Image.new("RGBA", creature.size)
            draw = ImageDraw.Draw(ring)
            draw.ellipse((cx - 12, cy - 3, cx + 12, cy + 3), outline=(77, 44, 125, 255), width=2)
            draw.arc((cx - 11, cy - 3, cx + 11, cy + 2), 5, 160, fill=(165, 97, 230, 255), width=1)
            draw.arc((cx - 11, cy - 3, cx + 11, cy + 2), 185, 285, fill=(222, 187, 255, 255), width=1)
            for side in (-1, 1):
                draw.point((cx + side * 13, cy - 6 - phase % 4), fill=(165, 97, 230, 255))
            for angle in (phase * math.tau / 16, phase * math.tau / 16 + math.pi):
                draw.point((round(cx + 14 * math.cos(angle)), round(cy + 4 * math.sin(angle))), fill=(222, 187, 255, 255))
            creature.alpha_composite(ring)
            if row == 3:
                creature.alpha_composite(foreground)
            for name, frame in (("mount", creature), ("foreground", foreground), ("rider_mask", mask)):
                sheets[name].alpha_composite(frame, (col * FRAME, row * FRAME))
    for name, sheet in sheets.items():
        exported = sheet.resize((FRAME * 8, FRAME * 8), NEAREST)
        assert exported.resize(sheet.size, NEAREST).resize(exported.size, NEAREST).tobytes() == exported.tobytes()
        path = ASSETS / f"{name}.png"
        exported.save(path)
        write_texture_import(ROOT, path.relative_to(ROOT))
    print("Built Mega Alakazam mount, foreground and rider mask: 896x896, 224px frames.")


if __name__ == "__main__":
    build()
