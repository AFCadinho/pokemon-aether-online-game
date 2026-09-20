extends "res://tools/sprite_factory/forest_battle_review.gd"
## Paid assets stay in the isolated local project, never in the repository.
const CLEAR_RADIUS := 12.0
const BLEND_RADIUS := 19.0

func _credit_text() -> String:
	return "FancifulCrow · Temperate Forest · isolated battle review\nFlat clearing · neutral Pokémon lighting · no gameplay changes"

func _ground_position(pos: Vector3) -> Vector3:
	pos.y = 0.0
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
	# Hide authored objects near the clearing, including canopy overhang margin.
	# Freeing nested authored instances before Terrain3D enters the tree crashes
	# the bundled 1.0.1 extension; retain their ownership until normal teardown.
	for child in terrain.get_children():
		if child is Node3D and Vector2(child.position.x, child.position.z).length() < 24.0:
			child.visible = false
	scene.ready.connect(func(): _flatten(terrain))
	return scene

func _flatten(terrain) -> void:
	# Runtime-only edits: original purchased terrain resources are never saved.
	for z in range(-19, 20):
		for x in range(-19, 20):
			var pos := Vector3(x, 0, z)
			var radius := Vector2(x, z).length()
			if radius >= BLEND_RADIUS:
				continue
			var height: float = terrain.data.get_height(pos)
			assert(is_finite(height))
			var blend := smoothstep(CLEAR_RADIUS, BLEND_RADIUS, radius)
			terrain.data.set_height(pos, height * blend)
	terrain.data.update_maps()
	# Shift applies to all mesh types, including flowers, not just grass asset 0.
	terrain.instancer.remove_instances(Vector3.ZERO, {
		"asset_id": 0, "modifier_shift": true, "modifier_alt": false,
		"size": (CLEAR_RADIUS + 1.0) * 2.0,
		"strength": 100.0, "slope": Vector2(0, 90)})
	for pos in [Vector3.ZERO, Vector3(-2.8, 0, 1.5), Vector3(2.8, 0, -1.5)]:
		assert(absf(terrain.data.get_height(pos)) < 0.001)
	print("TEMPERATE_CLEARING_OK radius=", CLEAR_RADIUS)
