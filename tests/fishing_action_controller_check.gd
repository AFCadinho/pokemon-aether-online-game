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
		controller_source.contains("actions_row.add_child(action_slot)")
		and controller_source.contains('action_button.pressed.connect(_toggle_popup)'),
		"action bar exposes a clickable rod selector"
	)
	_check(
		controller_source.contains('const FISHING_ACTION_ICON := preload("res://assets/ui/fishing_rod.svg")')
		and controller_source.contains("action_button.texture_normal = FISHING_ACTION_ICON")
		and controller_source.contains("header_icon.texture = FISHING_ACTION_ICON"),
		"toolbar and header use the dedicated vector fishing icon"
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
		controller_source.contains('button.add_theme_constant_override("icon_max_width", 32)')
		and not controller_source.contains("button.icon_max_width ="),
		"rod buttons size icons through the supported Button theme constant"
	)
	_check(
		controller_source.contains("popup.z_index = POPUP_Z_INDEX")
		and controller_source.contains("popup.move_to_front()"),
		"fishing selector renders above the action bars"
	)
	_check(
		controller_source.contains('action_slot.add_theme_stylebox_override("panel", style)')
		and controller_source.contains('popup.add_theme_stylebox_override("panel", _make_popup_style())'),
		"fishing action and selector use dedicated styled surfaces"
	)
	_check(
		controller_source.contains("experience_bar = ProgressBar.new()")
		and controller_source.contains("func _apply_rod_button_style("),
		"fishing selector presents styled XP and rod states"
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
