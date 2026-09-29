extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := root.get_node("SettingsManager")
	var previous_mode: String = settings.battle_presentation_mode
	var previous_catalog: String = settings.battle_3d_catalog_path
	var report := OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	assert(not report.is_empty() and FileAccess.file_exists(report), "A prepared model report is required")
	settings.battle_presentation_mode = "2.5d"
	settings.battle_3d_catalog_path = report
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	root.add_child(host)
	host.mount(battle)
	await process_frame
	var stage = battle.battle_stage.get_node("ExperimentalBattle3D")
	stage.set_combatant(0, "Dragonite")
	stage.set_combatant(1, "Roaring Moon")
	for frame in 600:
		await process_frame
		if stage.active and stage.viewport != null:
			break
	assert(stage.active, stage.reason)
	assert(stage.viewport.transparent_bg, "2.5D models need a transparent 3D layer")
	assert(stage.arena_id == "classic", "2.5D must not mount a 3D arena")
	assert(battle.player_battle_platform.get_node("PlatformImage").self_modulate.a > 0.99)
	assert(battle.enemy_battle_platform.get_node("PlatformImage").self_modulate.a > 0.99)
	assert(battle.player_sprite_box.single_sprite.self_modulate.a < 0.01)
	settings.battle_presentation_mode = previous_mode
	settings.battle_3d_catalog_path = previous_catalog
	host.queue_free()
	await process_frame
	print("DESKTOP_PRESENTATION_ASSETS_OK")
	quit()
