extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load("res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn")
	var root := scene.instantiate()
	var collision := root.get_node("Collision") as TileMapLayer
	var start := Vector2i(20, 17)
	var target := Vector2i(40, 25)
	var queue: Array[Vector2i] = [start]
	var parent := {start: start}
	var index := 0
	while index < queue.size() and not parent.has(target):
		var cell := queue[index]
		index += 1
		for delta in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var next: Vector2i = cell + delta
			if not Rect2i(0, 0, 50, 40).has_point(next) or parent.has(next) or collision.get_cell_source_id(next) != -1:
				continue
			parent[next] = cell
			queue.append(next)
	var path: Array = []
	if parent.has(target):
		var cell := target
		while cell != start:
			path.push_front([cell.x * 32 + 16, cell.y * 32 + 16])
			cell = parent[cell]
	var door := root.get_node("Exits/ToOaksLab") as Area2D
	var shape := door.get_node("CollisionShape2D") as CollisionShape2D
	print("PALLET_TEST_PATH ", JSON.stringify({"path": path, "doorCenter": str(door.position + shape.position), "doorCellBlocked": collision.get_cell_source_id(Vector2i(40,24)) != -1, "frontCellBlocked": collision.get_cell_source_id(target) != -1}))
	root.free()
	quit(0 if not path.is_empty() else 1)
