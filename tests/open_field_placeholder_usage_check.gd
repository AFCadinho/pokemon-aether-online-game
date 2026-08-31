extends SceneTree

const OVERWORLD_ROOT := "res://scenes/overworld"
const PLACEHOLDER_SCRIPT_PATH := "res://scripts/world/kanto/open_field_placeholder_map.gd"
const ALLOWED_PLACEHOLDERS := [
	"res://scenes/overworld/kanto/caves/cerulean_cave/cerulean_cave.tscn",
	"res://scenes/overworld/kanto/routes/kanto_route_5.tscn",
	"res://scenes/overworld/kanto/routes/kanto_route_9.tscn",
]
const FINISHED_MAPS := [
	"res://scenes/overworld/kanto/routes/kanto_route_24.tscn",
	"res://scenes/overworld/kanto/routes/route25/kanto_route_25.tscn",
]

var failed := false


func _init() -> void:
	var placeholder_users: Array[String] = []
	_scan_scenes(OVERWORLD_ROOT, placeholder_users)
	placeholder_users.sort()

	for scene_path: String in placeholder_users:
		_check(
			ALLOWED_PLACEHOLDERS.has(scene_path),
			"%s is an explicitly allowed prototype placeholder" % scene_path
		)
		var source := FileAccess.get_file_as_string(scene_path)
		_check(
			source.contains("placeholder_runtime_generation_enabled = true"),
			"%s explicitly enables prototype terrain generation" % scene_path
		)

	for scene_path: String in ALLOWED_PLACEHOLDERS:
		_check(
			placeholder_users.has(scene_path),
			"%s remains registered as a prototype placeholder" % scene_path
		)

	for scene_path: String in FINISHED_MAPS:
		var source := FileAccess.get_file_as_string(scene_path)
		_check(
			not source.contains(PLACEHOLDER_SCRIPT_PATH),
			"%s cannot use the open-field placeholder script" % scene_path
		)
		_check(
			source.contains("res://scripts/world/map_metadata.gd"),
			"%s uses non-mutating map metadata" % scene_path
		)

	var placeholder_script := FileAccess.get_file_as_string(PLACEHOLDER_SCRIPT_PATH)
	_check(
		placeholder_script.contains("placeholder_runtime_generation_enabled := false"),
		"Open-field runtime generation is disabled by default"
	)
	quit(1 if failed else 0)


func _scan_scenes(directory_path: String, placeholder_users: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		failed = true
		push_error("FAIL Could not scan %s" % directory_path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		var entry_path := directory_path.path_join(entry)
		if directory.current_is_dir():
			_scan_scenes(entry_path, placeholder_users)
		elif entry.ends_with(".tscn"):
			var source := FileAccess.get_file_as_string(entry_path)
			if source.contains(PLACEHOLDER_SCRIPT_PATH):
				placeholder_users.append(entry_path)
		entry = directory.get_next()
	directory.list_dir_end()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
