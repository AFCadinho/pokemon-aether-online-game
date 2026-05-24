# Main Systems Guide

Deze guide beschrijft hoe de huidige basis-systemen opnieuw opgebouwd kunnen worden:

- tile-based movement
- collision via een collision TileMapLayer
- exits tussen maps
- spawn posities
- map switching via `World`

De voorbeelden zijn gebaseerd op de huidige projectstructuur.

## Scene Structuur

De hoofdscene is `World`. Die houdt de speler en de actieve map bij.

```text
World
├── CurrentMap
│   └── KantoRoute1 / PalletTown / andere map
└── Player
```

Belangrijk:

- `Player` blijft in `World`.
- De huidige map zit als child onder `CurrentMap`.
- `GameState.current_map` wijst naar de actieve map.
- Na een map switch moet de speler opnieuw weten welke collision layer bij de actieve map hoort.

## Movement

De speler beweegt tile-based: dus niet vrij pixel voor pixel, maar steeds 1 tile per stap.

In `player.gd` gebruiken we hiervoor:

```gdscript
const TILE_SIZE := 32
const MOVE_SPEED := 200.0

var is_moving := false
var target_position := Vector2.ZERO
var last_direction := "down"
```

De speler heeft twee belangrijke posities:

- `global_position`: waar de speler nu staat in de wereld.
- `target_position`: waar de speler naartoe loopt.

Bij input bereken je een nieuwe doelpositie:

```gdscript
var new_target_position := global_position + (direction * TILE_SIZE)
```

Daarna check je eerst of de speler daarheen mag:

```gdscript
if can_move_to(new_target_position):
	target_position = new_target_position
	is_moving = true
```

Tijdens het lopen beweeg je richting de target:

```gdscript
global_position = global_position.move_toward(target_position, MOVE_SPEED * delta)
```

Als de speler op de target staat, stop je de movement:

```gdscript
if global_position == target_position:
	is_moving = false
	set_idle_frame()
```

## Collision

Collision wordt nu niet via `move_and_slide()` gedaan. We checken zelf of er op de volgende tile een collision tile staat.

Elke map die collision nodig heeft, moet een `TileMapLayer` hebben met exact deze naam:

```text
Collision
```

In `player.gd` bewaren we een referentie naar die layer:

```gdscript
var collision_tilemap: TileMapLayer
```

Wanneer een map geladen wordt, halen we de collision layer op uit de huidige map:

```gdscript
func refresh_map_layers() -> void:
	if GameState.current_map == null:
		collision_tilemap = null
		grass_tilemap = null
		return

	collision_tilemap = GameState.current_map.get_node_or_null("Collision")
	grass_tilemap = GameState.current_map.get_node_or_null("TallGrass")
```

Daarom moet `World` na het laden van een map dit aanroepen:

```gdscript
$Player.refresh_map_layers()
```

### Hoe `can_move_to()` werkt

`can_move_to()` krijgt een wereldpositie in pixels:

```gdscript
func can_move_to(check_position: Vector2) -> bool:
	if collision_tilemap == null:
		return true

	var local_position := collision_tilemap.to_local(check_position)
	var tile_position := collision_tilemap.local_to_map(local_position)
	var tile_data := collision_tilemap.get_cell_tile_data(tile_position)

	return tile_data == null
```

Stap voor stap:

1. `check_position` is een globale pixelpositie.
2. `to_local()` zet die globale positie om naar een positie binnen de collision TileMapLayer.
3. `local_to_map()` zet die lokale pixelpositie om naar een tile coordinate.
4. `get_cell_tile_data()` checkt of daar een tile staat.
5. Als daar geen tile staat, mag de speler lopen.

Kort gezegd:

```text
wereld pixels -> lokale tilemap pixels -> tile coordinate -> tile data check
```

## Pixelpositie vs Tile Coordinate

Een pixelpositie is een echte positie in de wereld, bijvoorbeeld:

```gdscript
Vector2(530, 46)
```

Een tile coordinate is een grid-positie, bijvoorbeeld:

```gdscript
Vector2i(16, 1)
```

Bij tile-based movement gebruik je vaak allebei:

- `Vector2` voor echte posities in pixels.
- `Vector2i` voor tile coordinates in de TileMap.

Voorbeeld:

```gdscript
var local_position: Vector2 = collision_tilemap.to_local(global_position)
var tile_position: Vector2i = collision_tilemap.local_to_map(local_position)
```

## Spawn Posities

Een map krijgt een `Spawns` node met daaronder `Marker2D` nodes.

Voorbeeld:

```text
PalletTown
├── Spawns
│   └── FromRoute1
└── Exits
    └── ToRoute1
```

En voor Route 1:

```text
KantoRoute1
├── Spawns
│   └── FromPalletTown
└── Exits
    └── ToPalletTown
```

De naam van de marker is belangrijk. Die naam gebruik je later als `target_spawn_name`.

Als je vanaf Route 1 naar Pallet Town gaat:

```gdscript
target_spawn_name = "FromRoute1"
```

Als je vanaf Pallet Town terug naar Route 1 gaat:

```gdscript
target_spawn_name = "FromPalletTown"
```

## Exits

Een exit is een `Area2D` met een `CollisionShape2D`.

Voorbeeld:

```text
Exits
└── ToPalletTown
    └── CollisionShape2D
```

De `Area2D` krijgt een script:

```gdscript
extends Area2D

@export_file("*.tscn") var target_scene_path := "res://scenes/overworld/kanto/towns/pallet_town.tscn"
@export var target_spawn_name := "FromRoute1"

func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return

	var world := get_tree().current_scene
	world.load_map(target_scene_path, target_spawn_name)
```

Belangrijk:

- Connect het `body_entered` signal van de `Area2D`.
- De speler moet door de mask/layer van de `Area2D` gezien worden.
- `target_scene_path` is het pad naar de map scene.
- `target_spawn_name` is de naam van de spawn marker in de nieuwe map.

### Waarom `@export_file`?

Gebruik hier liever:

```gdscript
@export_file("*.tscn") var target_scene_path := ""
```

In plaats van:

```gdscript
@export var target_scene: PackedScene
```

De reden: als twee maps elkaar allebei als `PackedScene` export referencen, kan Godot circular scene loading problemen krijgen. Met een scene path laad je de andere scene pas op het moment dat je hem echt nodig hebt.

## Collision Layer en Mask

Voor exits is dit de simpele gedachte:

- `Layer`: wat ben ik?
- `Mask`: wat kan ik detecteren?

Voorbeeld:

```text
Player
Layer: 1

Exit Area2D
Mask: 1
```

Dan kan de exit de speler detecteren.

De exit zelf hoeft niet per se op dezelfde layer te zitten, zolang de mask maar de speler ziet.

## World.load_map()

`World` is verantwoordelijk voor het wisselen van maps.

De functie krijgt:

```gdscript
func load_map(target_scene_path: String, target_spawn_name: String) -> void:
```

De stappen:

1. Check of het scene path bestaat.
2. Laad de scene met `load(target_scene_path)`.
3. Verwijder de huidige map uit `CurrentMap`.
4. Instance de nieuwe map.
5. Zet `GameState.current_map`.
6. Zoek de juiste spawn marker.
7. Zet de speler op die spawn positie.
8. Stop eventuele oude movement.
9. Refresh de map layers van de speler.

Voorbeeld:

```gdscript
func load_map(target_scene_path: String, target_spawn_name: String) -> void:
	if target_scene_path == "":
		return

	var target_scene := load(target_scene_path) as PackedScene
	if target_scene == null:
		return

	for child in $CurrentMap.get_children():
		child.queue_free()

	var new_map := target_scene.instantiate()
	$CurrentMap.add_child(new_map)

	GameState.current_map = new_map

	var spawn_position := Vector2.ZERO
	var spawn := new_map.get_node_or_null("Spawns/" + target_spawn_name)
	if spawn != null:
		spawn_position = spawn.global_position

	$Player.global_position = spawn_position
	$Player.target_position = spawn_position
	$Player.is_moving = false
	$Player.set_idle_frame()
	$Player.refresh_map_layers()
```

## Z-Index en Achter Gebouwen Lopen

De speler hoeft niet per se in de map scene te zitten om achter dingen te kunnen lopen.

Voor gebouwen kun je beter werken met gesplitste visuals:

```text
BuildingBottom
Player
BuildingTop
```

Bijvoorbeeld:

- onderkant van huis: normale tile layer
- speler: z-index ertussen
- dak/top van huis: hogere z-index

Dan lijkt het alsof de speler achter het dak verdwijnt.

## Namen Die Exact Moeten Kloppen

Deze namen worden in code gebruikt, dus typ ze precies hetzelfde:

```text
World
CurrentMap
Player
Collision
TallGrass
Spawns
Exits
FromRoute1
FromPalletTown
```

Als een naam anders is, vindt `get_node_or_null()` de node niet.

## Veelvoorkomende Problemen

### Exit print wel `entered`, maar wisselt niet van map

Check:

```gdscript
print("target_scene_path: ", target_scene_path)
print("target_spawn_name: ", target_spawn_name)
print("current_scene: ", get_tree().current_scene.name)
print("has load_map: ", get_tree().current_scene.has_method("load_map"))
```

Als `target_scene_path` leeg is, is het target path niet goed ingesteld.

### Collision werkt pas nadat je terugkomt op Route 1

Dan is de collision layer waarschijnlijk pas na een map switch refreshed.

Check of dit in `World._ready()` staat:

```gdscript
func _ready() -> void:
	var first_map := $CurrentMap.get_child(0)
	GameState.current_map = first_map
	$Player.refresh_map_layers()
```

### Speler blijft loop animatie doen na map switch

Dan stond `is_moving` nog op `true`, of de idle frame is niet opnieuw gezet.

Gebruik na het teleporteren:

```gdscript
$Player.is_moving = false
$Player.set_idle_frame()
```

### Godot geeft `Parse Error: Busy`

Dit kan gebeuren als twee scenes elkaar direct als `PackedScene` referencen.

Gebruik voor exits daarom liever een path:

```gdscript
@export_file("*.tscn") var target_scene_path := ""
```

En laad de scene pas in `World.load_map()`:

```gdscript
var target_scene := load(target_scene_path) as PackedScene
```

