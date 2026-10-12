extends "res://tests/battle_dialogue_preview.gd"
const Recipes = preload("res://scripts/battle/battle_ui/move_recipe_3d.gd")
func _start() -> void:
	left_species = "Dragonite"
	await super._start()
	root.get_node("SettingsManager").battle_3d_camera_motion = true
	move_picker.clear()
	var subset := OS.get_environment("POKEAETHER_Z_PREVIEW_MOVES").split(",",false)
	for recipe: Dictionary in Recipes.DATA.data.moves.values():
		if recipe.has("z_choreography") and (subset.is_empty() or Recipes.key(str(recipe.name)) in subset):move_picker.add_item(str(recipe.name))
	root.title = "PokeAether — 35 cinematic Z-moves"
	status.text = "Z-moves: volle 3D-vormen, eigen belichting en camerashots. Test ook ontwijken."
	print("Z_CHOREOGRAPHY_PREVIEW_READY moves=",move_picker.item_count)
	if "--smoke-z" in OS.get_cmdline_user_args():await _check_z()
func _check_z() -> void:
	create_timer(300).timeout.connect(func():printerr("Z_PREVIEW_TIMEOUT");quit(1))
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	var renderer = battle.animation_router.model_presenter
	toolbar.get_parent().hide()
	battle.animation_router.playback_speed = 1.8
	for i in move_picker.item_count:
		move_picker.select(i)
		var move := move_picker.get_item_text(i)
		_preview_move()
		while renderer.common_effects.is_empty() and move_busy:await process_frame
		assert(not renderer.common_effects.is_empty(),move)
		var effect: Node = renderer.common_effects[0]
		for phase in [["charge",effect.launch*.75],["main",lerpf(effect.launch,effect.impact,.65)],["compression",lerpf(effect.impact,effect.duration,.08)],["climax",lerpf(effect.impact,effect.duration,.35)],["dissipation",lerpf(effect.impact,effect.duration,.65)]]:
			while is_instance_valid(effect) and effect.elapsed<float(phase[1]):await process_frame
			assert(is_instance_valid(effect) and effect.cursor>0,move+str(phase[0]))
			battle.animation_router.playback_speed = 0
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join(Recipes.key(move)+"-"+str(phase[0])+".png"))
			battle.animation_router.playback_speed = 1.8
		while move_busy:await process_frame
		assert(renderer.common_effects.is_empty(),move)
		print("Z_RENDER_OK ",move)
	move_reverse.button_pressed = true
	if not OS.get_environment("POKEAETHER_Z_PREVIEW_MOVES").is_empty():
		print("Z_RENDER_SUBSET_OK moves=",move_picker.item_count)
		await _close_z_preview()
		return
	for move in ["Black Hole Eclipse","Corkscrew Crash","Oceanic Operetta","Supersonic Skystrike","Shattered Psyche"]:
		for i in move_picker.item_count:
			if move_picker.get_item_text(i)==move:move_picker.select(i)
		for outcome in [1,2]:
			move_outcome.select(outcome)
			_preview_move()
			while renderer.common_effects.is_empty():await process_frame
			var effect: Node = renderer.common_effects[0]
			while is_instance_valid(effect) and effect.elapsed<lerpf(effect.launch,effect.impact,.5):await process_frame
			assert(is_instance_valid(effect))
			battle.animation_router.playback_speed=0
			await process_frame
			await RenderingServer.frame_post_draw
			var before: float=effect.elapsed
			renderer.user_camera_yaw=.7
			await create_timer(.12).timeout
			assert(is_equal_approx(before,effect.elapsed))
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join(Recipes.key(move)+"-reverse-"+str(outcome)+".png"))
			renderer.user_camera_yaw=0
			battle.animation_router.playback_speed=1.8
			var recovery: float = lerpf(effect.impact,effect.duration,0.35)
			while is_instance_valid(effect) and effect.elapsed<recovery: await process_frame
			assert(is_instance_valid(effect) and not effect.impact_drawn,"No explosion on reversed miss/block")
			if effect.get("cinematic_climax") != null:
				assert(effect.cinematic_climax.start_index<0,"No hit finale on reversed miss/block")
			battle.animation_router.playback_speed=0
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join(Recipes.key(move)+"-reverse-"+str(outcome)+"-recovery.png"))
			battle.animation_router.playback_speed=1.8
			while move_busy:await process_frame
	print("Z_RENDER_SUITE_OK moves=35 phases=175 reverse_outcomes=10 recovery_outcomes=true pause_orbit=true")
	await _close_z_preview()

func _close_z_preview() -> void:
	battle.animation_router.cancel_render()
	host.release()
	host.queue_free()
	host = null
	await process_frame
	await process_frame
	quit()
