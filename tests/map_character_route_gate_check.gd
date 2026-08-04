extends SceneTree

const MapCharacterBlockingScript := preload("res://scripts/world/map_character_blocking.gd")

var failed := false


class FakeGate extends Node2D:
	var route_gate_id := ""
	var open := false

	func is_gate_open() -> bool:
		return open

	func handles_route_gate(candidate_route_gate_id: String) -> bool:
		return route_gate_id == candidate_route_gate_id


func _init() -> void:
	var map := Node2D.new()
	var entities := Node2D.new()
	entities.name = "Entities"
	map.add_child(entities)
	var npcs := Node2D.new()
	npcs.name = "NPCs"
	entities.add_child(npcs)

	var north_gate := _add_gate(npcs, "north")
	var south_gate := _add_gate(npcs, "south")
	var route_gates := Node2D.new()
	route_gates.name = "RouteGates"
	map.add_child(route_gates)
	_add_route_gate_layer(route_gates, "north", Vector2i(1, 1))
	_add_route_gate_layer(route_gates, "south", Vector2i(2, 2))

	_check_equal(
		MapCharacterBlockingScript.get_closed_route_gate_npc(map, Vector2(48, 48)),
		north_gate,
		"north route-gate tile selects its matching guard"
	)
	_check_equal(
		MapCharacterBlockingScript.get_closed_route_gate_npc(map, Vector2(80, 80)),
		south_gate,
		"south route-gate tile selects its matching guard"
	)

	north_gate.open = true
	_check_equal(
		MapCharacterBlockingScript.get_closed_route_gate_npc(map, Vector2(48, 48)),
		null,
		"an open matching guard does not fall back to another closed guard"
	)

	map.free()
	quit(1 if failed else 0)


func _add_gate(parent: Node, gate_id: String) -> FakeGate:
	var gate := FakeGate.new()
	gate.route_gate_id = gate_id
	parent.add_child(gate)
	return gate


func _add_route_gate_layer(parent: Node, gate_id: String, cell: Vector2i) -> void:
	var image := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(32, 32)
	source.create_tile(Vector2i.ZERO)
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	tile_set.add_source(source, 0)

	var layer := TileMapLayer.new()
	layer.tile_set = tile_set
	layer.set_meta("route_gate_id", gate_id)
	layer.set_cell(cell, 0, Vector2i.ZERO)
	parent.add_child(layer)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
