extends SceneTree
## Diagnose actual battle HUD geometry; no performance or admission approval.
const Candidate = preload("res://tests/phase5_candidate_stage.gd")
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Cache = preload("res://scripts/battle/battle_ui/model_resource_cache.gd")

func _init() -> void:
	_run.call_deferred()

func _rect(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _run() -> void:
	var directory := OS.get_environment("POKEAETHER_FORM_BUNDLE_WORK")
	var output := OS.get_environment("POKEAETHER_MEGA_HUD_OUTPUT")
	assert(directory.is_absolute_path() and output.is_absolute_path())
	assert(not DirAccess.dir_exists_absolute(output))
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("runtime-fixture.json")))
	Registry.DATA.data.models.merge(fixture.models, true)
	Registry.DATA.data.profiles.merge(fixture.profiles, true)
	var catalog := directory.path_join("on-demand-installed-catalog.json")
	var settings := root.get_node("SettingsManager")
	settings.battle_3d_catalog_path = catalog
	settings.battle_3d_camera_motion = false
	settings.battle_ui_layout = "immersive"
	settings.battle_presentation_mode = "3d"
	root.size = Vector2i(1280, 720)
	var report := {"runtime_approved": false, "complete": false, "scope": "Actual idle HUD geometry diagnostic; no performance qualification", "catalog_sha256": FileAccess.get_sha256(catalog), "entries": []}
	var selected := OS.get_environment("POKEAETHER_MEGA_RUNTIME_ONLY").split(",", false)
	for arena in ["classic", "stadium"]:
		settings.battle_3d_arena = arena
		var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
		var battle = load("res://scenes/battle/battle.tscn").instantiate()
		root.add_child(host)
		host.mount(battle)
		var old = battle.animation_router.model_presenter
		var index: int = old.get_index()
		old.free()
		var stage := Candidate.new()
		stage.use_runtime_registry = true
		stage.name = "ExperimentalBattle3D"
		battle.battle_stage.add_child(stage)
		battle.battle_stage.move_child(stage, index)
		stage.setup([battle.player_sprite_box, battle.enemy_sprite_box], [battle.player_battle_platform, battle.enemy_battle_platform])
		battle.animation_router.model_presenter = stage
		for key: String in fixture.models:
			if key.ends_with("@shiny") or (not selected.is_empty() and key not in selected):
				continue
			stage.set_combatant(0, key, false, true)
			stage.set_combatant(1, key, true, true)
			await stage.await_prepared(true, 30000)
			assert(stage.active and not stage.preparation_failed, stage.reason)
			battle.player_hud_panel.set_pokemon_data(key.capitalize(), 100, 100, 100)
			battle.enemy_hud_panel.set_pokemon_data(key.capitalize(), 100, 100, 100)
			await create_timer(.2).timeout
			var own: Rect2 = battle.player_hud_panel.get_global_rect()
			var enemy: Rect2 = battle.enemy_hud_panel.get_global_rect()
			var left: Rect2 = stage._visual_rect(0)
			var right: Rect2 = stage._visual_rect(1)
			var row := {"species": key, "arena": arena, "own_hud": _rect(own), "enemy_hud": _rect(enemy), "own_model": _rect(left), "enemy_model": _rect(right), "own_overlap": own.intersects(left), "enemy_overlap": enemy.intersects(right)}
			row["cross_overlap"] = own.intersects(right) or enemy.intersects(left)
			row["hud_overlap"] = own.intersects(enemy)
			if row.own_overlap or row.enemy_overlap or row.cross_overlap or row.hud_overlap or not selected.is_empty():
				row["image"] = key + "-" + arena + ".png"
				assert(root.get_texture().get_image().save_png(output.path_join(row.image)) == OK)
				print("MEGA_HUD_GEOMETRY ", JSON.stringify(row))
			report.entries.append(row)
		host.release()
		host.queue_free()
		for frame in 5:
			await process_frame
	Cache.clear()
	report.complete = true
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("MEGA_HUD_DIAGNOSTIC_OK observations=", report.entries.size())
	quit()
