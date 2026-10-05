extends "res://tests/batch_four_moves_preview.gd"

func _start() -> void:
	await super._start()
	root.title = "PokeAether — grotere 3D-aanvallen"
	move_picker.select(FIRST_MOVES.find("Moonblast"))
	status.text = "Grotere move-effecten: bekijk Moonblast, Flash Cannon en de andere moves. Test ook ontwijken en de camera."
	if "--smoke-move-scale" in OS.get_cmdline_user_args():
		await _check_move_scale()
	print("MOVE_SCALE_PREVIEW_READY")

func _check_move_scale() -> void:
	create_timer(180).timeout.connect(func(): printerr("MOVE_SCALE_TIMEOUT"); quit(1))
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	var cases := [["Moonblast","Dragonite"],["Flash Cannon","Blastoise"],
		["Shadow Ball","Dragonite"],["Focus Blast","Dragonite"],
		["Ember","Charmander"],["Water Gun","Blastoise"],
		["Scratch","Pikachu"],["Ice Beam","Blastoise"],["Swift","Dragonite"],["Bubble","Squirtle"]]
	for item in cases:
		left_species = item[1]
		_sync_model_picker()
		await _load_preview()
		move_picker.select(FIRST_MOVES.find(item[0]))
		move_outcome.select(0)
		move_reverse.button_pressed = false
		_preview_move()
		var renderer = battle.animation_router.model_presenter
		while renderer.common_effects.is_empty(): await process_frame
		var effect: Node = renderer.common_effects[0]
		var scale_value: float = effect.presentation_scale
		var phases := ["flight","impact"]
		if item[0] in ["Moonblast","Flash Cannon"]: phases.push_front("charge")
		for phase in phases:
			var target_time: float = effect.launch*.85 if phase=="charge" else (lerpf(effect.launch,effect.impact,.6) if phase=="flight" else effect.impact+effect.duration*.055)
			while effect.elapsed<target_time: await process_frame
			battle.animation_router.playback_speed = 0
			await process_frame
			var count: int = effect.cursor
			var aim: Vector3 = effect.anchors.call().target
			for baseline in [true,false]:
				effect.presentation_scale = 1.0 if baseline else scale_value
				effect._process(0)
				assert(effect.cursor==count and effect.anchors.call().target==aim)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("%s-%s-%s.png" % [effect.key,phase,"before" if baseline else "after"]))
			battle.animation_router.playback_speed = 1
		while move_busy: await process_frame
		print("MOVE_SCALE_CASE_OK ",item[0])
	print("MOVE_SCALE_PREVIEW_OK cases=10 anchor_stability=true particle_count_unchanged=true")
	quit()
