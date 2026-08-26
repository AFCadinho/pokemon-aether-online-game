extends SceneTree

const Route4Script := preload("res://scripts/world/kanto/routes/kanto_route_4.gd")
const ROUTE_SCENE_PATH := "res://scenes/overworld/kanto/routes/kanto_route_4.tscn"
const ROUTE_SCRIPT_PATH := "res://scripts/world/kanto/routes/kanto_route_4.gd"

var failed := false


func _init() -> void:
	var route_source := FileAccess.get_file_as_string(ROUTE_SCENE_PATH)
	var script_source := FileAccess.get_file_as_string(ROUTE_SCRIPT_PATH)
	_check(
		route_source.contains('[node name="Collision" type="TileMapLayer" parent="Tiles"'),
		"Route 4 keeps Collision under its Tiles branch"
	)
	_check(
		script_source.contains("MapLayerResolverScript.find_tilemap_layer("),
		"Route 4 resolves nested map layers"
	)
	_check(
		not script_source.contains("$Collision"),
		"Route 4 does not use the obsolete root Collision path"
	)
	_check(
		not script_source.contains("COLLISION_SOURCE_ID"),
		"Route 4 derives the boundary tile from its active TileSet"
	)

	var route := Route4Script.new()
	var collision := _build_collision_layer()
	route.add_child(collision)
	route.collision = collision
	route.call("_build_map_boundaries")

	for cell: Vector2i in [
		Vector2i(0, 0),
		Vector2i(99, 0),
		Vector2i(0, 49),
		Vector2i(99, 49),
		Vector2i(0, 25),
		Vector2i(99, 35),
		Vector2i(99, 40),
	]:
		_check(collision.get_cell_source_id(cell) == 0, "Route 4 closes boundary cell %s" % cell)
	for road_y: int in range(36, 40):
		_check(
			collision.get_cell_source_id(Vector2i(99, road_y)) < 0,
			"Route 4 leaves Cerulean road cell (99, %d) open" % road_y
		)

	route.free()
	quit(1 if failed else 0)


func _build_collision_layer() -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = "Collision"
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = ImageTexture.create_from_image(
		Image.create(32, 32, false, Image.FORMAT_RGBA8)
	)
	atlas_source.texture_region_size = Vector2i(32, 32)
	atlas_source.create_tile(Vector2i.ZERO)
	tile_set.add_source(atlas_source, 0)
	layer.tile_set = tile_set
	layer.set_cell(Vector2i(50, 25), 0, Vector2i.ZERO)
	return layer


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error("FAILED: %s" % label)
