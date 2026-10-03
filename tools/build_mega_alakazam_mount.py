"""Build original-size Mega Alakazam with the approved seated/levitating pose.

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
CREATURE_SIZE = 32
NEAREST = Image.Resampling.NEAREST
DIRECTIONS = ("down", "left", "right", "up")
# Center the unchanged 32px logical player frame in every direction. The
# player's normal ground position anchors the rig; Alakazam and psychic wisps
# move around it. Close the side gap while retaining the approved rear height.
RIDER_POS = ((40, 40),) * 4
MOUNT_POS = ((40, 31), (59, 38), (21, 38), (40, 43))


def build() -> None:
    source = Image.open(ASSETS / "source.png").convert("RGBA")
    assert source.size == (512, 256)
    # UI icons use the original creature cell without the large rider canvas.
    icon_path = ASSETS / "icon.png"
    source.crop((0, 0, 64, 64)).save(icon_path)
    write_texture_import(ROOT, icon_path.relative_to(ROOT))
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
            sprite = normalized.resize((CREATURE_SIZE, CREATURE_SIZE), NEAREST)
            assert sprite.tobytes() == normalized.tobytes(), "Retain the original creature pixel grid."
            creature = Image.new("RGBA", (FRAME, FRAME))
            mx, my = MOUNT_POS[row]
            mount_bob = round(math.sin(phase * math.tau / 16))
            creature.alpha_composite(sprite, (mx, my + mount_bob))
            assert creature.getchannel("A").histogram()[255] == sprite.getchannel("A").histogram()[255]
            foreground = Image.new("RGBA", creature.size)
            if row == 3:
                foreground = creature.copy()
                # Precisely exclude the floating spoons, including frame bob.
                spoon_height = math.ceil(CREATURE_SIZE * 7 / 32)
                foreground.paste((0, 0, 0, 0), (0, 0, FRAME, my + spoon_height + mount_bob))
            mask = Image.new("RGBA", creature.size, (255, 255, 255, 0))
            mask.putalpha(foreground.getchannel("A"))
            rx, ry = RIDER_POS[row]
            rider_bob = round(-2 * math.sin(phase * math.tau / 16))
            cx, cy = rx + 16, ry + 30 + rider_bob
            ring = Image.new("RGBA", creature.size)
            draw = ImageDraw.Draw(ring)
            # Broken translucent arcs suggest psychic lift rather than a platform.
            bounds = (cx - 10, cy - 2, cx + 10, cy + 2)
            for start, end in ((25, 75), (105, 155)):
                draw.arc(bounds, start, end, fill=(164, 126, 206, 170), width=1)
            draw.arc(bounds, 210, 315, fill=(194, 167, 226, 110), width=1)
            for side in (-1, 1):
                spark_y = cy - 5 - (col + (side + 1) // 2) % 3
                draw.point((cx + side * 11, spark_y), fill=(194, 167, 226, 145))
            # Keep the energy behind Alakazam, preserving the source pixels.
            ring.alpha_composite(creature)
            creature = ring
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
