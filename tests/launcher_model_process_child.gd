extends "res://tests/phase5_battle_stress_check.gd"
## Real child game process: autoloads + renderer/UI, no accounts or network battle.

func _run() -> void:
	var directory := OS.get_environment("POKEAETHER_E2E_OUTPUT")
	var phase := OS.get_environment("POKEAETHER_E2E_PHASE")
	if not OS.get_environment("POKEAETHER_E2E_GAME_BINARY").is_empty():
		assert(not OS.has_feature("editor"), "Export smoke test accidentally used the editor engine")
	var settings = root.get_node("SettingsManager")
	var selected := OS.get_environment("POKEAETHER_MODEL_CATALOG")
	assert(selected.is_absolute_path() and FileAccess.file_exists(selected))
	assert(settings.get_battle_3d_catalog_path() == selected)
	assert(settings.battle_3d_catalog_path.is_empty(), "Launcher selection was persisted into game Settings")
	assert(settings.battle_presentation_mode == "2.5d", "Launcher forced 3D mode")
	assert("--locale=nl" in OS.get_cmdline_user_args(), "Launcher locale argument lost")
	var settings_hash := FileAccess.get_sha256(settings.SETTINGS_PATH)
	if phase == "install":
		OS.set_environment("POKEAETHER_PHASE5_RUNTIME_REPORT", selected)
		OS.set_environment("POKEAETHER_PHASE5_PRODUCTION", "1")
		OS.set_environment("POKEAETHER_PHASE5_CAPTURE", "0")
		OS.set_environment("POKEAETHER_PHASE5_STRESS_OUTPUT", directory.path_join("battles"))
		await super._run()
		assert(evidence.get("complete", false) and evidence.rounds.size() == 3, "Battle matrix did not finish")
	else:
		# New process means a cold in-memory model cache; no manual catalog assignment.
		settings.battle_presentation_mode = "3d"
		settings.battle_3d_arena = "stadium"
		var presenter := Renderer.new()
		root.add_child(presenter)
		presenter.setup()
		await presenter.await_prepared(true)
		assert(presenter.active and presenter.actors == [null, null], "Empty Team Preview stalled")
		presenter.set_combatant(0, "pikachu", true)
		presenter.set_combatant(1, "snorlax")
		await presenter.await_prepared(true)
		assert(presenter.active and presenter.handles("p1") and presenter.handles("p2"))
		assert(presenter.loaded_path == selected)
		presenter.queue_free()
		for frame in 3: await process_frame
		Cache.clear()
	assert(FileAccess.get_sha256(settings.SETTINGS_PATH) == settings_hash, "Battle tests changed saved settings")
	var file := FileAccess.open(directory.path_join(phase + "-result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"complete": true, "pid": OS.get_process_id(), "launcher_pid": OS.get_environment("POKEAETHER_E2E_PARENT_PID").to_int(), "catalog_sha256": FileAccess.get_sha256(selected), "settings_unchanged": true, "standalone_runtime": not OS.has_feature("editor")}))
	file.close()
	print("MODEL_PROCESS_CHILD_OK phase=", phase)
	quit()

func _finish_run() -> void:
	pass # Parent stress harness returns; this child writes its process evidence first.
