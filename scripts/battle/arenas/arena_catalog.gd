extends RefCounted
## Arena presentation contract. No battle rules or species-specific offsets.
const IDS := ["classic", "forest", "cave", "sea", "stadium", "route_1", "route_1_water", "route_22", "route_22_water"]
const Framing = preload("res://scripts/battle/arenas/shared/framing.gd")
const OutdoorLighting = preload("res://scripts/battle/arenas/shared/outdoor_lighting.gd")
const CAMERA_FOV := Framing.CAMERA_FOV
const SELECTION_IDS := ["auto", "classic", "forest", "cave", "sea", "stadium"]

static func validate_selection(id: String) -> String:
	return id if id in SELECTION_IDS else "auto"

static func resolve(selection: String, environment_id: StringName) -> String:
	if validate_selection(selection) != "auto":
		return validate(selection)
	return validate(preload("res://scripts/battle/battle_environment_catalog.gd").get_profile(environment_id).arena_3d_id)
# Compatibility API names retain existing settings, preparation UI and metrics.
# These methods now load only shared art; they never mount a native extension.
const Art = preload("res://scripts/battle/arenas/shared/forest_art_pack.gd")
static var forest_error := ""
static var forest_load_ms := 0

static func forest_progress() -> Array:
	return Art.progress()

static func forest_ready() -> bool:
	var result := Art.ready()
	forest_error = Art.error
	forest_load_ms = Art.load_ms
	return result

static func prepare_forest(manifest_path: String) -> String:
	forest_error = Art.prepare(manifest_path)
	return forest_error

# Stable IDs preserve saved selections. Scope/type make the authoring structure explicit.
const DEFINITIONS := {
	"classic": {"scope": "generic", "terrain": "fallback", "lighting": "fallback", "builder": ""},
	"forest": {"scope": "generic", "terrain": "grass", "lighting": "outdoor", "builder": "generic/grassfield_arena.gd"},
	"cave": {"scope": "generic", "terrain": "cave", "lighting": "enclosed", "builder": "generic/cave_arena.gd"},
	"sea": {"scope": "generic", "terrain": "water", "lighting": "outdoor", "builder": "generic/water_arena.gd"},
	"stadium": {"scope": "generic", "terrain": "stadium", "lighting": "enclosed", "builder": "generic/stadium_arena.gd"},
	"route_1": {"scope": "map", "map_id": "kanto_route_1", "terrain": "grass", "lighting": "outdoor", "builder": "maps/route_1/arena.gd"},
	"route_1_water": {"scope": "map", "map_id": "kanto_route_1", "terrain": "water", "lighting": "outdoor", "builder": "maps/route_1/arena.gd"},
	"route_22": {"scope": "map", "map_id": "kanto_route_22", "terrain": "grass", "lighting": "outdoor", "builder": "maps/route_22/arena.gd"},
	"route_22_water": {"scope": "map", "map_id": "kanto_route_22", "terrain": "water", "lighting": "outdoor", "builder": "maps/route_22/arena.gd"},
}

static func definition(id: String) -> Dictionary:
	return DEFINITIONS.get(validate(id), DEFINITIONS.classic).duplicate(true)

const BUILDERS := {
	"cave": preload("res://scripts/battle/arenas/generic/cave_arena.gd"),
	"sea": preload("res://scripts/battle/arenas/generic/water_arena.gd"),
	"stadium": preload("res://scripts/battle/arenas/generic/stadium_arena.gd"),
}

static func validate(id: String) -> String:
	return id if id in IDS else "classic"

static func spawn(index: int) -> Vector3:
	return Framing.spawn(index)

static func battle_origin(id: String) -> Vector3:
	return Framing.battle_origin(id)

static func camera_home(id: String) -> Vector3:
	return Framing.camera_home(id)

static func camera_target(id: String) -> Vector3:
	return Framing.camera_target(id)

static func uses_forest_assets(id: String) -> bool:
	return id in ["forest", "route_1", "route_1_water", "route_22", "route_22_water"]

static func uses_outdoor_lighting(id: String) -> bool:
	return str(definition(id).get("lighting", "fallback")) == "outdoor"

static func _apply_lighting(id: String, arena: Node3D) -> Node3D:
	if arena != null and uses_outdoor_lighting(id):
		var lighting := OutdoorLighting.new()
		lighting.name = "OutdoorLighting"
		arena.add_child(lighting)
	return arena

static func build(id: String, world: Node3D, camera: Camera3D = null) -> Node3D:
	if uses_forest_assets(id) and not Art.mounted_path.is_empty() and Art.error.is_empty():
		for child in world.get_children():
			if child is WorldEnvironment:
				child.environment.background_color = Color("b4cad6")
		if id in ["route_1", "route_1_water"]:
			var route = preload("res://scripts/battle/arenas/maps/route_1/arena.gd").new()
			route.water_battle = id == "route_1_water"
			return _apply_lighting(id, route.build(camera))
		if id in ["route_22", "route_22_water"]:
			var route = preload("res://scripts/battle/arenas/maps/route_22/arena.gd").new()
			route.water_battle = id == "route_22_water"
			return _apply_lighting(id, route.build(camera))
		return _apply_lighting(id, preload("res://scripts/battle/arenas/generic/grassfield_arena.gd").new().build(camera))
	if not BUILDERS.has(id):
		return null
	return _apply_lighting(id, BUILDERS[id].new(world).build())
