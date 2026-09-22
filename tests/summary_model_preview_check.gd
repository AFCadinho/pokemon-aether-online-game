extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings := root.get_node("SettingsManager")
	var old_mode: String = settings.battle_presentation_mode
	var old_catalog: String = settings.battle_3d_catalog_path
	var old_manual: bool = settings._manual_model_catalog_this_session
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_catalog_path = OS.get_environment("SUMMARY_MODEL_CATALOG")
	settings._manual_model_catalog_this_session = true
	assert(FileAccess.file_exists(settings.battle_3d_catalog_path))
	var overlay = load("res://scenes/interface/ui_overlay.tscn").instantiate()
	var host := Control.new()
	host.size = Vector2(1280,720)
	root.add_child(host)
	overlay.root_control = host
	overlay._setup_pokemon_summary_popup("model_preview_check")
	overlay.pokemon_summary_popup.show()
	var sprite: TextureRect = overlay.pokemon_summary_sprite
	var stage: Control = sprite.get_parent()
	var animated: AnimatedSprite2D = overlay.pokemon_summary_animated_sprite
	var pokemon := Pokemon.new("garchomp", 100)
	overlay._set_pokemon_summary_sprite(pokemon)
	var preview = stage.get_node("SummaryModelPreview")
	assert(not animated.visible and not sprite.visible)
	for frame in 1200:
		await process_frame
		if preview.configured_player != null:
			break
	var button := animated.get_meta("preview_animation_button") as MenuButton
	var menu := button.get_popup()
	assert(preview.player != null and menu.item_count >= 7)
	assert(button.visible and not button.disabled)
	assert(button.offset_top == -66.0, "reuse play menu above level")
	assert(preview.find_child("ModelAnimations", true, false) == null)
	assert(not preview.preview_floor.visible, "no artificial floor cutting through faint")
	var original_actor = preview.actor
	overlay._set_pokemon_summary_sprite(pokemon)
	assert(preview.actor == original_actor, "card refresh must not restart model loading")
	for index in menu.item_count:
		overlay._on_preview_animation_selected(menu.get_item_id(index), button, animated, null)
		assert(preview.player.current_animation == str(menu.get_item_metadata(index)))
		preview.toggle_pause()
		assert(not preview.player.is_playing())
		preview.toggle_pause()
		assert(preview.player.is_playing())
		preview.play_clip(preview.selected_clip)
		assert(is_zero_approx(preview.player.current_animation_position))
	preview.play_clip("damage")
	preview.player.seek(0.1, true)
	var damage_pose := _pose(preview.actor)
	preview.play_clip("faint_loop")
	preview.player.seek(0.3, true)
	preview.play_clip("damage")
	preview.player.seek(0.1, true)
	assert(_pose(preview.actor) == damage_pose, "faint must not contaminate damage pose")
	preview.play_clip("idle")
	var zoom := stage.find_child("PreviewZoomButton", true, false) as Button
	var distance: float = preview.camera.position.distance_to(preview.camera_target)
	zoom.button_pressed = true
	assert(is_equal_approx(preview.camera.position.distance_to(preview.camera_target), distance / 2))
	zoom.button_pressed = false
	stage.hide()
	await process_frame
	await process_frame
	assert(preview.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	stage.show()
	await process_frame
	await process_frame
	assert(preview.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	var second = load("res://scripts/ui/summary_model_preview.gd").new()
	root.add_child(second)
	assert(second.show_species("azumarill", false))
	for frame in 1200:
		await process_frame
		if second.configured_player != null:
			break
	assert(second.player != null and second.player != preview.player)
	preview.toggle_pause()
	assert(second.player.is_playing(), "each card owns its playback state")
	second.free()
	preview.play_clip("idle")
	var capture := OS.get_environment("SUMMARY_CAPTURE")
	if not capture.is_empty():
		for frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(capture) == OK)
		for action in ["faint_loop", "damage"]:
			preview.play_clip(action)
			preview.player.seek(0.1, true)
			preview.player.pause()
			for frame in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(capture + "." + action + ".png") == OK)
	pokemon.shiny = true
	overlay._set_pokemon_summary_sprite(pokemon)
	assert(not preview.visible and preview.actor == null)
	assert(animated.visible or sprite.visible, "unsupported shiny retains the sprite fallback")
	stage.free()
	host.free()
	overlay.free()
	settings.battle_presentation_mode = old_mode
	settings.battle_3d_catalog_path = old_catalog
	settings._manual_model_catalog_this_session = old_manual
	print("SUMMARY_MODEL_PREVIEW_OK: original menu, zoom, faint→damage baseline, replay, hidden, independent cards, fallback")
	quit()

func _pose(actor: Node3D) -> Array:
	var result: Array = []
	for node in actor.find_children("*", "Node3D", true, false):
		result.append(node.transform)
		if node is Skeleton3D:
			for bone in node.get_bone_count():
				result.append(node.get_bone_pose(bone))
	return result
