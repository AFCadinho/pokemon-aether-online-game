extends SceneTree

const SavedMapScenePathResolver := preload("res://scripts/world/saved_map_scene_path_resolver.gd")
const WORLD_SCRIPT_PATH := "res://scripts/world/world.gd"
const EXPECTED_MIGRATIONS := {
	"res://scenes/overworld/kanto/routes/kanto_route_2.tscn":
		"res://scenes/overworld/kanto/routes/route2/kanto_route_2.tscn",
	"res://scenes/overworld/kanto/routes/route_2_house.tscn":
		"res://scenes/overworld/kanto/routes/route2/route_2_house.tscn",
	"res://scenes/overworld/kanto/routes/kanto_route_25.tscn":
		"res://scenes/overworld/kanto/routes/route25/kanto_route_25.tscn",
	"res://scenes/overworld/kanto/routes/bills_house.tscn":
		"res://scenes/overworld/kanto/routes/route25/bills_house.tscn",
}

var failed := false


func _init() -> void:
	var world_source := FileAccess.get_file_as_string(WORLD_SCRIPT_PATH)
	_check(
		world_source.contains("var saved_scene_path := _resolve_saved_map_scene_path("),
		"World setup resolves legacy paths before loading a saved map"
	)
	_check(
		world_source.contains("var target_scene_path := _resolve_saved_map_scene_path("),
		"Authorized teleports resolve legacy paths before validating and loading a map"
	)
	_check(
		world_source.contains("return SavedMapScenePathResolver.resolve(scene_path)"),
		"World setup delegates saved paths to the migration resolver"
	)

	for legacy_path: String in EXPECTED_MIGRATIONS:
		var current_path: String = EXPECTED_MIGRATIONS[legacy_path]
		_check(
			SavedMapScenePathResolver.resolve(legacy_path) == current_path,
			"Saved map path migrates from %s" % legacy_path
		)
		_check(ResourceLoader.exists(current_path), "Migrated map scene exists at %s" % current_path)

	var unchanged_path := "res://scenes/overworld/kanto/routes/kanto_route_3.tscn"
	_check(
		SavedMapScenePathResolver.resolve("  %s  " % unchanged_path) == unchanged_path,
		"Current map paths remain unchanged"
	)
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
