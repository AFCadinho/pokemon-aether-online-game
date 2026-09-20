extends Node

class HostWorld extends "res://scripts/world/world.gd":
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass
	func _exit_tree() -> void:
		pass

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings := get_node("/root/SettingsManager")
	var old_mode: String = settings.battle_presentation_mode
	var old_path: String = settings.battle_3d_catalog_path
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_catalog_path = OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	# Use the real World's mount/clear paths, without startup network requests.
	var world: Variant = Node2D.new()
	add_child(world)
	world.set_script(HostWorld)
	var layer := CanvasLayer.new()
	world.add_child(layer)
	var container := Control.new()
	layer.add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world.battle_ui_host = container
	var overlay := CanvasLayer.new()
	overlay.name = "UIOverlay"
	world.add_child(overlay)
	overlay.set_process_input(true)
	overlay.set_process_unhandled_input(false)
	var player := Node2D.new()
	world.add_child(player)
	var camera := Camera2D.new()
	player.add_child(camera)
	for round_index in 3:
		assert(world._mount_battle_ui())
		var host = world.battle_screen_host
		var battle = world.battle_instance
		var host_ref: WeakRef = weakref(host)
		var battle_ref: WeakRef = weakref(battle)
		assert(not overlay.visible and not overlay.is_processing_input())
		assert(not get_tree().paused and player.is_inside_tree() and camera.enabled)
		assert(battle.has_meta("dedicated_battle_screen"))
		assert(not battle.battle_drag_handle.visible)
		host.set_anchors_preset(Control.PRESET_TOP_LEFT)
		for screen_size in [Vector2(1280, 720), Vector2(2560, 1080), Vector2(1920, 1080)]:
			host.size = screen_size
			host._fit_battle()
			assert(battle.position == Vector2.ZERO)
			assert((battle.size * battle.scale).is_equal_approx(screen_size))
			assert(is_equal_approx(battle.scale.x, battle.scale.y))
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		host._fit_battle()
		world._prepare_battle_instance_reveal()
		assert(battle.modulate.a == 1.0)
		if round_index == 0:
			var presenter = battle.battle_stage.get_node("ExperimentalBattle3D")
			presenter.set_combatant(0, "Dragonite")
			presenter.set_combatant(1, "Roaring Moon")
			await presenter.await_prepared()
			await get_tree().create_timer(0.3).timeout
			assert(not host.get_node("Cover").visible)
			var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
			if not output.is_empty() and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(output + "/fullscreen-3d.png")
		elif round_index == 1:
			await get_tree().process_frame # Cancel during deferred loading/reveal.
		# A server-driven relocation is not overwritten on return.
		player.position = Vector2(321, 456)
		world._clear_battle_ui_instance()
		world._clear_battle_ui_instance() # Idempotent abort/end.
		assert(overlay.visible and overlay.is_processing_input())
		assert(not overlay.is_processing_unhandled_input())
		assert(player.position == Vector2(321, 456) and camera.enabled)
		await get_tree().process_frame
		await get_tree().process_frame
		assert(host_ref.get_ref() == null and battle_ref.get_ref() == null)
	# Hidden UI stays hidden, including a world teardown/disconnect.
	overlay.hide()
	assert(world._mount_battle_ui())
	# Keep the observer alive so _exit_tree restoration can be asserted.
	overlay.reparent(self)
	world.free()
	await get_tree().process_frame
	assert(not overlay.visible and overlay.is_processing_input())
	overlay.free()
	settings.battle_presentation_mode = old_mode
	settings.battle_3d_catalog_path = old_path
	print("battle_screen_host_check: PASS")
	get_tree().quit()
