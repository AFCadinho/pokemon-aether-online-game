extends SceneTree

const CITY_PATH := "res://scenes/overworld/kanto/towns/vermilion_city/vermilion_city.tscn"
const CENTER_PATH := "res://scenes/overworld/kanto/towns/vermilion_city/pokemon_center.tscn"
const TEMPLATE_PATH := "res://scenes/overworld/kanto/reusable_interiors/pokemon_center_template.tscn"
const MAP_ID := "kanto_vermilion_city_pokemon_center"
const STAFF := ["NurseJoy", "Banker", "Clerk", "Clerk2", "AetherAtelier", "MoveManiac", "MoveDeleter"]
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var center := (load(CENTER_PATH) as PackedScene).instantiate()
	var template := (load(TEMPLATE_PATH) as PackedScene).instantiate()
	var city := (load(CITY_PATH) as PackedScene).instantiate()
	_check(center.map_id == MAP_ID, "center has its own map identity")
	_check(center.world_access_group_id == city.map_id, "center belongs to Vermilion City")
	_check(center.get_node("Visuals").scene_file_path == template.get_node("Visuals").scene_file_path, "center inherits the template visual")
	var collision := center.get_node("Collision") as TileMapLayer
	var template_collision := template.get_node("Collision") as TileMapLayer
	_check(collision.tile_map_data == template_collision.tile_map_data, "center retains template collision")
	var npcs := center.get_node("Entities/NPCs")
	var occupied: Dictionary = {}
	for name: String in STAFF:
		var actor := npcs.get_node(name)
		var original := template.get_node("Entities/NPCs/" + name)
		_check(actor.position == original.position, name + " keeps its service position")
		_check(actor.npc_id == original.npc_id, name + " keeps shared metadata")
		occupied[collision.local_to_map(actor.position)] = true
	_check(npcs.get_node("NurseJoy").respawn_point_id == MAP_ID, "Nurse Joy records this center for respawn")
	_check(center.get_node_or_null("Entities/Interactables/PokemonPC") != null, "Pokemon PC is available")
	for group: Node in [npcs, center.get_node("Entities/Pokemon")]:
		for actor: Node in group.get_children():
			if actor.name in STAFF or actor.name == "HealMachineEffect":
				continue
			var cell := collision.local_to_map(actor.position)
			_check(collision.get_cell_source_id(cell) == -1, str(actor.name) + " stands on open floor")
			_check(not occupied.has(cell), str(actor.name) + " does not overlap another character")
			occupied[cell] = true
	_check(npcs.get_child_count() == template.get_node("Entities/NPCs").get_child_count() + 3, "three unique visitors supplement the template staff")
	var pokemon := center.get_node("Entities/Pokemon")
	_check(pokemon.get_child_count() == 3, "three unique companion Pokemon")
	for actor: Node in pokemon.get_children():
		_check(FollowerSpriteService.get_sprite_frames(actor.species_id, false) != null, str(actor.name) + " has follower sprites")
		var cell := collision.local_to_map(actor.position)
		if actor.movement_behavior == "idle":
			continue
		for offset: int in [-1, 1]:
			var lane := cell + Vector2i.DOWN * offset
			_check(collision.get_cell_source_id(lane) == -1, str(actor.name) + " patrol stays on open floor")
			_check(not occupied.has(lane), str(actor.name) + " patrol avoids other characters")
	# The center aisle, door and healing approach must remain usable.
	for y in range(23, 33):
		var cell := Vector2i(14, y)
		_check(collision.get_cell_source_id(cell) == -1 and not occupied.has(cell), "central aisle is clear at row %d" % y)
	var entrance := city.get_node("Exits/ToPokecenter")
	var exit := center.get_node("Exits/ToOutside")
	_check(entrance.target_scene_path == CENTER_PATH and entrance.target_spawn_name == "FromOutside", "city entrance targets center spawn")
	_check(exit.target_scene_path == CITY_PATH and exit.target_spawn_name == "FromPokecenter", "center returns to city spawn")
	_check(entrance.contains_world_position(Vector2(400, 464)), "city entrance covers the visible doorway")
	_check(not entrance.contains_world_position(city.get_node("Spawns/FromPokecenter").position), "city return spawn avoids immediate re-entry")
	_check(not exit.contains_world_position(center.get_node("Spawns/FromOutside").position), "center arrival avoids immediate exit")
	var city_collision := city.get_node("Tiles/Collision") as TileMapLayer
	_check(city_collision.get_cell_source_id(Vector2i(12, 16)) == -1, "city return spawn is walkable")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	_check(catalog.areas.has(MAP_ID), "center is registered for world access")
	_check(catalog.transitions.has("kanto_vermilion_city__to_pokemon_center") and catalog.transitions.has(MAP_ID + "__to_outside"), "both transitions are registered")
	var loader = load("res://scripts/services/web_asset_module_service.gd")
	_check(loader.module_for_scene(CENTER_PATH) == loader.EXTENDED_MODULE_NAME, "browser loads the center from the Vermilion map pack")
	center.free()
	template.free()
	city.free()
	print("VERMILION_POKEMON_CENTER ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("FAIL " + label)
