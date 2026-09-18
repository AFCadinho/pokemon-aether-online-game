extends SceneTree
## Local composition probe; use a real display, never --headless.
## --script tools/sprite_factory/review_scene.gd -- /absolute/output-directory

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 1)
	root.size = Vector2i(1400, 800)
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(battle)
	battle.call("_apply_battle_environment", &"pvp_stadium")
	var player = battle.get_node("%PlayerSpriteBox")
	var enemy = battle.get_node("%EnemySpriteBox")
	for pair: Array in [["rattata", "dragonite"], ["dragonite", "rattata"]]:
		player.set_single_pokemon_species(pair[0], "back", false)
		enemy.set_single_pokemon_species(pair[1], "front", false)
		assert(player.single_sprite.sprite_frames.has_meta("rendered_asset"))
		assert(enemy.single_sprite.sprite_frames.has_meta("rendered_asset"))
		await create_timer(0.3).timeout
		player.single_sprite.pause()
		enemy.single_sprite.pause()
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		assert(image != null)
		image.save_png(args[0].path_join("battle-" + pair[0] + "-" + pair[1] + ".png"))
	battle.queue_free()
	await process_frame
	print("Generic rendered sprite battle compositions saved")
	quit()
