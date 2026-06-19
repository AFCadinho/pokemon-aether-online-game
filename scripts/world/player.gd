extends CharacterBody2D

const TILE_SIZE := 32
const TILE_MOVE_DURATION := 0.22
const MOVE_EASE_AMOUNT := 0.0
const INPUT_BUFFER_DURATION := 0.14
const CONTINUOUS_MOVE_HOLD_DELAY := 0.0
const SORT_Z_MIN := -256
const SORT_Z_MAX := 256
const IDLE_ANIMATION_SPEED := 5.0
const WALK_ANIMATION_SPEED := 7.5
const PLAYER_SPRITE_TEXTURE_FILTER := CanvasItem.TEXTURE_FILTER_NEAREST
const MOVE_ACTIONS := ["move_right", "move_left", "move_down", "move_up"]
const HIDDEN_FOR_MISSING_ANIMATION_META := "hidden_for_missing_animation"
const BASE_SPRITE_OFFSET_META := "base_sprite_offset"
const FACE_GEAR_SPRITE_NAME := "FaceGearSprite"
const BODY_SPRITE_NAME := "BodySprite"

@onready var look_node: Node2D = $Look
@onready var feet_marker: Marker2D = $FeetMarker

# TileMapLayer nodes die speciale map-informatie bevatten.
# Collision bevat de onzichtbare/blokkerende tegels.
# TallGrass kan later gebruikt worden voor encounters/effects.
var collision_tilemap: TileMapLayer
var grass_tilemap: TileMapLayer

# Movement state.
# is_moving voorkomt dat je nieuwe input verwerkt terwijl de speler nog naar
# de volgende tile aan het lopen is.
var is_moving := false

# target_position is een wereldpositie in pixels.
var target_position := Vector2.ZERO
var move_start_position := Vector2.ZERO
var move_elapsed := 0.0

# Onthoudt de laatste kijkrichting, zodat de idle frame goed blijft staan.
var last_direction := Vector2.DOWN
var input_action_priority := ["move_right", "move_left", "move_down", "move_up"]
var buffered_direction := Vector2.ZERO
var input_buffer_time_left := 0.0
var held_direction := Vector2.ZERO
var held_direction_time := 0.0
var route_gate_interaction_in_progress := false
var frame_opaque_center_y_cache := {}
var appearance_sprites: Array[AnimatedSprite2D] = []
var master_appearance_sprite: AnimatedSprite2D
var pokemon_follower: PokemonFollower

func get_feet_position() -> Vector2:
	return feet_marker.global_position

func get_target_feet_position() -> Vector2:
	return target_position + (feet_marker.global_position - global_position)

func is_tile_moving() -> bool:
	return is_moving

func set_body_appearance(body_id: String) -> void:
	PlayerSave.appearance_body_id = body_id
	_apply_body_appearance(body_id)
	_cache_appearance_sprites()
	set_idle_frame()

func get_network_movement_state() -> Dictionary:
	return {
		"isMoving": is_moving,
		"startPosition": {
			"x": move_start_position.x,
			"y": move_start_position.y,
		},
		"targetPosition": {
			"x": target_position.x,
			"y": target_position.y,
		},
		"elapsed": move_elapsed,
		"duration": TILE_MOVE_DURATION,
	}

func reset_movement_state() -> void:
	is_moving = false
	global_position = _snap_world_position(global_position)
	target_position = global_position
	move_start_position = global_position
	move_elapsed = 0.0
	_clear_input_buffer()
	_clear_held_direction()
	set_idle_frame()
	if pokemon_follower != null:
		pokemon_follower.reset_follow_position()

func face_world_position(world_position: Vector2) -> void:
	var delta := world_position - get_feet_position()
	if delta == Vector2.ZERO:
		return
	
	if abs(delta.x) > abs(delta.y):
		last_direction = Vector2.RIGHT if delta.x > 0 else Vector2.LEFT
	else:
		last_direction = Vector2.DOWN if delta.y > 0 else Vector2.UP
	
	set_idle_frame()

func _ready() -> void:
	add_to_group("player")
	z_as_relative = false
	_apply_body_appearance(PlayerSave.appearance_body_id)
	_cache_appearance_sprites()

	# Haal de TileMapLayer nodes uit de huidige map op als die al geldig is.
	# Bij scene switches kan de vorige map al freed zijn terwijl de autoload nog
	# even naar die node wijst.
	if GameState.current_map != null and is_instance_valid(GameState.current_map):
		grass_tilemap = GameState.current_map.get_node_or_null("TallGrass")
		collision_tilemap = GameState.current_map.get_node_or_null("Collision")
	
	# Zet speler terug op laatst bekende positie in de juiste richting.
	if GameState.has_player_position:
		global_position = _snap_world_position(GameState.player_position)
		last_direction = GameState.player_direction
	
	# De eerste target is waar de speler nu al staat.
	# Daardoor begint hij niet meteen ergens heen te bewegen.
	target_position = _snap_world_position(global_position)
	move_start_position = target_position
	global_position = target_position
	_update_sort_z()
	_setup_pokemon_follower.call_deferred()

func _process(delta: float) -> void:
	_update_sort_z()
	_sync_appearance_sprite_frames()

	if _can_accept_movement_input():
		_update_input_priority()
		_update_held_direction(delta)
		_update_input_buffer(delta)
	else:
		_clear_input_buffer()
		_clear_held_direction()

	if is_moving:
		# Beweeg per render-frame naar de volgende tile.
		# De tile-logica blijft deterministisch; alleen de visual interpolation is soepeler.
		move_elapsed = minf(move_elapsed + delta, TILE_MOVE_DURATION)
		var move_progress := move_elapsed / TILE_MOVE_DURATION
		var interpolated_position: Vector2 = move_start_position.lerp(target_position, _get_move_interpolation(move_progress))
		global_position = _snap_world_position(interpolated_position)
		_update_sort_z()

		# Als de bestemming is bereikt.
		if _has_reached_target():
			global_position = _snap_world_position(target_position)
			is_moving = false

			if check_for_map_exit():
				return
			
			if is_standing_on_tall_grass():
				check_for_grass_encounter()

			if _can_accept_movement_input():
				var next_direction := _get_next_movement_direction()
				if next_direction != Vector2.ZERO and _try_start_move(next_direction):
					return

			set_idle_frame()
		return

	if not _can_accept_movement_input():
		set_idle_frame()
		return

	var direction := _get_next_movement_direction()

	if direction != Vector2.ZERO:
		if not _try_start_move(direction):
			set_idle_frame()

func refresh_pokemon_follower() -> void:
	_ensure_pokemon_follower_parent()
	if pokemon_follower == null or not is_instance_valid(pokemon_follower):
		return

	var lead_pokemon: Pokemon = null
	if GameState.show_follower and not PlayerSave.party.is_empty():
		lead_pokemon = PlayerSave.party[0]

	pokemon_follower.set_pokemon(lead_pokemon)

func set_show_follower(show_follower: bool) -> void:
	GameState.show_follower = show_follower
	refresh_pokemon_follower()

func reset_pokemon_follower_position() -> void:
	_ensure_pokemon_follower_parent()
	if pokemon_follower != null and is_instance_valid(pokemon_follower):
		pokemon_follower.reset_follow_position()

func _setup_pokemon_follower() -> void:
	if pokemon_follower != null and is_instance_valid(pokemon_follower):
		_ensure_pokemon_follower_parent()
		return

	pokemon_follower = PokemonFollower.new()
	pokemon_follower.name = "PokemonFollower"
	_get_pokemon_follower_parent().add_child(pokemon_follower)
	pokemon_follower.setup(self)
	refresh_pokemon_follower()

	var refresh_callable: Callable = Callable(self, "refresh_pokemon_follower")
	if not PlayerSave.party_changed.is_connected(refresh_callable):
		PlayerSave.party_changed.connect(refresh_callable)

func _ensure_pokemon_follower_parent() -> void:
	if pokemon_follower != null and not is_instance_valid(pokemon_follower):
		pokemon_follower = null
	if pokemon_follower == null:
		_setup_pokemon_follower()
		return

	var follower_parent := _get_pokemon_follower_parent()
	if pokemon_follower.get_parent() == follower_parent:
		return

	var follower_position := pokemon_follower.global_position
	if pokemon_follower.get_parent() != null:
		pokemon_follower.get_parent().remove_child(pokemon_follower)
	follower_parent.add_child(pokemon_follower)
	pokemon_follower.global_position = follower_position

func _get_pokemon_follower_parent() -> Node:
	var world := GameState.get_world()
	if world != null and is_instance_valid(world):
		return world
	var parent := get_parent()
	if parent != null:
		return parent
	return self

func _can_accept_movement_input() -> bool:
	return not GameState.is_overworld_input_locked() and not _is_ui_typing()

func _update_input_priority() -> void:
	for action_name in MOVE_ACTIONS:
		if Input.is_action_just_pressed(action_name):
			input_action_priority.erase(action_name)
			input_action_priority.insert(0, action_name)

func _update_held_direction(delta: float) -> void:
	var direction := _get_input_direction()
	if direction == Vector2.ZERO:
		_clear_held_direction()
		return

	if direction != held_direction:
		held_direction = direction
		held_direction_time = 0.0
		return

	held_direction_time += delta

func _update_input_buffer(delta: float) -> void:
	if input_buffer_time_left > 0.0:
		input_buffer_time_left = maxf(input_buffer_time_left - delta, 0.0)
		if input_buffer_time_left == 0.0:
			buffered_direction = Vector2.ZERO

	for action_name in input_action_priority:
		if not Input.is_action_just_pressed(action_name):
			continue

		buffered_direction = _get_action_direction(action_name)
		input_buffer_time_left = INPUT_BUFFER_DURATION
		return

func _get_next_movement_direction() -> Vector2:
	var direction := _consume_buffered_direction()
	if direction != Vector2.ZERO:
		return direction

	if held_direction_time >= CONTINUOUS_MOVE_HOLD_DELAY:
		return held_direction

	return Vector2.ZERO

func _consume_buffered_direction() -> Vector2:
	if input_buffer_time_left <= 0.0:
		buffered_direction = Vector2.ZERO
		return Vector2.ZERO

	var direction := buffered_direction
	buffered_direction = Vector2.ZERO
	input_buffer_time_left = 0.0
	return direction

func _clear_input_buffer() -> void:
	buffered_direction = Vector2.ZERO
	input_buffer_time_left = 0.0

func _clear_held_direction() -> void:
	held_direction = Vector2.ZERO
	held_direction_time = 0.0

func _has_reached_target() -> bool:
	return move_elapsed >= TILE_MOVE_DURATION

func _get_move_interpolation(progress: float) -> float:
	var linear_progress := clampf(progress, 0.0, 1.0)
	if MOVE_EASE_AMOUNT <= 0.0:
		return linear_progress

	var eased_progress := linear_progress * linear_progress * (3.0 - (2.0 * linear_progress))
	return linear_progress + ((eased_progress - linear_progress) * MOVE_EASE_AMOUNT)

func _snap_world_position(position: Vector2) -> Vector2:
	return Vector2(roundf(position.x), roundf(position.y))

func _get_input_direction() -> Vector2:
	for action_name in input_action_priority:
		if Input.is_action_pressed(action_name):
			return _get_action_direction(action_name)

	return Vector2.ZERO

func _get_action_direction(action_name: String) -> Vector2:
	match action_name:
		"move_right":
			return Vector2.RIGHT
		"move_left":
			return Vector2.LEFT
		"move_down":
			return Vector2.DOWN
		"move_up":
			return Vector2.UP

	return Vector2.ZERO

func _try_start_move(direction: Vector2) -> bool:
	last_direction = direction

	# Bepaal de volgende wereldpositie.
	# Voorbeeld: Vector2.RIGHT * 32 = Vector2(32, 0), dus 1 tile naar rechts.
	var new_target_position := _snap_world_position(global_position) + (direction * TILE_SIZE)

	if _try_trigger_route_gate(new_target_position):
		set_idle_frame()
		return false

	# Check eerst of de target tile vrij is.
	# Alleen als can_move_to true teruggeeft, starten we de beweging.
	if not can_move_to(new_target_position):
		return false

	target_position = _snap_world_position(new_target_position)
	move_start_position = _snap_world_position(global_position)
	global_position = move_start_position
	move_elapsed = 0.0
	is_moving = true
	play_walk_animation(direction)
	return true

func play_walk_animation(direction: Vector2) -> void:
	var animation_name := _get_walk_animation_name(direction)
	var should_restart_animation := master_appearance_sprite == null \
		or master_appearance_sprite.animation != animation_name \
		or not master_appearance_sprite.is_playing()

	for sprite in appearance_sprites:
		if _sprite_has_animation(sprite, animation_name):
			_restore_layer_visibility_if_needed(sprite)
			sprite.animation = animation_name
			if should_restart_animation:
				sprite.frame = 0
				sprite.frame_progress = 0.0
			_apply_face_gear_frame_alignment(sprite)
			sprite.play(animation_name)
		else:
			_hide_layer_for_missing_animation(sprite)

func can_move_to(check_position: Vector2) -> bool:
	refresh_map_layers()

	if collision_tilemap == null:
		push_warning("Player.can_move_to: Collision TileMapLayer is missing; allowing movement as fallback.")
		return true
	
	var current_map: Node = _resolve_current_map()
	if current_map != null:
		var is_blocked_by_character := false
		if current_map.has_method("is_position_blocked_by_character"):
			is_blocked_by_character = bool(current_map.is_position_blocked_by_character(check_position))
		else:
			is_blocked_by_character = MapCharacterBlocking.is_position_blocked_by_character(current_map, check_position)

		if is_blocked_by_character:
			return false
	
	# check_position is een global/world pixelpositie.
	# TileMapLayer.local_to_map() verwacht juist een lokale positie binnen die TileMapLayer.
	# Daarom zetten we eerst world -> local om.
	var local_position := collision_tilemap.to_local(check_position)

	# Zet de lokale pixelpositie om naar een tile/grid coördinaat.
	# Voorbeeld bij 32x32 tiles: lokale pixelpositie (64, 96) wordt ongeveer tile (2, 3).
	var tile_position := collision_tilemap.local_to_map(local_position)

	# Vraag tiledata op voor die tile.
	# In deze setup betekent: geen tile_data = geen collision tile = vrij lopen.
	# Wel tile_data = er ligt een collision tile = blokkeren.
	var source_id: int = collision_tilemap.get_cell_source_id(tile_position)
	if source_id != -1:
		return false

	var tile_data := collision_tilemap.get_cell_tile_data(tile_position)

	return tile_data == null

func _try_trigger_route_gate(check_position: Vector2) -> bool:
	if route_gate_interaction_in_progress:
		return true

	var current_map: Node = _resolve_current_map()
	if current_map == null or not current_map.has_method("get_closed_route_gate_npc"):
		return false

	var gate_npc: Node = current_map.get_closed_route_gate_npc(check_position)
	if gate_npc == null:
		return false

	route_gate_interaction_in_progress = true
	Callable(self, "_handle_route_gate_interaction").call_deferred(gate_npc)
	return true

func _handle_route_gate_interaction(gate_npc: Node) -> void:
	if gate_npc.has_method("on_route_gate_blocked"):
		await gate_npc.on_route_gate_blocked(self)

	route_gate_interaction_in_progress = false
	
func set_idle_frame() -> void:
	for sprite in appearance_sprites:
		sprite.stop()
		_set_idle_animation(sprite, last_direction)
	
func refresh_map_layers() -> void:
	var current_map: Node = _resolve_current_map()
	if current_map == null:
		collision_tilemap = null
		grass_tilemap = null	
		push_warning("Player.refresh_map_layers: could not resolve current map.")
		return

	GameState.current_map = current_map
	collision_tilemap = current_map.get_node_or_null("Collision")
	grass_tilemap = current_map.get_node_or_null("TallGrass")

	if collision_tilemap == null:
		push_warning("Player.refresh_map_layers: Collision layer missing on %s." % current_map.name)
	
func is_standing_on_tall_grass() -> bool:
	if grass_tilemap == null:
		refresh_map_layers()

	if grass_tilemap == null:
		return false
		
	var local_position := grass_tilemap.to_local(global_position)
	var tile_position := grass_tilemap.local_to_map(local_position)
	var tile_data := grass_tilemap.get_cell_tile_data(tile_position)
	
	return tile_data != null
		
func check_for_grass_encounter() -> void:
	var current_map := GameState.current_map
	
	if current_map == null:
		return
		
	if not current_map.has_method("get_wild_encounter_area_id"):
		return
		
	var area_id: String = str(current_map.call("get_wild_encounter_area_id"))
	if area_id == "":
		return

	if GameState.repel_enabled:
		return

	if current_map.has_method("should_trigger_wild_encounter"):
		if not bool(current_map.call("should_trigger_wild_encounter", "grass")):
			return
	
	var world := GameState.get_world()
	if world != null and world.has_method("start_triggered_wild_battle_for_area"):
		world.start_triggered_wild_battle_for_area(area_id, "grass")

func _is_ui_typing() -> bool:
	var focused_control := get_viewport().gui_get_focus_owner()
	return focused_control is LineEdit or focused_control is TextEdit

func check_for_map_exit() -> bool:
	var current_map: Node = _resolve_current_map()
	if current_map == null:
		return false

	var exits := current_map.get_node_or_null("Exits")
	if exits == null:
		return false

	for exit_node: Node in exits.get_children():
		if not (exit_node is Area2D):
			continue

		var exit_area := exit_node as Area2D
		if _is_inside_exit_area(exit_area):
			if exit_area.has_method("_on_body_entered"):
				exit_area.call("_on_body_entered", self)
				return true

	return false

func _is_inside_exit_area(exit_area: Area2D) -> bool:
	for child: Node in exit_area.get_children():
		if not (child is CollisionShape2D):
			continue

		var shape_node := child as CollisionShape2D
		if shape_node.disabled:
			continue

		var shape: Shape2D = shape_node.shape
		if shape is RectangleShape2D:
			var rectangle_shape := shape as RectangleShape2D
			var local_position := shape_node.to_local(global_position)
			var shape_rect := Rect2(-rectangle_shape.size * 0.5, rectangle_shape.size)
			if shape_rect.has_point(local_position):
				return true

	return false

func _resolve_current_map() -> Node:
	var parent_node := get_parent()
	while parent_node != null:
		if parent_node.get_node_or_null("Collision") != null or parent_node.get_node_or_null("TallGrass") != null:
			return parent_node

		parent_node = parent_node.get_parent()

	if GameState.current_map != null and is_instance_valid(GameState.current_map):
		return GameState.current_map

	return null

func _update_sort_z() -> void:
	z_index = clampi(floori(get_feet_position().y / TILE_SIZE), SORT_Z_MIN, SORT_Z_MAX)

func _cache_appearance_sprites() -> void:
	appearance_sprites.clear()
	_collect_appearance_sprites(look_node)
	master_appearance_sprite = _get_master_appearance_sprite()
	_sync_appearance_animation_speeds()

func _collect_appearance_sprites(parent: Node) -> void:
	for child: Node in parent.get_children():
		var sprite: AnimatedSprite2D = child as AnimatedSprite2D
		if sprite != null:
			sprite.texture_filter = PLAYER_SPRITE_TEXTURE_FILTER
			appearance_sprites.append(sprite)

		_collect_appearance_sprites(child)

func _get_master_appearance_sprite() -> AnimatedSprite2D:
	for sprite in appearance_sprites:
		if sprite.name == BODY_SPRITE_NAME:
			return sprite

	if appearance_sprites.is_empty():
		return null

	return appearance_sprites[0]

func _apply_body_appearance(body_id: String) -> void:
	var body_sprite := look_node.get_node_or_null(BODY_SPRITE_NAME) as AnimatedSprite2D
	if body_sprite == null:
		push_warning("Player: BodySprite node is missing.")
		return

	var body_frames: SpriteFrames = CharacterAppearanceService.get_body_frames(body_id)
	if body_frames == null:
		push_warning("Player: body appearance '%s' could not be loaded." % body_id)
		return

	body_sprite.sprite_frames = body_frames
	body_sprite.texture_filter = PLAYER_SPRITE_TEXTURE_FILTER

func _sync_appearance_sprite_frames() -> void:
	if master_appearance_sprite == null or not master_appearance_sprite.is_playing():
		return

	var animation_name: StringName = master_appearance_sprite.animation
	var frame: int = master_appearance_sprite.frame
	var frame_progress: float = master_appearance_sprite.frame_progress

	for sprite in appearance_sprites:
		if sprite == master_appearance_sprite:
			continue
		if not _sprite_has_animation(sprite, animation_name):
			_hide_layer_for_missing_animation(sprite)
			continue

		_restore_layer_visibility_if_needed(sprite)
		sprite.animation = animation_name
		var frame_count: int = sprite.sprite_frames.get_frame_count(animation_name)
		if frame_count <= 0:
			continue

		sprite.frame = mini(frame, frame_count - 1)
		sprite.frame_progress = frame_progress
		_apply_face_gear_frame_alignment(sprite)
		if not sprite.is_playing():
			sprite.play(animation_name)

func _sync_appearance_animation_speeds() -> void:
	var idle_animation_names: Array[String] = ["idle_down", "idle_left", "idle_right", "idle_up"]
	var walk_animation_names: Array[String] = ["walk_down", "walk_left", "walk_right", "walk_up"]

	for sprite in appearance_sprites:
		if sprite.sprite_frames == null:
			continue

		for animation_name: String in idle_animation_names:
			if sprite.sprite_frames.has_animation(animation_name):
				sprite.sprite_frames.set_animation_speed(animation_name, IDLE_ANIMATION_SPEED)

		for animation_name: String in walk_animation_names:
			if sprite.sprite_frames.has_animation(animation_name):
				sprite.sprite_frames.set_animation_speed(animation_name, WALK_ANIMATION_SPEED)

func _set_idle_animation(sprite: AnimatedSprite2D, direction: Vector2) -> void:
	var animation_name := _get_idle_animation_name(direction)
	if _sprite_has_animation(sprite, animation_name):
		_restore_layer_visibility_if_needed(sprite)
		sprite.play(animation_name)
		sprite.stop()
		_apply_face_gear_frame_alignment(sprite)
		return
	
	animation_name = _get_walk_animation_name(direction)
	if _sprite_has_animation(sprite, animation_name):
		_restore_layer_visibility_if_needed(sprite)
		sprite.animation = animation_name
		sprite.frame = 0
		sprite.stop()
		_apply_face_gear_frame_alignment(sprite)
		return

	_hide_layer_for_missing_animation(sprite)

func _apply_face_gear_frame_alignment(sprite: AnimatedSprite2D) -> void:
	if sprite == null or sprite.name != FACE_GEAR_SPRITE_NAME or sprite.sprite_frames == null:
		return

	if master_appearance_sprite == null or master_appearance_sprite.sprite_frames == null:
		return

	if not sprite.has_meta(BASE_SPRITE_OFFSET_META):
		sprite.set_meta(BASE_SPRITE_OFFSET_META, sprite.offset)

	var animation_name: StringName = sprite.animation
	if not sprite.sprite_frames.has_animation(animation_name):
		return

	if not master_appearance_sprite.sprite_frames.has_animation(animation_name):
		return

	var frame_count := sprite.sprite_frames.get_frame_count(animation_name)
	var master_frame_count := master_appearance_sprite.sprite_frames.get_frame_count(animation_name)
	if frame_count <= 0 or master_frame_count <= 0:
		return

	var frame_index := clampi(sprite.frame, 0, frame_count - 1)
	var master_frame_index := clampi(master_appearance_sprite.frame, 0, master_frame_count - 1)

	var reference_face_center_y := _get_frame_opaque_center_y(sprite.sprite_frames, animation_name, 0)
	var current_face_center_y := _get_frame_opaque_center_y(sprite.sprite_frames, animation_name, frame_index)
	var reference_body_center_y := _get_frame_opaque_center_y(master_appearance_sprite.sprite_frames, animation_name, 0)
	var current_body_center_y := _get_frame_opaque_center_y(master_appearance_sprite.sprite_frames, animation_name, master_frame_index)
	if reference_face_center_y < 0.0 or current_face_center_y < 0.0:
		return
	if reference_body_center_y < 0.0 or current_body_center_y < 0.0:
		return

	var base_offset: Vector2 = sprite.get_meta(BASE_SPRITE_OFFSET_META)
	var body_bob_y := current_body_center_y - reference_body_center_y
	sprite.offset = base_offset + Vector2(0.0, reference_face_center_y + body_bob_y - current_face_center_y)

func _get_frame_opaque_center_y(sprite_frames: SpriteFrames, animation_name: StringName, frame_index: int) -> float:
	var cache_key := "%s:%s:%d" % [str(sprite_frames.get_instance_id()), str(animation_name), frame_index]
	if frame_opaque_center_y_cache.has(cache_key):
		return float(frame_opaque_center_y_cache[cache_key])

	var texture := sprite_frames.get_frame_texture(animation_name, frame_index)
	if texture == null:
		frame_opaque_center_y_cache[cache_key] = -1.0
		return -1.0

	var image := texture.get_image()
	if image == null:
		frame_opaque_center_y_cache[cache_key] = -1.0
		return -1.0

	var top_y := image.get_height()
	var bottom_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.05:
				top_y = mini(top_y, y)
				bottom_y = maxi(bottom_y, y)

	if bottom_y < top_y:
		frame_opaque_center_y_cache[cache_key] = -1.0
		return -1.0

	var center_y := (float(top_y) + float(bottom_y)) * 0.5
	frame_opaque_center_y_cache[cache_key] = center_y
	return center_y

func _hide_layer_for_missing_animation(sprite: AnimatedSprite2D) -> void:
	if sprite == null or sprite == master_appearance_sprite:
		return

	if sprite.visible:
		sprite.set_meta(HIDDEN_FOR_MISSING_ANIMATION_META, true)
		sprite.visible = false

	sprite.stop()

func _restore_layer_visibility_if_needed(sprite: AnimatedSprite2D) -> void:
	if sprite == null:
		return

	if sprite.get_meta(HIDDEN_FOR_MISSING_ANIMATION_META, false) == true:
		sprite.visible = true
		sprite.set_meta(HIDDEN_FOR_MISSING_ANIMATION_META, false)

func _sprite_has_animation(sprite: AnimatedSprite2D, animation_name: StringName) -> bool:
	return sprite != null and sprite.sprite_frames != null and str(animation_name) != "" and sprite.sprite_frames.has_animation(animation_name)

func _get_idle_animation_name(direction: Vector2) -> String:
	if direction == Vector2.DOWN:
		return "idle_down"
	if direction == Vector2.UP:
		return "idle_up"
	if direction == Vector2.LEFT:
		return "idle_left"
	if direction == Vector2.RIGHT:
		return "idle_right"
	
	return ""

func _get_walk_animation_name(direction: Vector2) -> String:
	if direction == Vector2.DOWN:
		return "walk_down"
	if direction == Vector2.UP:
		return "walk_up"
	if direction == Vector2.LEFT:
		return "walk_left"
	if direction == Vector2.RIGHT:
		return "walk_right"
	
	return ""
