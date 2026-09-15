extends SceneTree

const MAPS := {
	"kanto_route_1": "res://scenes/overworld/kanto/routes/kanto_route_1.tscn",
	"kanto_route_2": "res://scenes/overworld/kanto/routes/route2/kanto_route_2.tscn",
	"kanto_route_22": "res://scenes/overworld/kanto/routes/kanto_route_22.tscn",
	"kanto_viridian_forest": "res://scenes/overworld/kanto/routes/viridian_forest.tscn",
}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var result := {"schemaVersion": 1, "maps": {}}
	for area: String in MAPS:
		var map: Node2D = load(MAPS[area]).instantiate()
		var grass := map.get_node("Tiles/TallGrass") as TileMapLayer
		var transform := grass.global_transform
		if transform.x != Vector2.RIGHT or transform.y != Vector2.DOWN:
			map.free()
			quit(1)
			return
		var cells: Array = []
		for cell: Vector2i in grass.get_used_cells():
			if grass.get_cell_tile_data(cell) != null:
				cells.append([cell.x, cell.y])
		cells.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
		result["maps"][area] = {"scenePath": MAPS[area], "origin": [transform.origin.x, transform.origin.y],
			"tileSize": [grass.tile_set.tile_size.x, grass.tile_set.tile_size.y], "cells": cells}
		map.free()
	var args := OS.get_cmdline_user_args()
	if args.size() < 1 or args.size() > 2 or result["maps"].size() != 4:
		quit(1)
		return
	if args.size() == 2:
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
		var normalized: Variant = JSON.parse_string(JSON.stringify(result, "", true))
		quit(0 if args[1] == "--check" and JSON.stringify(saved, "", true) == JSON.stringify(normalized, "", true) else 1)
		return
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(result, "\t", true) + "\n")
	quit(0)
