@tool
extends BaseNPC

class_name TrainerNPC

const TrainerDefinitionResource := preload("res://scripts/world/npcs/trainer_definition.gd")
const FIRST_ENCOUNTER_MARKER_TEXTURE := preload("res://assets/ui/icons/trainer_first_encounter.png")
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
## Number of tiles directly ahead that can trigger this trainer. After spotting
## the player, the trainer walks along that line until they are one tile away.
@export_range(0, 12, 1) var sight_range_tiles := 5

@onready var vision_collision_shape: CollisionShape2D = $VisionArea/CollisionShape2D

var triggered := false
var vision_candidate: Node2D
var auto_trigger_failed := false
var trainer_progress_state := STATE_FIRST_ENCOUNTER
var trainer_progress_loaded := false
var trainer_progress_request_active := false
var developer_rematch_mode := false
var battle_in_progress := false
var next_progress_refresh_at_msec := 0
var rematch_marker: PanelContainer
var rematch_marker_icon: TextureRect
var rematch_marker_sleep_label: Label
var resolved_battle_dialogue_speaker_name := ""

func _ready() -> void:
	_ready_base_npc()
	if Engine.is_editor_hint():
		return
	add_to_group("trainer_npcs")
	_configure_vision_area()
	_setup_rematch_marker()
	if not TrainerProgressService.progress_invalidated.is_connected(_reload_trainer_progress):
		TrainerProgressService.progress_invalidated.connect(_reload_trainer_progress)
	_load_trainer_progress.call_deferred()


func _loads_pickpocket_profile_from_npc_metadata() -> bool:
	# Battle Orchestrator owns trainer names, dialogue, teams, and progression.
	return false


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
	# A vision area is short and straight. Bound this animation defensively:
	# malformed map origins/facing data must never leave the overworld locked in
	# an unbounded approach loop before the battle dialogue can begin.
	var expected_steps: int = absi(stop_tile.x - npc_tile.x) + absi(stop_tile.y - npc_tile.y)
	var maximum_steps := clampi(expected_steps + 1, 1, 16)
	var completed_steps := 0
	while _to_tile(get_feet_position()) != stop_tile and completed_steps < maximum_steps:
		var current_tile := _to_tile(get_feet_position())
		var next_tile := current_tile + Vector2i(int(direction.x), int(direction.y))
		var target_position := _tile_to_world(next_tile)
		var tween := create_tween()
		tween.tween_property(self, "global_position", target_position, TILE_SIZE / MOVE_SPEED)
		await tween.finished
		completed_steps += 1
		_update_sort_z()

	if _to_tile(get_feet_position()) != stop_tile:
		push_warning(
			"TrainerNPC vision approach exceeded its straight-line bound; snapping to battle position."
		)
		global_position = _tile_to_world(stop_tile)
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
		_refresh_rematch_marker()
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
	resolved_battle_dialogue_speaker_name = ""
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
	if not resolved_battle_dialogue_speaker_name.is_empty():
		speaker_name = resolved_battle_dialogue_speaker_name

	await get_tree().create_timer(INTRO_DIALOGUE_DELAY_SECONDS).timeout
	
	dialogue_box.start_dialogue(dialogue_lines, speaker_name, mugshot)
	await dialogue_box.dialogue_finished
	await get_tree().create_timer(BATTLE_TRANSITION_DELAY_SECONDS).timeout
	var battle_metadata := trainer_metadata.duplicate(true)
	battle_metadata["_is_rematch"] = is_rematch
	var battle_result: Dictionary = await start_trainer_battle(battle_metadata)
	if not bool(battle_result.get("success", false)):
		_release_failed_battle_start()
		await GameErrorDialogService.show_response(
			battle_result,
			"backend.error.trainer_battle_start",
			dialogue_box
		)
		_recover_overworld_after_failed_battle_start()


func _release_failed_battle_start() -> void:
	battle_in_progress = false
	# A player who remains inside a Trainer's vision after a rejected start
	# must be able to read the error and regain control without retriggering
	# the intro every frame. Manual interaction remains available for retries.
	auto_trigger_failed = true
	vision_candidate = null
	if trainer_progress_state == STATE_FIRST_ENCOUNTER:
		triggered = false
	_refresh_rematch_marker()


func _recover_overworld_after_failed_battle_start() -> void:
	# A trainer challenge takes an early, local input lock before World begins
	# its transition. If the backend rejects that transition, the World normally
	# releases it; invoke the idempotent recovery after the error dialogue too,
	# so a failed request can never leave a browser player frozen on relog.
	var world := get_tree().get_first_node_in_group("world")
	if world != null and world.has_method("recover_failed_trainer_battle_start"):
		world.call("recover_failed_trainer_battle_start")
		return
	GameState.unlock_overworld_input()


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
	var result := await NpcDialogueService.resolve_dialogue(
		intro_dialogue_id,
		[],
		"TrainerNPC"
	)
	var speaker_name := str(result.get("speakerName", "")).strip_edges()
	if not speaker_name.is_empty():
		resolved_battle_dialogue_speaker_name = speaker_name
	return _string_array(result.get("lines", []))

func _fail_trainer_metadata(dialogue_box: Node, message: String) -> void:
	push_error("TrainerNPC: %s" % message)
	auto_trigger_failed = true
	battle_in_progress = false
	triggered = false
	vision_candidate = null
	_refresh_rematch_marker()
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
	if not _claim_battle_interaction():
		return

	triggered = true
	GameState.lock_overworld_input()
	await _wait_for_body_tile_movement(body)
	if not _is_body_in_sight_range(body):
		battle_in_progress = false
		triggered = false
		_refresh_rematch_marker()
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
			if not _claim_battle_interaction():
				return
			triggered = true
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
	if not _claim_battle_interaction():
		return
	await _show_battle_dialogue(true)


func _claim_battle_interaction() -> bool:
	if battle_in_progress:
		return false
	battle_in_progress = true
	_refresh_rematch_marker()
	return true


func finish_trainer_battle(finished_trainer_id: String, player_won: bool) -> void:
	if finished_trainer_id.strip_edges() != trainer_id.strip_edges():
		return
	battle_in_progress = false
	if trainer_progress_state == STATE_FIRST_ENCOUNTER:
		if player_won:
			trainer_progress_state = STATE_DEFEATED
			_configure_vision_area()
		else:
			triggered = false
	_refresh_rematch_marker()


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
	_apply_trainer_progress(progress, STATE_DEFEATED)
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
		_refresh_rematch_marker()
		_configure_vision_area()
		return

	var progress: Dictionary = result.get("progress", {}) as Dictionary
	_apply_trainer_progress(progress, STATE_FIRST_ENCOUNTER)
	if trainer_progress_state == STATE_SLEEPING:
		next_progress_refresh_at_msec = Time.get_ticks_msec() + SLEEPING_REFRESH_INTERVAL_MSEC
	_refresh_rematch_marker()
	_configure_vision_area()


func _apply_trainer_progress(progress: Dictionary, fallback_state: String) -> void:
	developer_rematch_mode = bool(progress.get("developerRematchMode", false))
	trainer_progress_state = str(progress.get("state", fallback_state)).strip_edges().to_lower()
	if has_existing_trainer_completion():
		trainer_progress_state = STATE_COMPLETED
	elif not supports_trainer_rematches():
		if trainer_progress_state != STATE_FIRST_ENCOUNTER:
			trainer_progress_state = STATE_COMPLETED
	elif developer_rematch_mode and trainer_progress_state == STATE_FIRST_ENCOUNTER:
		# The protected server setting projects ordinary trainers as rematches.
		# Story and gym trainer subclasses opt out through supports_trainer_rematches.
		trainer_progress_state = STATE_READY
	trainer_progress_loaded = true


func _reload_trainer_progress() -> void:
	if battle_in_progress:
		return
	while trainer_progress_request_active:
		await get_tree().process_frame
	if not is_inside_tree() or battle_in_progress:
		return
	triggered = false
	auto_trigger_failed = false
	vision_candidate = null
	trainer_progress_loaded = false
	developer_rematch_mode = false
	next_progress_refresh_at_msec = 0
	await _load_trainer_progress()


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
		and not is_interacting
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
	var fallback_lines := _string_array(metadata.get("dialogue_after_battle", []))
	var lines: Array[String] = []
	var speaker_name := str(metadata.get("name", display_name))
	var completed_dialogue_id := str(metadata.get("completedDialogueId", "")).strip_edges()
	var dialogue_id := completed_dialogue_id
	if dialogue_id.is_empty():
		dialogue_id = str(metadata.get("outroDialogueId", "")).strip_edges()
	if not dialogue_id.is_empty():
		var dialogue := await NpcDialogueService.resolve_dialogue(
			dialogue_id,
			fallback_lines,
			"TrainerNPC"
		)
		lines = _string_array(dialogue.get("lines", []))
		var localized_speaker_name := str(dialogue.get("speakerName", "")).strip_edges()
		if not localized_speaker_name.is_empty():
			speaker_name = localized_speaker_name
	else:
		lines = fallback_lines
	if lines.is_empty():
		lines = [LocalizationManager.text("npc.trainer.rematch.defeated")]
	await show_dialogue(lines, speaker_name)


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
	rematch_marker_sleep_label.add_theme_font_size_override("font_size", 22)
	rematch_marker_sleep_label.add_theme_constant_override("outline_size", 5)
	rematch_marker_sleep_label.add_theme_constant_override("shadow_offset_x", 1)
	rematch_marker_sleep_label.add_theme_constant_override("shadow_offset_y", 2)
	rematch_marker_sleep_label.add_theme_constant_override("shadow_outline_size", 2)
	rematch_marker_sleep_label.add_theme_color_override("font_color", Color("#e8f8ffff"))
	rematch_marker_sleep_label.add_theme_color_override("font_outline_color", Color("#123b63ff"))
	rematch_marker_sleep_label.add_theme_color_override("font_shadow_color", Color("#020811cc"))
	rematch_marker_sleep_label.add_theme_stylebox_override("normal", _sleeping_marker_style())
	rematch_marker_sleep_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rematch_marker.add_child(rematch_marker_sleep_label)
	_refresh_rematch_marker()


func _refresh_rematch_marker() -> void:
	if rematch_marker == null:
		return
	var show_first_encounter := (
		trainer_progress_loaded
		and trainer_progress_state == STATE_FIRST_ENCOUNTER
		and not battle_in_progress
	)
	var show_ready := trainer_progress_state == STATE_READY and supports_trainer_rematches()
	var show_sleeping := trainer_progress_state == STATE_SLEEPING and supports_trainer_rematches()
	rematch_marker.visible = show_first_encounter or show_ready or show_sleeping
	rematch_marker_icon.visible = show_first_encounter or show_ready
	rematch_marker_icon.texture = (
		FIRST_ENCOUNTER_MARKER_TEXTURE if show_first_encounter else REMATCH_MARKER_TEXTURE
	)
	rematch_marker_sleep_label.visible = show_sleeping


func _update_rematch_marker_animation() -> void:
	if rematch_marker == null:
		return
	if trainer_progress_state in [STATE_FIRST_ENCOUNTER, STATE_READY] and rematch_marker.visible:
		var bob := sin(float(Time.get_ticks_msec()) * 0.006) * 2.5
		rematch_marker.position = REMATCH_MARKER_BASE_POSITION + Vector2(0.0, bob)
		rematch_marker.modulate = Color.WHITE
	elif trainer_progress_state == STATE_SLEEPING and rematch_marker.visible:
		var pulse := (sin(float(Time.get_ticks_msec()) * 0.004) + 1.0) * 0.5
		rematch_marker.position = REMATCH_MARKER_BASE_POSITION + Vector2(0.0, -pulse * 2.0)
		rematch_marker.modulate = Color(1.0, 1.0, 1.0, lerpf(0.82, 1.0, pulse))
	else:
		rematch_marker.position = REMATCH_MARKER_BASE_POSITION
		rematch_marker.modulate = Color.WHITE


func _rematch_marker_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	return style


func _sleeping_marker_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#071827e6")
	style.border_color = Color("#69d5ffff")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 5.0
	style.content_margin_top = 1.0
	style.content_margin_right = 5.0
	style.content_margin_bottom = 2.0
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
