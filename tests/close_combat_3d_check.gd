extends "res://tests/battle_move_effects_3d_check.gd"
const Recipes = preload("res://scripts/battle/battle_ui/move_recipe_3d.gd")
func _run() -> void:
	get_tree().create_timer(90).timeout.connect(func():get_tree().quit(1))
	_setup()
	var recipe := Recipes.get_recipe("Close Combat")
	var combo: Dictionary=recipe.close_choreography
	var bytes := FileAccess.get_file_as_bytes(combo.reference_path)
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256);hash_context.update(bytes)
	assert(hash_context.finish().hex_encode()==combo.reference_sha256)
	var reference: Dictionary=JSON.parse_string(bytes.get_string_from_utf8())
	assert(reference.frames.size()==combo.source_frames and combo.beats.size()==14)
	for beat: Dictionary in combo.beats:
		var found := false
		for cell: Dictionary in reference.frames[int(beat.frame)]:
			found=found or cell.pattern==beat.pattern and cell.x-384==beat.x and 96-cell.y==beat.y
		assert(found,"Every strike originates in the 2D storyboard")
	assert(recipe.audio.size()==6)
	for i in 5:
		assert(recipe.audio[i].source_frame==reference.timings[i].frame)
		assert(recipe.audio[i].pitch==reference.timings[i].pitch)
		assert(is_equal_approx(recipe.audio[i].at_fraction,reference.timings[i].frame/37.))
	assert(is_equal_approx(recipe.audio[5].at_fraction,recipe.impact_fraction))
	var maximum := 0
	for slot in 4:
		var actor := "p%d"%(slot+1)
		var target_slot := slot^1
		var target := "p%d"%(target_slot+1)
		for result in ["hit","miss","block"]:
			stage.start_move_action(actor,"Close Combat")
			if result=="miss":stage.start_move_dodge(actor,target,"Close Combat")
			var effect: Node=stage.create_move_effect("Close Combat",actor,target,{"show_impact":result=="hit","result":result})
			effect.set_process(false)
			var duration: float=effect.duration
			var displacement: Vector3=stage.move_contacts[slot].displacement
			var seen := {}
			for quarter in range(1,145):
				var frame := quarter/4.
				stage.players[slot].seek(frame/37.*duration,true)
				stage._update_move_contacts();stage._update_move_dodges()
				effect._process(0)
				for beat in effect.combo_beats_drawn:seen[beat]=true
				maximum=maxi(maximum,effect.cursor)
				assert(effect.cursor<=90)
				for j in effect.cursor:assert(effect.pieces[j].transform.is_finite())
				if frame>=3 and frame<=31:assert(stage.contact_offsets[slot].is_equal_approx(displacement),"Stay at the opponent for the entire combo")
				if frame>=35:assert(stage.contact_offsets[slot].is_zero_approx())
				assert(effect.impact_drawn==(result=="hit" and frame>=28),"One final gameplay beat")
				if result=="miss" and frame>=3 and frame<=28:
					assert(stage.dodge_offsets[target_slot].length()>=stage.move_dodges[target_slot].displacement.length()*.98,"Evade the first punch, stay aside through the finisher")
			assert(seen.size()==14)
			effect.cancel()
			stage._clear_move_dodge(target_slot)
			await get_tree().process_frame
			assert(stage.contact_offsets[slot].is_zero_approx() and stage.dodge_offsets[target_slot].is_zero_approx())
	# Cancellation halfway through the barrage immediately restores native actors.
	stage.start_move_action("p1","Close Combat")
	var effect: Node=stage.create_move_effect("Close Combat","p1","p2",{"show_impact":true})
	stage.players[0].seek(effect.duration*.4,true);stage._update_move_contacts()
	assert(stage.contact_offsets[0].length()>.1)
	effect.cancel()
	assert(stage.contact_offsets[0].is_zero_approx())
	router.cancel_render();router.release_threaded_resource_requests();router=null
	stage.queue_free();await get_tree().process_frame
	print("CLOSE_COMBAT_3D_OK beats=14 source_hash=true audio_repeats=6 slots=4 outcomes=3 early_dodge=true contact_hold=true cancellation=true max_pieces=",maximum)
	get_tree().quit()
