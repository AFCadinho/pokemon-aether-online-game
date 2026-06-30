extends SceneTree

const PokeAetherTmxImporter := preload("res://addons/pokeaether_tiled_importer/importer/pokeaether_tmx_importer.gd")

const SUCCESS_FIXTURE := "res://tests/fixtures/tiled/pokeaether_phase2a_minimal.tmx"
const OFFICIAL_TEMPLATE_FIXTURE := "res://docs/tiled/pokeaether_template/pokeaether_map_template.tmx"
const OFFICIAL_EXAMPLE_FIXTURE := "res://docs/tiled/pokeaether_template/pokeaether_minimal_example.tmx"
const DUPLICATE_SPAWN_FIXTURE := "res://tests/fixtures/tiled/pokeaether_phase2a_duplicate_spawn.tmx"
const MISSING_COLLISION_FIXTURE := "res://tests/fixtures/tiled/pokeaether_phase2b_missing_collision.tmx"
const GENERATED_RUNTIME := "res://generated/maps/phase2a_test_map/phase2a_test_map.runtime.tscn"
const GENERATED_MAP_DATA := "res://generated/maps/phase2a_test_map/phase2a_test_map.map_data.tres"
const GENERATED_TILESET := "res://generated/maps/phase2a_test_map/phase2a_test_map.tileset.tres"

var failed := false


func _init() -> void:
	_cleanup_generated_outputs()

	var importer := PokeAetherTmxImporter.new()
	_check_success_import(importer)
	_check_official_template_import(importer)
	_check_official_example_import(importer)
	_check_duplicate_spawn_failure(importer)
	_check_missing_collision_failure(importer)

	_cleanup_generated_outputs()
	quit(1 if failed else 0)


func _check_success_import(importer: RefCounted) -> void:
	var result: Dictionary = importer.import_tmx(SUCCESS_FIXTURE)
	_check_true(bool(result.get("success", false)), "success fixture import should pass: %s" % str(result.get("error", "")))

	_check_file_exists(GENERATED_RUNTIME, "runtime scene exists")
	_check_file_exists(GENERATED_MAP_DATA, "map data resource exists")
	_check_file_exists(GENERATED_TILESET, "tileset resource exists")

	_check_equal(str(result.get("runtime_scene_path", "")), GENERATED_RUNTIME, "runtime scene path")
	_check_equal(str(result.get("map_data_path", "")), GENERATED_MAP_DATA, "map data path")
	_check_equal(str(result.get("tileset_path", "")), GENERATED_TILESET, "tileset path")

	var map_data := load(GENERATED_MAP_DATA) as Resource
	_check_true(map_data != null, "generated map_data.tres loads")
	if map_data != null:
		_check_equal(str(map_data.get("map_id")), "phase2a_test_map", "map data map_id")
		_check_equal((map_data.get("spawns") as Array).size(), 1, "spawn data count")
		_check_equal((map_data.get("warps") as Array).size(), 1, "warp data count")
		_check_equal((map_data.get("npcs") as Array).size(), 1, "npc data count")
		_check_equal((map_data.get("items") as Array).size(), 1, "item data count")
		_check_equal((map_data.get("encounter_regions") as Array).size(), 1, "encounter region data count")
		_check_equal((map_data.get("triggers") as Array).size(), 1, "trigger data count")

	var runtime_scene := load(GENERATED_RUNTIME) as PackedScene
	_check_true(runtime_scene != null, "generated runtime.tscn loads")
	if runtime_scene == null:
		return

	var runtime_root := runtime_scene.instantiate()
	_check_true(runtime_root != null, "generated runtime scene instantiates")
	if runtime_root != null:
		for node_path in [
			"Collision",
			"TallGrass",
			"LedgeDown",
			"LedgeUp",
			"LedgeLeft",
			"LedgeRight",
			"RouteGates",
			"Spawns/Start",
			"Exits/ToOther",
			"Entities/NPCs/guide",
			"Entities/Players",
			"Items/potion_1",
			"EncounterRegions/grass_a",
			"Triggers/intro",
		]:
			_check_true(runtime_root.get_node_or_null(node_path) != null, "runtime has node %s" % node_path)
		runtime_root.free()


func _check_official_template_import(importer: RefCounted) -> void:
	var map_id := "pokeaether_template_map"
	var result: Dictionary = importer.import_tmx(OFFICIAL_TEMPLATE_FIXTURE)
	_check_true(bool(result.get("success", false)), "official template import should pass: %s" % str(result.get("error", "")))
	_check_generated_outputs_for_map(result, map_id, "official template")

	var map_data := load(_generated_map_data(map_id)) as Resource
	_check_true(map_data != null, "official template map_data.tres loads")
	if map_data != null:
		_check_equal(str(map_data.get("map_id")), map_id, "official template map_id")
		_check_equal((map_data.get("spawns") as Array).size(), 0, "official template spawn data count")
		_check_equal((map_data.get("warps") as Array).size(), 0, "official template warp data count")
		_check_equal((map_data.get("npcs") as Array).size(), 0, "official template npc data count")
		_check_equal((map_data.get("items") as Array).size(), 0, "official template item data count")
		_check_equal((map_data.get("encounter_regions") as Array).size(), 0, "official template encounter region data count")
		_check_equal((map_data.get("triggers") as Array).size(), 0, "official template trigger data count")

	_check_runtime_nodes(map_id, [
		"Ground",
		"GroundDetail",
		"Path",
		"Water",
		"Objects",
		"Overhead",
		"Collision",
		"TallGrass",
		"LedgeDown",
		"LedgeUp",
		"LedgeLeft",
		"LedgeRight",
		"RouteGates",
		"Spawns",
		"Exits",
		"Entities/NPCs",
		"Entities/Players",
		"Items",
		"EncounterRegions",
		"Triggers",
	], "official template")


func _check_official_example_import(importer: RefCounted) -> void:
	var map_id := "pokeaether_minimal_example"
	var result: Dictionary = importer.import_tmx(OFFICIAL_EXAMPLE_FIXTURE)
	_check_true(bool(result.get("success", false)), "official example import should pass: %s" % str(result.get("error", "")))
	_check_generated_outputs_for_map(result, map_id, "official example")

	var map_data := load(_generated_map_data(map_id)) as Resource
	_check_true(map_data != null, "official example map_data.tres loads")
	if map_data != null:
		_check_equal(str(map_data.get("map_id")), map_id, "official example map_id")
		_check_equal((map_data.get("spawns") as Array).size(), 1, "official example spawn data count")
		_check_equal((map_data.get("warps") as Array).size(), 1, "official example warp data count")
		_check_equal((map_data.get("npcs") as Array).size(), 1, "official example npc data count")
		_check_equal((map_data.get("items") as Array).size(), 1, "official example item data count")
		_check_equal((map_data.get("encounter_regions") as Array).size(), 1, "official example encounter region data count")
		_check_equal((map_data.get("triggers") as Array).size(), 1, "official example trigger data count")

	_check_runtime_nodes(map_id, [
		"Ground",
		"GroundDetail",
		"Path",
		"Water",
		"Objects",
		"Overhead",
		"Collision",
		"TallGrass",
		"LedgeDown",
		"LedgeUp",
		"LedgeLeft",
		"LedgeRight",
		"RouteGates",
		"Spawns/Start",
		"Exits/ToTemplateExit",
		"Entities/NPCs/guide",
		"Entities/Players",
		"Items/hidden_potion_1",
		"EncounterRegions/grass_patch_a",
		"Triggers/intro_trigger",
	], "official example")


func _check_duplicate_spawn_failure(importer: RefCounted) -> void:
	var result: Dictionary = importer.import_tmx(DUPLICATE_SPAWN_FIXTURE)
	_check_true(not bool(result.get("success", false)), "duplicate spawn fixture should fail")
	_check_contains(str(result.get("error", "")), "Duplicate spawn_id 'Start'", "duplicate spawn error")


func _check_missing_collision_failure(importer: RefCounted) -> void:
	var result: Dictionary = importer.import_tmx(MISSING_COLLISION_FIXTURE)
	_check_true(not bool(result.get("success", false)), "missing collision fixture should fail")
	_check_contains(str(result.get("error", "")), "Required tile layer 'Collision' is missing", "missing collision error")


func _check_file_exists(path: String, label: String) -> void:
	_check_true(FileAccess.file_exists(ProjectSettings.globalize_path(path)), label)


func _check_generated_outputs_for_map(result: Dictionary, map_id: String, label: String) -> void:
	var runtime_path := _generated_runtime(map_id)
	var map_data_path := _generated_map_data(map_id)
	var tileset_path := _generated_tileset(map_id)

	_check_file_exists(runtime_path, "%s runtime scene exists" % label)
	_check_file_exists(map_data_path, "%s map data resource exists" % label)
	_check_file_exists(tileset_path, "%s tileset resource exists" % label)

	_check_equal(str(result.get("runtime_scene_path", "")), runtime_path, "%s runtime scene path" % label)
	_check_equal(str(result.get("map_data_path", "")), map_data_path, "%s map data path" % label)
	_check_equal(str(result.get("tileset_path", "")), tileset_path, "%s tileset path" % label)


func _check_runtime_nodes(map_id: String, node_paths: Array, label: String) -> void:
	var runtime_scene := load(_generated_runtime(map_id)) as PackedScene
	_check_true(runtime_scene != null, "%s runtime.tscn loads" % label)
	if runtime_scene == null:
		return

	var runtime_root := runtime_scene.instantiate()
	_check_true(runtime_root != null, "%s runtime scene instantiates" % label)
	if runtime_root != null:
		for node_path in node_paths:
			_check_true(runtime_root.get_node_or_null(str(node_path)) != null, "%s runtime has node %s" % [label, str(node_path)])
		runtime_root.free()


func _check_true(value: bool, label: String) -> void:
	if value:
		return

	failed = true
	push_error(label)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])


func _check_contains(actual: String, expected_fragment: String, label: String) -> void:
	if actual.contains(expected_fragment):
		return

	failed = true
	push_error("%s expected fragment=%s actual=%s" % [label, expected_fragment, actual])


func _cleanup_generated_outputs() -> void:
	for map_id in [
		"phase2a_test_map",
		"pokeaether_template_map",
		"pokeaether_minimal_example",
	]:
		_cleanup_generated_output(map_id)


func _cleanup_generated_output(map_id: String) -> void:
	var files: Array[String] = [
		_generated_runtime(map_id),
		_generated_map_data(map_id),
		_generated_tileset(map_id),
	]
	for path in files:
		var global_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(global_path):
			DirAccess.remove_absolute(global_path)

	var global_dir := ProjectSettings.globalize_path(_generated_dir(map_id))
	if DirAccess.dir_exists_absolute(global_dir):
		DirAccess.remove_absolute(global_dir)


func _generated_dir(map_id: String) -> String:
	return "res://generated/maps/%s" % map_id


func _generated_runtime(map_id: String) -> String:
	return "%s/%s.runtime.tscn" % [_generated_dir(map_id), map_id]


func _generated_map_data(map_id: String) -> String:
	return "%s/%s.map_data.tres" % [_generated_dir(map_id), map_id]


func _generated_tileset(map_id: String) -> String:
	return "%s/%s.tileset.tres" % [_generated_dir(map_id), map_id]
