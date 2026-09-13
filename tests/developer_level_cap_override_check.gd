extends SceneTree

const SERVICE_PATH := "res://scripts/services/trainer_progress_service.gd"
const TRAINER_PROGRESS_POPUP_PATH := "res://scripts/ui/dev_badge_progress_popup.gd"

var failures: Array[String] = []


func _init() -> void:
	var service_source := FileAccess.get_file_as_string(SERVICE_PATH)
	var popup_source := FileAccess.get_file_as_string(TRAINER_PROGRESS_POPUP_PATH)
	_check(
		service_source.contains('DEVELOPER_LEVEL_CAP_OVERRIDE_ENDPOINT := "/game/dev/progression/pokemon-level-cap-override"'),
		"developer level-cap override uses the protected backend endpoint"
	)
	_check(
		service_source.contains("func set_developer_level_cap_override(enabled: bool)"),
		"developer level-cap override service can update the setting"
	)
	_check(
		popup_source.contains("LevelCapOverrideButton"),
		"Trainer Progress exposes the level-cap override control"
	)
	_check(
		popup_source.contains('get_node_or_null("/root/PlayerPartyStateService")'),
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
