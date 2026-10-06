extends "res://tests/battle_dialogue_preview.gd"
const ReviewedEffect = preload("res://scripts/battle/battle_ui/move_effect_3d.gd")
func _start() -> void:
	left_species = "Dragonite"
	await super._start()
	root.title = "PokeAether — 194 moves: soepel verloop en uitstraling"
	status.text = "Alle 194 moves opnieuw nagelopen. Kies een move, test de camera en vergelijk raak met ontwijken."
	print("PRESENTATION_REVIEW_READY moves=",move_picker.item_count)
	if "--smoke-review" in OS.get_cmdline_user_args(): await _review_all()
func _review_all() -> void:
	var watchdog := Timer.new()
	root.add_child(watchdog)
	watchdog.one_shot=true
	watchdog.timeout.connect(func():printerr("REVIEW_TIMEOUT");quit(1))
	watchdog.start(750)
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	var renderer = battle.animation_router.model_presenter
	var subset := OS.get_environment("POKEAETHER_REVIEW_MOVES").split(",",false)
	battle.animation_router.playback_speed = 1.5
	var count := 0
	for i in move_picker.item_count:
		move_picker.select(i)
		var move := move_picker.get_item_text(i)
		if not subset.is_empty() and ReviewedEffect.move_key(move) not in subset:continue
		_preview_move()
		while renderer.common_effects.is_empty() and move_busy:await process_frame
		assert(not renderer.common_effects.is_empty(),move)
		var effect: Node = renderer.common_effects[0]
		for phase in [["main",lerpf(effect.launch,effect.impact,.72)],["impact",lerpf(effect.impact,effect.duration,.1)]]:
			while is_instance_valid(effect) and effect.elapsed<float(phase[1]):await process_frame
			assert(is_instance_valid(effect),move)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join(ReviewedEffect.move_key(move)+"-"+str(phase[0])+".png"))
		while move_busy:await process_frame
		assert(renderer.common_effects.is_empty(),move)
		count+=1
		print("PRESENTATION_RENDER_OK ",move)
	print("PRESENTATION_RENDER_SUITE_OK moves=",count)
	watchdog.queue_free()
	host.release()
	host.queue_free()
	host=null
	await process_frame
	await process_frame
	# Let the awaiting preview coroutine return before shutting down the tree.
	quit.call_deferred()
