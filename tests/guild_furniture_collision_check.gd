extends SceneTree

const Catalog := preload("res://scripts/world/guild_base_furniture_catalog.gd")
const Authoring := preload("res://tools/guild_furniture_collision_authoring.gd")
const Furniture := preload("res://scripts/world/guild_base_furniture.gd")
var failed := false

class Mask extends Node2D:
	func get_active_floor_region() -> Rect2:
		return Rect2(128, 32, 512, 480)

class Room extends Node2D:
	var room_key := "left_room"
	var room_size := Vector2i(23, 19)
	func is_walkable_tile(cell: Vector2i) -> bool:
		return (Rect2i(4, 4, 15, 12).has_point(cell) and cell not in [Vector2i(4, 15), Vector2i(18, 15)]) or Rect2i(19, 8, 1, 3).has_point(cell)

func _init() -> void:
	_run.call_deferred()

func _placement(id: String, x := 6, y := 10) -> Dictionary:
	var spec := Catalog.item(id)
	return {"id": id, "furnitureId": id, "x": x, "y": y, "width": spec.footprint[0], "height": spec.footprint[1], "parentId": null, "slot": null}

func _run() -> void:
	var checked := Authoring.export_catalogs(Authoring.default_backend_path(), true)
	_check(bool(checked.success) and int(checked.get("count", 0)) == Catalog.load_data().items.size(), "Every saved authoring layer matches both catalogs")
	var spec := Catalog.item("table_small")
	var original := spec.duplicate(true)
	var layer := Authoring.create_layer(spec)
	for cell: Vector2i in [Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)]:
		layer.erase_cell(cell)
	var painted := Authoring.read_cells(layer, spec)
	_check(bool(painted.success) and painted.cells == [[0, 0], [1, 0], [0, 1]], "Erasing cells exports the exact L-shaped collision")
	var authored_scene := Node2D.new()
	authored_scene.set_script(Furniture)
	authored_scene.furniture_id = str(spec.id)
	authored_scene.add_child(layer)
	layer.owner = authored_scene
	var packed := PackedScene.new()
	_check(packed.pack(authored_scene) == OK, "Painted layer can be saved with the furniture")
	var path := "user://painted-furniture-%d.tscn" % OS.get_process_id()
	_check(ResourceSaver.save(packed, path) == OK, "Authoring scene saves")
	var preserved := Authoring.load_existing_layer(path)
	var preserved_cells := Authoring.read_cells(preserved, spec)
	_check(bool(preserved_cells.success) and preserved_cells.cells == painted.cells, "The visual importer retains edited collision from the saved scene")
	preserved.free()
	var front_path := path.replace(".tscn", "-front.json")
	var back_path := path.replace(".tscn", "-back.json")
	var fixture := {"items": [original.duplicate(true)]}
	fixture.items[0].scenePath = path
	for target: String in [front_path, back_path]:
		var file := FileAccess.open(target, FileAccess.WRITE)
		file.store_string(JSON.stringify(fixture))
		file.close()
	var exported := Authoring.export_catalogs(back_path, false, front_path)
	_check(bool(exported.success) and int(exported.get("changed", 0)) == 1, "Export updates a changed drawing in both catalogs")
	var exported_text := FileAccess.get_file_as_string(front_path)
	_check(exported_text == FileAccess.get_file_as_string(back_path), "Paired export writes identical complete catalogs")
	_check(bool(Authoring.export_catalogs(back_path, true, front_path).success), "Saved exported masks are stable when JSON loads numeric cells")
	layer.set_cell(Vector2i(9, 9), 0, Vector2i.ZERO)
	packed.pack(authored_scene)
	ResourceSaver.save(packed, path)
	_check(not bool(Authoring.export_catalogs(back_path, false, front_path).success), "Invalid drawings abort the paired export")
	_check(exported_text == FileAccess.get_file_as_string(front_path) and exported_text == FileAccess.get_file_as_string(back_path), "A rejected export preserves both original catalogs")
	layer.erase_cell(Vector2i(9, 9))
	for target: String in [front_path, back_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	spec.collisionCells = painted.cells
	var table := _placement("table_small")
	_check(Catalog.movement_cells(table) == [Vector2i(6, 10), Vector2i(7, 10), Vector2i(6, 11)], "Placement translates painted cells without filling the bounding rectangle")
	var room := Room.new()
	var mask := Mask.new()
	mask.name = "FloorVisibilityMask"
	room.add_child(mask)
	root.add_child(room)
	_check(Catalog.validate(room, [table, _placement("bin_full", 8, 11)]) == "", "Another piece fits in the unpainted part of the footprint")
	_check(Catalog.validate(room, [table, _placement("bin_full", 6, 10)]) == "overlap", "Painted cells still reject overlapping furniture")
	var placed := Furniture.instantiate_placement(room, table, [table])
	room.add_child(placed)
	_check(not placed.get_node("Collision").visible, "The authoring overlay stays hidden during play")
	_check(placed.blocks_world_position(Vector2(208, 336)), "Walking is blocked on a painted cell")
	_check(not placed.blocks_world_position(Vector2(240, 368)), "Walking is allowed through an unpainted cell")
	var preview := Furniture.instantiate_placement(room, table, [table], true)
	room.add_child(preview)
	_check(not preview.blocks_world_position(Vector2(208, 336)), "Placement previews do not block movement")
	layer.set_cell(Vector2i(9, 9), 0, Vector2i.ZERO)
	_check(not bool(Authoring.read_cells(layer, spec).success), "Collision outside the artwork is rejected before export")
	layer.erase_cell(Vector2i(9, 9))
	layer.position.x = 1
	_check(not bool(Authoring.read_cells(layer, spec).success), "Misaligned authoring layers cannot produce differing client/server cells")
	authored_scene.free()
	var decoration := Authoring.create_layer(Catalog.item("flowers"))
	decoration.set_cell(Vector2i.ZERO, 0, Vector2i.ZERO)
	_check(not bool(Authoring.read_cells(decoration, Catalog.item("flowers")).success), "Tabletop floor collision is authored on the parent furniture, not silently ignored")
	decoration.free()
	spec.merge(original, true)
	var rug_spec := Catalog.item("red_carpet")
	var rug_original := rug_spec.duplicate(true)
	rug_spec.collisionCells = [[0, 0], [2, 2]]
	rug_spec.blocksMovement = true
	var rug := _placement("red_carpet", 5, 8)
	rug.width = 7
	rug.height = 6
	_check(Catalog.movement_cells(rug) == [Vector2i(5, 8), Vector2i(11, 13)], "Resizable furniture expands corner collision with the same nine-slice rule as its art")
	rug_spec.merge(rug_original, true)
	room.free()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			var viewport := SubViewport.new()
			viewport.size = Vector2i(448, 448)
			viewport.disable_3d = true
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var example := load(str(original.scenePath)).instantiate() as Node2D
			example.position = Vector2(32, 416)
			example.scale = Vector2(4, 4)
			viewport.add_child(example)
			var collision := example.get_node("Collision") as TileMapLayer
			collision.clear()
			for cell: Array in painted.cells:
				collision.set_cell(Vector2i(cell[0], cell[1]), 0, Vector2i.ZERO)
			collision.show()
			for frame in range(4):
				await process_frame
			RenderingServer.force_draw(false)
			viewport.get_texture().get_image().save_png(argument.trim_prefix("--capture="))
			viewport.free()
	print("Guild furniture painted collision: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
