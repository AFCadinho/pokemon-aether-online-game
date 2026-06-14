extends Node2D

class_name BaseNPC

const MISSING_DIALOGUE_LINES: Array[String] = [
	"This NPC has no dialogue.",
	"Please contact staff.",
]

@export var npc_id := ""
@export var display_name := ""
@export var facing_direction := Vector2.DOWN
@export var dialogue_lines: Array[String] = []
@export var npc_sprite_frames: SpriteFrames
@export var sprite_offset := Vector2(0, -16)
@export var mugshot: Texture2D

const TILE_SIZE := 32
const MOVE_SPEED := 120.0
const SORT_Z_MIN := -256
const SORT_Z_MAX := 256

@onready var sprite: AnimatedSprite2D = $Look/AnimatedSprite2D
@onready var feet_marker: Marker2D = $FeetMarker
@onready var interaction_area: Area2D = $InteractionArea

var player_nearby := false
var nearby_player: Node2D
var is_interacting := false
var npc_metadata_loaded := false
var npc_metadata_load_failed := false


func _ready_base_npc() -> void:
	if npc_sprite_frames != null:
		sprite.sprite_frames = _get_directional_sprite_frames(npc_sprite_frames)
	sprite.position = sprite_offset
	_set_idle_frame(_get_cardinal_direction(facing_direction))
	if interaction_area != null:
		var body_entered_callable := Callable(self, "_on_interaction_area_body_entered")
		var body_exited_callable := Callable(self, "_on_interaction_area_body_exited")
		if not interaction_area.body_entered.is_connected(body_entered_callable):
			interaction_area.body_entered.connect(body_entered_callable)
		if not interaction_area.body_exited.is_connected(body_exited_callable):
			interaction_area.body_exited.connect(body_exited_callable)
	_update_sort_z()


func blocks_world_position(world_position: Vector2) -> bool:
	return _to_tile(feet_marker.global_position) == _to_tile(world_position)


func get_feet_position() -> Vector2:
	return feet_marker.global_position


func _to_tile(world_position: Vector2) -> Vector2i:
	var local_position := world_position - _get_map_origin()
	return Vector2i(
		floori(local_position.x / TILE_SIZE),
		floori(local_position.y / TILE_SIZE)
	)


func _tile_to_world(tile_position: Vector2i) -> Vector2:
	return _get_map_origin() + Vector2(
		tile_position.x * TILE_SIZE + TILE_SIZE * 0.5,
		tile_position.y * TILE_SIZE + TILE_SIZE * 0.5
	)


func _get_map_origin() -> Vector2:
	if GameState.current_map != null:
		return GameState.current_map.global_position

	return Vector2.ZERO


func _get_body_feet_position(body: Node2D) -> Vector2:
	if body.has_method("get_feet_position"):
		return body.get_feet_position()
	return body.global_position


func _get_body_target_feet_position(body: Node2D) -> Vector2:
	if body.has_method("get_target_feet_position"):
		return body.get_target_feet_position()
	return _get_body_feet_position(body)


func _get_step_direction_from_positions(from_position: Vector2, to_position: Vector2) -> Vector2:
	var delta := to_position - from_position
	if abs(delta.x) > abs(delta.y):
		return Vector2(sign(delta.x), 0)

	if delta.y != 0:
		return Vector2(0, sign(delta.y))

	if delta.x != 0:
		return Vector2(sign(delta.x), 0)

	return Vector2.ZERO


func _face_body(body: Node2D) -> void:
	var direction := _get_step_direction_from_positions(get_feet_position(), _get_body_feet_position(body))
	_set_idle_frame(direction)


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


func _get_directional_sprite_frames(source_sprite_frames: SpriteFrames) -> SpriteFrames:
	if _has_all_directional_animations(source_sprite_frames):
		return source_sprite_frames

	var atlas_texture := _get_first_atlas_texture(source_sprite_frames)
	if atlas_texture == null or atlas_texture.atlas == null:
		return source_sprite_frames

	var frame_size: Vector2 = atlas_texture.region.size
	if frame_size.x <= 0.0 or frame_size.y <= 0.0:
		return source_sprite_frames

	var atlas_size := atlas_texture.atlas.get_size()
	if atlas_size.x < frame_size.x * 4.0 or atlas_size.y < frame_size.y * 4.0:
		return source_sprite_frames

	var generated_sprite_frames := SpriteFrames.new()
	_add_directional_animation(generated_sprite_frames, atlas_texture.atlas, frame_size, "down", 0)
	_add_directional_animation(generated_sprite_frames, atlas_texture.atlas, frame_size, "left", 1)
	_add_directional_animation(generated_sprite_frames, atlas_texture.atlas, frame_size, "right", 2)
	_add_directional_animation(generated_sprite_frames, atlas_texture.atlas, frame_size, "up", 3)
	return generated_sprite_frames


func _get_first_atlas_texture(source_sprite_frames: SpriteFrames) -> AtlasTexture:
	for animation_name: StringName in source_sprite_frames.get_animation_names():
		var frame_count: int = source_sprite_frames.get_frame_count(animation_name)
		for frame_index: int in range(frame_count):
			var frame_texture: Texture2D = source_sprite_frames.get_frame_texture(animation_name, frame_index)
			var atlas_texture: AtlasTexture = frame_texture as AtlasTexture
			if atlas_texture != null and atlas_texture.atlas != null:
				return atlas_texture

	return null


func _has_all_directional_animations(source_sprite_frames: SpriteFrames) -> bool:
	return (
		(source_sprite_frames.has_animation("walk_down") or source_sprite_frames.has_animation("idle_down"))
		and (source_sprite_frames.has_animation("walk_up") or source_sprite_frames.has_animation("idle_up"))
		and (source_sprite_frames.has_animation("walk_left") or source_sprite_frames.has_animation("idle_left"))
		and (source_sprite_frames.has_animation("walk_right") or source_sprite_frames.has_animation("idle_right"))
	)


func _add_directional_animation(
	target_sprite_frames: SpriteFrames,
	atlas: Texture2D,
	frame_size: Vector2,
	direction_name: String,
	row: int
) -> void:
	var idle_animation_name := "idle_%s" % direction_name
	var walk_animation_name := "walk_%s" % direction_name

	target_sprite_frames.add_animation(idle_animation_name)
	target_sprite_frames.set_animation_loop(idle_animation_name, true)
	target_sprite_frames.set_animation_speed(idle_animation_name, 5.0)
	target_sprite_frames.add_frame(idle_animation_name, _create_atlas_frame(atlas, frame_size, 0, row))

	target_sprite_frames.add_animation(walk_animation_name)
	target_sprite_frames.set_animation_loop(walk_animation_name, true)
	target_sprite_frames.set_animation_speed(walk_animation_name, 5.0)
	for column: int in range(4):
		target_sprite_frames.add_frame(walk_animation_name, _create_atlas_frame(atlas, frame_size, column, row))


func _create_atlas_frame(atlas: Texture2D, frame_size: Vector2, column: int, row: int) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = atlas
	frame.region = Rect2(
		Vector2(frame_size.x * float(column), frame_size.y * float(row)),
		frame_size
	)
	return frame


func _process_base_npc() -> void:
	_update_sort_z()
	if _can_start_manual_interaction():
		await _start_manual_interaction(nearby_player)


func _can_start_manual_interaction() -> bool:
	if is_interacting:
		return false

	if not player_nearby or nearby_player == null:
		return false

	if GameState.input_locked:
		return false

	if _is_ui_typing():
		return false

	if not Input.is_action_just_pressed("interact"):
		return false

	var dialogue_box := _get_dialogue_box()
	if dialogue_box != null and dialogue_box.is_open:
		return false

	return true


func _start_manual_interaction(body: Node2D) -> void:
	is_interacting = true
	GameState.input_locked = true
	_face_body(body)
	if body.has_method("face_world_position"):
		body.face_world_position(get_feet_position())

	await interact_with_player(body)
	GameState.input_locked = false
	is_interacting = false


func interact_with_player(_player: Node2D) -> void:
	await show_dialogue()


func show_dialogue(lines: Array[String] = [], speaker_name_override := "") -> void:
	var dialogue_box := _get_dialogue_box()
	if dialogue_box == null:
		push_warning("%s: DialogueBox/Box not found." % name)
		return

	var source_dialogue_lines := lines
	if source_dialogue_lines.is_empty():
		if not npc_id.is_empty():
			var metadata_response: Dictionary = await _load_npc_metadata()
			if not metadata_response.get("success", false):
				await GameErrorDialogService.show_report_to_staff_message(dialogue_box)
				return
		source_dialogue_lines = dialogue_lines

	var valid_dialogue_lines := _get_valid_dialogue_lines(source_dialogue_lines)
	if valid_dialogue_lines.is_empty():
		push_error("%s has no dialogue lines." % name)
		dialogue_box.start_dialogue(MISSING_DIALOGUE_LINES, "System")
		await dialogue_box.dialogue_finished
		return

	var speaker_name := speaker_name_override
	if speaker_name.is_empty():
		speaker_name = display_name
	if speaker_name.is_empty():
		speaker_name = name

	dialogue_box.start_dialogue(valid_dialogue_lines, speaker_name, mugshot)
	await dialogue_box.dialogue_finished


func _load_npc_metadata() -> Dictionary:
	if npc_metadata_loaded:
		return {
			"success": true,
			"metadata": {},
		}

	if npc_metadata_load_failed:
		return {
			"success": false,
			"error": "NPC metadata already failed for %s" % npc_id,
		}

	var response: Dictionary = await NpcMetadataService.get_npc_metadata(npc_id)
	if not response.get("success", false):
		npc_metadata_load_failed = true
		push_error("%s metadata failed for %s: %s" % [
			name,
			npc_id,
			str(response.get("error", "Unknown API error")),
		])
		return response

	var metadata: Dictionary = response.get("metadata", {})
	_apply_npc_metadata(metadata)
	npc_metadata_loaded = true
	return response


func _apply_npc_metadata(metadata: Dictionary) -> void:
	var metadata_name := str(metadata.get("name", ""))
	if not metadata_name.is_empty():
		display_name = metadata_name

	var metadata_dialogue: Array[String] = _get_string_array(metadata.get("dialogue", []))
	if not metadata_dialogue.is_empty():
		dialogue_lines = metadata_dialogue


func _get_string_array(value: Variant) -> Array[String]:
	var strings: Array[String] = []
	if value is Array:
		for item: Variant in value:
			strings.append(str(item))

	return _get_valid_dialogue_lines(strings)


func _get_valid_dialogue_lines(lines: Array[String]) -> Array[String]:
	var valid_dialogue_lines: Array[String] = []
	for line: String in lines:
		if not line.strip_edges().is_empty():
			valid_dialogue_lines.append(line)

	return valid_dialogue_lines


func _get_dialogue_box() -> Node:
	if get_tree().current_scene == null:
		return null

	return get_tree().current_scene.get_node_or_null("DialogueBox/Box")


func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = true
		nearby_player = body


func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = false
		if body == nearby_player:
			nearby_player = null


func _wait_for_body_tile_movement(body: Node2D) -> void:
	while body != null and body.has_method("is_tile_moving") and body.is_tile_moving():
		await get_tree().process_frame


func _is_ui_typing() -> bool:
	var focused_control := get_viewport().gui_get_focus_owner()
	return focused_control is LineEdit or focused_control is TextEdit


func _update_sort_z() -> void:
	z_index = clampi(floori(get_feet_position().y / TILE_SIZE), SORT_Z_MIN, SORT_Z_MAX)


func _get_cardinal_direction(direction: Vector2) -> Vector2:
	if direction == Vector2.ZERO:
		return Vector2.DOWN

	if abs(direction.x) > abs(direction.y):
		return Vector2(sign(direction.x), 0)

	return Vector2(0, sign(direction.y))
