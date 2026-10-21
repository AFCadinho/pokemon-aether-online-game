extends SceneTree

const CITY_PATH := "res://scenes/overworld/kanto/towns/celadon_city/celadon_city.tscn"
const CENTER_PATH := "res://scenes/overworld/kanto/towns/celadon_city/pokemon_center.tscn"
const TEMPLATE_PATH := "res://scenes/overworld/kanto/reusable_interiors/pokemon_center_template.tscn"
const MAP_ID := "kanto_celadon_city_pokemon_center"
const STAFF := ["NurseJoy", "Banker", "Clerk", "Clerk2", "AetherAtelier", "MoveManiac", "MoveDeleter"]
const VISITORS := ["GardenerFlora", "CourierDaan", "YoungTrainerMika", "CaretakerRina"]
const SPECIES := ["bellossom", "skitty", "budew", "chansey"]
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var center := (load(CENTER_PATH) as PackedScene).instantiate()
	var template := (load(TEMPLATE_PATH) as PackedScene).instantiate()
	var city := (load(CITY_PATH) as PackedScene).instantiate()
	_check(center.map_id == MAP_ID and center.world_access_group_id == city.map_id, "Center has its own identity within Celadon City")
	_check(center.lighting_profile == "indoor" and center.weather_profile == "disabled", "Center has indoor lighting and no weather")
	_check(center.music_track_id == template.music_track_id, "Center inherits Pokémon Center music")
	_check(center.get_node("Visuals").scene_file_path == template.get_node("Visuals").scene_file_path, "Center uses the reusable visual")
	var npcs := center.get_node("Entities/NPCs")
	_check(npcs.get_child_count() == template.get_node("Entities/NPCs").get_child_count() + 4, "Four new visitors supplement the shared staff")
	var occupied := {}
	for staff_name: String in STAFF:
		var actor := npcs.get_node(staff_name)
		var original := template.get_node("Entities/NPCs/" + staff_name)
		_check(actor.position == original.position and actor.npc_id == original.npc_id, staff_name + " keeps its shared service and position")
		occupied[Vector2i(actor.position / 32.0)] = true
	_check(center.get_node("Entities/Interactables/PokemonPC") != null, "Storage PC is available")
	occupied[Vector2i(center.get_node("Entities/Interactables/PokemonPC").position / 32.0)] = true
	var actors: Array[Node] = []
	for visitor_name: String in VISITORS:
		actors.append(npcs.get_node(visitor_name))
	var pokemon := center.get_node("Entities/Pokemon")
	_check(pokemon.get_child_count() == 4, "Center has four new companion Pokémon")
	var found_species: Array[String] = []
	for actor: Node in pokemon.get_children():
		actors.append(actor)
		found_species.append(actor.species_id)
		_check(FollowerSpriteService.get_sprite_frames(actor.species_id, false) != null, str(actor.name) + " has follower sprites")
	for species: String in SPECIES:
		_check(species in found_species, species + " is present")
	var ids := {}
	for actor: Node2D in actors:
		var tile := Vector2i(actor.position / 32.0)
		occupied[tile] = true
		var id := str(actor.get("overworld_pokemon_id") if actor.get_parent() == pokemon else actor.get("npc_id"))
		_check(id.begins_with(MAP_ID + "_") and not ids.has(id), str(actor.name) + " has a unique Center metadata ID")
		ids[id] = true
	var speeds := {}
	var waits := {}
	for actor: Node2D in actors:
		var tile := Vector2i(actor.position / 32.0)
		if actor.movement_behavior == "idle":
			continue
		speeds[actor.movement_speed_pixels] = true
		waits[actor.movement_wait_seconds] = true
		_check(actor.natural_ambient_movement and actor.movement_wait_jitter_seconds > 0.0, str(actor.name) + " uses independent timing")
	_check(speeds.size() >= 5 and waits.size() == 6, "Visitors and Pokémon have varied speeds and pauses")
	var nurse := npcs.get_node("NurseJoy")
	_check(nurse.respawn_point_id == MAP_ID, "Nurse Joy records the Celadon respawn point")
	var state := root.get_node("GameState")
	var previous_map: Node = state.get("current_map")
	state.set("current_map", center)
	var payload: Dictionary = nurse.call("_build_respawn_point_payload")
	state.set("current_map", previous_map)
	_check(payload.get("mapId") == MAP_ID and payload.get("mapScenePath") == CENTER_PATH, "Healing sends this Center's canonical scene identity")
	_check(payload.get("spawnMarker") == "HealNPC" and payload.get("position") == {"x": 464.0, "y": 752.0}, "Healing targets the safe tile in front of the counter")
	var entrance := city.get_node("Exits/ToPokecenter")
	var exit_node := center.get_node("Exits/ToOutside")
	_check(entrance.target_scene_path == CENTER_PATH and entrance.target_spawn_name == "FromOutside", "City doorway enters the Center")
	_check(exit_node.target_scene_path == CITY_PATH and exit_node.target_spawn_name == "FromPokecenter", "Center returns to Celadon City")
	_check(entrance.transition_facing_direction == "up" and exit_node.transition_facing_direction == "down", "Both arrivals face into their destination")
	_check(entrance.contains_world_position(Vector2(1968, 448)), "Entrance covers the visible northeastern Center doorway")
	_check(not entrance.contains_world_position(city.get_node("Spawns/FromPokecenter").position), "Outside return avoids immediate re-entry")
	_check(not exit_node.contains_world_position(center.get_node("Spawns/FromOutside").position), "Inside arrival avoids immediate exit")
	_check(entrance.is_connected("body_entered", Callable(entrance, "_on_body_entered")) and exit_node.is_connected("body_entered", Callable(exit_node, "_on_body_entered")), "Both transitions respond to player entry")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	_check(catalog.areas.has(MAP_ID) and catalog.areas[MAP_ID].areaType == "interior", "Center is registered for server-authorized travel")
	_check(catalog.transitions.has("kanto_celadon_city__to_pokemon_center") and catalog.transitions.has(MAP_ID + "__to_outside"), "Both transition directions are exported")
	var loader = load("res://scripts/services/web_asset_module_service.gd")
	_check(loader.module_for_scene(CENTER_PATH) == loader.EXTENDED_MODULE_NAME, "Browser can load the Center map")
	center.free()
	template.free()
	city.free()
	print("CELADON_POKEMON_CENTER ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _check(ok: bool, description: String) -> void:
	if not ok:
		failed = true
		push_error(description)
