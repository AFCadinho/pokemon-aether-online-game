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
	var pokemon := Pokemon.new("cloyster", 100)
	overlay._set_pokemon_summary_sprite(pokemon)
	var preview = stage.get_node("SummaryModelPreview")
	assert(not animated.visible and not sprite.visible)
	for frame in 1200:
		await process_frame
		if preview.configured_player != null:
			break
	assert(preview.player != null and preview.clips.item_count >= 7)
	var original_actor = preview.actor
	overlay._set_pokemon_summary_sprite(pokemon)
	assert(preview.actor == original_actor, "card refresh must not restart model loading")
	for index in preview.clips.item_count:
		preview.clips.select(index)
		preview.play_selected()
		assert(preview.player.current_animation == str(preview.clips.get_item_metadata(index)))
		preview.toggle_pause()
		assert(not preview.player.is_playing())
		preview.toggle_pause()
		assert(preview.player.is_playing())
		preview.play_selected()
		assert(is_zero_approx(preview.player.current_animation_position))
	preview.clips.select(0)
	preview.play_selected()
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
	preview.play_selected()
	var capture := OS.get_environment("SUMMARY_CAPTURE")
	if not capture.is_empty():
		for frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(capture) == OK)
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
	print("SUMMARY_MODEL_PREVIEW_OK: clips, replay, pause, refresh, hidden, independent cards, fallback")
	quit()
