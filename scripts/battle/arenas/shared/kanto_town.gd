extends "res://scripts/battle/arenas/shared/cerulean_region.gd"
const TownKit = preload("res://scripts/battle/arenas/shared/kanto_city_landmarks.gd")

func _begin_town(label: String, id: String, paved := false) -> Node3D:
	var scenery := _begin_region(label, id)
	kit = TownKit.new(route_scene)
	if paved:
		var material := ShaderMaterial.new()
		material.shader = preload("res://scripts/battle/arenas/shared/city_ground.gdshader")
		material.set_shader_parameter("ground_albedo", load("res://entities/nature/ground/groundA_albedo.png"))
		material.set_shader_parameter("ground_normal", load("res://entities/nature/ground/groundA_normal.png"))
		route_scene.get_node("MeshTerrain").material_override = material
	return scenery

func _grass_rect() -> Rect2i:
	return Rect2i(-7, -7, 14, 14)

func _town_lamps(parent: Node3D, positions: Array[Vector2]) -> void:
	for p in positions:
		kit.lamp(parent, _point(p))

func _center(parent: Node3D, p: Vector2, angle := 0.0) -> void:
	kit.pokemon_center(parent, _point(p))
	parent.get_child(-1).rotation.y = angle

func _flower_planters(parent: Node3D, beds: Array[Vector2]) -> void:
	var frames := _group(parent, "FlowerPlanters")
	for p in beds:
		var base := _point(p)
		kit._box(frames, "green", base + Vector3(0, 0.012, 0.2), Vector3(3.7, 0.02, 2.0))
		for x in [-1.95, 1.95]:
			kit._box(frames, "stone", base + Vector3(x, 0.07, 0.2), Vector3(0.18, 0.14, 2.3))
		for z in [-0.85, 1.25]:
			kit._box(frames, "stone", base + Vector3(0, 0.07, z), Vector3(4.0, 0.14, 0.18))
