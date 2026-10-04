extends SceneTree

const MAP_SCENES := [
	"res://scenes/overworld/kanto/towns/vermilion_city/vermilion_city.tscn",
	"res://scenes/overworld/kanto/routes/kanto_route_6.tscn",
]
const NPC_SCRIPT := "res://scripts/world/npcs/base_npc.gd"


func _init() -> void:
	for scene_path: String in MAP_SCENES:
		var source := FileAccess.get_file_as_string(scene_path)
		if source.is_empty():
			push_error("Could not read NPC map scene: %s" % scene_path)
			quit(1)
			return
		if source.contains("manual_interaction_reach_tiles = 0"):
			push_error("NPCs in %s have zero interaction reach" % scene_path)
			quit(1)
			return
		if not source.contains("manual_interaction_reach_tiles = 1"):
			push_error("NPCs in %s do not set an adjacent-tile interaction reach" % scene_path)
			quit(1)
			return

	var npc_source := FileAccess.get_file_as_string(NPC_SCRIPT)
	if not npc_source.contains("for distance: int in range(1, manual_interaction_reach_tiles + 1):"):
		push_error("NPC facing check no longer uses the configured interaction reach")
		quit(1)
		return

	print("Vermilion City and Route 6 NPCs are interactable from an adjacent tile")
	quit(0)
