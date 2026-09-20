extends "res://tools/sprite_factory/forest_battle_review.gd"
## Paid assets stay in the isolated local project, never in the repository.
const CLEAR_RADIUS := 5.0
const BLEND_RADIUS := 9.0
const PATCH_RADIUS := 6.0
var ground_height := 0.0

func _credit_text() -> String:
	return "FancifulCrow · Temperate Forest · isolated battle review\nFlat clearing · neutral Pokémon lighting · no gameplay changes"

func _ground_position(pos: Vector3) -> Vector3:
	pos.y = ground_height
	return pos

func _make_forest() -> Node3D:
	# Terrain3D expects a current scene even in this SceneTree-script harness.
	current_scene = stage
	var scene: Node3D = load("res://scenes/world/test_world.res").instantiate()
	for node_name in ["Rendering", "Player", "WorldBarrier", "GrassPlacer"]:
		var node := scene.get_node_or_null(NodePath(node_name))
		if node != null:
			scene.remove_child(node)
			node.free()
	var terrain = scene.get_node("Terrain3D")
	terrain.set_camera(stage.camera)
	# Hide only objects occupying the battle space or casting shade across it.
	# Preserve Terrain3D-owned runtime nodes and retain scene ownership until
	# normal teardown; do not free terrain children during construction.
	scene.ready.connect(func(): _flatten(terrain))
	return scene

func _bounds(node: Node, accumulated: Transform3D, boxes: Array) -> void:
	if node is Node3D:
		accumulated = accumulated * node.transform
	if node is MeshInstance3D and node.mesh != null:
		boxes.append(accumulated * node.get_aabb())
	for child in node.get_children():
		_bounds(child, accumulated, boxes)

func _shades_battle(node: Node3D) -> bool:
	var boxes: Array = []
	_bounds(node, Transform3D.IDENTITY, boxes)
	var sun_ray := Basis.from_euler(Vector3(-45, -30, 0) * PI / 180.0) * Vector3.FORWARD
	for box: AABB in boxes:
		var shadow := Rect2()
		for corner in 8:
			var p := box.get_endpoint(corner)
			p += sun_ray * maxf(0.0, (ground_height - p.y) / sun_ray.y)
			var projected := Vector2(p.x, p.z)
			shadow = Rect2(projected, Vector2.ZERO) if corner == 0 else shadow.expand(projected)
		if shadow.intersects(Rect2(-6, -4, 12, 8)):
			return true
	return false

func _flatten(terrain) -> void:
	# Runtime-only edits: original purchased terrain resources are never saved.
	ground_height = terrain.data.get_height(Vector3.ZERO)
	target.y = ground_height + 1.3
	_camera()
	for child in terrain.get_children():
		# Never hide Terrain3D's generated Instancer container at the origin:
		# that hides every grass/flower instance across the entire environment.
		if child is Node3D and not child.scene_file_path.is_empty() and (Vector2(child.position.x, child.position.z).length() < 9.0 or _shades_battle(child)):
			child.visible = false
		if child is Node3D and child.scene_file_path.is_empty():
			assert(child.visible, "Generated terrain vegetation must remain visible")
	for z in range(-9, 10):
		for x in range(-9, 10):
			var pos := Vector3(x, 0, z)
			var radius := Vector2(x, z).length()
			if radius >= BLEND_RADIUS:
				continue
			var height: float = terrain.data.get_height(pos)
			assert(is_finite(height))
			var blend := smoothstep(CLEAR_RADIUS, BLEND_RADIUS, radius)
			terrain.data.set_height(pos, lerpf(ground_height, height, blend))
	terrain.data.update_maps()
	# Terrain3D 1.0.1 uses 0.4 * size as removal radius, not size / 2.
	# One shared circular arena: retain all grass outside its boundary.
	terrain.instancer.remove_instances(Vector3.ZERO, {
		"asset_id": 0, "modifier_shift": true, "modifier_alt": false,
		"size": PATCH_RADIUS / 0.4,
		"strength": 100.0, "slope": Vector2(0, 90)})
	terrain.instancer.update_transforms(AABB(Vector3(-9, -100, -9), Vector3(18, 200, 18)))
	for pos in [Vector3.ZERO, Vector3(-2.8, 0, 1.5), Vector3(2.8, 0, -1.5)]:
		assert(absf(terrain.data.get_height(pos) - ground_height) < 0.001)
	print("TEMPERATE_CLEARING_OK radius=", CLEAR_RADIUS)
