extends Node2D
## Opt-in visual door. Uses existing map pixels and never changes collision,
## access checks, network state, or the server-authorized MapExit.

@export var access_enabled := true
@export var source_layers: Array[NodePath] = []
@export var players_path: NodePath
@export var access_lock_path: NodePath
@export var panel_size := Vector2(40, 44)
@export var activation_rect := Rect2(4, 16, 32, 72)
@export_range(0.01, 1.0) var animation_seconds := 0.18
@export var movement_sound_id := ""

@export var opening_color := Color("192c3b")

var open_amount := 0.0:
	set(value):
		open_amount = clampf(value, 0.0, 1.0)
		queue_redraw()
var wants_open := false
var pieces: Array[Dictionary] = []
var close_delay := 0.0
var movement_direction := 0
var arrival_open := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cache_panel_pieces()
	set_process(not pieces.is_empty())


func _process(delta: float) -> void:
	if arrival_open:
		var players := get_node_or_null(players_path)
		var local_player := players.get_node_or_null("Player") if players != null else null
		# A completed exit already places the player at this doorway. Keep it
		# open while access metadata loads, until the player clears the front.
		arrival_open = local_player != null and _actor_needs_door(local_player)
	wants_open = arrival_open or (_has_nearby_player() and _access_allows_opening())
	if wants_open:
		close_delay = 0.15
	else:
		close_delay = maxf(0.0, close_delay - delta)
	var next_amount := move_toward(open_amount, 1.0 if wants_open or close_delay > 0.0 else 0.0, delta / animation_seconds)
	var direction := int(signf(next_amount - open_amount))
	if direction != 0 and direction != movement_direction:
		_play_movement_sound(direction)
	movement_direction = direction
	open_amount = next_amount


func prepare_for_arrival() -> void:
	# Called synchronously after spawn placement, before the map is revealed.
	# Idempotent: authorized placement runs again after the physics frame.
	arrival_open = true
	wants_open = true
	close_delay = 0.15
	movement_direction = 0
	open_amount = 1.0


func _play_movement_sound(direction: int) -> void:
	if movement_sound_id.is_empty():
		return
	var players := get_node_or_null(players_path)
	var listener := players.get_node_or_null("Player") if players != null else null
	if listener == null or not listener.has_method("get_feet_position"):
		return
	var feet: Vector2 = listener.call("get_feet_position")
	var distance := feet.distance_to(to_global(Vector2(panel_size.x * 0.5, panel_size.y)))
	# SfxManager handles native/web routing and user volume. Attenuate against
	# the local player's feet, so remote doors are not audible across the map.
	const HEARING_RADIUS := 192.0
	if distance >= HEARING_RADIUS:
		return
	var gain := maxf(0.001, 1.0 - distance / HEARING_RADIUS)
	SfxManager.play(movement_sound_id, linear_to_db(gain) + (0.0 if direction > 0 else -2.0), 1.0 if direction > 0 else 0.9)


func _access_allows_opening() -> bool:
	if not access_enabled:
		return false
	if access_lock_path.is_empty():
		return true
	var access_lock := get_node_or_null(access_lock_path)
	return access_lock != null and bool(access_lock.get("is_unlocked"))


func _has_nearby_player() -> bool:
	var players := get_node_or_null(players_path)
	if players == null:
		return false
	for child: Node in players.get_children():
		if _actor_needs_door(child):
			return true
		# World owns RemotePlayers beneath the same map's Players container.
		if child.name == &"RemotePlayers":
			for avatar: Node in child.get_children():
				if _actor_needs_door(avatar):
					return true
	return false


func _actor_needs_door(actor: Node) -> bool:
	if not actor is Node2D or not actor.has_method("get_feet_position"):
		return false
	var feet: Vector2 = actor.call("get_feet_position")
	if activation_rect.has_point(to_local(feet)):
		return true
	# Start opening during the approach step, before entry can trigger a fade.
	# Never use a stale local target while the player is stationary.
	if actor.has_method("is_tile_moving") and bool(actor.call("is_tile_moving")) and actor.has_method("get_target_feet_position"):
		var target: Vector2 = actor.call("get_target_feet_position")
		return activation_rect.has_point(to_local(target))
	return false


func _cache_panel_pieces() -> void:
	pieces.clear()
	for layer_path: NodePath in source_layers:
		var layer := get_node_or_null(layer_path) as TileMapLayer
		if layer == null or layer.tile_set == null:
			pieces.clear()
			push_warning("Sliding door source layer is missing: %s" % layer_path)
			return
		var top_left := layer.to_local(global_position)
		var bounds := Rect2(top_left, panel_size)
		var first := layer.local_to_map(top_left)
		var last := layer.local_to_map(bounds.end - Vector2.ONE)
		var tile_size := Vector2(layer.tile_set.tile_size)
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var cell := Vector2i(x, y)
				var source_id := layer.get_cell_source_id(cell)
				if source_id < 0:
					continue
				var source := layer.tile_set.get_source(source_id) as TileSetAtlasSource
				if source == null:
					continue
				var cell_origin := layer.map_to_local(cell) - tile_size * 0.5
				var overlap := Rect2(cell_origin, tile_size).intersection(bounds)
				var atlas_region := source.get_tile_texture_region(layer.get_cell_atlas_coords(cell))
				pieces.append({
					"texture": source.texture,
					"destination": Rect2(overlap.position - top_left, overlap.size),
					"source": Rect2(Vector2(atlas_region.position) + overlap.position - cell_origin, overlap.size),
				})


func _draw() -> void:
	if pieces.is_empty() or open_amount <= 0.0:
		return
	var aperture := Rect2(Vector2.ZERO, panel_size)
	draw_rect(aperture, opening_color)
	# A single glass leaf slides right, behind its fixed frame. Integer offsets
	# and clipping preserve the pixel art and keep glass off the adjacent wall.
	var offset := Vector2(roundf(panel_size.x * open_amount), 0)
	for piece: Dictionary in pieces:
		var moved: Rect2 = piece.destination
		moved.position += offset
		var clipped := moved.intersection(aperture)
		if not clipped.has_area():
			continue
		var source: Rect2 = piece.source
		source.position += clipped.position - moved.position
		source.size = clipped.size
		draw_texture_rect_region(piece.texture, clipped, source)
