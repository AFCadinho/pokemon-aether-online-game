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
			assert(await _check_party_clicks(battle))
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

func _check_party_clicks(battle: Control) -> bool:
	var grid: PartyGrid = battle.player_party_grid
	# Observe actual GUI selection without submitting a network choice.
	grid.party_selected.disconnect(battle._on_party_grid_party_selected)
	for connection in grid.pokemon_hovered.get_connections():
		grid.pokemon_hovered.disconnect(connection.callable)
	for connection in grid.pokemon_unhovered.get_connections():
		grid.pokemon_unhovered.disconnect(connection.callable)
	var selected: Array[int] = []
	grid.party_selected.connect(func(slot: int): selected.append(slot))
	var reserve := {"species": "Roaring Moon", "hp": 100, "max_hp": 100, "active": false}
	grid.set_party([
		{"species": "Dragonite", "hp": 100, "max_hp": 100, "active": true},
		reserve,
		{"species": "Dragonite", "hp": 0, "max_hp": 100, "fainted": true},
	])
	# Isolate the real rail in the scaled screen without needing a server request
	# to lay out the rest of the action dock.
	grid.reparent(battle)
	grid.set_party(grid.current_party_data)
	grid.position = Vector2(200, 500)
	grid.show()
	grid.move_to_front()
	battle.battle_input_locked = false
	battle._set_battle_actions_ready(true)
	assert(grid.is_slot_selectable(2))
	assert(not grid.is_slot_selectable(1) and not grid.is_slot_selectable(3))
	var card: PartyHoverCard = battle.party_hover_card
	card.move_to_front()
	card.show_for_pokemon(reserve)
	# Cover is normally released after prepared loading; this unit tests input.
	battle.get_parent().get_parent().get_node("Cover").hide()
	await get_tree().process_frame
	await get_tree().process_frame
	var button := grid.get_child(1) as Button
	var original_scale := battle.scale
	for factor in [0.75, 1.0, 1.5]:
		battle.scale = Vector2.ONE * factor
		var scaled_anchor := button.get_global_rect()
		card.position_near_rect(scaled_anchor, get_viewport().get_visible_rect().size)
		assert(not card.get_global_rect().intersects(scaled_anchor), "Hover overlaps at scale %s" % factor)
		assert(get_viewport().get_visible_rect().encloses(card.get_global_rect()))
	battle.scale = original_scale
	var anchor := button.get_global_rect()
	assert(get_viewport().get_visible_rect().has_point(anchor.get_center()))
	card.position_near_rect(anchor, get_viewport().get_visible_rect().size)
	assert(not card.get_global_rect().intersects(anchor), "Scaled hover overlaps its team button")
	# Even accidental overlap must never swallow the switch click.
	card.global_position = anchor.position - Vector2(20, 20)
	_click_at(anchor.get_center())
	assert(selected == [2], "Hover swallowed a real reserve-button click")
	battle.battle_input_locked = true
	battle._sync_party_rail_interaction()
	_click_at(anchor.get_center())
	assert(selected == [2], "Locked battle accepted a switch")
	battle.battle_input_locked = false
	battle._set_battle_actions_ready(false)
	_click_at(anchor.get_center())
	assert(selected == [2], "Closed turn accepted a switch")
	battle._set_battle_actions_ready(true)
	_click_at(anchor.get_center())
	assert(selected == [2, 2], "Reopened turn did not restore switching")
	card.hide_card()
	print("PARTY_HOVER_CLICK_AND_LOCKS_OK")
	return true

func _click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		get_viewport().push_input(click, true)
