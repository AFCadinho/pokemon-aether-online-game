extends SceneTree

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures := 0
	var settings := root.get_node("SettingsManager")
	var install_dir := "user://forest_delivery_%d" % Time.get_ticks_usec()
	var absolute := ProjectSettings.globalize_path(install_dir)
	DirAccess.make_dir_recursive_absolute(absolute.path_join("forest-runtime"))
	var manifest_path := absolute.path_join("forest-runtime/forest.json")
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	file.store_string('{"schema":1,"pack":"forest.pck"}')
	file.close()
	var local_game_user_data := absolute.path_join("app_userdata/PokeAether")
	var installed_forest_dir := absolute.path_join("app_userdata/PokeAether Launcher/game/forest-runtime")
	DirAccess.make_dir_recursive_absolute(installed_forest_dir)
	var installed_manifest := installed_forest_dir.path_join("forest.json")
	FileAccess.open(installed_manifest, FileAccess.WRITE).store_string('{"schema":1,"pack":"forest.pck"}')
	FileAccess.open(installed_forest_dir.path_join("forest.pck"), FileAccess.WRITE).store_buffer(PackedByteArray([1]))
	if settings._editor_installed_forest_manifest(local_game_user_data, true) != installed_manifest: failures += 1
	if not settings._editor_installed_forest_manifest(local_game_user_data, false).is_empty(): failures += 1

	var previous_setting: String = settings.battle_3d_forest_manifest
	var had_env := OS.has_environment("POKEAETHER_FOREST_MANIFEST")
	var previous_env := OS.get_environment("POKEAETHER_FOREST_MANIFEST")
	settings.battle_3d_forest_manifest = ""
	OS.set_environment("POKEAETHER_FOREST_MANIFEST", manifest_path)
	if settings.get_battle_3d_forest_manifest() != manifest_path: failures += 1
	var custom_manifest_path := absolute.path_join("custom-forest.json")
	var custom_file := FileAccess.open(custom_manifest_path, FileAccess.WRITE)
	custom_file.store_string('{"schema":1,"pack":"custom.pck"}')
	custom_file.close()
	settings.battle_3d_forest_manifest = custom_manifest_path
	if settings.get_battle_3d_forest_manifest() != custom_manifest_path: failures += 1
	settings.battle_3d_forest_manifest = "user://explicit-forest-that-was-moved.json"
	if settings.get_battle_3d_forest_manifest() != manifest_path: failures += 1
	settings.battle_3d_forest_manifest = previous_setting
	if had_env: OS.set_environment("POKEAETHER_FOREST_MANIFEST", previous_env)
	else: OS.unset_environment("POKEAETHER_FOREST_MANIFEST")

	var workflow := FileAccess.get_file_as_string("res://.github/workflows/deploy-desktop-r2.yml")
	if not workflow.contains('register_external_pack "battle-environment-forest"'): failures += 1
	if workflow.contains('register_external_pack "battle-environment-forest" "${FOREST_ASSET_VERSION}" "${FOREST_ASSET_SIZE}" "${FOREST_ASSET_SHA256}" "true"'): failures += 1
	if workflow.count('"battle-environment-forest",') != 1: failures += 1
	print("FOREST_RUNTIME_DELIVERY_%s" % ("OK" if failures == 0 else "FAIL"))
	quit(failures)
