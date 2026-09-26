extends "res://scripts/battle/arenas/shared/wooded_route.gd"
## Shared shoreline and small props; route builders still own their terrain/layout.
const BASE_HEIGHT := 0.037750244140625
const WATER_LEVEL := -0.22
const WATER_DEPTH := 0.22
const Details := {
	"log": preload("res://assets/models/battle/nature_details/log.glb"),
	"stump": preload("res://assets/models/battle/nature_details/stump_roundDetailed.glb"),
	"mushrooms": preload("res://assets/models/battle/nature_details/mushroom_redGroup.glb"),
	"lily": preload("res://assets/models/battle/nature_details/lily_large.glb"),
}
var water_battle := false
var detail_materials := {}

func _point(p: Vector2) -> Vector3:
	return Vector3(p.x, _height(p.x, p.y), p.y)

func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(a + (b - a) * clampf((p - a).dot(b - a) / a.distance_squared_to(b), 0, 1))

func _basin(p: Vector2, center: Vector2, radii: Vector2, shallows: bool) -> float:
	var depth := -WATER_LEVEL + WATER_DEPTH if shallows else 1.4
	return depth * (1.0 - smoothstep(1.0 if shallows else 0.8, 1.15, ((p - center) / radii).length()))

func _pond(parent: Node3D, label: String, center: Vector2, radii: Vector2, shallows: bool) -> void:
	var shore := Node3D.new()
	shore.name = label
	parent.add_child(shore)
	var plane := PlaneMesh.new()
	plane.size = radii * 2.5
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/battle/arenas/shared/pond_water.gdshader")
	material.set_shader_parameter("pond_center", center)
	material.set_shader_parameter("pond_radii", radii)
	material.set_shader_parameter("battle_shallows", shallows)
	var geo := RouteGeometry.new(route_scene)
	var surface := geo._put(shore, plane, material, Vector3(center.x, BASE_HEIGHT + WATER_LEVEL, center.y), Vector3.ONE)
	surface.name = "WaterSurface"
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 30:
		var angle := TAU * i / 30.0
		var p := center + Vector2(cos(angle), sin(angle)) * radii * 1.13
		_sized_asset(shore, "rocks/rock_object_a", _point(p) - Vector3.UP * 0.05,
			Vector3(0.6, 0.35, 0.55) * rng.randf_range(0.7, 1.2), angle)

func _detail(parent: Node3D, kind: String, point: Vector3, size: Vector3, angle := 0.0) -> Node3D:
	var node: Node3D = Details[kind].instantiate()
	_strip_runtime_helpers(node)
	_detail_materials(node)
	parent.add_child(node)
	var boxes: Array = []
	_bounds(node, Transform3D.IDENTITY, boxes)
	var bounds: AABB = boxes[0]
	for box: AABB in boxes:
		bounds = bounds.merge(box)
	node.scale = size / bounds.size
	node.rotation.y = angle
	node.position = point - node.basis * Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	return node

func _finish_surface() -> void:
	ground_height = BASE_HEIGHT + (WATER_LEVEL - WATER_DEPTH if water_battle else 0.0)
	route_scene.set_meta("surface_height", ground_height)

func _detail_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var source := node.get_active_material(surface) as StandardMaterial3D
			if source == null:
				continue
			var key := source.get_instance_id()
			if not detail_materials.has(key):
				var material: StandardMaterial3D = source.duplicate()
				material.metallic = 0.0
				material.roughness = 0.95
				var colors := {"woodBark": "77583d", "woodInner": "c5a477", "leafsGreen": "4b854f", "leafsDark": "386641", "colorRed": "c36665"}
				if colors.has(source.resource_name):
					material.albedo_color = Color(colors[source.resource_name])
				detail_materials[key] = material
			node.set_surface_override_material(surface, detail_materials[key])
	for child in node.get_children():
		_detail_materials(child)
