extends SceneTree

const Templates := preload("res://tools/guild_room_template_authoring.gd")
const Collision := preload("res://tools/guild_furniture_collision_authoring.gd")
const Catalog := preload("res://scripts/world/guild_base_furniture_catalog.gd")
var failed := false

func _init() -> void:
	_run.call_deferred()

func _tables(scene: Node2D) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for object: Node2D in Templates._objects(scene):
		if str(object.furniture_id) == "table_small":
			result.append(object)
	return result

func _run() -> void:
	if "--capture-only" in OS.get_cmdline_user_args():
		await _capture()
		quit(0)
		return
	for template: Dictionary in Templates.templates():
		var scene: Node2D = load(Templates.FOLDER + str(template.id) + ".tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		var objects := Templates._objects(scene)
		_check(objects.size() == template.items.size() and scene.has_node("RoomVisual"), "Complete saved template includes terrain, furniture and attached decorations")
		for object: Node in objects:
			_check(scene.is_editable_instance(object) and object.has_node("Collision"), "Every furniture instance exposes editable Collision children")
		var unchanged := Templates.collect(scene)
		_check(bool(unchanged.success) and unchanged.layers.is_empty(), "A saved template has no collision overrides to export")
		Templates._free_layers(unchanged.get("layers", {}))
		if str(template.id) == "guild-room-1-template":
			await _edit_and_export(scene)
		else:
			scene.free()
	var pillows := ["stool", "stool_cyan", "stool_blue", "stool_green", "stool_pink"]
	for id: String in pillows:
		var spec := Catalog.item(id)
		_check(not bool(spec.blocksMovement) and spec.collisionCells.is_empty(), "All pillow colours are walkable")
		var cushion: Node2D = load(str(spec.scenePath)).instantiate()
		cushion.configure(null, {"id": id, "furnitureId": id, "x": 9, "y": 12, "width": 1, "height": 1, "parentId": null, "slot": null}, true)
		_check(cushion.z_index == 2, "Cushions render beneath a player standing on them")
		cushion.free()
	var cafe: Dictionary = Templates.templates()[0]
	var blocked := Catalog.blocked_cells(cafe.items)
	for cell: Vector2i in [Vector2i(12, 4), Vector2i(12, 6), Vector2i(17, 4), Vector2i(17, 6), Vector2i(4, 12), Vector2i(9, 12), Vector2i(14, 12), Vector2i(8, 14), Vector2i(13, 14), Vector2i(18, 14)]:
		_check(not blocked.has(cell), "Both composite and separate cafe pillows allow standing: " + str(cell))
	_check(blocked.has(Vector2i(16, 4)), "Adjacent solid cafe furniture still blocks walking")
	for id: String in ["design_kitchen_counter", "design_cafe_table_set", "design_cafe_corner_table"]:
		var composite: Node2D = load(str(Catalog.item(id).scenePath)).instantiate()
		var details := composite.get_node("FloorDetails0") as TileMapLayer
		_check(details.get_used_cells().size() > 0 and details.z_index == 2 and not details.z_as_relative, "Embedded cushions also draw below standing players")
		composite.free()
	if "--capture" in OS.get_cmdline_user_args():
		await _capture()
	print("Guild room template authoring: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _edit_and_export(scene: Node2D) -> void:
	var tables := _tables(scene)
	var layer := tables[0].get_node("Collision") as TileMapLayer
	layer.erase_cell(Vector2i(2, 0))
	layer.erase_cell(Vector2i(1, 1))
	layer.erase_cell(Vector2i(2, 1))
	var edits := Templates.collect(scene)
	_check(bool(edits.success) and edits.layers.size() == 1, "One edited copy changes its shared furniture shape")
	Templates._free_layers(edits.get("layers", {}))
	var path := "user://room-template-%d" % OS.get_process_id()
	var packed := PackedScene.new()
	_check(packed.pack(scene) == OK and ResourceSaver.save(packed, path + ".tscn") == OK, "Edited template saves without detaching source furniture scenes")
	scene.free()
	scene = ResourceLoader.load(path + ".tscn", "PackedScene", ResourceLoader.CACHE_MODE_IGNORE).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	tables = _tables(scene)
	edits = Templates.collect(scene)
	_check(bool(edits.success) and edits.layers.size() == 1, "Painted instance overrides survive reopening the complete template")
	Templates._free_layers(edits.get("layers", {}))
	var source_path := str(Catalog.item("table_small").scenePath)
	var original := FileAccess.get_file_as_string(source_path)
	var source_scene: Node2D = load(source_path).instantiate()
	packed.pack(source_scene)
	ResourceSaver.save(packed, path + "-furniture.tscn")
	source_scene.free()
	var fixture := Catalog.load_data().duplicate(true)
	for spec: Dictionary in fixture.items:
		if str(spec.id) == "table_small":
			spec.scenePath = path + "-furniture.tscn"
	for target: String in [path + "-front.json", path + "-back.json"]:
		var file := FileAccess.open(target, FileAccess.WRITE)
		file.store_string(JSON.stringify(fixture))
		file.close()
	var exported := Templates.export_scene(scene, path + "-back.json", path + "-front.json")
	_check(bool(exported.success) and int(exported.get("changed", 0)) == 1, "Template export saves the edited source furniture and both catalogs")
	_check(FileAccess.get_file_as_string(path + "-front.json") == FileAccess.get_file_as_string(path + "-back.json"), "Template export keeps client and server collision identical")
	var saved := Collision.load_existing_layer(path + "-furniture.tscn")
	var saved_cells := Collision.read_cells(saved, Catalog.item("table_small"))
	_check(bool(saved_cells.success) and saved_cells.cells == [[0, 0], [1, 0], [0, 1]], "Source furniture receives the exact painted shape")
	saved.free()
	for table: Node2D in tables:
		_check(table.get_node("Collision").get_used_cells().size() == 3, "Repeated copies synchronize after export")
	_check(FileAccess.get_file_as_string(source_path) == original, "Isolated export test leaves project furniture unchanged")
	var staged_path := ProjectSettings.globalize_path(path + "-front.json")
	var before := FileAccess.get_file_as_string(staged_path)
	var staged := Collision.write_files({staged_path: "replacement", ProjectSettings.globalize_path(path + "-missing/file.json"): "replacement"})
	_check(not bool(staged.success) and FileAccess.get_file_as_string(staged_path) == before and not FileAccess.file_exists(staged_path + ".collision-export.tmp"), "A failed staging write leaves all existing files unchanged and removes staging files")
	scene.free()
	for suffix: String in [".tscn", "-furniture.tscn", "-front.json", "-back.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	scene = load(Templates.FOLDER + "guild-room-1-template.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	tables = _tables(scene)
	tables[0].get_node("Collision").erase_cell(Vector2i(0, 0))
	tables[1].get_node("Collision").erase_cell(Vector2i(1, 0))
	_check(not bool(Templates.collect(scene).success), "Contradictory edits on two copies are rejected")
	tables[0].get_node("Collision").set_cell(Vector2i(0, 0), 0, Vector2i.ZERO)
	tables[1].get_node("Collision").set_cell(Vector2i(1, 0), 0, Vector2i.ZERO)
	tables[0].position.x += 32
	_check(not bool(Templates.collect(scene).success), "Moved furniture cannot silently export a different template layout")
	tables[0].position.x -= 32
	var carpet := scene.get_node("Furniture/RedCarpet_04/Collision") as TileMapLayer
	carpet.set_cell(Vector2i(2, 1), 0, Vector2i.ZERO)
	_check(not bool(Templates.collect(scene).success), "Resized carpet rejects collision that cannot repeat with its nine-slice artwork")
	scene.free()
	var narrow := Node2D.new()
	narrow.set_meta("collision_baseline", [[1, 1]])
	var mask := Collision.create_layer(Catalog.item("red_carpet"))
	narrow.add_child(mask)
	mask.position = Vector2(0, -64)
	var retained := Templates._read(narrow, Catalog.item("red_carpet"), {"width": 2, "height": 2})
	_check(bool(retained.success) and retained.cells == [[1, 1]], "A narrow carpet preserves the latest baseline of invisible centre sections")
	narrow.free()

func _capture() -> void:
	for template: Dictionary in Templates.templates():
		var viewport := SubViewport.new()
		viewport.size = Vector2i(736, 608)
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var scene: Node2D = load(Templates.FOLDER + str(template.id) + ".tscn").instantiate()
		viewport.add_child(scene)
		for object: Node2D in Templates._objects(scene):
			object.get_node("Collision").show()
		for frame in range(4):
			await process_frame
		RenderingServer.force_draw(false)
		viewport.get_texture().get_image().save_png("/tmp/%s-authoring.png" % str(template.id))
		viewport.free()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
