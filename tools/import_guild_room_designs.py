"""Convert the two authored TMXs to editable, room-specific furniture layouts.
Run before the existing furniture baker/scene importer. Artist sources stay untouched.
"""
import json
from pathlib import Path
import sys
from uuid import NAMESPACE_URL, uuid5
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1])
BACKEND = Path(sys.argv[2])
catalog = json.loads((ROOT / 'data/guild_base_furniture.json').read_text())
generated_ids = {'design_kitchen_counter', 'design_cafe_table_set', 'design_cafe_corner_table', 'design_statue_bench_left', 'design_statue_bench_right', 'design_planter_bench', 'design_red_runner'}
authored_collision = {s['id']: s['collisionCells'] for s in catalog['items'] if 'collisionCells' in s}
catalog['items'] = [s for s in catalog['items'] if s['id'] not in generated_ids]

def layers(path):
    return [{(i % 23, i // 23): int(v.strip()) for i,v in enumerate(l.find('data').text.replace('\n','').strip().split(',')) if int(v.strip())} for l in ET.parse(path).getroot().findall('layer')]

def take(grid, key, x, y, width, height, foot, offset):
    stacks=[]
    for dy in range(height):
        row=[]
        for dx in range(width):
            point=(x+dx,y+dy)
            art=[v for v in grid.get(point,[]) if not (2601 <= v <= 2651 or 3305 <= v <= 3333)]
            row.append(art)
            for v in art:grid[point].remove(v)
            if point in grid and not grid[point]:grid.pop(point)
        stacks.append(row)
    layer_count=max(len(v) for row in stacks for v in row)
    art_layers=[[[v[n] if n<len(v) else 0 for v in row] for row in stacks] for n in range(layer_count)]
    tiles=art_layers[0]
    spec = dict(id=key,nameKey='ui.guild_base.furniture.'+key,category='kitchen' if 'kitchen' in key else 'seating',tiles=tiles,artLayers=art_layers,footprint=foot,visualSize=[width,height],visualOffset=offset,blocksMovement=True,starterQuantity=2,placement='floor',surfaceSlots=[],resizable=False,scenePath=f'res://scenes/world/guild_base/furniture/{key}.tscn')
    if key in authored_collision:
        spec['collisionCells'] = authored_collision[key]
        spec['blocksMovement'] = bool(spec['collisionCells'])
    catalog['items'].append(spec)
    return spec,x,y,width,height

runner = dict(next(s for s in catalog['items'] if s['id']=='red_carpet'))
runner.update(id='design_red_runner',nameKey='ui.guild_base.furniture.design_red_runner',tiles=[[2634]*3,[2642]*3,[2650]*3],scenePath='res://scenes/world/guild_base/furniture/design_red_runner.tscn')
if runner['id'] in authored_collision:
    runner['collisionCells'] = authored_collision[runner['id']]
    runner['blocksMovement'] = bool(runner['collisionCells'])
catalog['items'].append(runner)
presets=[]
for number, room, title in [(1,'right_room','Guild Café'),(2,'left_room','Grand Lounge')]:
    full=layers(SOURCE/f'Guild Base Room {number}.tmx'); empty=layers(SOURCE/f'Guild Base Room {number} - Empty.tmx')
    grids=[{p:g for p,g in layer.items() if n>=2 or empty[n].get(p)!=g} for n,layer in enumerate(full)]
    # Art split across Tiled layers belongs to the same furniture piece.
    grid={}
    for layer in grids:
        for point,value in layer.items():grid.setdefault(point,[]).append(value)
    found=[]
    if number==1:
        found.append(take(grid,'design_kitchen_counter',4,2,9,6,[9,4],[0,-192]))
        found.append(take(grid,'design_cafe_table_set',13,2,6,6,[6,4],[0,-192]))
        found.append(take(grid,'design_cafe_corner_table',4,12,4,3,[4,3],[0,-96]))
    else:
        found.append(take(grid,'design_statue_bench_left',4,4,6,3,[5,3],[0,-96]))
        found.append(take(grid,'design_statue_bench_right',13,4,6,3,[5,3],[-32,-96]))
        found.append(take(grid,'design_planter_bench',5,13,13,3,[13,2],[0,-96]))
    # Nine-slice carpets are recognized before the fixed-size pieces.
    for spec in [s for s in catalog['items'] if s['resizable']]:
        for y in range(19):
            for x in range(23):
                for h in range(12,1,-1):
                    for w in range(15,1,-1):
                        pts={(x+dx,y+dy):spec['tiles'][0 if dy==0 else 2 if dy==h-1 else 1][0 if dx==0 else 2 if dx==w-1 else 1] for dy in range(h) for dx in range(w)}
                        if all(g in grid.get(p,[]) for p,g in pts.items()):
                            found.append((spec,x,y,w,h))
                            for p,g in pts.items():
                                grid[p].remove(g)
                                if not grid[p]:grid.pop(p)
    for spec in sorted([s for s in catalog['items'] if not s['resizable'] and not s['id'].startswith('design_')],key=lambda s:sum(bool(v) for row in s['tiles'] for v in row),reverse=True):
        pts={(dx,dy):v for dy,row in enumerate(spec['tiles']) for dx,v in enumerate(row) if v}
        for y in range(19):
            for x in range(23):
                if all(v in grid.get((x+dx,y+dy),[]) for (dx,dy),v in pts.items()):
                    found.append((spec,x,y,*spec['visualSize']))
                    for (dx,dy),v in pts.items():
                        point=(x+dx,y+dy); grid[point].remove(v)
                        if not grid[point]:grid.pop(point)
    if grid:raise ValueError(f'Unmapped tiles in room {number}: {grid}')
    items=[]; surfaces=[]
    for n,(spec,x,y,w,h) in enumerate(found):
        fw,fh=[w,h] if spec['resizable'] else spec['footprint']; ox,oy=[0,-h*32] if spec['resizable'] else spec['visualOffset']
        item=dict(id=str(uuid5(NAMESPACE_URL,f'guild-design-{number}-{n}')),furnitureId=spec['id'],x=x-ox//32,y=y-fh-oy//32,width=fw,height=fh,parentId=None,slot=None)
        if spec['placement']=='surface':surfaces.append((item,spec,x,y))
        else:items.append(item)
    for item,spec,x,y in surfaces:
        for parent in items:
            parent_spec=next(s for s in catalog['items'] if s['id']==parent['furnitureId'])
            for slot,(sx,sy) in enumerate(parent_spec['surfaceSlots']):
                if (parent['x']*32+sx+spec['visualOffset'][0],(parent['y']+parent['height'])*32+sy+spec['visualOffset'][1]) == (x*32,y*32):
                    item.update(x=0,y=0,parentId=parent['id'],slot=slot)
        if item['parentId'] is None:raise ValueError(('Unattached decoration',number,item,x,y))
        items.append(item)
    presets.append(dict(id=f'guild-room-{number}-template',name=title,roomKey=room,roomNumber=number,door='left' if number==1 else 'right',items=items))
catalog['version']=3
for key,x in [('left_room',19),('right_room',3)]:
    catalog['rooms'][key]['walkableRects'][1]=[x,8,1,3]
    catalog['rooms'][key]['entrance']=[x,9]
    catalog['rooms'][key]['reservedRects']=[[18 if x==19 else 3,8,2,3]]
for path in [ROOT/'data/guild_base_furniture.json',BACKEND/'account-service/catalogs/guild_base_furniture.json']:path.write_text(json.dumps(catalog,indent=2)+'\n')
existing_path=ROOT/'data/guild_room_designs.json'
existing_designs=json.loads(existing_path.read_text())['templates'] if existing_path.exists() else []
initial_ids={v['id'] for v in presets}
presets += [v for v in existing_designs if v['id'] not in initial_ids]
for path in [existing_path,BACKEND/'account-service/catalogs/guild_room_designs.json']:path.write_text(json.dumps(dict(version=1,templates=presets),indent=2)+'\n')
print([(p['name'],len(p['items'])) for p in presets])
