extends SceneTree

const CITY := "res://scenes/overworld/kanto/towns/celadon_city/celadon_city.tscn"
const ROUTE := "res://scenes/overworld/kanto/routes/kanto_route_7.tscn"
const AtlasValidator := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
const PokemonScript := "res://scripts/world/npcs/overworld_pokemon.gd"
const NpcScript := "res://scripts/world/npcs/dialogue_npc.gd"
var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var city := (load(CITY) as PackedScene).instantiate()
	var route := (load(ROUTE) as PackedScene).instantiate()
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
	_check(city.get("map_id") == "kanto_celadon_city", "City has a distinct map identity")
	_check(city.get("world_access_group_id") == "kanto_celadon_city", "City has its own location group")
	var visual := city.get_node("Visual")
	var dimensions: Dictionary = visual.get_meta("tiled_visual_map")
	_check(dimensions.width == 80 and dimensions.height == 70, "Artist map keeps its original dimensions")
	_check(str(visual.get_meta("tiled_source_path")).ends_with("/Celadon City.tmx"), "Requested artist visual is used")
	_check(AtlasValidator.new().validate(visual,
		"res://generated/tiled_visuals/celadon_city/celadon_city.visual.tileset.tres").is_empty(), "Visual uses compact lossless atlases")
	_check(city.get_node("Entities").y_sort_enabled, "Actors sort together by their feet")
	_check(city.has_node("Entities/Players") and city.has_node("Entities/Interactables"), "City supports players and interactions")
	_check_connection(city, "ToRoute7", route, ROUTE, "right")
	_check_connection(route, "ToCeladonCity", city, CITY, "left")
	var ids := {}
	var occupied := {}
	var npcs := city.get_node("Entities/NPCs").get_children()
	var pokemon := city.get_node("Entities/Pokemon").get_children()
	_check(npcs.size() == 10 and pokemon.size() == 11, "City contains nine residents, a Transit Keeper and eleven Pokémon, including Mira and her Eevee")
	for actor: Node2D in npcs + pokemon:
		var is_pokemon: bool = actor.get_script().resource_path == PokemonScript
		var is_keeper: bool = actor.get_script().resource_path == "res://scripts/world/npcs/transit_keeper_npc.gd"
		_check(is_pokemon or is_keeper or actor.get_script().resource_path == NpcScript, "Actor uses the established interaction script")
		var id := str(actor.get("overworld_pokemon_id") if is_pokemon else actor.get("npc_id"))
		if is_keeper:
			_check(actor.local_destination_id == city.map_id, "Transit Keeper serves Celadon")
		else:
			_check(id.begins_with("kanto_celadon_city_") and not ids.has(id), "Actor metadata ID is unique: %s" % id)
			ids[id] = true
		var tile := Vector2i(actor.position / 32.0)
		occupied[tile] = true
		if is_pokemon:
			var frames := FollowerSpriteService.get_sprite_frames(actor.get("species_id"), false) as SpriteFrames
			_check(frames != null, "Pokémon has a follower sprite: %s" % actor.name)
		else:
			_check(actor.get("npc_sprite_frames") != null, "Resident has an overworld sprite")
	var catalog := JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json")) as Dictionary
	_check(catalog.areas.has("kanto_celadon_city"), "City is registered for server-authorized travel")
	for id: String in ["kanto_celadon_city__to_route7", "kanto_route_7__to_celadon_city"]:
		_check(catalog.transitions.has(id), "Connection is exported: %s" % id)
	player.free()
	city.free()
	route.free()
	print("celadon_city_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures else 0)


func _check_connection(source: Node, exit_name: String, target: Node, path: String, facing: String) -> void:
	var exit_node := source.get_node("Exits/" + exit_name)
	_check(exit_node.get("target_scene_path") == path, "Exit targets its neighboring map")
	_check(exit_node.get("transition_facing_direction") == facing, "Arrival faces into destination")
	_check(exit_node.is_connected("body_entered", Callable(exit_node, "_on_body_entered")), "Exit handles player entry")
	var marker := target.get_node("Spawns/" + str(exit_node.get("target_spawn_name"))) as Marker2D
	for target_exit: Node2D in target.get_node("Exits").get_children():
		var shape := target_exit.get_node("CollisionShape2D") as CollisionShape2D
		var size := (shape.shape as RectangleShape2D).size
		_check(not Rect2(target_exit.position + shape.position - size / 2.0, size).has_point(marker.position), "Arrival avoids immediate return transition")


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1
