#!/usr/bin/env python3
"""Build the explicitly staged extension. No name/type heuristic assigns a motif.

Requires the local Showdown metadata snapshot and optionally the user's read-only
SV battle_ew directory. Output is checked in; the game never accesses either.
All new presentations remain pending player review, independently of coverage.
"""
import argparse, collections, hashlib, json, re
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
def key(s): return re.sub(r"[\s\-_,'.’]", '', s.lower())
# Every move is selected deliberately. A missing or duplicate selection is fatal.
GROUPS = {
'mist': '''Smog|Clear Smog''',
'ram': '''Accelerock|Assurance|Behemoth Bash|Bide|Body Slam|Bolt Beak|Breaking Swipe|Chip Away|Collision Course|Comeuppance|Counter|Covet|Double-Edge|Dragon Hammer|Dragon Rush|Endeavor|Facade|Feint|Feint Attack|First Impression|Flail|Foul Play|Head Charge|Headbutt|Heart Stamp|Heat Crash|Heavy Slam|High Horsepower|Last Resort|Lash Out|Payback|Play Rough|Power Trip|Psyshield Bash|Punishment|Rage|Raging Bull|Retaliate|Revenge|Reversal|Rock Climb|Skull Bash|Slam|Smelling Salts|Stomp|Stomping Tantrum|Strength|Struggle|Take Down|Thief|Thrash|Upper Hand|Veevee Volley|Zen Headbutt''',
'rush': '''Liquidation|Triple Dive|Acrobatics|Aerial Ace|Aqua Step|Aura Wheel|Blazing Torque|Bolt Strike|Brave Bird|Combat Torque|Double Shock|Dragon Ascent|Flame Charge|Flame Wheel|Flare Blitz|Glaive Rush|Ice Spinner|Lunge|Magical Torque|Noxious Torque|Nuzzle|Pounce|Raging Fury|Sizzly Slide|Skitter Smack|Sunsteel Strike|Supercell Slam|Temper Flare|Trailblaze|V-create|Volt Tackle|Waterfall|Wave Crash|Wicked Torque|Wild Charge|Zing Zap|Zippy Zap''',
'punch': '''Arm Thrust|Comet Punch|Dizzy Punch|Double Hit|Double Slap|Dynamic Punch|Focus Punch|Force Palm|Hammer Arm|Ice Hammer|Jet Punch|Mach Punch|Mega Punch|Meteor Mash|Plasma Fists|Power-Up Punch|Rage Fist|Shadow Punch|Sky Uppercut|Surging Strikes|Wake-Up Slap|Wicked Blow''',
'kick': '''Axe Kick|Blaze Kick|Flying Press|Jump Kick|Low Sweep|Mega Kick|Rolling Kick|Thunderous Kick|Triple Axel|Triple Kick|Trop Kick''',
'slash': '''Aqua Cutter|Behemoth Blade|Bitter Blade|Brick Break|Cross Chop|Cross Poison|Crush Claw|Cut|Dire Claw|Dual Chop|False Surrender|False Swipe|Fury Cutter|Fury Swipes|Guillotine|Hold Back|Karate Chop|Leaf Blade|Metal Claw|Mighty Cleave|Night Slash|Psyblade|Psycho Cut|Sacred Sword|Shadow Claw|Slash|Solar Blade|Stone Axe|Throat Chop|X-Scissor''',
'fang': '''Clamp|Crunch|Fire Fang|Fishious Rend|Hyper Fang|Ice Fang|Jaw Lock|Leech Life|Poison Fang|Psychic Fangs|Super Fang|Thunder Fang''',
'pierce': '''Beak Blast|Branch Poke|Drill Peck|Fell Stinger|Horn Attack|Horn Drill|Horn Leech|Hyper Drill|Megahorn|Meteor Assault|Needle Arm|Pluck|Poison Jab|Smart Strike''',
'lash': '''Anchor Shot|Aqua Tail|Bind|Constrict|Dragon Tail|Fire Lash|Iron Tail|Poison Tail|Power Whip|Tail Slap|Wrap''',
'spin': '''Brutal Swing|Darkest Lariat|Double Iron Bash|Drill Run|Dual Wingbeat|Gear Grind|Gyro Ball|Ice Ball|Mortal Spin|Multi-Attack|Spin Out|Steamroller|Steel Roller|Steel Wing''',
'hammer': '''Bone Club|Bone Rush|Crabhammer|Drum Beating|Gigaton Hammer|Ivy Cudgel|Order Up|Shadow Bone|Spirit Break''',
'grip': '''Circle Throw|Crush Grip|Hard Press|Seismic Toss|Storm Throw|Submission|Vise Grip|Vital Throw''',
'vanish': '''Dig|Dive|Fly|Bounce|Floaty Fall|Hyperspace Fury|Phantom Force|Shadow Force|Shadow Sneak|Sky Attack|Sky Drop|Spectral Thief''',
'swarm': '''Attack Order|Beat Up|Population Bomb|Infestation''',
'orb': '''Last Respects|Aura Sphere|Baddy Bad|Bitter Malice|Blood Moon|Bouncy Bubble|Buzzy Buzz|Electro Ball|Energy Ball|Fusion Flare|Glitzy Glow|Infernal Parade|Judgment|Luster Purge|Mist Ball|Mystical Power|Pika Papow|Pollen Puff|Psystrike|Stored Power|Tera Blast|Terrain Pulse|Venoshock|Zap Cannon''',
'bomb': '''Acid|Acid Spray|Apple Acid|Barrage|Belch|Chilling Water|Egg Bomb|Fling|Flower Trick|Gunk Shot|Matcha Gotcha|Mud Bomb|Mud Shot|Natural Gift|Octazooka|Present|Seed Bomb|Shell Side Arm|Sludge|Spit Up|Syrup Bomb''',
'shard': '''Smack Down|Barb Barrage|Bullet Seed|Diamond Storm|Dragon Darts|Glacial Lance|Icicle Spear|Magnet Bomb|Pay Day|Pin Missile|Power Gem|Rock Blast|Rock Wrecker|Salt Cure|Scale Shot|Spike Cannon|Spirit Shackle|Thousand Arrows|Triple Arrows|Twineedle''',
'boomerang': '''Bonemerang''',
'beam': '''Aeroblast|Armor Cannon|Aurora Beam|Blue Flare|Charge Beam|Chloroblast|Core Enforcer|Dragon Energy|Dragon Rage|Dynamax Cannon|Electro Drift|Eternabeam|Fickle Beam|Fleur Cannon|Freezing Glare|Freeze Shock|Frost Breath|Hydro Cannon|Hydro Pump|Hydro Steam|Ice Burn|Light of Ruin|Mirror Shot|Meteor Beam|Moongeist Beam|Oblivion Wing|Origin Pulse|Photon Geyser|Prismatic Laser|Psybeam|Roar of Time|Signal Beam|Snipe Shot|Steel Beam|Techno Blast|Twin Beam''',
'cutwave': '''Air Cutter|Air Slash|Esper Wing|Razor Wind|Secret Sword|Spacial Rend|Tachyon Cutter|Vacuum Wave''',
'sound': '''Alluring Voice|Boomburst|Bug Buzz|Chatter|Clanging Scales|Echoed Voice|Eerie Spell|Hyper Voice|Overdrive|Relic Song|Round|Snarl|Snore|Sonic Boom|Sparkly Swirl|Struggle Bug|Torch Song|Uproar''',
'pulse': '''Dazzling Gleam|Dragon Pulse|Expanding Force|Extrasensory|Fiery Wrath|Final Gambit|Freezy Frost|Hyperspace Hole|Metal Burst|Mirror Coat|Nature’s Madness|Night Daze|Night Shade|Psycho Boost|Psywave|Ruination|Secret Power|Synchronoise|Trump Card|Wring Out''',
'drain': '''Dream Eater|Giga Drain|Mega Drain|Parabolic Charge|Sappy Seed''',
'wave': '''Brine|Muddy Water|Sludge Wave|Splishy Splash|Surf|Thousand Waves|Water Spout''',
'vortex': '''Fire Spin|Icy Wind|Leaf Tornado|Magma Storm|Ominous Wind|Sand Tomb|Sandsear Storm|Silver Wind|Springtide Storm|Twister|Whirlpool|Wildbolt Storm''',
'rain': '''Astral Barrage|Avalanche|Doom Desire|Grav Apple|Icicle Crash|Leaf Storm|Mountain Gale|Petal Blizzard|Petal Dance|Rock Slide|Rock Tomb''',
'eruption': '''Ancient Power|Blast Burn|Bulldoze|Eruption|Fire Pledge|Fissure|Frenzy Plant|Grass Knot|Grass Pledge|Land’s Wrath|Lava Plume|Magnitude|Precipice Blades|Scorching Sands|Stone Edge|Water Pledge''',
'burst': '''Burn Up|Burning Jealousy|Discharge|Fiery Dance|Flame Burst|Glaciate|Incinerate|Inferno|Mind Blown|Misty Explosion|Overheat|Revelation Dance|Sacred Fire|Searing Shot|Seed Flare|Self-Destruct|Sheer Cold|Shell Trap|Steam Eruption|Strange Steam''',
'lightning': '''Fusion Bolt|Lumina Crash|Rising Voltage|Shock Wave|Thunder|Thunderclap''',
'firestar': '''Fire Blast|Mystical Fire''',
'cage': '''Electroweb|Malignant Chain|Poltergeist|Snap Trap|Thunder Cage''',
'prism': '''Tri Attack''',
'shield': '''Acid Armor|Baneful Bunker|Barrier|Burning Bulwark|Crafty Shield|Defend Order|Detect|Endure|Flower Shield|Iron Defense|King’s Shield|Magic Coat|Mat Block|Max Guard|Obstruct|Quick Guard|Safeguard|Shelter|Silk Trap|Spiky Shield|Wide Guard''',
'heal': '''Aqua Ring|Aromatherapy|Floral Healing|Heal Bell|Heal Order|Heal Pulse|Healing Wish|Jungle Healing|Life Dew|Lunar Blessing|Lunar Dance|Milk Drink|Moonlight|Morning Sun|Purify|Refresh|Rest|Revival Blessing|Shore Up|Slack Off|Soft-Boiled|Strength Sap|Swallow|Synthesis|Take Heart''',
'boost': '''Acupressure|Amnesia|Autotomize|Belly Drum|Bulk Up|Clangorous Soul|Coaching|Coil|Cosmic Power|Cotton Guard|Decorate|Dragon Cheer|Fillet Away|Gear Up|Geomancy|Hone Claws|Laser Focus|Magnet Rise|Magnetic Flux|Meditate|Minimize|No Retreat|Psych Up|Quiver Dance|Rock Polish|Sharpen|Shell Smash|Shift Gear|Stockpile|Stuff Cheeks|Tail Glow|Tidy Up|Victory Dance|Work Up''',
'heart': '''Attract|Captivate|Charm|Lovely Kiss|Sweet Kiss''',
'statussound': '''Confide|Entrainment|Grass Whistle|Metal Sound|Noble Roar|Parting Shot|Perish Song|Roar|Sing|Sleep Talk''',
'statuswave': '''Confuse Ray|Dark Void|Eerie Impulse|Electrify|Flash|Flatter|Glare|Hypnosis|Kinesis|Play Nice|Scary Face|Simple Beam|Spicy Extract|Swagger|Tearful Look|Teeter Dance|Tickle|Topsy-Turvy|Torment|Yawn''',
'statuscloud': '''Aromatic Mist|Corrosive Gas|Cotton Spore|Fake Tears|Feather Dance|Gastro Acid|Magic Powder|Poison Gas|Powder|Rage Powder|Soak|Stun Spore|Tar Shot|Toxic Thread|Venom Drench''',
'seal': '''Block|Curse|Destiny Bond|Disable|Embargo|Fairy Lock|Foresight|Forest’s Curse|Grudge|Heal Block|Imprison|Lock-On|Mean Look|Mind Reader|Miracle Eye|Nightmare|Octolock|Odor Sleuth|Quash|Spider Web|Spite|Telekinesis|Trick-or-Treat|Worry Seed''',
'exchange': '''After You|Ally Switch|Baton Pass|Bestow|Conversion|Conversion 2|Doodle|Guard Split|Guard Swap|Heart Swap|Helping Hand|Hold Hands|Instruct|Pain Split|Power Shift|Power Split|Power Swap|Power Trick|Psycho Shift|Reflect Type|Role Play|Skill Swap|Speed Swap|Switcheroo|Trick''',
'ritual': '''Assist|Camouflage|Celebrate|Copycat|Follow Me|Happy Hour|Ingrain|Lucky Chant|Me First|Memento|Metronome|Mimic|Mirror Move|Nature Power|Recycle|Rototiller|Shed Tail|Sketch|Snatch|Splash|Spotlight|Teatime|Transform''',
'weather': '''Hail|Rain Dance|Sandstorm|Snowscape|Sunny Day''',
'room': '''Gravity|Ion Deluge|Magic Room|Mist|Mud Sport|Tailwind|Trick Room|Water Sport|Whirlwind|Wonder Room''',
'max': '''Max Airstream|Max Darkness|Max Flare|Max Flutterby|Max Geyser|Max Hailstorm|Max Knuckle|Max Lightning|Max Mindstorm|Max Ooze|Max Overgrowth|Max Phantasm|Max Quake|Max Rockfall|Max Starfall|Max Steelspike|Max Strike|Max Wyrmwind''',
}
COLORS=dict(normal='dfccb0',fighting='ed9b62',flying='b4deed',poison='b460cf',ground='bf8955',rock='b8a07c',bug='b3cf56',ghost='9b75d5',steel='bedbea',fire='ff8444',water='50bbef',grass='8bd864',electric='ffe477',psychic='ed83c6',ice='a4ecf5',dragon='797ae8',dark='8868b3',fairy='ffb3da')
CONTACT=set('ram rush punch kick slash fang pierce lash spin hammer grip vanish'.split())
PROJECTILES=set('orb bomb shard boomerang cutwave prism swarm'.split())
FIELDS=set('wave vortex rain eruption burst lightning firestar max weather room'.split())
SELF=set('shield heal boost ritual'.split())
# Deliberate signature overrides, kept separate from shared construction defaults.
OVERRIDES={
 'fireblast':dict(count=5,scale=1.7,duration_seconds=1.85,camera='beam'),
 'hydropump':dict(width=.23,duration_seconds=1.7,camera='beam'),
 'hydrocannon':dict(width=.32,duration_seconds=1.95,camera='beam'),
 'aurasphere':dict(color='71cfff',arc=0.,width=.36,camera='projectile'),
 'energyball':dict(color='a1ed65',width=.32,camera='projectile'),
 'bloodmoon':dict(color='e87156',width=.55,duration_seconds=2.1,camera='projectile'),
 'astralbarrage':dict(color='a483f5',count=6,duration_seconds=1.9),
 'gigatonhammer':dict(scale=1.8,duration_seconds=1.6),
 'bonemerang':dict(count=1,arc=.4,duration_seconds=1.4),
 'triattack':dict(count=3,arc=0.),
 'dragondarts':dict(count=2,width=.17),
 'populationbomb':dict(count=6,duration_seconds=1.65),
 'surgingstrikes':dict(count=3,duration_seconds=1.45),
 'tripleaxel':dict(count=3), 'triplekick':dict(count=3), 'tripledive':dict(count=3),
 'doublehit':dict(count=2),'doubleironbash':dict(count=2),'dualwingbeat':dict(count=2),
 'sunnyday':dict(color='ffd984',count=1),'raindance':dict(color='86adc9'),
 'sandstorm':dict(color='c6ad79'),'hail':dict(color='d2edf7'),'snowscape':dict(color='b6d2eb'),
 'trickroom':dict(color='c69bea',duration_seconds=1.6),
 'meteorbeam':dict(color='aed8ff',duration_seconds=2.0,camera='beam'),
 'thunder':dict(color='ffea93',count=3,duration_seconds=1.65),
 'leafstorm':dict(count=7), 'petalblizzard':dict(color='f0a8d1',count=7),
 'stoneedge':dict(count=5),'precipiceblades':dict(count=5,scale=1.65),
 'fissure':dict(count=1,scale=1.6), 'surf':dict(width=.9,scale=1.6),
 'doomdesire':dict(color='fcf0ae',count=4),'sheercold':dict(color='c1fbff'),
 'prismaticlaser':dict(color='b5f5ff',duration_seconds=2.1,camera='beam'),
 'eternabeam':dict(color='ed74c9',duration_seconds=2.15,camera='beam'),
 'roaroftime':dict(color='839dff',duration_seconds=2.0,camera='beam'),
 'spacialrend':dict(color='f1a4df',scale=1.65,camera='projectile'),
 'kingsshield':dict(color='ffd890'), 'spikyshield':dict(color='a6d778'),
}

def build(metadata, source, output=None):
 summary=json.loads((ROOT/'data/move_summary_index.json').read_text())
 old=json.loads((ROOT/'data/battle_move_recipes_3d.json').read_text())['moves']
 dedicated=json.loads(re.search(r'const KEYS := (\[.*?\])',(ROOT/'scripts/battle/battle_ui/move_effect_3d.gd').read_text())[1])
 missing={key(v['name']):v for v in summary.values() if key(v['name']) not in set(old)|set(dedicated)}
 assignments={}
 for motif,names in GROUPS.items():
  for name in names.split('|'):
   k=key(name)
   if k not in missing: continue # Explicitly listed legacy relatives keep their approved renderer.
   assert k not in assignments,(k,motif,assignments.get(k))
   assignments[k]=motif
 assert not missing.keys()-assignments.keys(), 'Unassigned: '+', '.join(missing[k]['name'] for k in missing.keys()-assignments.keys())
 records={}
 for k,v in sorted(missing.items()):
  m=metadata[k]; motif=assignments[k]; power=v.get('basePower',0); typ=v['type']
  contact=motif in CONTACT and bool(m.get('flags',{}).get('contact',False)) and m['target']!='self'
  family='contact' if contact else 'beams' if motif=='beam' else 'projectiles' if motif in PROJECTILES else 'field' if motif in FIELDS else 'self' if motif in SELF and m['target'] in ['self','allySide','allyTeam'] else 'waves' if motif in ['sound','pulse','drain'] else 'projectiles' if motif in CONTACT and v['category']!='status' else 'status'
  target='actor' if m['target'] in ['self','allySide','allyTeam'] else 'target'
  damaging=v['category']!='status'
  count=3 if motif in ['shard','rain','swarm','eruption','sound'] else 1
  multi=m.get('multihit'); count=min(6,multi if isinstance(multi,int) else multi[-1]) if multi else count
  length=1.0 if motif in CONTACT else 1.4
  if power>=100: length+=.25
  if motif in ['weather','room','max']:length=1.8
  if motif=='beam':length=1.75
  launch=.18 if motif in CONTACT else .26; impact=.52 if motif in CONTACT else .65
  row=dict(name=v['name'],renderer='extended',motif=motif,family=family,variant=motif,type=typ,color=COLORS[typ],contact=contact,target=target,gameplay_target=m['target'],damaging=damaging,duration_seconds=length,launch_fraction=launch,impact_fraction=impact,scale=1.25 if power>=100 else 1.0,attachment='mouth' if motif in ['beam','sound','statussound','fang'] else 'hand' if motif in ['punch','slash','hammer'] else 'foot' if motif=='kick' else 'body',count=count,width=.27,arc=.8 if motif=='bomb' else 0.,rotation=-.6 if motif=='slash' else .35,source_id=m['num'],audio=[],presentation_review='implemented-pending-player-review')
  row.update(OVERRIDES.get(k,{}))
  if k in ['fly','bounce','skydrop','skyattack','floatyfall','dragonascent','acrobatics','flyingpress']: row['contact_arc']=1.8
  elif k in ['jumpkick','axekick','highhorsepower','tripledive']: row['contact_arc']=.7
  elif k in ['dig','dive']: row['contact_arc']=-.65
  luminous=typ in ['fire','electric','psychic','ghost','dragon','fairy','ice','water','grass'] and (motif not in CONTACT or motif=='rush')
  row['lighting']={'energy':.7 if luminous else 0.,'mix':.14 if luminous else 0.,'brightness':.96 if typ in ['ghost','dark'] else 1.0}
  if motif=='weather':row['lighting']={'energy':.25,'mix':.23,'brightness':1.02 if k=='sunnyday' else .94}
  if motif=='max':row['scale']=1.8;row['lighting']['mix']=.22
  folder=source/f"ew{m['num']:04}" if source else None
  row['source_reference']={'directory':folder.name if folder else '', 'files':sorted(p.name for p in folder.glob('*.ptcl')) if folder else [],'usage':'shape-and-phase-reference; authored geometry, no SV timeline conversion'}
  records[k]=row
 out={'schema':1,'scope':'707 previously missing unique names in the 919-record gameplay index; original 194 retain ownership','aliases':{key(v['id']):key(v['name']) for v in summary.values() if key(v['id'])!=key(v['name'])},'moves':records}
 (output or ROOT/'data/battle_move_extensions_3d.json').write_text(json.dumps(out,indent=2,ensure_ascii=False)+'\n')
 print('EXTENDED_CATALOG',len(records),dict(collections.Counter(r['motif'] for r in records.values())))
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--metadata',type=Path,required=True);p.add_argument('--source',type=Path);p.add_argument('--output',type=Path);a=p.parse_args();build(json.loads(a.metadata.read_text()),a.source,a.output)
