extends "res://tests/battle_move_effects_3d_check.gd"
const Recipes = preload("res://scripts/battle/battle_ui/move_recipe_3d.gd")
func _run() -> void:
	get_tree().create_timer(60).timeout.connect(func():get_tree().quit(1))
	_setup()
	var styles := {}
	for key: String in Recipes.DATA.data.moves:
		var recipe := Recipes.get_recipe(key)
		if not recipe.has("z_choreography"):continue
		var ref: Dictionary = recipe.z_choreography
		styles[ref.style] = true
		var raw := FileAccess.get_file_as_bytes(ref.reference_path)
		var hash_context := HashingContext.new()
		hash_context.start(HashingContext.HASH_SHA256)
		hash_context.update(raw)
		assert(hash_context.finish().hex_encode()==ref.reference_sha256,key)
		var source: Dictionary = JSON.parse_string(raw.get_string_from_utf8())
		assert(source.frames.size()==int(ref.source_frames))
		assert(is_equal_approx(float(recipe.launch_fraction),float(ref.release_frame)/float(ref.source_frames)))
		for frames in [60.0,120.0,407.5]:
			var action := "physical_attack" if recipe.contact else "special_attack"
			stage.entries.fixture.action_timing[action].frames = frames
			stage.start_move_action("p1",key)
			var timing: Dictionary = stage.move_timing(key,"p1")
			var rate: float = stage.players[0].get_playing_speed()
			assert(is_equal_approx(timing.frames/60/rate,float(recipe.duration_seconds)))
			var audio := Recipes.audio_plan(timing)
			for cue: Dictionary in audio.cues:
				assert(cue.at_seconds>=0 and cue.event.end_seconds<=audio.duration_seconds)
				if cue.event.role=="impact":
					assert(cue.event.requires_hit and is_equal_approx(cue.at_seconds,timing.impact_frame/60))
			var before: Vector3 = stage.actors[0].position
			var effect: Node = stage.create_move_effect(key,"p1","p2",{"show_impact":true})
			assert(effect.get_script()==Stage.ZMoveEffect)
			if recipe.contact:
				stage.players[0].seek(timing.launch_frame/60-.001,true)
				stage._update_move_contacts()
				assert(stage.contact_offsets[0].is_zero_approx(),"Z charge must precede the approach")
				stage.players[0].seek(lerpf(timing.launch_frame/60,timing.impact_frame/60,.5),true)
				stage._update_move_contacts()
				assert(stage.contact_offsets[0].length()>.1)
				if ref.style in ["sky_dive","moonsault","body_slam","electric_dive"]:assert(stage.contact_offsets[0].y>.5)
				stage.players[0].seek(timing.impact_frame/60,true)
				stage._update_move_contacts()
				assert(stage.contact_offsets[0].is_equal_approx(stage.move_contacts[0].displacement),"Stay at the target through the final impact")
			effect.cancel()
			await get_tree().process_frame
			assert(stage.actors[0].position.is_equal_approx(before) and stage.move_contacts[0].is_empty())
	assert(styles.size()==35)
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("Z_CHOREOGRAPHY_OK moves=35 source_hashes=true clips=3 charge_before_contact=true airborne=true cancellation_restore=true audio_markers=true")
	get_tree().quit()
