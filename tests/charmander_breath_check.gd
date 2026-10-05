extends SceneTree
const Breath = preload("res://scripts/battle/animations/charmander_breath.gd")
const Models = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Timing = preload("res://scripts/battle/battle_3d_move_timing.gd")
const Effect = preload("res://scripts/battle/battle_ui/move_effect_3d.gd")
const ActionMap = preload("res://scripts/battle/animations/model_action_map.gd")
func _init() -> void:
	var shared := AnimationLibrary.new()
	var idle := Animation.new()
	shared.add_animation("idle", idle)
	shared.add_animation("special_attack", Animation.new())
	var players: Array[AnimationPlayer] = []
	for identity: String in Breath.DATA.data.models:
		var player := AnimationPlayer.new()
		player.add_animation_library("", shared)
		assert(not Breath.apply(player, identity, "wrong-revision"))
		assert(not player.has_animation("special_attack_2"))
		var digest: String = Breath.DATA.data.models[identity]
		assert(Breath.apply(player, identity, digest))
		assert(not shared.has_animation("special_attack_2"), "Never modify another actor's shared library")
		assert(player.get_animation("idle") != idle)
		var clip := player.get_animation("special_attack_2")
		assert(clip.get_track_count() == 68 * 3 and is_equal_approx(clip.length, 2.3))
		assert(clip.loop_mode == Animation.LOOP_NONE)
		for t in clip.get_track_count():
			assert(clip.track_get_type(t) in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D])
			assert(clip.track_get_key_count(t) == 139)
			for k in range(1, clip.track_get_key_count(t)):
				assert(clip.track_get_key_time(t,k) > clip.track_get_key_time(t,k-1))
		for boundary in [40, 78]:
			var max_rotation := 0.0
			var max_translation := 0.0
			for t in clip.get_track_count():
				if clip.track_get_type(t) == Animation.TYPE_ROTATION_3D:
					var difference: float = clip.track_get_key_value(t,boundary-1).angle_to(clip.track_get_key_value(t,boundary))
					max_rotation = maxf(max_rotation, difference)
				elif clip.track_get_type(t) == Animation.TYPE_POSITION_3D:
					max_translation = maxf(max_translation, clip.track_get_key_value(t,boundary-1).distance_to(clip.track_get_key_value(t,boundary)))
			print("BREATH_SEAM frame=",boundary," rotation=",max_rotation," translation=",max_translation)
			assert(max_rotation < 0.35 and max_translation < 0.035, "Native segment boundaries must remain continuous")
		var profile := Models.resolve(identity, digest)
		var timing := Timing.profile(identity, "Ember", "special_attack_2", profile.action_timing)
		assert(not timing.is_empty() and timing.launch_frame == 40 and timing.impact_frame == 64)
		assert(profile.motion.clips.has("special_attack_2"))
		assert(Timing.profile(identity, "Water Gun", "special_attack", profile.action_timing).is_empty())
		assert(ActionMap.resolve("special_attack_2", PackedStringArray(["special_attack"]), profile.action_timing).action == "special_attack")
		var source := {"cues":[{"at_seconds":0.0,"event":{"name":"Ember.wav"}}]}
		var audio := Effect.audio_plan(source, timing)
		assert(is_equal_approx(audio.cues[0].at_seconds, 40.0/60.0))
		assert(Effect.launch_time(timing) == audio.cues[0].at_seconds)
		assert(source.cues[0].at_seconds == 0.0)
		players.append(player)
	players[0].get_animation("special_attack_2").length = 0.1
	assert(is_equal_approx(players[1].get_animation("special_attack_2").length, 2.3))
	assert(not Breath.matches("charmeleon", Breath.DATA.data.models.charmander))
	for player in players: player.free()
	print("CHARMANDER_BREATH_OK normal_shiny=true isolated_libraries=true clip_clock=true guarded_fallback=true audio_launch=true")
	quit()
