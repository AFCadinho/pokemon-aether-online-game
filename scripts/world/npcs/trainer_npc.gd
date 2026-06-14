extends BaseNPC

class_name TrainerNPC

@export var trainer_id := "route_1_bug_catcher_1"
@export var sight_direction := Vector2.DOWN
@export var sight_range_tiles := 5

@onready var vision_collision_shape: CollisionShape2D = $VisionArea/CollisionShape2D

var triggered := false
var vision_candidate: Node2D
var auto_trigger_failed := false

func _ready() -> void:
	_ready_base_npc()
	_configure_vision_area()
	

func walk_to_player(body: Node2D) -> void:
	var player_tile := _to_tile(_get_body_target_feet_position(body))
	var npc_tile := _to_tile(get_feet_position())
	var direction := _get_cardinal_direction(sight_direction)
	if direction == Vector2.ZERO:
		return
	
	var stop_tile := _get_straight_line_stop_tile(npc_tile, player_tile, direction)
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

func _get_straight_line_stop_tile(npc_tile: Vector2i, player_tile: Vector2i, direction: Vector2) -> Vector2i:
	if direction.x != 0:
		return Vector2i(player_tile.x - int(direction.x), npc_tile.y)

	return Vector2i(npc_tile.x, player_tile.y - int(direction.y))
	
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
	await _wait_for_body_tile_movement(body)
	if not _is_body_in_sight_range(body):
		triggered = false
		GameState.input_locked = false
		return

	await walk_to_player(body)
	if body.has_method("face_world_position"):
		body.face_world_position(get_feet_position())
	await show_intro_dialogue()

func _on_vision_area_body_exited(body: Node2D) -> void:
	if body == vision_candidate:
		vision_candidate = null

func _process(_delta: float) -> void:
	await _process_base_npc()
	
	if vision_candidate != null:
		_try_trigger_vision(vision_candidate)

func _can_start_manual_interaction() -> bool:
	if triggered:
		return false

	return super._can_start_manual_interaction()

func interact_with_player(_player: Node2D) -> void:
	await show_intro_dialogue()

func _is_body_in_sight_range(body: Node2D) -> bool:
	var range_tiles: int = maxi(sight_range_tiles, 0)
	if range_tiles == 0:
		return false
	
	var direction := _get_cardinal_direction(sight_direction)
	var npc_tile := _to_tile(get_feet_position())
	var body_tile := _to_tile(_get_body_target_feet_position(body))
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
