extends SceneTree

const FloorVisibilityMaskScript := preload("res://scripts/world/floor_visibility_mask.gd")
const MapMetadataScript := preload("res://scripts/world/map_metadata.gd")
const PLAYERS_HOUSE_SCENE_PATH := "res://scenes/overworld/kanto/towns/pallet_town/players_house.tscn"
const UI_OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"

var failed := false


func _init() -> void:
	var players_house := MapMetadataScript.new()
	players_house.map_display_name = "Player's House"
	var floor_mask := FloorVisibilityMaskScript.new()
	floor_mask.name = "FloorVisibilityMask"
	floor_mask.floor_display_names = {
		&"ground_floor": "Player's House",
		&"upper_floor": "Player's Room",
	}
	players_house.add_child(floor_mask)

	floor_mask.active_floor = &"ground_floor"
	_check_equal(
		players_house.get_map_display_name(),
		"Player's House",
		"Ground floor uses the Player's House location label"
	)
	floor_mask.active_floor = &"upper_floor"
	_check_equal(
		players_house.get_map_display_name(),
		"Player's Room",
		"Upper floor uses the Player's Room location label"
	)

	var scene_source := FileAccess.get_file_as_string(PLAYERS_HOUSE_SCENE_PATH)
	_check(
		scene_source.contains("&\"upper_floor\": \"Player's Room\""),
		"Player's House configures Player's Room for its upper floor"
	)
	_check(
		scene_source.contains("&\"ground_floor\": \"Player's House\""),
		"Player's House keeps its ground-floor label"
	)
	var ui_source := FileAccess.get_file_as_string(UI_OVERLAY_SCRIPT_PATH)
	_check(
		ui_source.contains(
			"displayed_location_map == current_map and displayed_location_name == current_location_name"
		),
		"Location card refreshes when a floor changes the current location name"
	)

	players_house.free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	_check(actual == expected, "%s (expected %s, got %s)" % [label, str(expected), str(actual)])
