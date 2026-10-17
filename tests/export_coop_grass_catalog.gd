extends SceneTree

const LayerResolver := preload("res://scripts/world/map_layer_resolver.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for child: Node in root.get_children():
		child.set_process(false)
	var args := OS.get_cmdline_user_args()
	if args.size() < 1 or args.size() > 2:
		quit(1)
		return
	# Output belongs to backend/account-service/generated. Read the paired
	# encounter tables so decorative grass and unused table-only maps stay out.
	var encounter_root := args[0].get_base_dir().path_join("../../battle-orchestrator/data/encounters").simplify_path()
	if not DirAccess.dir_exists_absolute(encounter_root):
		push_error("Expected a paired backend grass catalog output path")
		quit(1)
		return
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	var result := {"schemaVersion": 1, "maps": {}}
	var seen: Dictionary = {}
	for map_id: String in world["areas"]:
		var scene_path := str(world["areas"][map_id].get("scenePath", ""))
		if scene_path.is_empty() or seen.has(scene_path):
			continue
		seen[scene_path] = true
		var map: Node2D = load(scene_path).instantiate()
		if not map.has_method("get_wild_encounter_area_id"):
			map.free()
			continue
		var area := str(map.call("get_wild_encounter_area_id"))
		var names: Array[String] = ["TallGrass"]
		var grass := LayerResolver.find_tilemap_layer(map, names)
		if area.is_empty() or grass == null or grass.get_used_cells().is_empty():
			map.free()
			continue
		var table_id := "kanto_route_2_south_towards_viridian_city" if area == "kanto_route_2" else area
		var region := table_id.get_slice("_", 0)
		var table_path := encounter_root.path_join(region).path_join(table_id.trim_prefix(region + "_") + ".json")
		var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(table_path)) if FileAccess.file_exists(table_path) else {}
		if table.get("grass", {}).get("pokemon", []).is_empty():
			map.free()
			continue
		# The current admission protocol identifies grass by the physical map ID.
		# Refuse aliases/transforms that would silently validate the wrong cells.
		var transform := grass.global_transform
		if area != map_id or transform.x != Vector2.RIGHT or transform.y != Vector2.DOWN:
			push_error("Unsupported co-op grass geometry or area alias: " + map_id)
			map.free()
			quit(1)
			return
		var cells: Array = []
		for cell: Vector2i in grass.get_used_cells():
			if grass.get_cell_tile_data(cell) != null:
				cells.append([cell.x, cell.y])
		cells.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
		if not cells.is_empty():
			result["maps"][area] = {"scenePath": scene_path, "origin": [transform.origin.x, transform.origin.y],
				"tileSize": [grass.tile_set.tile_size.x, grass.tile_set.tile_size.y], "cells": cells}
		map.free()
	if result["maps"].is_empty():
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
	print("Exported %d playable grass encounter maps" % result["maps"].size())
	quit(0)
