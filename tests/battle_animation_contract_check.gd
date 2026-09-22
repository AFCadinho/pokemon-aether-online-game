extends Node
const ActionMap = preload("res://scripts/battle/animations/model_action_map.gd")
const AttackSelection = preload("res://scripts/battle/animations/model_attack_selection.gd")
const Timeline = preload("res://scripts/battle/animations/battle_sound_timeline.gd")

class CapturingPlayer extends MoveAnimationPlayer:
	var heard: Array = []
	func _play_sound_event(event: Dictionary) -> void:
		heard.append(event.duplicate(true))

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var timing := {}
	var available := PackedStringArray()
	for action in ActionMap.CLIPS:
		timing[action] = {"frames": 120, "speed": 0.75, "loop": false}
		available.append(action)
		var mapped := ActionMap.resolve(action, available, timing)
		assert(mapped.action == action and mapped.duration == 2.0 and mapped.speed == .75)
	assert(ActionMap.resolve("faint_loop", available, timing).loop)
	assert(ActionMap.resolve("unknown", available, timing).is_empty())
	assert(ActionMap.resolve("physical_attack", PackedStringArray(["special_attack"]), timing).action == "special_attack")
	assert(ActionMap.resolve("physical_attack_2", PackedStringArray(["physical_attack_2"]), timing).action == "physical_attack_2")
	assert(ActionMap.resolve("physical_attack_2", PackedStringArray(["physical_attack"]), timing).action == "physical_attack")
	assert(ActionMap.resolve("damage", PackedStringArray(["idle", "physical_attack"]), timing).is_empty())
	assert(AttackSelection.family_for("Dragon Claw") == "claw")
	assert(AttackSelection.family_for("Fire Fang") == "bite")
	assert(AttackSelection.family_for("Earthquake").is_empty())
	assert(AttackSelection.request_for("Crunch", {"bite": "physical_attack_2"}) == "physical_attack_2")
	assert(AttackSelection.request_for("Dragon Claw", {}) == "physical_attack")
	for invalid in [0, -1, NAN, true, "120"]:
		var bad := timing.duplicate(true)
		bad.idle.frames = invalid
		assert(ActionMap.resolve("idle", available, bad).is_empty())
	var timings := [{"frame": 0, "type": 0, "name": "hit", "volume": 80, "pitch": 90},
		{"frame": 0, "type": 0, "name": "hit", "volume": 10, "pitch": 20},
		{"frame": 2, "type": 0, "name": "tail", "volume": 100, "pitch": 100},
		{"frame": 1, "type": 1, "name": "background"}]
	var custom := [{"frame": 0, "name": " hit ", "pitch": 110}, {"frame": 0, "name": "hit"},
		{"frame": 2, "name": " "}, "invalid"]
	var played := {}
	var first := Timeline.take_frame(timings, custom, 0, false, played)
	assert(first.size() == 2 and first[0].volume == 80 and first[0].pitch == 90)
	assert(first[1] == {"name": "hit", "volume": 100.0, "pitch": 110.0})
	assert(Timeline.take_frame(timings, custom, 0, false, played).is_empty())
	assert(Timeline.take_frame(timings, custom, 1, false, played).is_empty())
	assert(Timeline.take_frame(timings, custom, 2, false, played).size() == 1)
	assert(Timeline.take_frame(timings, custom, 0, true, {}).size() == 1)
	# Exercise the actual legacy player without loading audio or rendering VFX.
	var player := CapturingPlayer.new()
	player.data = {"timings": timings}
	player.custom_sound_events = custom
	for frame in 3:
		player._apply_timing_events(frame)
	assert(player.heard.size() == 3 and player.heard[0] == first[0] and player.heard[1] == first[1])
	player._apply_timing_events(0)
	assert(player.heard.size() == 3)
	player.played_events.clear() # Existing play/loop reset re-enables each cue.
	player._apply_timing_events(0)
	assert(player.heard.size() == 5)
	player.free()
	var plan := Timeline.compile({"fps": 20, "frames": [[], [], []], "timings": timings}, {"custom_sound_events": custom})
	assert(is_equal_approx(plan.duration_seconds, .15) and plan.cues.size() == 3)
	assert(plan.cues[0].at_seconds == 0 and is_equal_approx(plan.cues[2].at_seconds, .1))
	var cropped := Timeline.compile({"fps": 20, "frames": [[], [], []], "timings": timings}, {"animation_start_frame": 2})
	assert(cropped.cues.size() == 1 and cropped.cues[0].at_seconds == 0 and is_equal_approx(cropped.duration_seconds, .05))
	assert(Timeline.compile({"fps": 0, "frames": [[]]}).is_empty())
	_check_catalog("res://data/battle_move_animations.json", "moves", ["outrage", "dragondance", "roost"])
	_check_catalog("res://data/battle_effect_animations.json", "effects", ["stat_up", "stat_down", "health_up"])
	print("BATTLE_ANIMATION_CONTRACT_OK")
	get_tree().quit()

func _check_catalog(path: String, section: String, keys: Array) -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for key in keys:
		var config: Dictionary = catalog[section][key]
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(config.data_path))
		var plan := Timeline.compile(data, config)
		assert(not plan.is_empty() and not plan.cues.is_empty(), key)
		var player := CapturingPlayer.new()
		player.data = data
		player.custom_sound_events = config.get("custom_sound_events", [])
		player.disable_data_sound_events = config.get("disable_data_sound_events", false)
		var start := int(config.get("animation_start_frame", 0))
		var end := int(config.get("animation_end_frame", data.frames.size() - 1))
		if end < 0:
			end = data.frames.size() - 1
		for frame in range(start, end + 1):
			var count := player.heard.size()
			player._apply_timing_events(frame)
			for event_index in range(count, player.heard.size()):
				assert(player.heard[event_index] == plan.cues[event_index].event)
				assert(is_equal_approx(plan.cues[event_index].at_seconds, (frame - start) / float(data.get("fps", 20))))
		assert(player.heard.size() == plan.cues.size())
		player.free()
		print("AUDIO_TIMELINE_PARITY ", key, " cues=", plan.cues.size())
