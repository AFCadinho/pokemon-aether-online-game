@tool
extends RefCounted

const CATALOG_PATH := "res://data/guild_base_furniture.json"
const TILESET_PATH := "res://assets/guild_base/furniture/collision.tileset.tres"

static func load_existing_layer(scene_path: String) -> TileMapLayer:
	if not FileAccess.file_exists(scene_path):
		return null
	var packed := ResourceLoader.load(scene_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if packed == null:
		return null
	var scene := packed.instantiate()
	var authored := scene.get_node_or_null("Collision") as TileMapLayer
	var layer := authored.duplicate() as TileMapLayer if authored != null else null
	scene.free()
	return layer


static func create_layer(spec: Dictionary) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = "Collision"
	layer.tile_set = load(TILESET_PATH)
	layer.position = Vector2(0, -int(spec.footprint[1]) * 32)
	layer.z_index = 10
	layer.collision_enabled = false
	layer.navigation_enabled = false
	if spec.has("collisionCells"):
		for cell: Array in spec.collisionCells:
			layer.set_cell(Vector2i(cell[0], cell[1]), 0, Vector2i.ZERO)
	elif bool(spec.blocksMovement):
		for y: int in range(int(spec.footprint[1])):
			for x: int in range(int(spec.footprint[0])):
				layer.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	return layer


static func read_cells(layer: TileMapLayer, spec: Dictionary) -> Dictionary:
	if layer == null or layer.tile_set == null or layer.tile_set.tile_size != Vector2i(32, 32):
		return {"success": false, "error": "Missing Collision layer or 32×32 TileSet."}
	if layer.scale != Vector2.ONE or not is_zero_approx(layer.rotation) or layer.skew != 0:
		return {"success": false, "error": "Collision must have scale 1 and rotation/skew 0."}
	var origin := layer.position / 32.0 + Vector2(0, int(spec.footprint[1]))
	if not origin.is_equal_approx(origin.round()):
		return {"success": false, "error": "Collision position must align to the 32-pixel grid."}
	var art_origin := Vector2i(int(spec.visualOffset[0]) / 32, int(spec.footprint[1]) + int(spec.visualOffset[1]) / 32)
	var art_bounds := Rect2i(art_origin, Vector2i(spec.visualSize[0], spec.visualSize[1]))
	var cells: Array = []
	var points := layer.get_used_cells()
	if str(spec.placement) == "surface" and not points.is_empty():
		return {"success": false, "error": "Tabletop decorations inherit floor collision from their parent. Paint the table's Collision layer."}
	points.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y or (a.y == b.y and a.x < b.x))
	for point: Vector2i in points:
		var cell := point + Vector2i(origin)
		if not art_bounds.has_point(cell):
			return {"success": false, "error": "Collision tile %s is outside the furniture artwork." % str(cell)}
		cells.append([cell.x, cell.y])
	return {"success": true, "cells": cells}


static func default_backend_path() -> String:
	var project := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var sibling := "backend" if project.get_file() == "frontend" else "pokemon-aether-backend"
	return project.get_base_dir().path_join(sibling).path_join("account-service/catalogs/guild_base_furniture.json")


static func export_catalogs(backend_path: String, check := false, frontend_catalog_path := CATALOG_PATH, layers := {}) -> Dictionary:
	var frontend_path := ProjectSettings.globalize_path(frontend_catalog_path)
	backend_path = ProjectSettings.globalize_path(backend_path)
	if backend_path.simplify_path() == frontend_path.simplify_path():
		return {"success": false, "error": "Frontend and backend catalogs must be separate files."}
	if not FileAccess.file_exists(backend_path):
		return {"success": false, "error": "Backend catalog not found: " + backend_path}
	var original_text := FileAccess.get_file_as_string(frontend_path)
	var catalog: Dictionary = JSON.parse_string(original_text)
	var backend: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(backend_path))
	if catalog != backend:
		return {"success": false, "error": "Frontend and backend catalogs differ. Reconcile them before exporting collision."}
	var count := 0
	var changes := 0
	var writes := {}
	for spec: Dictionary in catalog.items:
		var packed := ResourceLoader.load(str(spec.scenePath), "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		if packed == null:
			return {"success": false, "error": "Could not load " + str(spec.scenePath)}
		var scene := packed.instantiate()
		if str(scene.get("furniture_id")) != str(spec.id):
			scene.free()
			return {"success": false, "error": "Furniture ID does not match the catalog: " + str(spec.scenePath)}
		var collision := scene.get_node_or_null("Collision") as TileMapLayer
		if layers.has(str(spec.id)):
			var edited := layers[str(spec.id)] as TileMapLayer
			if collision == null or edited == null:
				scene.free()
				return {"success": false, "error": "Missing source or edited Collision layer: " + str(spec.id)}
			collision.position = edited.position
			collision.tile_map_data = edited.tile_map_data
		var result := read_cells(collision, spec)
		if bool(result.success) and layers.has(str(spec.id)) and not check:
			var packed_scene := PackedScene.new()
			var temporary := "user://guild-collision-%d-%s.tscn" % [OS.get_process_id(), str(spec.id)]
			if packed_scene.pack(scene) != OK or ResourceSaver.save(packed_scene, temporary) != OK:
				scene.free()
				return {"success": false, "error": "Could not prepare furniture scene: " + str(spec.id)}
			writes[ProjectSettings.globalize_path(str(spec.scenePath))] = FileAccess.get_file_as_string(temporary)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		scene.free()
		if not bool(result.success):
			return {"success": false, "error": str(spec.id) + ": " + str(result.error)}
		if not spec.has("collisionCells") or not _same_cells(spec.collisionCells, result.cells) or bool(spec.blocksMovement) != (not result.cells.is_empty()):
			changes += 1
		spec.collisionCells = result.cells
		spec.blocksMovement = not result.cells.is_empty()
		count += 1
	if check:
		return {"success": changes == 0, "count": count, "changed": changes, "error": "%d collision layers need exporting." % changes}
	if changes > 0 or not writes.is_empty():
		var text := JSON.stringify(catalog, "  ", false) + "\n"
		writes[frontend_path] = text
		writes[backend_path] = text
		var saved := write_files(writes)
		if not bool(saved.success):
			return saved
	return {"success": true, "count": count, "changed": changes}


static func write_files(writes: Dictionary) -> Dictionary:
	# Stage every scene and both catalogs before replacing any source file.
	var originals := {}
	for path: String in writes:
		originals[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null
		var file := FileAccess.open(path + ".collision-export.tmp", FileAccess.WRITE)
		if file == null:
			_remove_staged(writes)
			return {"success": false, "error": "Cannot write collision file: " + path}
		file.store_string(str(writes[path]))
		file.flush()
		var error := file.get_error()
		file.close()
		if error != OK:
			_remove_staged(writes)
			return {"success": false, "error": "Could not finish writing collision file: " + path}
	for path: String in writes:
		if DirAccess.rename_absolute(path + ".collision-export.tmp", path) != OK:
			for restore: String in originals:
				if originals[restore] == null:
					DirAccess.remove_absolute(restore)
					continue
				var file := FileAccess.open(restore, FileAccess.WRITE)
				if file != null:
					file.store_string(str(originals[restore]))
					file.close()
			_remove_staged(writes)
			return {"success": false, "error": "Could not replace collision file: " + path}
	return {"success": true}


static func _remove_staged(writes: Dictionary) -> void:
	for path: String in writes:
		if FileAccess.file_exists(path + ".collision-export.tmp"):
			DirAccess.remove_absolute(path + ".collision-export.tmp")

static func _same_cells(first: Array, second: Array) -> bool:
	if first.size() != second.size():
		return false
	for index: int in range(first.size()):
		# JSON numbers load as floats; TileMap coordinates are integers.
		if Vector2(first[index][0], first[index][1]) != Vector2(second[index][0], second[index][1]):
			return false
	return true
