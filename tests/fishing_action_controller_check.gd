extends SceneTree

const CONTROLLER_PATH := "res://scripts/ui/fishing_action_controller.gd"
const OVERLAY_PATH := "res://scenes/interface/ui_overlay.tscn"
const WORLD_PATH := "res://scripts/world/world.gd"

var failed := false


func _init() -> void:
	var controller_source := FileAccess.get_file_as_string(CONTROLLER_PATH)
	var overlay_source := FileAccess.get_file_as_string(OVERLAY_PATH)
	var world_source := FileAccess.get_file_as_string(WORLD_PATH)

	_check(
		overlay_source.contains('path="res://scripts/ui/fishing_action_controller.gd"')
		and overlay_source.contains('[node name="FishingActionController" type="Node" parent="."]'),
		"overworld overlay installs the fishing action controller"
	)
	_check(
		controller_source.contains('actions_row.add_child(slot)')
		and controller_source.contains('action_button.pressed.connect(_toggle_popup)'),
		"action bar exposes a clickable rod selector"
	)
	_check(
		controller_source.contains("not bool(rod.get(\"owned\", false))")
		and controller_source.contains("not bool(rod.get(\"usable\", false))")
		and controller_source.contains("InventoryService.select_fishing_rod"),
		"rod selector only submits owned and currently usable rods"
	)
	_check(
		controller_source.contains("action_button.disabled = selection_pending"),
		"players without a rod can still inspect the fishing progression panel"
	)
	_check(
		world_source.contains("await _refresh_fishing_progression()")
		and world_source.contains('reward.get("fishingProgression", {})')
		and world_source.contains('"Fishing Level increased to %d!"'),
		"world refreshes regional progression and reports Fishing XP levels"
	)
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
