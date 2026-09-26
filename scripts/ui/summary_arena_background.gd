extends SubViewportContainer
## Card-owned scenery pass. Native low poses remain visible over the terrain.
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")
const Lighting = preload("res://scripts/battle/battle_ui/material_response.gd")
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var arena: Node3D
var arena_id := "forest"
var waiting_for_art := false

static func arena_for_types(types: Array) -> String:
	var normalized: Array[String] = []
	for type in types:
		normalized.append(str(type).strip_edges().to_lower())
	if "water" in normalized:
		return "sea"
	if "rock" in normalized or "ground" in normalized:
		return "cave"
	return "forest"

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.add_child(environment)
	Lighting.apply_neutral_lighting(world)
	camera = Camera3D.new()
	camera.fov = 40.0
	camera.far = 2200.0
	world.add_child(camera)
	camera.position = Vector3(0, 3.2, 9)
	camera.look_at(Vector3(0, 1.6, -5))
	select_arena(arena_id)

func select_arena(id: String) -> void:
	if id not in ["forest", "cave", "sea"]:
		return
	arena_id = id
	waiting_for_art = false
	if arena != null:
		arena.free()
		arena = null
	# A pending/missing optional art pack keeps the existing card backdrop.
	visible = false
	if id == "forest":
		var settings := get_node_or_null("/root/SettingsManager")
		if settings == null or not Arenas.prepare_forest(settings.get_battle_3d_forest_manifest()).is_empty():
			return
		waiting_for_art = true
		return
	_build()

func _build() -> void:
	for child in world.get_children():
		if child is WorldEnvironment:
			child.environment.background_mode = Environment.BG_COLOR
	arena = Arenas.build(arena_id, world, camera)
	if arena == null:
		return
	world.add_child(arena)
	# Summary inspection uses stable daylight, independent of the world clock.
	var daylight := arena.get_node_or_null("OutdoorLighting")
	if daylight != null:
		daylight.set_process(false)
		daylight.apply_seconds(12.0 * 3600.0)
	visible = true

func _process(_delta: float) -> void:
	var active: bool = get_parent().is_visible_in_tree()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active and arena != null else SubViewport.UPDATE_DISABLED
	if active and waiting_for_art:
		if Arenas.forest_ready():
			waiting_for_art = false
			_build()
		elif not Arenas.forest_error.is_empty():
			waiting_for_art = false
