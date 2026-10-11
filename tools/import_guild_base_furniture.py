"""Bake only the furniture tiles selected from the shared artist tileset.

Usage: python tools/import_guild_base_furniture.py <Indoors Tileset.tsx>
Then run import_guild_base_furniture.gd through the assigned slot environment.
"""
from pathlib import Path
import json
import sys
import xml.etree.ElementTree as ET

from PIL import Image

root = Path(__file__).resolve().parents[1]
catalog = json.loads((root / "data/guild_base_furniture.json").read_text())
tsx_path = Path(sys.argv[1]).resolve()
tsx = ET.parse(tsx_path).getroot()
source = Image.open(tsx_path.parent / tsx.find("image").get("source")).convert("RGBA")
source_columns = int(tsx.get("columns"))
assert int(tsx.get("tilewidth")) == int(tsx.get("tileheight")) == catalog["tileSize"] == 32
assert source.width == source_columns * 32 and source.height % 32 == 0
assert len({item["id"] for item in catalog["items"]}) == len(catalog["items"]), "Duplicate furniture ID"
for item in catalog["items"]:
    width, height = item["visualSize"]
    assert len(item["tiles"]) == height and all(len(row) == width for row in item["tiles"]), item["id"]
    assert all(dimension > 0 for dimension in item["footprint"]), item["id"]
    assert not item["resizable"] or (width, height) == (3, 3), "Resizable rugs require nine-slice art"
gids = sorted({gid for item in catalog["items"] for row in item["tiles"] for gid in row if gid})
assert all(isinstance(gid, int) and 0 < gid <= int(tsx.get("tilecount")) for gid in gids), "Source tile outside tileset"
columns = 16
atlas = Image.new("RGBA", (columns*32, ((len(gids)+columns-1)//columns)*32))
images = {}
for index, gid in enumerate(gids):
    tile = gid-1
    x, y = (tile % source_columns)*32, (tile // source_columns)*32
    images[gid] = source.crop((x, y, x+32, y+32))
    atlas.paste(images[gid], ((index % columns)*32, (index // columns)*32))
folder = root / "assets/guild_base/furniture"
folder.mkdir(parents=True, exist_ok=True)
atlas.save(folder / "tiles.png")
icons = folder / "icons"
icons.mkdir(exist_ok=True)
for item in catalog["items"]:
    width, height = item["visualSize"]
    icon = Image.new("RGBA", (width*32, height*32))
    for y, row in enumerate(item["tiles"]):
        for x, gid in enumerate(row):
            if gid:
                icon.paste(images[gid], (x*32, y*32))
    icon.save(icons / (item["id"]+".png"))
tile_set = ['[gd_resource type="TileSet" load_steps=3 format=3]',
    '[ext_resource type="Texture2D" path="res://assets/guild_base/furniture/tiles.png" id="1_texture"]',
    '[sub_resource type="TileSetAtlasSource" id="atlas"]', 'texture = ExtResource("1_texture")',
    'texture_region_size = Vector2i(32, 32)']
tile_set += [f'{i%columns}:{i//columns}/0 = 0' for i in range(len(gids))]
tile_set += ['[resource]', 'tile_size = Vector2i(32, 32)', 'sources/0 = SubResource("atlas")']
(folder / "furniture.tileset.tres").write_text('\n'.join(tile_set)+'\n')
(root / "data/guild_base_furniture_atlas.json").write_text(json.dumps({str(gid): [i%columns, i//columns] for i, gid in enumerate(gids)}, indent=2)+'\n')
print(f'Baked {len(gids)} tiles and {len(catalog["items"])} icons.')
