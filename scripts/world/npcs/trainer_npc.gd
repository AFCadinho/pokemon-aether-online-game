extends Node2D

@export var trainer_id := "route_1_bug_catcher_1"
@export var sight_direction := Vector2.DOWN
@export var sight_range_tiles := 5
@export var trainer_sprite_frames: SpriteFrames
@export var sprite_offset := Vector2(0, -16)
@export var mugshot: Texture2D


const TILE_SIZE := 32
const MOVE_SPEED := 120.0
const SORT_Z_MIN := -256
const SORT_Z_MAX := 256

@onready var sprite: AnimatedSprite2D = $Look/AnimatedSprite2D
@onready var feet_marker: Marker2D = $FeetMarker
@onready var vision_collision_shape: CollisionShape2D = $VisionArea/CollisionShape2D

var triggered := false
var player_nearby := false
var nearby_player: Node2D
var is_interacting := false
var vision_candidate: Node2D
var auto_trigger_failed := false

func _ready() -> void:
	if trainer_sprite_frames != null:
		sprite.sprite_frames = trainer_sprite_frames
	sprite.position = sprite_offset
	_configure_vision_area()
	_update_sort_z()

func blocks_world_position(world_position: Vector2) -> bool:
	return _to_tile(feet_marker.global_position) == _to_tile(world_position)

func get_feet_position() -> Vector2:
	return feet_marker.global_position
	
func _to_tile(world_position: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_position.x / TILE_SIZE),
		floori(world_position.y / TILE_SIZE)
	)
	

func walk_to_player(body: Node2D) -> void:
	var player_tile := _to_tile(_get_body_feet_position(body))
	var npc_tile := _to_tile(get_feet_position())
	var direction := _get_step_direction_from_tiles(npc_tile, player_tile)
	if direction == Vector2.ZERO:
		_set_idle_frame(direction)
		return
	
	var stop_tile := player_tile - Vector2i(int(direction.x), int(direction.y))
	if npc_tile == stop_tile:
		_set_idle_frame(direction)
		return

	_play_walk_animation(direction)
	
	while _to_tile(get_feet_position()) != stop_tile:
		var current_tile := _to_tile(get_feet_position())
		var next_tile := current_tile + Vector2i(int(direction.x), int(direction.y))
		var target_position := _tile_to_world(next_tile)
		var tween := create_tween()
		tween.tween_property(self, "global_position", target_position, TILE_SIZE / MOVE_SPEED)
		await tween.finished
		_update_sort_z()
	
	_set_idle_frame(direction)

func _get_body_feet_position(body: Node2D) -> Vector2:
	if body.has_method("get_feet_position"):
		return body.get_feet_position()
	return body.global_position

func _get_step_direction_from_positions(from_position: Vector2, to_position: Vector2) -> Vector2:
	var delta := to_position - from_position
	if abs(delta.x) > abs(delta.y):
		return Vector2(sign(delta.x), 0)
	
	if delta.y != 0:
		return Vector2(0, sign(delta.y))
	
	if delta.x != 0:
		return Vector2(sign(delta.x), 0)
	
	return Vector2.ZERO

func _get_step_direction_from_tiles(from_tile: Vector2i, to_tile: Vector2i) -> Vector2:
	var delta := to_tile - from_tile
	if abs(delta.x) > abs(delta.y):
		return Vector2(sign(delta.x), 0)
	
	if delta.y != 0:
		return Vector2(0, sign(delta.y))
	
	if delta.x != 0:
		return Vector2(sign(delta.x), 0)
	
	return Vector2.ZERO

func _get_stop_position_before_player(player_position: Vector2, direction: Vector2) -> Vector2:
	if direction.x != 0:
		return Vector2(player_position.x - direction.x * TILE_SIZE, global_position.y)
	
	return Vector2(global_position.x, player_position.y - direction.y * TILE_SIZE)

func _tile_to_world(tile_position: Vector2i) -> Vector2:
	return Vector2(
		tile_position.x * TILE_SIZE + TILE_SIZE * 0.5,
		tile_position.y * TILE_SIZE + TILE_SIZE * 0.5
	)

func _play_walk_animation(direction: Vector2) -> void:
	var animation_name := _get_walk_animation_name(direction)
	if animation_name != "" and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)

func _set_idle_frame(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	
	var animation_name := _get_idle_animation_name(direction)
	if animation_name != "" and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)
		sprite.stop()
		return
	
	animation_name = _get_walk_animation_name(direction)
	if animation_name != "" and sprite.sprite_frames.has_animation(animation_name):
		sprite.animation = animation_name
		sprite.frame = 0
		sprite.stop()

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
	
func show_intro_dialogue() -> void:
	var dialogue_box := get_tree().current_scene.get_node_or_null("DialogueBox/Box")
	if dialogue_box == null:
		push_warning("TrainerNPC: DialogueBox/Box not found.")
		GameState.input_locked = false
		return
	
	var metadata_response: Dictionary = await TrainerMetadataService.get_trainer_metadata(trainer_id)
	if not metadata_response.get("success", false):
		await _fail_trainer_metadata(dialogue_box, "Trainer metadata failed for %s: %s" % [
			trainer_id,
			str(metadata_response.get("error", "Unknown API error")),
		])
		return

	var trainer_metadata: Dictionary = metadata_response.get("metadata", {})
	var speaker_name := str(trainer_metadata.get("name", ""))
	if speaker_name == "":
		await _fail_trainer_metadata(dialogue_box, "Trainer metadata for %s is missing name." % trainer_id)
		return

	var dialogue_lines := _get_dialogue_lines_from_trainer_metadata(trainer_metadata)
	if dialogue_lines.is_empty():
		await _fail_trainer_metadata(dialogue_box, "Trainer metadata for %s is missing dialogue_before_battle." % trainer_id)
		return
	
	dialogue_box.start_dialogue(dialogue_lines, speaker_name, mugshot)
	await dialogue_box.dialogue_finished
	
	var battle_started := await start_trainer_battle(trainer_metadata)
	if not battle_started:
		await _show_generic_trainer_error_dialogue(dialogue_box)
	
func start_trainer_battle(trainer_metadata: Dictionary) -> bool:
	var world := get_tree().get_first_node_in_group("world")
	if world == null or not world.has_method("start_trainer_battle"):
		push_warning("TrainerNPC: World cannot start trainer battle.")
		GameState.input_locked = false
		return false

	return await world.start_trainer_battle(trainer_metadata)

func _get_dialogue_lines_from_trainer_metadata(trainer_metadata: Dictionary) -> Array[String]:
	var dialogue_lines: Array[String] = []
	var dialogue_value: Variant = trainer_metadata.get("dialogue_before_battle", [])
	if dialogue_value is Array:
		for item: Variant in dialogue_value:
			dialogue_lines.append(str(item))
	
	return dialogue_lines

func _fail_trainer_metadata(dialogue_box: Node, message: String) -> void:
	push_error("TrainerNPC: %s" % message)
	auto_trigger_failed = true
	triggered = false
	vision_candidate = null
	await _show_generic_trainer_error_dialogue(dialogue_box)

func _show_generic_trainer_error_dialogue(dialogue_box: Node) -> void:
	await GameErrorDialogService.show_report_to_staff_message(dialogue_box)
	

func _on_vision_area_body_entered(body: Node2D) -> void:
	if triggered:
		return
		
	if body.name != "Player":
		return
	
	vision_candidate = body
	await _try_trigger_vision(body)

func _try_trigger_vision(body: Node2D) -> void:
	if triggered:
		return

	if auto_trigger_failed:
		return
	
	if body == null or body.name != "Player":
		return
	
	if not _is_body_in_sight_range(body):
		return
	
	triggered = true
	GameState.input_locked = true
	await walk_to_player(body)
	if body.has_method("face_world_position"):
		body.face_world_position(get_feet_position())
	await show_intro_dialogue()

func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = true
		nearby_player = body

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = false
		if body == nearby_player:
			nearby_player = null


func _on_vision_area_body_exited(body: Node2D) -> void:
	if body == vision_candidate:
		vision_candidate = null

func _process(_delta: float) -> void:
	_update_sort_z()
	if _can_start_manual_interaction():
		await _start_manual_interaction(nearby_player)
		return
	
	if vision_candidate != null:
		_try_trigger_vision(vision_candidate)

func _can_start_manual_interaction() -> bool:
	if triggered or is_interacting:
		return false
	
	if not player_nearby or nearby_player == null:
		return false
	
	if GameState.input_locked:
		return false
	
	if _is_ui_typing():
		return false
	
	if not Input.is_action_just_pressed("interact"):
		return false
	
	var dialogue_box := get_tree().current_scene.get_node_or_null("DialogueBox/Box")
	if dialogue_box != null and dialogue_box.is_open:
		return false
	
	return true

func _start_manual_interaction(body: Node2D) -> void:
	is_interacting = true
	GameState.input_locked = true
	_face_body(body)
	if body.has_method("face_world_position"):
		body.face_world_position(get_feet_position())
	await show_intro_dialogue()
	is_interacting = false

func _face_body(body: Node2D) -> void:
	var direction := _get_step_direction_from_positions(get_feet_position(), _get_body_feet_position(body))
	_set_idle_frame(direction)

func _is_ui_typing() -> bool:
	var focused_control := get_viewport().gui_get_focus_owner()
	return focused_control is LineEdit or focused_control is TextEdit

func _update_sort_z() -> void:
	z_index = clampi(floori(get_feet_position().y / TILE_SIZE), SORT_Z_MIN, SORT_Z_MAX)

func _is_body_in_sight_range(body: Node2D) -> bool:
	var range_tiles: int = maxi(sight_range_tiles, 0)
	if range_tiles == 0:
		return false
	
	var direction := _get_cardinal_direction(sight_direction)
	var npc_tile := _to_tile(get_feet_position())
	var body_tile := _to_tile(_get_body_feet_position(body))
	var delta := body_tile - npc_tile
	
	if direction.x != 0:
		return delta.y == 0 and delta.x == int(direction.x) * clampi(abs(delta.x), 1, range_tiles)
	
	return delta.x == 0 and delta.y == int(direction.y) * clampi(abs(delta.y), 1, range_tiles)

func _configure_vision_area() -> void:
	if vision_collision_shape == null:
		return
	
	var range_tiles: int = maxi(sight_range_tiles, 0)
	if range_tiles == 0:
		vision_collision_shape.disabled = true
		return
	
	var direction := _get_cardinal_direction(sight_direction)
	var shape := RectangleShape2D.new()
	var range_pixels := float(range_tiles * TILE_SIZE)
	
	if direction.x != 0:
		shape.size = Vector2(range_pixels, TILE_SIZE)
		vision_collision_shape.position = Vector2(direction.x * ((range_pixels + TILE_SIZE) * 0.5), 0)
	else:
		shape.size = Vector2(TILE_SIZE, range_pixels)
		vision_collision_shape.position = Vector2(0, direction.y * ((range_pixels + TILE_SIZE) * 0.5))
	
	vision_collision_shape.shape = shape
	vision_collision_shape.disabled = false

func _get_cardinal_direction(direction: Vector2) -> Vector2:
	if direction == Vector2.ZERO:
		return Vector2.DOWN
	
	if abs(direction.x) > abs(direction.y):
		return Vector2(sign(direction.x), 0)
	
	return Vector2(0, sign(direction.y))
