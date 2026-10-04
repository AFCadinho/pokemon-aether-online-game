extends SceneTree

const VERMILION_CITY_SCENE := "res://scenes/overworld/kanto/towns/vermilion_city/vermilion_city.tscn"
const MAP_METADATA_SCRIPT := "res://scripts/world/map_metadata.gd"
const FISHING_CONTROLLER_SCRIPT := "res://scripts/ui/fishing_action_controller.gd"


func _init() -> void:
	var scene_source := FileAccess.get_file_as_string(VERMILION_CITY_SCENE)
	var map_metadata_source := FileAccess.get_file_as_string(MAP_METADATA_SCRIPT)
	var fishing_controller_source := FileAccess.get_file_as_string(FISHING_CONTROLLER_SCRIPT)
	if not scene_source.contains('encounter_area_id = "kanto_vermilion_city"'):
		push_error("Vermilion City scene is missing its fishing encounter area ID")
		quit(1)
		return
	if not map_metadata_source.contains("func get_wild_encounter_area_id() -> String:\n\treturn encounter_area_id"):
		push_error("Map metadata does not expose its encounter area ID")
		quit(1)
		return
	if not fishing_controller_source.contains('current_map.call("get_wild_encounter_area_id")'):
		push_error("Fishing does not request encounters for the current map area")
		quit(1)
		return

	print("Vermilion City fishing encounter area is connected")
	quit(0)
