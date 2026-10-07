extends "res://scripts/world/map_metadata.gd"

## Shared room template. The server supplies a guild-specific map ID on entry.
@export_enum("main_hall", "left_room", "right_room", "elevator") var room_key := "main_hall"
@export var room_size := Vector2i(30, 40)
@export var walkable_rects: Array[Rect2i] = []
@export var blocked_rects: Array[Rect2i] = []

var guild_id := 0
var base_town_id := ""
var access_refresh_in_flight := false


func _ready() -> void:
	_build_room_collision()
	super._ready()
	if room_key == "elevator":
		# Until its artist layer names are standardized, expose the foreground
		# layer to the game's existing object depth sorter.
		var visual := get_node("Visual")
		var layers := visual.get_children()
		if not layers.is_empty():
			layers[-1].name = "ObjectsTop"
			layers[-1].set_meta("tiled_name", "ObjectsTop")
	var guild_service := get_node_or_null("/root/GuildService")
	if guild_service != null:
		guild_service.membership_changed.connect(_on_membership_changed)
	var timer := Timer.new()
	timer.wait_time = 15.0
	timer.autostart = true
	timer.timeout.connect(_refresh_access)
	add_child(timer)


func configure_guild_base_instance(instance_map_id: String) -> void:
	var parts := instance_map_id.split(":")
	if parts.size() != 4 or parts[0] != "guild_base" or parts[3] != room_key:
		push_error("Invalid Guild Base instance for room %s." % room_key)
		return
	if not parts[2].is_valid_int() or int(parts[2]) <= 0:
		push_error("Invalid Guild Base owner.")
		return
	guild_id = int(parts[2])
	base_town_id = parts[1]
	map_id = instance_map_id
	location_id = instance_map_id
	music_profile_id = "kanto." + base_town_id.trim_prefix("kanto_")


func is_walkable_tile(tile: Vector2i) -> bool:
	var walkable := false
	for rectangle: Rect2i in walkable_rects:
		if rectangle.has_point(tile):
			walkable = true
			break
	if not walkable:
		return false
	for rectangle: Rect2i in blocked_rects:
		if rectangle.has_point(tile):
			return false
	return true


func _build_room_collision() -> void:
	# Terrain collision belongs to the runtime scene, independently of TMX art.
	var layer := get_node("Collision") as TileMapLayer
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(32, 32)
	tiles.add_physics_layer()
	tiles.set_physics_layer_collision_layer(0, 1)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(Image.create(32, 32, false, Image.FORMAT_RGBA8))
	atlas.texture_region_size = Vector2i(32, 32)
	atlas.create_tile(Vector2i.ZERO)
	tiles.add_source(atlas, 0)
	var data := atlas.get_tile_data(Vector2i.ZERO, 0)
	data.set_collision_polygons_count(0, 1)
	data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16),
	]))
	layer.tile_set = tiles
	for y: int in range(-1, room_size.y + 1):
		for x: int in range(-1, room_size.x + 1):
			var tile := Vector2i(x, y)
			if not is_walkable_tile(tile):
				layer.set_cell(tile, 0, Vector2i.ZERO)
	layer.update_internals()
	collision = layer


func _on_membership_changed(_membership: Dictionary) -> void:
	_refresh_access.call_deferred()


func _refresh_access() -> void:
	if access_refresh_in_flight or guild_id <= 0 or not AuthService.is_authenticated() or GameState.current_map != self:
		return
	var world: Node = GameState.get_world()
	if world == null or world.is_map_transition_in_progress() or world.is_in_battle:
		return
	access_refresh_in_flight = true
	var result: Dictionary = await PlayerGameStateService.load_player_position()
	access_refresh_in_flight = false
	if not is_inside_tree() or GameState.current_map != self or not bool(result.get("success", false)):
		return
	if world.is_map_transition_in_progress() or world.is_in_battle:
		return
	var state: Dictionary = result.get("state", {})
	if str(state.get("mapId", map_id)) == map_id:
		return
	var begun: Dictionary = await world.begin_authorized_teleport(false)
	if bool(begun.get("success", false)):
		await world.apply_authorized_teleport_state(state)
