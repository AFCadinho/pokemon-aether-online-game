extends "res://tests/source_moves_preview.gd"
## Mouth/cannon review using the actual downloaded models and live battle renderer.
const Markers = preload("res://tests/move_attachment_markers_3d.gd")
var show_attachments := true
func _start() -> void:
	left_species = "Blastoise"
	await super._start()
	root.title = "PokeAether — mond- en kanonpunten"
	var toggle := CheckButton.new()
	toggle.text = "Aanvalspunten tonen (paars)"
	toggle.button_pressed = true
	toggle.toggled.connect(func(value): show_attachments = value)
	toolbar.add_child(toggle)
	status.text = "Test Charmander / Squirtle: mond. Blastoise + Water Gun: twee kanonnen. Pauzeer en draai de camera."
	if "--smoke-attachments" in OS.get_cmdline_user_args(): await _check_attachments()
func _load_preview() -> void:
	await super._load_preview()
	if not is_instance_valid(battle): return
	var renderer = battle.animation_router.model_presenter
	if not renderer.active: return
	var markers := Markers.new()
	markers.stage = renderer
	markers.selected_move = func(): return FIRST_MOVES[move_picker.selected]
	markers.enabled = func(): return show_attachments
	renderer.world.add_child(markers)
func _check_attachments() -> void:
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	for species in ["Charmander", "Squirtle", "Blastoise"]:
		left_species = species
		await _load_preview()
		var renderer = battle.animation_router.model_presenter
		assert(renderer.active)
		move_picker.select(3 if species == "Charmander" else 4)
		var move: String = FIRST_MOVES[move_picker.selected]
		var initial: Dictionary = renderer._move_anchors("p1", "p2", move)
		assert(initial.attachment_part == ("cannons" if species == "Blastoise" else "mouth"))
		assert(initial.sources.size() == (2 if species == "Blastoise" else 1))
		_preview_move()
		while renderer.common_effects.is_empty(): await process_frame
		var effect: Node = renderer.common_effects[0]
		while effect.elapsed < lerpf(effect.launch, effect.impact, 0.8): await process_frame
		battle.animation_router.playback_speed = 0
		await process_frame
		await process_frame
		var frozen: Dictionary = renderer._move_anchors("p1", "p2", move)
		assert(not initial.sources[0].is_equal_approx(frozen.sources[0]), "Emitter must follow the attack pose")
		for angle in [0, 1]:
			if angle == 1: renderer.user_camera_yaw += 1.4
			for i in 4: await process_frame
			var current: Dictionary = renderer._move_anchors("p1", "p2", move)
			assert(current.sources[0].is_equal_approx(frozen.sources[0]), "Camera must not move the emitter")
			if not output.is_empty() and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("%s-%d.png" % [species.to_lower(), angle]))
		if not output.is_empty() and DisplayServer.get_name() != "headless":
			await _capture_closeup(renderer, species, output)
		battle.animation_router.cancel_render()
		battle.animation_router.playback_speed = 1
		while move_busy: await process_frame
	print("MOVE_ATTACHMENTS_PREVIEW_OK species=3 animated_bones=true pause_orbit=true")
	quit()

func _capture_closeup(renderer: Node, species: String, output: String) -> void:
	# Inspect the bone placement without muzzle foam obscuring the opening.
	renderer.set_process(false)
	for effect: Node3D in renderer.common_effects: effect.hide()
	for effect: Node3D in overrides: effect.hide()
	var actor: Node3D = renderer.actors[0]
	var bounds: Dictionary = renderer._effect_bounds(0)
	var points: Dictionary = renderer._move_anchors("p1", "p2", FIRST_MOVES[move_picker.selected])
	var midpoint := Vector3.ZERO
	for point: Vector3 in points.sources: midpoint += point
	var center: Vector3 = renderer.world.to_global(midpoint / points.sources.size())
	renderer.camera.global_position = center + (actor.global_basis.z.normalized() * 2.0 + actor.global_basis.x.normalized() * 0.8 + Vector3.UP * 0.25) * bounds.height
	renderer.camera.look_at(center)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(species.to_lower() + "-closeup.png"))
	renderer.set_process(true)
