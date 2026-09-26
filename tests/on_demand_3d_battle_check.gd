extends SceneTree

const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var catalog := OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	assert(catalog.is_absolute_path() and FileAccess.file_exists(catalog))
	OS.set_environment("POKEAETHER_MODEL_CATALOG", catalog)
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_arena = "stadium"
	var stage := Renderer.new()
	root.add_child(stage)
	stage.setup()
	stage.set_combatant(0, "Hydreigon")
	stage.set_combatant(1, "Volcarona")
	await stage.await_prepared(true, 30000)
	assert(not stage.preparation_failed and stage.handles("p1") and stage.handles("p2"))
	assert(settings.get_battle_3d_catalog_path() != catalog)
	assert(FileAccess.file_exists(settings.get_battle_3d_catalog_path()))
	OS.set_environment("POKEAETHER_MODEL_CATALOG", catalog)
	var preview := preload("res://scripts/ui/pokedex_model_preview.gd").new()
	root.add_child(preview)
	assert(preview.show_species("Hydreigon", false), "Cached downloads must appear in the Pokédex on the next launch")
	print("ON_DEMAND_3D_BATTLE_OK initial_pair_loaded_before_reveal=true pokedex_cache=true")
	quit()
