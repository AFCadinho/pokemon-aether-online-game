extends "res://tests/battle_dialogue_preview.gd"
const Staging = preload("res://data/battle_move_staging_3d.json")
const Recipes = preload("res://scripts/battle/battle_ui/move_recipe_3d.gd")
const CHECK_MOVES := ["Fire Punch","Ice Punch","Thunder Punch","Close Combat","Hyper Beam","Scald","Psychic","Will-O-Wisp","Swords Dance","Stealth Rock","Electric Terrain","Hydro Vortex","Gigavolt Havoc","Black Hole Eclipse","Extreme Evoboost"]
func _start() -> void:
	left_species="Dragonite"
	await super._start()
	move_picker.clear()
	for key: String in Staging.data.moves:move_picker.add_item(str(Recipes.get_recipe(key).name))
	root.title="PokeAether — 158 overige moves — visuele review"
	status.text="124 gewone moves en 34 Z-moves. Kies een move; test ook ontwijken, de andere kant en de camera."
	print("COMPLETED_STAGING_PREVIEW_READY moves=",move_picker.item_count)
	if "--smoke-staging" in OS.get_cmdline_user_args():await _check_staging()
func _check_staging() -> void:
	var watchdog := Timer.new()
	root.add_child(watchdog)
	watchdog.one_shot=true
	watchdog.timeout.connect(func():printerr("STAGING_PREVIEW_TIMEOUT");quit(1))
	watchdog.start(300)
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	var renderer = battle.animation_router.model_presenter
	var subset := OS.get_environment("POKEAETHER_REVIEW_MOVES").split(",",false)
	var count := 0
	for reverse in [false,true]:
		move_reverse.button_pressed=reverse
		for i in move_picker.item_count:
			var move := move_picker.get_item_text(i)
			if move not in CHECK_MOVES or not subset.is_empty() and Recipes.key(move) not in subset:continue
			move_picker.select(i)
			move_outcome.select(1 if reverse else 0)
			battle.animation_router.playback_speed=1.5
			_preview_move()
			while renderer.common_effects.is_empty() and move_busy:await process_frame
			assert(not renderer.common_effects.is_empty(),move)
			var effect: Node=renderer.common_effects[0]
			for phase in [["charge",effect.launch*.9],["main",lerpf(effect.launch,effect.impact,.7)],["impact",lerpf(effect.impact,effect.duration,.2)]]:
				while is_instance_valid(effect) and effect.elapsed<float(phase[1]):await process_frame
				assert(is_instance_valid(effect),move)
				if reverse:
					battle.animation_router.playback_speed=0
					renderer.user_camera_yaw=.8
					await process_frame
					var before: float=effect.elapsed
					await create_timer(.12).timeout
					assert(is_equal_approx(before,effect.elapsed),move)
					assert(not effect.impact_drawn,move+" missed attack must not show a confirmed hit")
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join(Recipes.key(move)+("-reverse-" if reverse else "-front-")+str(phase[0])+".png"))
				battle.animation_router.playback_speed=1.5
			while move_busy:await process_frame
			renderer.user_camera_yaw=0
			assert(renderer.common_effects.is_empty() and battle.animation_router.active_audio_nodes.is_empty(),move)
			count+=1
			print("STAGING_RENDER_OK ",move," reverse=",reverse)
	watchdog.queue_free()
	host.release();host.queue_free();host=null
	await process_frame
	await process_frame
	print("STAGING_RENDER_SUITE_OK moves=",count/2," phases=",count*3," orbit_pause_miss=true")
	# Let the awaiting preview coroutine return before shutting down the tree.
	quit.call_deferred()
