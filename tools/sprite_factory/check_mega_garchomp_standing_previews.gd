extends SceneTree
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size()==2, "CATALOG OUTPUT_PNG")
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode="3d"
	settings.battle_3d_catalog_path=ProjectSettings.globalize_path(args[0])
	settings._manual_model_catalog_this_session=true
	root.size=Vector2i(1200,750)
	var previews := []
	for i in 4:
		var path := "res://scripts/ui/pokedex_model_preview.gd" if i<2 else "res://scripts/ui/summary_model_preview.gd"
		var preview: Control = load(path).new()
		root.add_child(preview)
		preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		preview.position=Vector2((i%2)*600,(i/2)*375)
		preview.size=Vector2(600,375)
		assert(preview.show_species("Garchomp-Mega",i%2==1))
		previews.append(preview)
	for frame in 1200:
		await process_frame
		var ready := true
		for preview in previews: ready=ready and preview.player!=null
		if ready: break
	for preview in previews:
		assert(preview.player!=null)
		assert(preview.player.current_animation=="idle")
		assert(is_equal_approx(preview.player.get_animation("idle").length,2.0))
		preview.player.pause()
		preview.player.seek(0.5,true)
	for frame in 3: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(args[1])
	print("MEGA_GARCHOMP_PREVIEWS_OK normal_shiny=true pokedex_summary=true")
	for preview in previews: preview.free()
	quit()
