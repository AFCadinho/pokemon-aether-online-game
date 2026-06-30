@tool
extends RefCounted

const PathUtils := preload("res://addons/tiled_tmx_importer/importer/tmx_path_utils.gd")
const Schema := preload("res://addons/pokeaether_tiled_importer/importer/pokeaether_tiled_schema.gd")
const RuntimeScript := preload("res://addons/pokeaether_tiled_importer/runtime/pokeaether_imported_map_runtime.gd")

const RESERVED_RUNTIME_CONTAINER_NAMES: Array[String] = [
	"Spawns",
	"Exits",
	"Entities",
	"Items",
	"EncounterRegions",
	"Triggers",
]


func build_scene(
	tmx_map_data: Dictionary,
	tile_set: TileSet,
	tileset_builder: RefCounted,
	imported_map_data: Resource
) -> Node2D:
	var root := Node2D.new()
	root.name = PathUtils.sanitize_node_name(str(imported_map_data.get("map_id")).to_pascal_case(), "ImportedMap")
	root.set_script(RuntimeScript)
	root.set("map_data", imported_map_data)
	root.set_meta("pao_generated", true)
	root.set_meta("pao_schema_version", int(imported_map_data.get("schema_version")))
	root.set_meta("tiled_source_path", str(tmx_map_data.get("source_path", "")))
	root.set_meta("tiled_properties", tmx_map_data.get("properties", {}).duplicate(true))

	var layer_by_name := _add_tile_layers(root, tmx_map_data, tile_set, tileset_builder)
	_ensure_required_tile_layers(root, tile_set, layer_by_name)
	_add_spawns(root, imported_map_data)
	_add_exits(root, imported_map_data)
	_add_entities(root, imported_map_data)
	_add_items(root, imported_map_data)
	_add_encounter_regions(root, imported_map_data)
	_add_triggers(root, imported_map_data)
	return root


func _add_tile_layers(root: Node2D, map_data: Dictionary, tile_set: TileSet, tileset_builder: RefCounted) -> Dictionary:
	var layer_by_name := {}
	var used_names := {}
	for reserved_name in RESERVED_RUNTIME_CONTAINER_NAMES:
		used_names[str(reserved_name)] = true

	var layer_index := 0
	for layer: Dictionary in map_data.get("layers", []):
		var tiled_name := str(layer.get("name", ""))
		var is_special := Schema.is_special_tile_layer(tiled_name)
		if not bool(layer.get("visible", true)) and not is_special:
			continue

		var layer_node := _create_tile_layer(layer, tile_set, layer_index, used_names)
		if Schema.is_hidden_runtime_tile_layer(tiled_name):
			layer_node.visible = false

		root.add_child(layer_node)
		layer_node.owner = root
		_set_tile_layer_cells(layer_node, layer, map_data, tileset_builder)

		if is_special:
			layer_by_name[tiled_name] = layer_node
		layer_index += 1

	return layer_by_name


func _ensure_required_tile_layers(root: Node2D, tile_set: TileSet, layer_by_name: Dictionary) -> void:
	for layer_name in Schema.REQUIRED_DIRECT_TILE_LAYERS:
		if layer_by_name.has(layer_name):
			continue

		var layer_node := TileMapLayer.new()
		layer_node.name = layer_name
		layer_node.tile_set = tile_set
		layer_node.visible = false
		layer_node.set_meta("pao_generated_empty_layer", true)
		layer_node.set_meta("tiled_name", layer_name)
		root.add_child(layer_node)
		layer_node.owner = root


func _create_tile_layer(layer: Dictionary, tile_set: TileSet, layer_index: int, used_names: Dictionary) -> TileMapLayer:
	var layer_node := TileMapLayer.new()
	var tiled_name := str(layer.get("name", ""))
	var layer_name := PathUtils.sanitize_node_name(tiled_name, "Layer%d" % layer_index)
	layer_node.name = _make_unique_node_name(layer_name, int(layer.get("id", layer_index)), used_names)
	layer_node.tile_set = tile_set
	layer_node.visible = bool(layer.get("visible", true))
	layer_node.modulate.a = float(layer.get("opacity", 1.0))
	layer_node.position = Vector2(float(layer.get("offset_x", 0.0)), float(layer.get("offset_y", 0.0)))
	layer_node.z_index = -99 if tiled_name == Schema.TILE_LAYER_COLLISION else layer_index
	layer_node.set_meta("tiled_name", tiled_name)
	layer_node.set_meta("tiled_layer_id", int(layer.get("id", 0)))
	layer_node.set_meta("tiled_properties", layer.get("properties", {}).duplicate(true))
	return layer_node


func _set_tile_layer_cells(layer_node: TileMapLayer, layer: Dictionary, map_data: Dictionary, tileset_builder: RefCounted) -> void:
	var width := int(layer.get("width", map_data.get("width", 0)))
	if width <= 0:
		return

	var raw_gids: Array = layer.get("raw_gids", [])
	for index in range(raw_gids.size()):
		var raw_gid := int(raw_gids[index])
		if raw_gid == 0:
			continue

		var cell: Dictionary = tileset_builder.get_cell_for_raw_gid(raw_gid)
		if cell.is_empty():
			continue

		var coords := Vector2i(index % width, index / width)
		layer_node.set_cell(
			coords,
			int(cell.get("source_id", -1)),
			cell.get("atlas_coords", Vector2i.ZERO),
			int(cell.get("alternative_tile", 0))
		)


func _add_spawns(root: Node2D, map_data: Resource) -> void:
	var spawns_root := Node2D.new()
	spawns_root.name = "Spawns"
	root.add_child(spawns_root)
	spawns_root.owner = root

	for spawn: Resource in map_data.get("spawns"):
		var marker := Marker2D.new()
		marker.name = PathUtils.sanitize_node_name(str(spawn.get("spawn_id")), "Spawn")
		marker.position = spawn.get("position")
		_apply_resource_metadata(marker, "pao_spawn", spawn)
		spawns_root.add_child(marker)
		marker.owner = root


func _add_exits(root: Node2D, map_data: Resource) -> void:
	var exits_root := Node2D.new()
	exits_root.name = "Exits"
	root.add_child(exits_root)
	exits_root.owner = root

	for warp: Resource in map_data.get("warps"):
		var area := _create_rectangle_area(PathUtils.sanitize_node_name(str(warp.get("warp_id")), "Warp"), warp.get("rect"))
		_apply_resource_metadata(area, "pao_warp", warp)
		exits_root.add_child(area)
		_set_owner_recursive(area, root)


func _add_entities(root: Node2D, map_data: Resource) -> void:
	var entities_root := Node2D.new()
	entities_root.name = "Entities"
	entities_root.z_index = 5
	root.add_child(entities_root)
	entities_root.owner = root

	var npcs_root := Node2D.new()
	npcs_root.name = "NPCs"
	entities_root.add_child(npcs_root)
	npcs_root.owner = root

	for npc: Resource in map_data.get("npcs"):
		var marker := Marker2D.new()
		marker.name = PathUtils.sanitize_node_name(str(npc.get("npc_id")), "NPC")
		marker.position = npc.get("position")
		_apply_resource_metadata(marker, "pao_npc", npc)
		npcs_root.add_child(marker)
		marker.owner = root

	var players_root := Node2D.new()
	players_root.name = "Players"
	entities_root.add_child(players_root)
	players_root.owner = root


func _add_items(root: Node2D, map_data: Resource) -> void:
	var items_root := Node2D.new()
	items_root.name = "Items"
	root.add_child(items_root)
	items_root.owner = root

	for item: Resource in map_data.get("items"):
		var marker := Marker2D.new()
		marker.name = PathUtils.sanitize_node_name(str(item.get("item_spawn_id")), "Item")
		marker.position = item.get("position")
		_apply_resource_metadata(marker, "pao_item", item)
		items_root.add_child(marker)
		marker.owner = root


func _add_encounter_regions(root: Node2D, map_data: Resource) -> void:
	var regions_root := Node2D.new()
	regions_root.name = "EncounterRegions"
	root.add_child(regions_root)
	regions_root.owner = root

	for region: Resource in map_data.get("encounter_regions"):
		var node := _create_region_placeholder(
			PathUtils.sanitize_node_name(str(region.get("encounter_region_id")), "EncounterRegion"),
			str(region.get("shape")),
			region.get("rect")
		)
		_apply_resource_metadata(node, "pao_encounter_region", region)
		regions_root.add_child(node)
		_set_owner_recursive(node, root)


func _add_triggers(root: Node2D, map_data: Resource) -> void:
	var triggers_root := Node2D.new()
	triggers_root.name = "Triggers"
	root.add_child(triggers_root)
	triggers_root.owner = root

	for trigger: Resource in map_data.get("triggers"):
		var node := _create_region_placeholder(
			PathUtils.sanitize_node_name(str(trigger.get("trigger_id")), "Trigger"),
			str(trigger.get("shape")),
			trigger.get("rect")
		)
		_apply_resource_metadata(node, "pao_trigger", trigger)
		triggers_root.add_child(node)
		_set_owner_recursive(node, root)


func _create_region_placeholder(node_name: String, shape: String, rect: Rect2) -> Node2D:
	if shape == "rectangle":
		return _create_rectangle_area(node_name, rect)

	var node := Node2D.new()
	node.name = node_name
	node.position = rect.position
	return node


func _create_rectangle_area(node_name: String, rect: Rect2) -> Area2D:
	var area := Area2D.new()
	area.name = node_name
	area.position = rect.position + rect.size * 0.5
	area.monitoring = false
	area.monitorable = false
	area.collision_layer = 0
	area.collision_mask = 0

	var shape := RectangleShape2D.new()
	shape.size = rect.size

	var collision_shape := CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	collision_shape.shape = shape
	area.add_child(collision_shape)
	return area


func _apply_resource_metadata(node: Node, meta_name: String, resource: Resource) -> void:
	node.set_meta("pao_placeholder_type", meta_name.trim_prefix("pao_"))
	node.set_meta("pao_resource_id", _resource_identifier(meta_name, resource))
	node.set_meta("pao_source_layer_name", str(resource.get("source_layer_name")))
	node.set_meta("pao_source_object_id", int(resource.get("source_object_id")))
	node.set_meta("pao_properties", resource.get("properties"))


func _resource_identifier(meta_name: String, resource: Resource) -> String:
	match meta_name:
		"pao_spawn":
			return str(resource.get("spawn_id"))
		"pao_warp":
			return str(resource.get("warp_id"))
		"pao_npc":
			return str(resource.get("npc_id"))
		"pao_item":
			return str(resource.get("item_spawn_id"))
		"pao_encounter_region":
			return str(resource.get("encounter_region_id"))
		"pao_trigger":
			return str(resource.get("trigger_id"))
		_:
			return ""


func _make_unique_node_name(base_name: String, source_id: int, used_names: Dictionary) -> String:
	var candidate := base_name
	if not used_names.has(candidate):
		used_names[candidate] = true
		return candidate

	candidate = "%s_%d" % [base_name, source_id]
	var suffix := 2
	while used_names.has(candidate):
		candidate = "%s_%d_%d" % [base_name, source_id, suffix]
		suffix += 1

	used_names[candidate] = true
	return candidate


func _set_owner_recursive(node: Node, owner: Node) -> void:
	node.owner = owner
	for child: Node in node.get_children():
		_set_owner_recursive(child, owner)
