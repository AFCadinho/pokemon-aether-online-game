extends SceneTree

const SFX_MANAGER_PATH := "res://scripts/services/sfx_manager.gd"
const FIELD_MOVE_SERVICE_PATH := "res://scripts/services/field_move_service.gd"
const FIELD_MOVE_OBSTACLE_PATH := "res://scripts/world/interactables/field_move_obstacle.gd"
const EXPECTED_SOUNDS := {
	"cut": "res://assets/battles/animations/razorleaf/PRSFX- Razor Leaf1.wav",
	"rock-smash": "res://assets/battles/animations/rocksmash/PRSFX- Rock Smash.wav",
	"rain-dance": "res://assets/battles/animations/weatherball/PRSFX- Weather Ball1.wav",
	"snowscape": "res://assets/battles/animations/powdersnow/PRSFX- Powder Snow1.wav",
	"sunny-day": "res://assets/battles/animations/charge/PRSFX- Solar Beam1.wav",
}

var failed := false


func _init() -> void:
	var sfx_source := FileAccess.get_file_as_string(SFX_MANAGER_PATH)
	for move_id: String in EXPECTED_SOUNDS:
		var sound_path := str(EXPECTED_SOUNDS[move_id])
		_check(sfx_source.contains('"%s"' % move_id), "%s has a field-move sound mapping" % move_id)
		_check(sfx_source.contains('"path": "%s"' % sound_path), "%s reuses its matching battle-animation sound" % move_id)
		_check(ResourceLoader.exists(sound_path), "%s battle-animation sound exists" % move_id)
		_check(load(sound_path) is AudioStream, "%s battle-animation sound loads" % move_id)

	var obstacle_source := FileAccess.get_file_as_string(FIELD_MOVE_OBSTACLE_PATH)
	var obstacle_success_index := obstacle_source.find("is_cleared = true")
	var obstacle_sound_index := obstacle_source.find("SfxManager.play_field_move(required_field_move)")
	_check(obstacle_sound_index > obstacle_success_index, "Cut and Rock Smash play sound only while clearing a valid obstacle")

	var weather_source := FileAccess.get_file_as_string(FIELD_MOVE_SERVICE_PATH)
	var response_success_index := weather_source.find('if not bool(response.get("success", false))')
	var weather_sound_index := weather_source.find("SfxManager.play_field_move(move_id)", response_success_index)
	_check(weather_sound_index > response_success_index, "weather moves play sound only after a successful server action")

	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
