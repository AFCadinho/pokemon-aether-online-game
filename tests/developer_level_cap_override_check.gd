extends SceneTree

const SERVICE_PATH := "res://scripts/services/trainer_progress_service.gd"
const OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"

var failures: Array[String] = []


func _init() -> void:
	var service_source := FileAccess.get_file_as_string(SERVICE_PATH)
	var overlay_source := FileAccess.get_file_as_string(OVERLAY_PATH)
	_check(
		service_source.contains('DEVELOPER_LEVEL_CAP_OVERRIDE_ENDPOINT := "/game/dev/progression/pokemon-level-cap-override"'),
		"developer level-cap override uses the protected backend endpoint"
	)
	_check(
		service_source.contains("func set_developer_level_cap_override(enabled: bool)"),
		"developer level-cap override service can update the setting"
	)
	_check(
		overlay_source.contains("dev_level_cap_override_button"),
		"Developer Tools exposes the level-cap override control"
	)
	_check(
		overlay_source.contains("await PlayerPartyStateService.load_party()"),
		"changing the override refreshes the authoritative party level cap"
	)
	if failures.is_empty():
		print("PASS: developer level-cap override checks")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
