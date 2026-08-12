@tool
extends BaseNPC

class_name TrainerNPC

const TrainerDefinitionResource := preload("res://scripts/world/npcs/trainer_definition.gd")
const REMATCH_MARKER_TEXTURE := preload("res://assets/ui/icons/trainer_challenge.png")
const INTRO_DIALOGUE_DELAY_SECONDS := 0.2
const BATTLE_TRANSITION_DELAY_SECONDS := 0.35
const SLEEPING_REFRESH_INTERVAL_MSEC := 60_000
const REMATCH_MARKER_BASE_POSITION := Vector2(-24.0, -132.0)

const STATE_FIRST_ENCOUNTER := "first_encounter"
const STATE_DEFEATED := "defeated"
const STATE_READY := "ready"
const STATE_SLEEPING := "sleeping"
const STATE_COMPLETED := "completed"

@export var trainer_id := "kanto_route_1_bug_catcher_1"
@export var sight_range_tiles := 5

@onready var vision_collision_shape: CollisionShape2D = $VisionArea/CollisionShape2D

var triggered := false
var vision_candidate: Node2D
var auto_trigger_failed := false
var trainer_progress_state := STATE_FIRST_ENCOUNTER
var trainer_progress_loaded := false
var trainer_progress_request_active := false
var battle_in_progress := false
var next_progress_refresh_at_msec := 0
var rematch_marker: PanelContainer
var rematch_marker_icon: TextureRect
var rematch_marker_sleep_label: Label

func _ready() -> void:
	_ready_base_npc()
	if Engine.is_editor_hint():
		return
	add_to_group("trainer_npcs")
	_configure_vision_area()
	_setup_rematch_marker()
	_load_trainer_progress.call_deferred()


func _apply_npc_profile() -> void:
	super._apply_npc_profile()
	var trainer_profile := npc_profile as TrainerDefinitionResource
	if trainer_profile == null:
		return
	if not trainer_profile.trainer_id.strip_edges().is_empty():
		trainer_id = trainer_profile.trainer_id
	var profile_environment_id := trainer_profile.battle_environment_id.strip_edges()
	if profile_environment_id != "" and profile_environment_id != "inherit":
		battle_environment_id = profile_environment_id
	

func walk_to_player(body: Node2D) -> void:
	var player_tile := _to_tile(_get_body_target_feet_position(body))
	var npc_tile := _to_tile(get_feet_position())
	var direction := _get_cardinal_direction(facing_direction)
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
	await _show_battle_dialogue(false)


func _show_battle_dialogue(is_rematch: bool) -> void:
	var dialogue_box := get_tree().current_scene.get_node_or_null("DialogueBox/Box")
	if dialogue_box == null:
		push_warning("TrainerNPC: DialogueBox/Box not found.")
		battle_in_progress = false
		GameState.unlock_overworld_input()
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

	var dialogue_lines: Array[String] = []
	if is_rematch:
		dialogue_lines = _resolve_rematch_dialogue_lines(trainer_metadata)
	else:
		dialogue_lines = await _resolve_intro_dialogue_lines(trainer_metadata)
	if dialogue_lines.is_empty():
		await _fail_trainer_metadata(
			dialogue_box,
			"Trainer metadata for %s is missing battle dialogue." % trainer_id
		)
		return

	await get_tree().create_timer(INTRO_DIALOGUE_DELAY_SECONDS).timeout
	
	dialogue_box.start_dialogue(dialogue_lines, speaker_name, mugshot)
	await dialogue_box.dialogue_finished
	await get_tree().create_timer(BATTLE_TRANSITION_DELAY_SECONDS).timeout
	if is_rematch and not await _reserve_daily_rematch(dialogue_box):
		return
	
	var battle_metadata := trainer_metadata.duplicate(true)
	battle_metadata["_is_rematch"] = is_rematch
	var battle_result: Dictionary = await start_trainer_battle(battle_metadata)
	if not bool(battle_result.get("success", false)):
		battle_in_progress = false
		if trainer_progress_state == STATE_FIRST_ENCOUNTER:
			triggered = false
		await GameErrorDialogService.show_response(
			battle_result,
			"backend.error.trainer_battle_start",
			dialogue_box
		)


func _resolve_rematch_dialogue_lines(trainer_metadata: Dictionary) -> Array[String]:
	var configured_lines := _string_array(trainer_metadata.get("dialogue_rematch", []))
	if not configured_lines.is_empty():
		return configured_lines
	return [LocalizationManager.text("npc.trainer.rematch.ready")]
	
func start_trainer_battle(trainer_metadata: Dictionary) -> Dictionary:
	var world := get_tree().get_first_node_in_group("world")
	if world == null or not world.has_method("start_trainer_battle"):
		push_warning("TrainerNPC: World cannot start trainer battle.")
		GameState.unlock_overworld_input()
		return {
			"success": false,
			"code": "trainer_battle_world_unavailable",
		}

	return await world.start_trainer_battle(build_battle_trainer_metadata(trainer_metadata))

func _get_dialogue_lines_from_trainer_metadata(trainer_metadata: Dictionary) -> Array[String]:
	var dialogue_lines: Array[String] = []
	var dialogue_value: Variant = trainer_metadata.get("dialogue_before_battle", [])
	if dialogue_value is Array:
		for item: Variant in dialogue_value:
			var line := str(item).strip_edges()
			if not line.is_empty():
				dialogue_lines.append(line)
	
	return dialogue_lines

func _resolve_intro_dialogue_lines(trainer_metadata: Dictionary) -> Array[String]:
	var configured_dialogue_id := _get_dialogue_override_id()
	if not configured_dialogue_id.is_empty():
		var configured_lines := await _get_dialogue_metadata_lines(configured_dialogue_id)
		if not configured_lines.is_empty():
			return configured_lines

	var metadata_dialogue_id := _get_intro_dialogue_id_from_trainer_metadata(trainer_metadata)
	if not metadata_dialogue_id.is_empty() and metadata_dialogue_id != configured_dialogue_id:
		var metadata_lines := await _get_dialogue_metadata_lines(metadata_dialogue_id)
		if not metadata_lines.is_empty():
			return metadata_lines

	return _get_dialogue_lines_from_trainer_metadata(trainer_metadata)

func _get_intro_dialogue_id_from_trainer_metadata(trainer_metadata: Dictionary) -> String:
	for key: String in [
		"battleIntroDialogueId",
		"battle_intro_dialogue_id",
		"introDialogueId",
		"intro_dialogue_id",
		"dialogueId",
		"dialogue_id",
	]:
		var value := str(trainer_metadata.get(key, "")).strip_edges()
		if not value.is_empty():
			return value

	return ""

func _get_dialogue_metadata_lines(intro_dialogue_id: String) -> Array[String]:
	return await NpcDialogueService.resolve_lines(
		intro_dialogue_id,
		[],
		"TrainerNPC"
	)

func _fail_trainer_metadata(dialogue_box: Node, message: String) -> void:
	push_error("TrainerNPC: %s" % message)
	auto_trigger_failed = true
	battle_in_progress = false
	triggered = false
	vision_candidate = null
	await _show_generic_trainer_error_dialogue(dialogue_box)

func _show_generic_trainer_error_dialogue(dialogue_box: Node) -> void:
	await GameErrorDialogService.show_report_to_staff_message(dialogue_box)
	

func _on_vision_area_body_entered(body: Node2D) -> void:
	if not _can_auto_challenge():
		return
		
	if body.name != "Player":
		return
	
	vision_candidate = body
	await _try_trigger_vision(body)

func _try_trigger_vision(body: Node2D) -> void:
	if not _can_auto_challenge():
		return

	if auto_trigger_failed:
		return
	
	if body == null or body.name != "Player":
		return
	
	if not _is_body_in_sight_range(body):
		return
	
	triggered = true
	battle_in_progress = true
	GameState.lock_overworld_input()
	await _wait_for_body_tile_movement(body)
	if not _is_body_in_sight_range(body):
		battle_in_progress = false
		triggered = false
		GameState.unlock_overworld_input()
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
	if Engine.is_editor_hint():
		return
	_update_rematch_marker_animation()
	await _refresh_sleeping_progress_if_due()

	if vision_candidate != null and _can_auto_challenge():
		_try_trigger_vision(vision_candidate)

func _can_start_manual_interaction() -> bool:
	if not trainer_progress_loaded or battle_in_progress:
		return false
	if trainer_progress_state == STATE_FIRST_ENCOUNTER and triggered:
		return false

	return super._can_start_manual_interaction()

func interact_with_player(_player: Node2D) -> void:
	match trainer_progress_state:
		STATE_FIRST_ENCOUNTER:
			triggered = true
			battle_in_progress = true
			await show_intro_dialogue()
		STATE_READY:
			await _begin_rematch_interaction()
		STATE_SLEEPING:
			await show_dialogue(
				[LocalizationManager.text("npc.trainer.rematch.sleeping")],
				display_name
			)
		STATE_DEFEATED, STATE_COMPLETED:
			await _show_post_battle_dialogue()


func supports_trainer_rematches() -> bool:
	return true


func has_existing_trainer_completion() -> bool:
	return false


func _begin_rematch_interaction() -> void:
	battle_in_progress = true
	await _show_battle_dialogue(true)


func _reserve_daily_rematch(dialogue_box: Node) -> bool:
	trainer_progress_request_active = true
	var result: Dictionary = await TrainerProgressService.begin_rematch(trainer_id)
	trainer_progress_request_active = false
	if not bool(result.get("success", false)):
		battle_in_progress = false
		await GameErrorDialogService.show_response(result, "", dialogue_box)
		await _load_trainer_progress()
		return false
	trainer_progress_state = STATE_SLEEPING
	next_progress_refresh_at_msec = Time.get_ticks_msec() + SLEEPING_REFRESH_INTERVAL_MSEC
	_refresh_rematch_marker()
	_configure_vision_area()
	return true


func finish_trainer_battle(finished_trainer_id: String, player_won: bool) -> void:
	if finished_trainer_id.strip_edges() != trainer_id.strip_edges():
		return
	battle_in_progress = false
	if trainer_progress_state == STATE_FIRST_ENCOUNTER:
		if player_won:
			trainer_progress_state = STATE_DEFEATED
			_refresh_rematch_marker()
			_configure_vision_area()
		else:
			triggered = false


func mark_trainer_completed() -> void:
	trainer_progress_loaded = true
	trainer_progress_state = STATE_COMPLETED
	battle_in_progress = false
	_refresh_rematch_marker()
	_configure_vision_area()


func apply_battle_victory_progress(progress_trainer_id: String, progress: Dictionary) -> void:
	if progress_trainer_id.strip_edges() != trainer_id.strip_edges():
		return
	battle_in_progress = false
	trainer_progress_loaded = true
	trainer_progress_state = str(progress.get("state", STATE_DEFEATED)).strip_edges().to_lower()
	if not supports_trainer_rematches():
		trainer_progress_state = STATE_COMPLETED
	if trainer_progress_state == STATE_SLEEPING:
		next_progress_refresh_at_msec = Time.get_ticks_msec() + SLEEPING_REFRESH_INTERVAL_MSEC
	_refresh_rematch_marker()
	_configure_vision_area()


func _load_trainer_progress() -> void:
	if trainer_progress_request_active:
		return
	trainer_progress_request_active = true
	var result: Dictionary = await TrainerProgressService.get_progress(trainer_id)
	trainer_progress_request_active = false
	if not bool(result.get("success", false)):
		push_warning("TrainerNPC: progress failed for %s: %s" % [
			trainer_id,
			str(result.get("error", "Unknown API error")),
		])
		# Keep the first encounter playable if the optional progress projection
		# cannot be loaded. Reward persistence remains server-authoritative.
		trainer_progress_state = (
			STATE_COMPLETED if has_existing_trainer_completion() else STATE_FIRST_ENCOUNTER
		)
		trainer_progress_loaded = true
		_configure_vision_area()
		return

	var progress: Dictionary = result.get("progress", {}) as Dictionary
	trainer_progress_state = str(progress.get("state", STATE_FIRST_ENCOUNTER)).strip_edges().to_lower()
	if has_existing_trainer_completion():
		trainer_progress_state = STATE_COMPLETED
	elif not supports_trainer_rematches() and trainer_progress_state != STATE_FIRST_ENCOUNTER:
		trainer_progress_state = STATE_COMPLETED
	trainer_progress_loaded = true
	if trainer_progress_state == STATE_SLEEPING:
		next_progress_refresh_at_msec = Time.get_ticks_msec() + SLEEPING_REFRESH_INTERVAL_MSEC
	_refresh_rematch_marker()
	_configure_vision_area()


func _refresh_sleeping_progress_if_due() -> void:
	if (
		trainer_progress_state != STATE_SLEEPING
		or trainer_progress_request_active
		or Time.get_ticks_msec() < next_progress_refresh_at_msec
	):
		return
	next_progress_refresh_at_msec = Time.get_ticks_msec() + SLEEPING_REFRESH_INTERVAL_MSEC
	await _load_trainer_progress()


func _can_auto_challenge() -> bool:
	return (
		trainer_progress_loaded
		and trainer_progress_state == STATE_FIRST_ENCOUNTER
		and not triggered
		and not battle_in_progress
		and not auto_trigger_failed
	)


func _show_post_battle_dialogue() -> void:
	var metadata_response: Dictionary = await TrainerMetadataService.get_trainer_metadata(trainer_id)
	if not bool(metadata_response.get("success", false)):
		await GameErrorDialogService.show_response(metadata_response)
		return
	var metadata: Dictionary = metadata_response.get("metadata", {}) as Dictionary
	var lines := _string_array(metadata.get("dialogue_after_battle", []))
	if lines.is_empty():
		lines = [LocalizationManager.text("npc.trainer.rematch.defeated")]
	await show_dialogue(lines, str(metadata.get("name", display_name)))


func _setup_rematch_marker() -> void:
	if rematch_marker != null:
		return
	rematch_marker = PanelContainer.new()
	rematch_marker.name = "RematchMarker"
	rematch_marker.visible = false
	rematch_marker.z_index = 514
	rematch_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rematch_marker.position = REMATCH_MARKER_BASE_POSITION
	rematch_marker.custom_minimum_size = Vector2(48.0, 48.0)
	rematch_marker.add_theme_stylebox_override("panel", _rematch_marker_style())
	add_child(rematch_marker)

	rematch_marker_icon = TextureRect.new()
	rematch_marker_icon.name = "PokeBall"
	rematch_marker_icon.texture = REMATCH_MARKER_TEXTURE
	rematch_marker_icon.custom_minimum_size = Vector2(48.0, 48.0)
	rematch_marker_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rematch_marker_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rematch_marker_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rematch_marker.add_child(rematch_marker_icon)

	rematch_marker_sleep_label = Label.new()
	rematch_marker_sleep_label.name = "Sleeping"
	rematch_marker_sleep_label.text = "Zzz"
	rematch_marker_sleep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rematch_marker_sleep_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rematch_marker_sleep_label.add_theme_font_size_override("font_size", 15)
	rematch_marker_sleep_label.add_theme_constant_override("outline_size", 4)
	rematch_marker_sleep_label.add_theme_color_override("font_color", Color("#9ed9ffff"))
	rematch_marker_sleep_label.add_theme_color_override("font_outline_color", Color("#07111cff"))
	rematch_marker_sleep_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rematch_marker.add_child(rematch_marker_sleep_label)
	_refresh_rematch_marker()


func _refresh_rematch_marker() -> void:
	if rematch_marker == null:
		return
	var show_ready := trainer_progress_state == STATE_READY and supports_trainer_rematches()
	var show_sleeping := trainer_progress_state == STATE_SLEEPING and supports_trainer_rematches()
	rematch_marker.visible = show_ready or show_sleeping
	rematch_marker_icon.visible = show_ready
	rematch_marker_sleep_label.visible = show_sleeping


func _update_rematch_marker_animation() -> void:
	if rematch_marker == null:
		return
	if trainer_progress_state == STATE_READY and rematch_marker.visible:
		var bob := sin(float(Time.get_ticks_msec()) * 0.006) * 2.5
		rematch_marker.position = REMATCH_MARKER_BASE_POSITION + Vector2(0.0, bob)
	else:
		rematch_marker.position = REMATCH_MARKER_BASE_POSITION


func _rematch_marker_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	return style


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			var text := str(item).strip_edges()
			if not text.is_empty():
				result.append(text)
	return result

func _is_body_in_sight_range(body: Node2D) -> bool:
	var range_tiles: int = maxi(sight_range_tiles, 0)
	if range_tiles == 0:
		return false
	
	var direction := _get_cardinal_direction(facing_direction)
	var npc_tile := _to_tile(get_feet_position())
	var body_tile := _to_tile(_get_body_target_feet_position(body))
	var delta := body_tile - npc_tile
	
	if direction.x != 0:
		return delta.y == 0 and delta.x == int(direction.x) * clampi(abs(delta.x), 1, range_tiles)
	
	return delta.x == 0 and delta.y == int(direction.y) * clampi(abs(delta.y), 1, range_tiles)

func _configure_vision_area() -> void:
	if vision_collision_shape == null:
		return
	if not Engine.is_editor_hint() and (
		not trainer_progress_loaded or trainer_progress_state != STATE_FIRST_ENCOUNTER
	):
		vision_collision_shape.disabled = true
		return
	
	var range_tiles: int = maxi(sight_range_tiles, 0)
	if range_tiles == 0:
		vision_collision_shape.disabled = true
		return
	
	var direction := _get_cardinal_direction(facing_direction)
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
