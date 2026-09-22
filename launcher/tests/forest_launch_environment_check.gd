extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var launcher = load("res://tests/model_launch_probe.gd").new()
	launcher.install_dir = ProjectSettings.globalize_path("user://forest-launch-install")
	var expected: String = launcher.install_dir.path_join("forest-runtime/forest.json")
	OS.set_environment("POKEAETHER_FOREST_MANIFEST", "parent-sentinel")
	assert(launcher._create_game_process("not-started") == 42)
	assert(launcher.observed_forest == expected)
	assert(OS.get_environment("POKEAETHER_FOREST_MANIFEST") == "parent-sentinel")
	OS.unset_environment("POKEAETHER_FOREST_MANIFEST")
	launcher.result = -1
	assert(launcher._create_game_process("not-started") == -1)
	assert(launcher.observed_forest == expected)
	assert(not OS.has_environment("POKEAETHER_FOREST_MANIFEST"))
	launcher.free()
	print("FOREST_LAUNCH_ENVIRONMENT_OK")
	quit()
