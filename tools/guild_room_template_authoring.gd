@tool
extends RefCounted

const Collision := preload("res://tools/guild_furniture_collision_authoring.gd")
const Catalog := preload("res://scripts/world/guild_base_furniture_catalog.gd")
const Furniture := preload("res://scripts/world/guild_base_furniture.gd")
const DESIGNS := "res://data/guild_room_designs.json"
const FOLDER := "res://scenes/world/guild_base/templates/"

static func templates() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string(DESIGNS)).templates

static func build(template: Dictionary) -> Node2D:
	var scene := Node2D.new()
	scene.name = "Room%dTemplate" % int(template.roomNumber)
	scene.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scene.set_meta("guild_room_template", str(template.id))
	scene.editor_description = "Paint Furniture/<piece>/Collision, then Project > Tools > Export Guild Furniture Collision. Collision changes apply to every use of that furniture. Layout positions come from guild_room_designs.json."
	var terrain: Node2D = load("res://generated/tiled_visuals/guild_base_%s/guild_base_%s.visual.tscn" % [template.roomKey, template.roomKey]).instantiate()
	terrain.name = "RoomVisual"
	scene.add_child(terrain)
	terrain.owner = scene
	var container := Node2D.new()
	container.name = "Furniture"
	scene.add_child(container)
	container.owner = scene
	var objects := {}
	for value: Dictionary in template.items:
		var spec := Catalog.item(str(value.furnitureId))
		var object: Node2D = load(str(spec.scenePath)).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		object.name = "%s_%02d" % [str(value.furnitureId).to_pascal_case(), objects.size() + 1]
		object.set_meta("placement", value.duplicate(true))
		object.set_meta("collision_baseline", spec.collisionCells.duplicate(true))
		object.editor_description = "Collision edits affect all %s furniture, including other templates. Repeated copies are synchronized on export." % str(value.furnitureId)
		if value.parentId == null:
			container.add_child(object)
			object.configure(scene, value, true)
		else:
			var parent: Node2D = objects[str(value.parentId)]
			parent.add_child(object)
			object.configure_surface(scene, value, Catalog.item(str(parent.furniture_id)), true)
		object.owner = scene
		scene.set_editable_instance(object, true)
		_refresh_collision(object, spec, value)
		objects[str(value.id)] = object
	return scene

static func _objects(scene: Node) -> Array[Node]:
	var objects: Array[Node] = []
	for child: Node in scene.get_children():
		if child.has_meta("placement"):
			objects.append(child)
		objects.append_array(_objects(child))
	return objects

static func _expanded(spec: Dictionary, value: Dictionary) -> Array:
	if not bool(spec.resizable):
		return spec.collisionCells.duplicate(true)
	var mask := {}
	for cell: Array in spec.collisionCells:
		mask[Vector2i(cell[0], cell[1])] = true
	var result: Array = []
	for y: int in range(int(value.height)):
		for x: int in range(int(value.width)):
			if mask.has(_slice_cell(x, y, int(value.width), int(value.height))):
				result.append([x, y])
	return result

static func _slice_cell(x: int, y: int, width: int, height: int) -> Vector2i:
	return Vector2i(0 if x == 0 else (2 if x == width - 1 else 1), 0 if y == 0 else (2 if y == height - 1 else 1))

static func _refresh_collision(object: Node2D, spec: Dictionary, value: Dictionary) -> void:
	var layer := object.get_node("Collision") as TileMapLayer
	layer.clear()
	layer.position = Vector2(0, -int(value.height) * 32) if bool(spec.resizable) else Vector2(0, -int(spec.footprint[1]) * 32)
	for cell: Array in _expanded(spec, value):
		layer.set_cell(Vector2i(cell[0], cell[1]), 0, Vector2i.ZERO)
	layer.z_as_relative = false
	layer.z_index = 4095
	object.set_meta("collision_baseline", spec.collisionCells.duplicate(true))

static func _read(object: Node2D, spec: Dictionary, value: Dictionary) -> Dictionary:
	var actual := spec.duplicate(true)
	if bool(spec.resizable):
		actual.footprint = [int(value.width), int(value.height)]
		actual.visualSize = actual.footprint
		actual.visualOffset = [0, -int(value.height) * 32]
	var result := Collision.read_cells(object.get_node_or_null("Collision") as TileMapLayer, actual)
	if not bool(result.success) or not bool(spec.resizable):
		return result
	var painted := {}
	for cell: Array in result.cells:
		painted[Vector2i(cell[0], cell[1])] = true
	var slices := {}
	for y: int in range(int(value.height)):
		for x: int in range(int(value.width)):
			var key := _slice_cell(x, y, int(value.width), int(value.height))
			var blocked := painted.has(Vector2i(x, y))
			if slices.has(key) and slices[key] != blocked:
				return {"success": false, "error": "Resizable carpets repeat their edges and centre. Paint each repeated section consistently, or edit the source furniture scene."}
			slices[key] = blocked
	var cells: Array = []
	# A two-tile span has no centre sample: retain its baseline centre cells.
	var baseline: Array = object.get_meta("collision_baseline", spec.collisionCells)
	for y: int in range(3):
		for x: int in range(3):
			var key := Vector2i(x, y)
			var fallback := false
			for cell: Array in baseline:
				fallback = fallback or Vector2i(cell[0], cell[1]) == key
			if bool(slices.get(key, fallback)):
				cells.append([x, y])
	return {"success": true, "cells": cells}

static func collect(scene: Node2D) -> Dictionary:
	var template: Dictionary = {}
	for candidate: Dictionary in templates():
		if str(candidate.id) == str(scene.get_meta("guild_room_template", "")):
			template = candidate
	if template.is_empty():
		return {"success": false, "error": "Open a Guild room template scene first."}
	var expected := {}
	for value: Dictionary in template.items:
		expected[str(value.id)] = value
	var objects := _objects(scene)
	if objects.size() != expected.size():
		return {"success": false, "error": "Template furniture differs from the saved layout. Rebuild the template scene before exporting collision."}
	var layers := {}
	var seen := {}
	for object: Node2D in objects:
		var value: Dictionary = object.get_meta("placement")
		var spec := Catalog.item(str(object.furniture_id))
		if seen.has(str(value.id)) or not expected.has(str(value.id)) or value != expected[str(value.id)] or str(object.furniture_id) != str(value.furnitureId):
			_free_layers(layers)
			return {"success": false, "error": "Template placement metadata no longer matches the saved design."}
		seen[str(value.id)] = true
		var position := Vector2(int(value.x), int(value.y) + int(value.height)) * 32
		if value.parentId != null:
			var parent_spec := Catalog.item(str(expected[str(value.parentId)].furnitureId))
			position = Vector2(parent_spec.surfaceSlots[int(value.slot)][0], parent_spec.surfaceSlots[int(value.slot)][1])
		if not object.position.is_equal_approx(position) or object.scale != Vector2.ONE or not is_zero_approx(object.rotation) or not is_zero_approx(object.skew):
			_free_layers(layers)
			return {"success": false, "error": "Furniture was moved or transformed. This export changes collision only; restore its template position first."}
		var painted := _read(object, spec, value)
		if not bool(painted.success):
			_free_layers(layers)
			return {"success": false, "error": str(object.name) + ": " + str(painted.error)}
		var source := Collision.load_existing_layer(str(spec.scenePath))
		var current := Collision.read_cells(source, spec)
		if source != null:
			source.free()
		if not bool(current.success):
			_free_layers(layers)
			return current
		var baseline: Array = object.get_meta("collision_baseline", spec.collisionCells)
		if Collision._same_cells(painted.cells, current.cells) or Collision._same_cells(painted.cells, baseline):
			continue
		if not Collision._same_cells(current.cells, baseline):
			_free_layers(layers)
			return {"success": false, "error": str(spec.id) + " changed in its source scene. Refresh this template before editing its collision."}
		if layers.has(str(spec.id)):
			var previous := Collision.read_cells(layers[str(spec.id)], spec)
			if not Collision._same_cells(previous.cells, painted.cells):
				_free_layers(layers)
				return {"success": false, "error": "Two copies of %s have different edits. Use the same collision shape: furniture is shared." % str(spec.id)}
		else:
			var edited_spec := spec.duplicate(true)
			edited_spec.collisionCells = painted.cells
			layers[str(spec.id)] = Collision.create_layer(edited_spec)
	return {"success": true, "layers": layers}

static func export_scene(scene: Node2D, backend_path: String, frontend_path := Collision.CATALOG_PATH) -> Dictionary:
	var edits := collect(scene)
	if not bool(edits.success):
		return edits
	var result := Collision.export_catalogs(backend_path, false, frontend_path, edits.layers)
	_free_layers(edits.layers)
	if bool(result.success):
		var fresh: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(frontend_path))
		var specs := {}
		for spec: Dictionary in fresh.items:
			specs[str(spec.id)] = spec
		for object: Node2D in _objects(scene):
			_refresh_collision(object, specs[str(object.furniture_id)], object.get_meta("placement"))
	return result

static func _free_layers(layers: Dictionary) -> void:
	for layer: TileMapLayer in layers.values():
		layer.free()
