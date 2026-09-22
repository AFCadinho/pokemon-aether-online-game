extends RefCounted
## Shared art-only loader for grassfield and map-specific outdoor arenas. Never loads the world scene or
## native extension. Uses the existing licensed pack without copying its assets.
const Layout = preload("res://scripts/battle/arenas/generic/grassfield_layout.gd")
static var mounted_path := ""
static var pending: Array[String] = []
static var resources: Dictionary = {}
static var error := ""
static var started_ms := 0
static var load_ms := 0
static var requested_count := 0

static func prepare(manifest_path: String) -> String:
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		return "Forest art manifest is missing"
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return "Invalid forest art manifest"
	var manifest: Dictionary = json.data
	if manifest.get("schema") != 1:
		return "Unsupported forest art manifest"
	var path := str(manifest.get("pack", ""))
	if path == mounted_path and not path.is_empty():
		return error
	if not mounted_path.is_empty():
		return "Restart the review before changing the art pack"
	if not FileAccess.file_exists(path) or not ProjectSettings.load_resource_pack(path, false):
		return "Forest art pack could not load"
	if json.parse(FileAccess.get_file_as_string("res://forest_uids.json")) != OK or not json.data is Dictionary:
		return "Forest art UID map is missing or invalid"
	for text_id in json.data:
		var id := ResourceUID.text_to_id(text_id)
		if ResourceUID.has_id(id) and ResourceUID.get_id_path(id) != json.data[text_id]:
			return "Forest art resource UID conflicts with the client"
		if not ResourceUID.has_id(id):
			ResourceUID.add_id(id, json.data[text_id])
	for spec in [["wind_direction", RenderingServer.GLOBAL_VAR_TYPE_VEC2, Vector2(0.6, 0.4)],
		["wind_speed", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 1.0],
		["wind_strength", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 1.0]]:
		if not ProjectSettings.has_setting("shader_globals/" + spec[0]):
			RenderingServer.global_shader_parameter_add(spec[0], spec[1], spec[2])
	mounted_path = path
	started_ms = Time.get_ticks_msec()
	var paths: Dictionary = {}
	for group in Layout.data().props + Layout.data().foliage:
		paths["res://entities/nature/" + group.scene + ".tscn"] = true
	for scene in ["grass/grass_3_faces", "trees/fir_tree_a", "trees/fir_tree_b", "trees/fir_tree_c", "trees/spruce_tree_b",
		"rocks/rock_object_a", "rocks/rock_object_c", "rocks/rock_object_e", "flowers/lupine_flower", "flowers/anemone_flower"]:
		paths["res://entities/nature/" + scene + ".tscn"] = true
	for texture in ["groundA_albedo", "groundA_normal"]:
		paths["res://entities/nature/ground/" + texture + ".png"] = true
	for resource_path: String in paths:
		pending.append(resource_path)
	requested_count = pending.size()
	_request_next()
	return error

static func _request_next() -> void:
	# Art scenes share meshes/materials. Keep one threaded request in flight to
	# avoid concurrent dependency construction (also unsafe in Godot's dummy renderer).
	if not pending.is_empty() and ResourceLoader.load_threaded_request(pending[0]) != OK:
		error = "Could not request forest art: " + pending[0].get_file()

static func ready() -> bool:
	if mounted_path.is_empty() or not error.is_empty():
		return false
	if not pending.is_empty():
		var path := pending[0]
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			resources[path] = ResourceLoader.load_threaded_get(path)
			pending.pop_front()
			_request_next()
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			ResourceLoader.load_threaded_get(path)
			error = "Forest art could not load: " + path.get_file()
			return false
	if pending.is_empty() and load_ms == 0:
		load_ms = Time.get_ticks_msec() - started_ms
	return pending.is_empty()

static func progress() -> Array:
	var complete := ready()
	var status := ResourceLoader.THREAD_LOAD_LOADED if complete else ResourceLoader.THREAD_LOAD_IN_PROGRESS
	if mounted_path.is_empty():
		status = ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
	elif not error.is_empty():
		status = ResourceLoader.THREAD_LOAD_FAILED
	return [status, [float(requested_count - pending.size()) / maxi(1, requested_count)], error]
