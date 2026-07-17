extends SceneTree

const UI_OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"
const UI_OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"
const WORLD_TIME_SERVICE_PATH := "res://scripts/services/world_time_service.gd"

var failed := false


func _init() -> void:
	var scene_source := FileAccess.get_file_as_string(UI_OVERLAY_SCENE_PATH)
	var ui_source := FileAccess.get_file_as_string(UI_OVERLAY_SCRIPT_PATH)
	var service_source := FileAccess.get_file_as_string(WORLD_TIME_SERVICE_PATH)

	_check_true(scene_source.contains('[node name="WorldTimeSelect" type="OptionButton"'), "developer menu contains a world-time selector")
	_check_true(scene_source.contains('popup/item_0/text = "Default (Server UTC)"'), "default server UTC is the first selector option")
	_check_true(scene_source.contains('popup/item_1/text = "Morning (06:00)"'), "morning preview is available")
	_check_true(scene_source.contains('popup/item_2/text = "Day (12:00)"'), "day preview is available")
	_check_true(scene_source.contains('popup/item_3/text = "Evening (19:00)"'), "evening preview is available")
	_check_true(scene_source.contains('popup/item_4/text = "Night (00:00)"'), "night preview is available")
	_check_true(ui_source.contains("const DEV_WORLD_TIME_HOURS: Array[int] = [-1, 6, 12, 19, 0]"), "selector options map to deterministic preview hours")
	_check_true(ui_source.contains("if not _can_use_dev_tools():\n\t\t_refresh_dev_world_time_selector()"), "world-time changes remain developer-only")
	_check_true(ui_source.contains("WorldTimeService.clear_debug_time()"), "default selection clears the override")
	_check_true(ui_source.contains("WorldTimeService.set_debug_time(selected_hour)"), "preview selections update the shared time source")
	_check_true(ui_source.contains("_refresh_utc_time_label(UTC_TIME_REFRESH_INTERVAL_SECONDS, true)"), "location clock refreshes immediately after selection")
	_check_true(not service_source.contains("user://") and not service_source.contains("SettingsManager"), "debug time is never persisted")

	quit(1 if failed else 0)


func _check_true(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
