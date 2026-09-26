extends SceneTree

const SCENE_PATHS := [
	"res://scenes/overworld/kanto/routes/kanto_route_1.tscn",
	"res://scenes/overworld/kanto/routes/route2/kanto_route_2.tscn",
	"res://scenes/overworld/kanto/routes/viridian_forest.tscn",
	"res://scenes/overworld/kanto/towns/pewter_city/pewter_gym.tscn",
	"res://scenes/overworld/kanto/routes/kanto_route_22.tscn",
]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var catalog := root.get_node("TrainerPortraitCatalog")
	var scenes: Array[String] = []
	for path: String in SCENE_PATHS:
		scenes.append(FileAccess.get_file_as_string(path))
	var trainer_ids: Array = root.get_node("CoopService").ORDINARY_TRAINERS.duplicate()
	trainer_ids.append_array(["kanto_alpha_gym_brock", "kanto_route_22_gary_oak"])
	for trainer_id: String in trainer_ids:
		var portrait_id := ""
		for scene_source: String in scenes:
			var marker := 'npc_id = "%s"' % trainer_id
			var start := scene_source.find(marker)
			if start < 0:
				continue
			var end := scene_source.find("\n[node ", start)
			var block := scene_source.substr(start, end - start if end >= 0 else -1)
			var definition_id := ""
			for line: String in block.split("\n"):
				if line.begins_with("npc_definition_id = "):
					definition_id = line.trim_prefix('npc_definition_id = "').trim_suffix('"')
					break
			portrait_id = catalog.resolve_portrait_id("", trainer_id, definition_id)
			break
		assert(not portrait_id.is_empty() and catalog.get_texture(portrait_id) != null,
			"co-op Trainer %s must have a usable defeat portrait" % trainer_id)

	var world: Node = load("res://scripts/world/world.gd").new()
	var game_state := root.get_node("GameState")
	var previous_map: Node = game_state.current_map
	var map_node := Node2D.new()
	var lass := BaseNPC.new()
	lass.npc_id = "kanto_route_1_lass_zoe"
	lass.npc_definition_id = "trainer_class_lass"
	lass.mugshot = catalog.get_texture("showdown_lass_gen6")
	map_node.add_child(lass)
	game_state.current_map = map_node
	assert(world.call("_coop_trainer_outro_mugshot", lass.npc_id, {}) == lass.mugshot,
		"co-op defeat dialogue uses the placed Lass NPC's mugshot")
	var gary := BaseNPC.new()
	gary.npc_id = "kanto_route_22_gary_oak"
	gary.npc_definition_id = "trainer_class_blue"
	gary.mugshot = catalog.get_texture("showdown_blue_lgpe")
	map_node.add_child(gary)
	assert(world.call("_coop_trainer_outro_mugshot", "kanto_route_22_gary_bulbasaur", {}) == gary.mugshot,
		"the Route 22 team ID resolves the placed Gary NPC's mugshot")
	game_state.current_map = null
	assert(world.call("_coop_trainer_outro_mugshot", lass.npc_id, {"trainer_class": "Lass"}) == lass.mugshot,
		"trainer class resolves the correct mugshot if the placed NPC is unavailable")
	assert(world.call("_coop_trainer_outro_mugshot", "unknown_trainer", {}) == null,
		"missing Trainer art cannot resolve to Professor Oak")
	game_state.current_map = previous_map
	map_node.free()
	world.free()
	var world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	assert(world_source.contains('mugshot, mugshot != null'),
		"defeat dialogue hides a missing portrait instead of showing the Oak default")
	print("COOP_TRAINER_DEFEAT_PORTRAITS_OK")
	quit()
