extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await _check_fullscreen_fade(root.get_node("SettingsManager"))
	await _check_world_handoff(root.get_node("SettingsManager"))
	if not failed:
		print("fullscreen_battle_fade_check: PASS")
	quit(1 if failed else 0)

func _check_fullscreen_fade(settings: Node) -> void:
	var previous_layout: String = settings.battle_ui_layout
	settings.battle_ui_layout = "immersive"
	settings.battle_presentation_mode = "2d"
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.12, 0.45, 0.22))
	var snapshot := ImageTexture.create_from_image(image)
	var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	root.add_child(host)
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	host.mount(battle, null, WildEncounterTransition.STYLE_FULLSCREEN_FADE, false, snapshot)
	await create_timer(0.1).timeout
	_check(host.preparation_ready and host.reveal_tween == null, "Scene readiness alone must not reveal unprepared battle data")
	_check(host.get_node("Cover").color.a == 0.0, "Fullscreen loading never uses a black cover")
	_check(host.outgoing_snapshot.texture == snapshot, "Loading preserves the outgoing world image")
	host.set_anchors_preset(Control.PRESET_TOP_LEFT)
	for screen_size in [Vector2(960, 540), Vector2(1920, 1080), Vector2(2560, 1080)]:
		host.size = screen_size
		host._fit_battle()
		for progress in [0.0, 0.25, 0.5, 0.75, 1.0]:
			host.fade_progress = progress
			var incoming := host.content as Control
			var outgoing: TextureRect = host.outgoing_snapshot
			_check(incoming.position == Vector2.ZERO and outgoing.position == Vector2.ZERO, "Fade keeps both screens stationary")
			_check(outgoing.size.is_equal_approx(screen_size), "World image covers the complete viewport")
			_check(is_equal_approx(outgoing.modulate.a, 1.0) and is_equal_approx(host.content.modulate.a, progress), "The complete battle fades above the unchanged world image")
			_check(host.backdrop.position == Vector2.ZERO and host.backdrop.color.a == 1.0, "Battle layers retain their full opacity inside the shared entry layer")
	# Capture the halfway blend on a rendered run.
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host._fit_battle()
	host.fade_progress = 0.5
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	if not output.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output + "/fullscreen-fade-halfway.png")
	# A solid incoming probe makes rendered alpha observable independently of HUD art.
	var rendered := DisplayServer.get_name() != "headless"
	if rendered:
		var probe := ColorRect.new()
		probe.color = Color.BLUE
		probe.z_index = 1000
		host.content.add_child(probe)
		probe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.fade_progress = 0.0
	host.request_reveal()
	# Simulate a scene/texture upload stall at the first reveal frame.
	OS.delay_msec(250)
	await process_frame
	await process_frame
	_check(host.fade_progress < 0.5, "A slow loading frame cannot skip the visible fade")
	var blend_frames := 0
	var rendered_blues: Array[float] = []
	while host.get_node("Cover").visible:
		await process_frame
		blend_frames += 1
		if rendered:
			await RenderingServer.frame_post_draw
			var frame := root.get_texture().get_image()
			var pixel := frame.get_pixel(frame.get_width() / 2, frame.get_height() / 2)
			if pixel.b > 0.25 and pixel.b < 0.95:
				if rendered_blues.is_empty() or absf(pixel.b - rendered_blues.back()) > 0.01:
					rendered_blues.append(pixel.b)
	_check(blend_frames >= 8, "Fade renders multiple intermediate frames after a stall")
	if rendered:
		_check(rendered_blues.size() >= 4, "Rendered pixels must show at least four intermediate fade levels after a loading stall")
		print("FULLSCREEN_FADE_RENDERED_LEVELS=", rendered_blues.size())
	await host.wait_until_revealed()
	_check(host.fade_progress == 1.0 and host.outgoing_snapshot.texture == null, "Completed fade releases the outgoing image")
	_check(not battle.has_meta("battle_screen_preparing"), "Battle input readiness is released after the fade")
	host.release()
	host.queue_free()
	await process_frame
	# Cancel during the fade, as a disconnect/world teardown would.
	host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	root.add_child(host)
	battle = load("res://scenes/battle/battle.tscn").instantiate()
	host.mount(battle, null, WildEncounterTransition.STYLE_FULLSCREEN_FADE, false, snapshot)
	host.request_reveal()
	await process_frame
	host.release()
	await host.wait_until_revealed()
	_check(host.outgoing_snapshot.texture == null, "Interrupted fades release their snapshot")
	host.queue_free()
	await process_frame
	settings.battle_ui_layout = previous_layout
	print("FULLSCREEN_FADE_COVERAGE_AND_CANCELLATION_OK")


func _check_world_handoff(settings: Node) -> void:
	var previous_layout: String = settings.battle_ui_layout
	settings.battle_ui_layout = "immersive"
	settings.battle_presentation_mode = "2d"
	var world: Variant = Node2D.new()
	root.add_child(world)
	world.set_script(load("res://scripts/world/world.gd"))
	world.set_process(false)
	world.battle_ui_host = Control.new()
	world.add_child(world.battle_ui_host)
	world.battle_ui_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var transition := WildEncounterTransition.new()
	root.add_child(transition)
	world.wild_encounter_transition = transition
	var overlay := CanvasLayer.new()
	overlay.name = "UIOverlay"
	world.add_child(overlay)
	overlay.set_process_input(true)
	world.active_battle_kind = "wild"
	world._begin_wild_encounter_transition()
	var snapshot: Texture2D = transition.overworld_snapshot
	_check(world._mount_battle_ui())
	var host = world.battle_screen_host
	_check(not host.reveal_requested, "Fullscreen handoff waits for the entry-ready callback")
	if snapshot != null:
		_check(host.outgoing_snapshot.texture == snapshot, "World and battle share one outgoing snapshot")
	_check(not overlay.visible and not overlay.is_processing_input(), "World UI stays locked during the handoff")
	await world._reveal_prepared_wild_battle()
	_check(not transition.visible and not host.get_node("Cover").visible, "Entry callback completes both transition layers")
	_check(transition.overworld_snapshot == null and host.outgoing_snapshot.texture == null, "Both owners release the snapshot after entry")
	world._clear_battle_ui_instance()
	_check(overlay.visible and overlay.is_processing_input(), "Battle teardown restores the world UI")
	# An ended encounter must not make a replay/resume wait for an entry callback.
	_check(world._mount_battle_ui())
	_check(world.battle_screen_host.reveal_requested, "Inactive fade styles cannot block later mounts")
	world.battle_screen_host.outgoing_snapshot.texture = null
	world.battle_screen_host.fade_progress = 0.5
	_check(is_equal_approx(world.battle_screen_host.content.modulate.a, 0.5), "Missing snapshots still fade the battle over the live world")
	world._clear_battle_ui_instance()
	world.set_script(null)
	world.queue_free()
	transition.queue_free()
	await process_frame
	settings.battle_ui_layout = previous_layout
	print("FULLSCREEN_FADE_WORLD_HANDOFF_OK")


func _check(value: bool, label := "Fullscreen fade contract") -> void:
	if not value:
		failed = true
		push_error(label)
