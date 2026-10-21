extends SceneTree
var failed := false
func _init() -> void:
	run.call_deferred()
func run() -> void:
	var route := (load("res://scenes/overworld/kanto/routes/kanto_route_16_east.tscn") as PackedScene).instantiate()
	var house := (load("res://scenes/overworld/kanto/routes/route_16_east_house.tscn") as PackedScene).instantiate()
	root.add_child(route)
	root.add_child(house)
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
	house.get_node("Entities/Players").add_child(player)
	player.refresh_map_layers()
	for x in range(8,11):
		check(player.overlaps_exit_at(house.get_node("Exits/ToRoute16East"),point(Vector2i(x,15))), "exit covers the full doorway")
	var bird: Node = house.get_node("Entities/NPCs/BirdKeeperRowan")
	check(bird.npc_id == "kanto_route_16_east_house_bird_keeper" and bird.npc_sprite_frames != null, "Bird Keeper has registered identity and art")
	bird._apply_npc_metadata({"id":bird.npc_id,"offeredQuestId":"route16_bird_research","questRewardId":"kanto_route_16_east_house_bird_keeper_fly_reward","questRewardReceivedDialogueId":"kanto_route_16_east_house_bird_keeper_received"})
	check(bird.offered_quest_id == "route16_bird_research" and bird.quest_reward_id == "kanto_route_16_east_house_bird_keeper_fly_reward", "NPC binds quest offer and reward metadata")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	for leg in [[route,"ToHouse",house,"FromRoute16East","up"],[house,"ToRoute16East",route,"FromHouse","down"]]:
		var exit_node: Node = leg[0].get_node("Exits/" + leg[1])
		var arrival: Marker2D = leg[2].get_node("Spawns/" + leg[3])
		check(exit_node.target_scene_path == leg[2].scene_file_path and exit_node.target_spawn_name == leg[3], "paired scene and spawn")
		check(exit_node.transition_facing_direction == leg[4], "arrival facing")
		check(exit_node.is_connected("body_entered",Callable(exit_node,"_on_body_entered")), "entry signal connected")
		player.reparent(leg[2].get_node("Entities/Players"))
		player.refresh_map_layers()
		for other_exit in leg[2].get_node("Exits").get_children():
			check(not player.overlaps_exit_at(other_exit,arrival.position), "arrival avoids immediate return " + leg[3])
		var definition: Dictionary = catalog.transitions[exit_node.transition_id]
		check(definition.sourceMapId == leg[0].map_id and definition.destinationAreaId == leg[2].map_id, "server endpoints match")
		check(definition.destination.position == {"x":arrival.position.x,"y":arrival.position.y}, "server spawn matches")
	player.reparent(route.get_node("Entities/Players"))
	player.refresh_map_layers()
	check(player.overlaps_exit_at(route.get_node("Exits/ToHouse"),route.get_node("Exits/ToHouse").position), "exterior door detects entry")
	var loader = load("res://scripts/services/web_asset_module_service.gd")
	check(loader.scene_for_map(house.map_id) == house.scene_file_path, "web module resolves house")
	var validator := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new()
	check(validator.validate(house.get_node("Visual"),"res://generated/tiled_visuals/route_16_east_house/route_16_east_house.visual.tileset.tres").is_empty(), "visual atlas resolves")
	route.free()
	house.free()
	print("ROUTE_16_EAST_HOUSE ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
func point(tile: Vector2i) -> Vector2:
	return Vector2(tile)*32+Vector2(16,16)
func check(ok: bool,label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
