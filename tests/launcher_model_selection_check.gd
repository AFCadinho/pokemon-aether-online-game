extends SceneTree
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings = root.get_node("SettingsManager")
	var old_path: String = settings.battle_3d_catalog_path
	var old_override: bool = settings._manual_model_catalog_this_session
	var old_mode: String = settings.battle_presentation_mode
	var previous := OS.get_environment("POKEAETHER_MODEL_CATALOG")
	var had_env := OS.has_environment("POKEAETHER_MODEL_CATALOG")
	var path := OS.get_environment("POKEAETHER_PHASE5_RUNTIME_REPORT")
	assert(path.is_absolute_path() and FileAccess.file_exists(path))
	settings.battle_3d_catalog_path = "user://manual-catalog.json"
	settings._manual_model_catalog_this_session = false
	OS.set_environment("POKEAETHER_MODEL_CATALOG", path)
	assert(settings.get_battle_3d_catalog_path() == path)
	assert(settings.battle_3d_catalog_path == "user://manual-catalog.json")
	assert(settings.battle_presentation_mode == old_mode, "Launcher must not force 3D mode")
	if DisplayServer.get_name() != "headless":
		var old_arena: String = settings.battle_3d_arena
		settings.battle_presentation_mode = "3d"
		settings.battle_3d_arena = "classic"
		var stage := Renderer.new()
		root.add_child(stage)
		stage.setup()
		stage.set_combatant(0, "pikachu", true)
		stage.set_combatant(1, "dragonite")
		await stage.await_prepared(true)
		assert(stage.active and stage.handles("p1") and stage.handles("p2"))
		assert(stage.loaded_path == path, "The presenter must use the launcher selection, not saved manual settings")
		stage.queue_free()
		for frame in 3: await process_frame
		Renderer.ModelCache.clear()
		settings.battle_presentation_mode = old_mode
		settings.battle_3d_arena = old_arena
		print("LAUNCHER_MODELS_REAL_BATTLE_OK shiny_pikachu/dragonite")
	# Choosing the same stored local path must still override this session's launcher selection.
	settings.set_battle_3d_catalog_path("user://manual-catalog.json")
	assert(settings.get_battle_3d_catalog_path() == "user://manual-catalog.json")
	settings._manual_model_catalog_this_session = false
	OS.set_environment("POKEAETHER_MODEL_CATALOG", "relative/invalid.json")
	assert(settings.get_battle_3d_catalog_path() == "user://manual-catalog.json")
	OS.set_environment("POKEAETHER_MODEL_CATALOG", "")
	assert(settings.get_battle_3d_catalog_path() == "user://manual-catalog.json")
	settings.battle_3d_catalog_path = old_path
	settings._manual_model_catalog_this_session = old_override
	settings.save_settings()
	if had_env: OS.set_environment("POKEAETHER_MODEL_CATALOG", previous)
	else: OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	print("LAUNCHER_MODEL_SELECTION_OK nonpersistent_override/manual_choice/disabled/web-safe_path")
	quit()
