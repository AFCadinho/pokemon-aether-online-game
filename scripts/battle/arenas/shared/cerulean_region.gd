extends "res://scripts/battle/arenas/shared/waterside_route.gd"
## Shared dressing only; each map owns its topography, shoreline and landmarks.
const Landmarks = preload("res://scripts/battle/arenas/shared/cerulean_landmarks.gd")
const Framing = preload("res://scripts/battle/arenas/shared/framing.gd")
var kit: RefCounted
var rock_material: Material

func _begin_region(label: String, id: String) -> Node3D:
	ground_height = BASE_HEIGHT
	_start_scene(label)
	route_scene.set_meta("source_map", "kanto_" + id)
	var scenery := Node3D.new()
	scenery.name = "RegionScenery"
	route_scene.add_child(scenery)
	kit = Landmarks.new(route_scene)
	rock_material = kit.geo._stone(Color("927458"))
	return scenery

func _group(parent: Node3D, label: String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	parent.add_child(node)
	return node

func _mountain_peaks(parent: Node3D, positions: Array[Vector2]) -> void:
	var ridge := _group(parent, "MountainPeaks")
	for i in positions.size():
		var p := positions[i]
		var height := rng.randf_range(4.5, 8.5)
		kit.geo._put(ridge, kit.geo._rock_mesh(810 + i), rock_material,
			_point(p) + Vector3(0, height * 0.12, 0), Vector3(7.5, height, 6.5), rng.randf() * TAU)

func _tree_rows(parent: Node3D, rows: Array, water_test: Callable, road_test: Callable) -> void:
	var trees := _group(parent, "RegionConifers")
	for row in rows:
		for i in int(row[2]):
			var p := Vector2(row[0] + i * row[3], row[1] + i * row[4])
			if water_test.call(p) or road_test.call(p) < 3.7:
				continue
			_plant_tree(trees, p, i)

func _rocks_and_flowers(parent: Node3D, beds: Array[Vector2], rocks: Array[Vector2]) -> void:
	var details := _group(parent, "RegionalDetails")
	_plant_beds(details, beds)
	for i in rocks.size():
		var p := rocks[i]
		_sized_asset(details, "rocks/rock_object_" + ("a" if i % 2 else "c"),
			_point(p) - Vector3.UP * 0.1, Vector3(1.8, 0.85, 1.3), i * 0.9)

func _road_distance(p: Vector2, lines: Array) -> float:
	var distance := 1000.0
	for line in lines:
		distance = minf(distance, _segment_distance(p, line[0], line[1]))
	return distance
