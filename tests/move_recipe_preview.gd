extends "res://tests/battle_dialogue_preview.gd"
const RecipeBook = preload("res://scripts/battle/battle_ui/move_recipe_3d.gd")
func _start() -> void:
	left_species = "Dragonite"
	await super._start()
	root.title = "PokeAether — alle 194 3D-moves"
	status.text = "24 goedgekeurde moves + 170 nieuwe basisversies. Kies een move en test beide kanten, ontwijken en pauze."
	move_picker.select(FIRST_MOVES.size())
	print("ALL_MOVES_PREVIEW_READY moves=",move_picker.item_count)
	if "--smoke-recipes" in OS.get_cmdline_user_args(): await _check_recipes()

func _check_recipes() -> void:
	create_timer(480).timeout.connect(func():printerr("RECIPE_PREVIEW_TIMEOUT");quit(1))
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	var renderer = battle.animation_router.model_presenter
	battle.animation_router.playback_speed = 2.5
	for i in range(FIRST_MOVES.size(),move_picker.item_count):
		move_picker.select(i)
		var move := move_picker.get_item_text(i)
		var recipe := RecipeBook.get_recipe(move)
		if "--only-z" in OS.get_cmdline_user_args() and recipe.family!="z" and recipe.variant!="rain": continue
		_preview_move()
		while renderer.common_effects.is_empty() and move_busy: await process_frame
		assert(not renderer.common_effects.is_empty(),move)
		var effect: Node = renderer.common_effects[0]
		while is_instance_valid(effect) and effect.elapsed<effect.duration*.48: await process_frame
		assert(is_instance_valid(effect) and effect.cursor>0,move)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(RecipeBook.key(move)+".png"))
		while move_busy:await process_frame
		assert(renderer.common_effects.is_empty(),move)
		print("RECIPE_RENDER_OK ",move)
	# Representative contact, beam, powder, self and Z cases under camera orbit,
	# pause and miss/block. Samples must not advance while the action is paused.
	battle.animation_router.playback_speed = 1.5
	move_reverse.button_pressed = true
	for move in ["Close Combat","Hyper Beam","Sleep Powder","Swords Dance","Bloom Doom"]:
		for i in move_picker.item_count:
			if move_picker.get_item_text(i)==move:move_picker.select(i)
		for outcome in [1,2]:
			move_outcome.select(outcome)
			_preview_move()
			while renderer.common_effects.is_empty():await process_frame
			var effect: Node = renderer.common_effects[0]
			while is_instance_valid(effect) and effect.elapsed<effect.duration*.45:await process_frame
			assert(is_instance_valid(effect))
			battle.animation_router.playback_speed = 0
			await process_frame
			await RenderingServer.frame_post_draw
			var before: float = effect.elapsed
			renderer.user_camera_yaw = .7
			await create_timer(.12).timeout
			assert(is_equal_approx(effect.elapsed,before))
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join(RecipeBook.key(move)+"-reverse-"+str(outcome)+".png"))
			renderer.user_camera_yaw = 0
			battle.animation_router.playback_speed = 1.5
			while move_busy:await process_frame
	print("RECIPE_RENDER_SUITE_OK scope=", "z-and-rain" if "--only-z" in OS.get_cmdline_user_args() else "170-new-moves", " reversed_outcomes=10 pause_orbit=true")
	quit()
