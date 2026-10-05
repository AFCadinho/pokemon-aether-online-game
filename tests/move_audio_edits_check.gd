extends SceneTree
const Effect = preload("res://scripts/battle/battle_ui/move_effect_3d.gd")
const Catalog = preload("res://scripts/battle/animations/battle_audio_catalog.gd")
func _initialize() -> void:
	var catalog := Catalog.new()
	var count := 0
	for move in Effect.KEYS:
		var source := catalog.get_plan("move", Effect.audio_source_key(move))
		var original := source.duplicate(true)
		for frames in [60.0, 120.0, 407.5]:
			var timing := {"move_key":move,"frames":frames,"launch_frame":frames*.17,"impact_frame":frames*.45}
			var plan := Effect.audio_plan(source,timing)
			assert(source==original and plan.bounded_to_action)
			var unique := {}
			for cue in source.cues: unique[cue.event.name] = true
			assert(plan.cues.size()==unique.size(), "Every current catalog sound needs an explicit 3D edit: "+move)
			for cue in plan.cues:
				assert(cue.event.end_seconds > cue.at_seconds and cue.event.end_seconds <= frames/60.0)
				assert(cue.event.fade_seconds>0 and cue.event.fade_seconds < cue.event.end_seconds-cue.at_seconds)
				assert(plan.sound_paths[cue.event.name].begins_with("res://assets/battles/moves_3d/audio_edited/"))
				var audio: AudioStream = load(plan.sound_paths[cue.event.name])
				assert(audio != null and audio.get_length() > 0 and audio.get_length() <= .56)
				if cue.event.requires_hit: assert(is_equal_approx(cue.at_seconds,frames*.45/60))
		count += 1
	var flash := Effect.audio_plan(catalog.get_plan("move","flashcannon"),{"move_key":"flashcannon","frames":407.5,"launch_frame":60,"impact_frame":120})
	assert(is_equal_approx(flash.cues[0].at_seconds,1.0))
	var flash_audio: AudioStream = load(flash.sound_paths["PRSFX- Flash Cannon.wav"])
	assert(absf(flash_audio.get_length()-.48)<.002)
	var moon := Effect.audio_plan(catalog.get_plan("move","moonblast"),{"move_key":"moonblast","frames":120,"launch_frame":20,"impact_frame":48})
	assert(moon.cues[0].at_seconds==0 and is_equal_approx(moon.cues[0].event.end_seconds,20.0/60))
	assert(moon.cues[0].event.role=="charge" and moon.cues[1].event.requires_hit)
	assert(catalog.get_plan("effect","stat_up").get("bounded_to_action",false)==false)
	print("MOVE_AUDIO_EDITS_OK moves=",count," timing_profiles=3 bounded=true source_2d_unchanged=true")
	quit()
