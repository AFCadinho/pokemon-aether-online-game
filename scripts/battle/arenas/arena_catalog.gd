extends RefCounted
## Arena presentation contract. No battle rules or species-specific offsets.
const IDS := ["classic", "forest", "cave", "sea", "stadium"]
static var mounted_forest := ""
static var forest_scene: PackedScene
static var forest_loading := false
static var forest_error := ""

static func forest_ready() -> bool:
	if forest_scene != null:
		return true
	if forest_loading and ResourceLoader.load_threaded_get_status("res://pokeaether_forest.tscn") == ResourceLoader.THREAD_LOAD_LOADED:
		forest_scene = ResourceLoader.load_threaded_get("res://pokeaether_forest.tscn")
		forest_loading = false
	elif forest_loading and ResourceLoader.load_threaded_get_status("res://pokeaether_forest.tscn") == ResourceLoader.THREAD_LOAD_FAILED:
		ResourceLoader.load_threaded_get("res://pokeaether_forest.tscn")
		forest_loading = false
		forest_error = "Forest scene could not load; check the local pack"
	return forest_scene != null

static func prepare_forest(manifest_path: String) -> String:
	if manifest_path.is_empty() or not FileAccess.file_exists(manifest_path):
		return "Choose a local forest pack manifest in Settings"
	if mounted_forest == manifest_path:
		return forest_error
	if not mounted_forest.is_empty():
		return "Restart the client before changing the forest pack"
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not data is Dictionary or data.get("schema",0) != 1:
		return "Invalid forest pack manifest"
	var pack: String = str(data.get("pack",""))
	var extension: String = str(data.get("extension",""))
	if not FileAccess.file_exists(pack) or not FileAccess.file_exists(extension):
		return "Forest pack or Terrain3D descriptor is missing"
	if not ProjectSettings.load_resource_pack(pack,false):
		return "Could not mount forest pack"
	var uids: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://forest_uids.json"))
	if uids is Dictionary:
		for text_id in uids:
			var id := ResourceUID.text_to_id(text_id)
			if ResourceUID.has_id(id) and ResourceUID.get_id_path(id) != uids[text_id]:
				return "Forest resource UID conflicts with the client; rebuild the local pack"
			if not ResourceUID.has_id(id):
				ResourceUID.add_id(id,uids[text_id])
	if not ClassDB.class_exists("Terrain3D"):
		var status := GDExtensionManager.load_extension(extension)
		if status != GDExtensionManager.LOAD_STATUS_OK and status != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
			return "Terrain3D could not load on this desktop"
	for spec in [["wind_direction",RenderingServer.GLOBAL_VAR_TYPE_VEC2,Vector2(0.6,0.4)], ["wind_speed",RenderingServer.GLOBAL_VAR_TYPE_FLOAT,1.0], ["wind_strength",RenderingServer.GLOBAL_VAR_TYPE_FLOAT,1.0]]:
		if not ProjectSettings.has_setting("shader_globals/"+spec[0]):
			RenderingServer.global_shader_parameter_add(spec[0],spec[1],spec[2])
	mounted_forest = manifest_path
	forest_loading = ResourceLoader.load_threaded_request("res://pokeaether_forest.tscn","PackedScene")==OK
	if not forest_loading:
		return "Could not request forest assets"
	return ""
const BUILDERS := {
	"cave": preload("res://scripts/battle/arenas/cave_arena.gd"),
	"sea": preload("res://scripts/battle/arenas/sea_arena.gd"),
	"stadium": preload("res://scripts/battle/arenas/stadium_arena.gd"),
}

static func validate(id: String) -> String:
	return id if id in IDS else "classic"

static func spawn(index: int) -> Vector3:
	return Vector3(-2.8,0,1.5) if index == 0 else Vector3(2.8,0,-1.5)

static func camera_home(id: String) -> Vector3:
	return Vector3(2.5,5.0,16.0) if id == "stadium" else Vector3(4,5.5,12)

static func camera_target(id: String) -> Vector3:
	return Vector3(0,2.8,0) if id == "stadium" else Vector3(0,1.3,0)

static func build(id: String, world: Node3D, camera: Camera3D = null) -> Node3D:
	if id == "forest" and not mounted_forest.is_empty():
		for child in world.get_children():
			if child is WorldEnvironment:
				child.environment.background_color = Color("b4cad6")
		return preload("res://scripts/battle/arenas/forest_arena.gd").new().build(camera)
	if not BUILDERS.has(id):
		return null
	return BUILDERS[id].new(world).build()
