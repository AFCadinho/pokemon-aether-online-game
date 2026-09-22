extends "res://scripts/battle/arenas/shared/mesh_grassland.gd"
## Generic grass terrain. The approved hills and props are sampled layout data,
## independent of any overworld map or native Terrain3D resources.
const Layout = preload("res://scripts/battle/arenas/generic/grassfield_layout.gd")
static var foliage_cache: Array[WeakRef] = []

func _grid_rect() -> Rect2i:
	return Rect2i(-100, -120, 201, 201)
func _grass_rect() -> Rect2i:
	return Rect2i(-8, -10, 16, 16)
func _height(x: float, z: float) -> float:
	return Layout.height_at(x, z)
func _route_z(x: float) -> float:
	return -18.0 + 2.3 * sin(x * 0.12)
func _dirt(x: float, z: float) -> float:
	return 1.0 - smoothstep(0.8, 1.8, absf(z - _route_z(x)))
func _has_grass(x: float, z: float) -> bool:
	return Vector2(x, z).length() > 6 and absf(z - _route_z(x)) > 1.65

func build(_camera: Camera3D = null) -> Node3D:
	ground_height = float(Layout.data().ground_height)
	_start_scene("GenericGrassfield")
	route_scene.set_meta("surface_height", ground_height)
	var scenery := Node3D.new()
	scenery.name = "GrassfieldScenery"
	route_scene.add_child(scenery)
	for prop in Layout.data().props:
		var node := _asset(scenery, prop.scene, Vector3.ZERO, Vector3.ONE)
		node.transform = Layout.transform_from(prop.transform)
	_grass(scenery)
	_foliage(scenery)
	return route_scene

func _foliage(parent: Node3D) -> void:
	var batches: Array[MultiMesh] = []
	for reference in foliage_cache:
		var batch = reference.get_ref()
		if batch != null:
			batches.append(batch)
	if batches.size() != foliage_cache.size() or batches.is_empty():
		batches.clear()
		foliage_cache.clear()
		for group in Layout.data().foliage:
			var source: Node3D = load("res://entities/nature/" + group.scene + ".tscn").instantiate()
			_strip_runtime_helpers(source)
			for card in source.find_children("*", "MeshInstance3D", true, false):
				var batch := MultiMesh.new()
				batch.transform_format = MultiMesh.TRANSFORM_3D
				batch.mesh = card.mesh.duplicate()
				for surface in batch.mesh.get_surface_count():
					batch.mesh.surface_set_material(surface, card.get_active_material(surface))
				batch.instance_count = group.transforms.size()
				for i in group.transforms.size():
					batch.set_instance_transform(i, Layout.transform_from(group.transforms[i]) * card.transform)
				batches.append(batch)
				foliage_cache.append(weakref(batch))
			source.free()
	for batch in batches:
		var node := MultiMeshInstance3D.new()
		node.multimesh = batch
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
