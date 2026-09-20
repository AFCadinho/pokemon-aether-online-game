extends "res://tools/sprite_factory/cave_battle_review.gd"
## Original stadium geometry. No reference image is projected as a backdrop.

func _init() -> void:
	angle = 0.16
	distance = 17.0
	elevation = 0.14
	target = Vector3(0, 3.1, 0)
	super._init()

func _camera() -> void:
	distance = clampf(distance, 8.0, 18.0)
	stage.camera.position = target + Vector3(sin(angle)*cos(elevation), sin(elevation), cos(angle)*cos(elevation))*distance
	stage.camera.look_at(target)

func _credit_text() -> String:
	return "PokeAether · 3D stadium study\nOriginal arena · neutral Pokémon rig · isolated PvP visual preview"

func _smoke() -> void:
	for frame in 30:
		await process_frame
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	DirAccess.make_dir_recursive_absolute(output)
	for player: AnimationPlayer in players:
		player.pause()
	ui.hide()
	await RenderingServer.frame_post_draw
	var before := root.get_texture().get_image()
	before.save_png(output.path_join("ambience-before.png"))
	for frame in 120:
		await process_frame
	await RenderingServer.frame_post_draw
	var after := root.get_texture().get_image()
	after.save_png(output.path_join("ambience-after.png"))
	assert(before.get_data() != after.get_data(), "Stadium ambience must animate independently of actors")
	print("STADIUM_AMBIENCE_OK fixed_camera_paused_actors")
	for player: AnimationPlayer in players:
		player.play()
	await super._smoke()

func _make_forest() -> Node3D:
	if response != null and response.world != null:
		for child in response.world.get_children():
			if child is WorldEnvironment:
				child.environment = child.environment.duplicate()
				child.environment.ssr_enabled = false
				child.environment.glow_enabled = false
	return load("res://scripts/battle/arenas/stadium_arena.gd").new(stage.world).build()
