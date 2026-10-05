extends SceneTree

const MAP_SCENES := [
	"res://scenes/overworld/kanto/towns/vermilion_city/vermilion_city.tscn",
	"res://scenes/overworld/kanto/routes/kanto_route_6.tscn",
]
const NPC_SCRIPT := "res://scripts/world/npcs/base_npc.gd"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
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
		# Godot omits exported properties that equal the script's default.
		# Inspect actual instances instead of requiring redundant scene text.
		var map := (load(scene_path) as PackedScene).instantiate()
		var inspected := 0
		for group_name in ["NPCs", "Pokemon"]:
			var group := map.get_node_or_null("Entities/" + group_name)
			if group == null:
				continue
			for actor: Node in group.get_children():
				for property: Dictionary in actor.get_property_list():
					if property.name != "manual_interaction_reach_tiles":
						continue
					inspected += 1
					if int(actor.get("manual_interaction_reach_tiles")) < 1:
						push_error("NPC %s in %s cannot reach an adjacent tile" % [actor.name, scene_path])
						map.free()
						quit(1)
						return
		map.free()
		if inspected == 0:
			push_error("No NPC interaction ranges inspected in %s" % scene_path)
			quit(1)
			return

	var npc_source := FileAccess.get_file_as_string(NPC_SCRIPT)
	if not npc_source.contains("for distance: int in range(1, manual_interaction_reach_tiles + 1):"):
		push_error("NPC facing check no longer uses the configured interaction reach")
		quit(1)
		return

	print("Vermilion City and Route 6 NPCs are interactable from an adjacent tile")
	quit(0)
