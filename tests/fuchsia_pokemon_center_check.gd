extends SceneTree

const CITY := "res://scenes/overworld/kanto/towns/fuchsia_city/fuchsia_city.tscn"
const CENTER := "res://scenes/overworld/kanto/towns/fuchsia_city/pokemon_center.tscn"
const TEMPLATE := "res://scenes/overworld/kanto/reusable_interiors/pokemon_center_template.tscn"
const CENTER_ID := "kanto_fuchsia_city_pokemon_center"
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var city := (load(CITY) as PackedScene).instantiate()
	var center := (load(CENTER) as PackedScene).instantiate()
	var template := (load(TEMPLATE) as PackedScene).instantiate()
	_check(center.map_id == CENTER_ID and center.world_access_group_id == city.map_id, "center belongs to Fuchsia City")
	_check(center.lighting_profile == "indoor" and center.weather_profile == "disabled", "indoor lighting and weather are inherited")
	_check(center.music_track_id == template.music_track_id, "Pokemon Center music is inherited")
	_check(center.get_node("Visuals").scene_file_path == template.get_node("Visuals").scene_file_path, "shared interior visual is used")
	var collision: TileMapLayer = center.get_node("Collision")
	_check(collision.tile_map_data == template.get_node("Collision").tile_map_data, "shared collision is preserved")
	for staff in ["NurseJoy", "Banker", "Clerk", "Clerk2", "AetherAtelier", "MoveManiac", "MoveDeleter"]:
		_check(center.has_node("Entities/NPCs/" + staff), "shared service exists: " + staff)
	_check(center.has_node("Entities/Interactables/PokemonPC"), "storage PC exists")
	for y in range(23,33):
		_check(collision.get_cell_source_id(Vector2i(14,y)) == -1, "healing aisle and exit stay clear")
	var nurse: Node = center.get_node("Entities/NPCs/NurseJoy")
	_check(nurse.respawn_point_id == CENTER_ID, "healing records this Center")
	var state: Node = root.get_node("GameState")
	var previous: Node = state.get("current_map")
	state.set("current_map", center)
	var payload: Dictionary = nurse.call("_build_respawn_point_payload")
	state.set("current_map", previous)
	_check(payload.get("mapId") == CENTER_ID and payload.get("mapScenePath") == CENTER, "respawn uses the dedicated scene identity")
	_check(payload.get("spawnMarker") == "HealNPC" and payload.get("position") == {"x":464.0,"y":752.0}, "respawn lands in front of Nurse Joy")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	_check(catalog.areas[CENTER_ID].areaType == "interior" and catalog.areas[CENTER_ID].locationGroupId == city.map_id, "catalog groups the Center under Fuchsia")
	for leg in [[city,"ToPokecenter",center,"FromOutside","up"],[center,"ToOutside",city,"FromPokecenter","down"]]:
		var exit_node: Node = leg[0].get_node("Exits/" + leg[1])
		var arrival: Marker2D = leg[2].get_node("Spawns/" + leg[3])
		_check(exit_node.target_scene_path == leg[2].scene_file_path and exit_node.target_spawn_name == leg[3], "round-trip endpoint matches")
		_check(exit_node.transition_facing_direction == leg[4], "arrival faces into destination")
		_check(exit_node.is_connected("body_entered",Callable(exit_node,"_on_body_entered")), "door signal is connected")
		var destination_collision: TileMapLayer = leg[2].find_map_tilemap_layer("Collision")
		_check(destination_collision.get_cell_source_id(destination_collision.local_to_map(arrival.position)) == -1, "arrival tile is walkable")
		for target_exit in leg[2].get_node("Exits").get_children():
			for offset in [Vector2.ZERO,Vector2(0,-16),Vector2(0,8)]:
				_check(not target_exit.contains_world_position(arrival.position+offset), "arrival avoids immediate return")
		var entry: Dictionary = catalog.transitions[exit_node.transition_id]
		_check(entry.sourceMapId == leg[0].map_id and entry.destinationAreaId == leg[2].map_id, "server catalog matches scene endpoints")
	_check(city.get_node("Exits/ToPokecenter").contains_world_position(Vector2(240,304)), "door covers the lower painted door tile")
	var city_collision: TileMapLayer = city.get_node("Tiles/Collision")
	for cell in [Vector2i(7,9),Vector2i(7,10),Vector2i(7,11)]:
		_check(city_collision.get_cell_source_id(cell) == -1, "doorway and front step are open")
	_check(city_collision.get_cell_source_id(Vector2i(7,8)) != -1, "upper building facade remains blocked")
	var loader = load("res://scripts/services/web_asset_module_service.gd")
	for path in [CITY,CENTER]:
		_check(loader.module_for_scene(path) == loader.EXTENDED_MODULE_NAME, "browser loads the Fuchsia scene")
	_check(loader.scene_for_map(CENTER_ID) == CENTER, "browser respawn resolves the Center scene")
	center.free()
	template.free()
	city.free()
	print("FUCHSIA_POKEMON_CENTER ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
