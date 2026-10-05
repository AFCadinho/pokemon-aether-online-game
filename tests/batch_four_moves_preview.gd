extends "res://tests/battle_dialogue_preview.gd"
const Batch = preload("res://scripts/battle/battle_ui/batch_four_move_effect_3d.gd")
const MODELS := ["Dragonite","Dragonite","Dragonite","Dragonite","Dragonite","Dragonite","Dragonite","Blastoise","Bulbasaur","Squirtle"]
var new_move_index := 0
func _start() -> void:
	left_species = MODELS[0]
	if "--smoke-batch-four" in OS.get_cmdline_user_args():
		create_timer(600).timeout.connect(func(): printerr("BATCH_FOUR_PREVIEW_TIMEOUT"); quit(1))
	await super._start()
	root.title = "PokeAether — 10 nieuwe 3D-moves uit de dump"
	move_picker.select(13)
	var row := HBoxContainer.new()
	toolbar.add_child(row)
	_button(row,"Vorige nieuwe move",func(): _select_new(-1))
	_button(row,"Volgende nieuwe move",func(): _select_new(1))
	status.text = "Nieuwe reeks: Shadow Ball t/m Water Pulse. Test raak / ontwijken en draai de camera."
	if "--audio-review" in OS.get_cmdline_user_args():
		root.title = "PokeAether — 3D movegeluiden testen"
		status.text = "Nieuwe korte 3D-geluiden: test vooral Moonblast, Flash Cannon en Magical Leaf. Raak / ontwijken via de keuzelijst."
	print("BATCH_FOUR_PREVIEW_READY moves=10")
	if "--smoke-batch-four" in OS.get_cmdline_user_args(): await _check_batch()
	if "--smoke-batch-navigation" in OS.get_cmdline_user_args(): await _check_navigation()

func _select_new(step: int) -> void:
	if move_busy or loading: return
	new_move_index = posmod(move_picker.selected-13+step,10)
	move_picker.select(13+new_move_index)
	if left_species!=MODELS[new_move_index]:
		left_species = MODELS[new_move_index]
		_sync_model_picker()
		await _load_preview()
	status.text = "Nieuwe move %d/10: %s" % [new_move_index+1,FIRST_MOVES[13+new_move_index]]

func _check_batch() -> void:
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	for index in 10:
		move_picker.select(13+index)
		if left_species!=MODELS[index]:
			left_species = MODELS[index]
			_sync_model_picker()
			await _load_preview()
		var renderer = battle.animation_router.model_presenter
		assert(renderer.active and battle.battle_state.battle_id.is_empty())
		renderer.user_camera_yaw = 0
		for reverse in [false,true]:
			move_reverse.button_pressed = reverse
			for outcome in [0,1,2]:
				move_outcome.select(outcome)
				_preview_move()
				while renderer.common_effects.is_empty(): await process_frame
				var effect: Node = renderer.common_effects[0]
				assert(effect.get_script()==Batch)
				var original_aim: Vector3 = effect.anchors.call().target
				if not reverse and index in [7,9]:
					assert(effect.anchors.call().attachment_part==("cannons" if index==7 else "mouth"))
				for phase in ["flight","impact"]:
					var target_time: float = lerpf(effect.launch,effect.impact,0.55) if phase=="flight" else effect.impact+effect.duration*0.025
					while effect.elapsed<target_time: await process_frame
					battle.animation_router.playback_speed = 0
					await process_frame
					await process_frame
					var frozen: float = effect.elapsed
					assert(renderer.move_contacts[1 if reverse else 0].is_empty())
					if outcome==1: assert(effect.anchors.call().target.is_equal_approx(original_aim))
					if not reverse and not output.is_empty() and DisplayServer.get_name()!="headless":
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png(output.path_join("%s-%d-%s.png" % [effect.key,outcome,phase]))
					renderer.user_camera_yaw += 0.12
					await create_timer(0.05).timeout
					assert(is_equal_approx(effect.elapsed,frozen))
					for i in effect.cursor:
						var piece: MeshInstance3D = effect.pieces[i]
						if piece.mesh is QuadMesh and effect.sprite_keys[i] not in ["magic_glow","poison_trail"]:
							assert(absf(piece.global_basis.z.normalized().dot(renderer.camera.global_basis.z.normalized()))>0.999)
					battle.animation_router.playback_speed = 1
				while move_busy: await process_frame
				await process_frame
				assert(renderer.common_effects.is_empty())
				print("BATCH_FOUR_CASE_OK ",Batch.MOVE_KEYS[index]," reverse=",reverse," outcome=",outcome)
		_preview_move()
		while renderer.common_effects.is_empty(): await process_frame
		battle.animation_router.cancel_render()
		while move_busy: await process_frame
		await process_frame
		assert(renderer.common_effects.is_empty() and battle.animation_router.active_audio_nodes.is_empty())
	print("BATCH_FOUR_PREVIEW_OK moves=10 directions=2 outcomes=3 attachments=true pause_orbit=true dodge=true cancellation=true")
	quit()

func _sync_model_picker() -> void:
	for index in move_model_picker.item_count:
		if move_model_picker.get_item_text(index)==left_species:
			move_model_picker.select(index)
			return

func _check_navigation() -> void:
	create_timer(90).timeout.connect(func(): quit(1))
	await _select_new(-1)
	assert(move_picker.selected==22 and left_species=="Squirtle")
	assert(move_model_picker.get_item_text(move_model_picker.selected)==left_species)
	await _select_new(1)
	assert(move_picker.selected==13 and left_species=="Dragonite")
	assert(move_model_picker.get_item_text(move_model_picker.selected)==left_species)
	# Inspect the source moon during charge, before the projectile is released.
	move_picker.select(16)
	_preview_move()
	var renderer = battle.animation_router.model_presenter
	while renderer.common_effects.is_empty(): await process_frame
	var effect: Node = renderer.common_effects[0]
	while effect.elapsed<effect.launch*0.6: await process_frame
	battle.animation_router.playback_speed = 0
	await process_frame
	await process_frame
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	if not output.is_empty() and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("moonblast-charge.png"))
	battle.animation_router.cancel_render()
	while move_busy: await process_frame
	print("BATCH_FOUR_NAVIGATION_OK wrap=true model_selection=true charge=true")
	quit()
