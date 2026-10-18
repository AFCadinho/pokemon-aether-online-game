@tool
extends TrainerNPC

const QUEST_ID := "investigate_celadon_game_corner"
const BATTLE_STEP := "investigate_game_corner"
const FLEE_STEP := "watch_guard_flee"
const DISGUISE_FRAMES := preload("res://assets/npcs/classes/worker_frames.tres")
const ROCKET_FRAMES := preload("res://assets/npcs/classes/rocket_grunt_m_frames.tres")
const DISGUISE_PORTRAIT := "showdown_worker_gen6"
const ROCKET_PORTRAIT := "showdown_rainbowrocketgrunt"
const ActorFrames := preload("res://scripts/world/story/rocket_trio_actor.gd")

var _origin := Vector2.ZERO
var _sequence_step := ""
var _dialogue_stage := 0
var _revealed := false
var _fled := false
var _fleeing := false
var _motion: Tween
var _presentation_generation := 0
var _rocket_walk_frames: SpriteFrames


func _ready() -> void:
	_origin = position
	super._ready()
	if Engine.is_editor_hint():
		return
	StoryService.story_changed.connect(_on_guard_story_changed)
	_on_guard_story_changed(StoryService.get_revision())


func _exit_tree() -> void:
	_cancel_motion()
	if not Engine.is_editor_hint() and StoryService.story_changed.is_connected(_on_guard_story_changed):
		StoryService.story_changed.disconnect(_on_guard_story_changed)


func supports_trainer_rematches() -> bool:
	return false


func _can_auto_challenge() -> bool:
	return false


func _refresh_rematch_marker() -> void:
	# His attendant disguise must not advertise a Trainer battle.
	if rematch_marker != null:
		rematch_marker.visible = false


func is_gate_open() -> bool:
	return StoryService.is_requirement_met(QUEST_ID, BATTLE_STEP, "completed") or StoryService.is_requirement_met(QUEST_ID, "", "completed")


func blocks_world_position(world_position: Vector2) -> bool:
	if not visible:
		return false
	if not is_gate_open():
		var tile := _to_tile(world_position)
		var origin_tile := _to_tile(get_feet_position())
		if tile in [origin_tile, origin_tile + Vector2i.RIGHT, origin_tile + Vector2i.RIGHT * 2]:
			return true
	return super.blocks_world_position(world_position)


func on_route_gate_blocked(player: Node2D) -> void:
	if is_interacting or _fleeing or not is_instance_valid(player):
		return
	await _start_manual_interaction(player)


func interact_with_player(player: Node2D) -> void:
	if StoryService.is_requirement_met(QUEST_ID, FLEE_STEP, "active"):
		var result: Dictionary = await $EscapeHook.try_handle_interaction(self, player, "interact")
		if not bool(result.get("success", false)):
			abort_story_sequence()
		return
	var dialogue: Dictionary = await NpcDialogueService.resolve_dialogue("kanto_game_corner_guard_blocked", [], "GameCornerRocketGuard")
	await show_dialogue(_string_array(dialogue.get("lines", [])), str(dialogue.get("speakerName", "")))


func prepare_story_sequence() -> Dictionary:
	abort_story_sequence()
	if StoryService.is_requirement_met(QUEST_ID, BATTLE_STEP, "active"):
		_sequence_step = BATTLE_STEP
	elif StoryService.is_requirement_met(QUEST_ID, FLEE_STEP, "active"):
		_sequence_step = FLEE_STEP
	return {"success": not _sequence_step.is_empty()}


func abort_story_sequence() -> void:
	_cancel_motion()
	_sequence_step = ""
	_dialogue_stage = 0
	_fled = false
	position = _origin
	battle_in_progress = false
	_on_guard_story_changed(StoryService.get_revision())


func show_dialogue(lines: Array[String] = [], speaker_name_override := "") -> bool:
	var step := _sequence_step
	var stage := _dialogue_stage
	if not step.is_empty():
		_dialogue_stage += 1
	var shown := await super.show_dialogue(lines, speaker_name_override)
	if not shown or not is_inside_tree():
		return false
	if step == BATTLE_STEP and stage == 1:
		# Player turns use the shared runner. This is the attendant's second
		# turn: "So, we've been found out", immediately before his threat.
		await _reveal_disguise()
	elif step == FLEE_STEP:
		await _flee_downstairs()
	return is_inside_tree()


func _reveal_disguise() -> void:
	var generation := _presentation_generation
	sprite.modulate = Color(1.8, 1.8, 1.8)
	await get_tree().create_timer(0.12).timeout
	if not is_inside_tree() or generation != _presentation_generation or _sequence_step != BATTLE_STEP:
		return
	_revealed = true
	_apply_guard_appearance()
	sprite.modulate = Color.WHITE


func _flee_downstairs() -> void:
	var generation := _presentation_generation
	_fleeing = true
	_play_walk_animation(Vector2.RIGHT)
	_motion = create_tween()
	_motion.tween_property(self, "position", _origin + Vector2(32, 0), 0.55)
	_motion.parallel().tween_property(self, "modulate:a", 0.0, 0.55)
	while _motion != null and _motion.is_valid() and _motion.is_running():
		await get_tree().process_frame
	if generation != _presentation_generation:
		return
	_fleeing = false
	_fled = true
	visible = false


func _cancel_motion() -> void:
	_presentation_generation += 1
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null
	_fleeing = false
	modulate = Color.WHITE
	if sprite != null:
		sprite.modulate = Color.WHITE


func _on_guard_story_changed(_revision: int) -> void:
	if _fleeing and StoryService.is_requirement_met(QUEST_ID, FLEE_STEP, "active"):
		return
	if _fleeing:
		_cancel_motion()
	_revealed = is_gate_open()
	if not _revealed:
		_fled = false
		position = _origin
	visible = not _fled and not StoryService.is_requirement_met(QUEST_ID, "", "completed")
	_apply_guard_appearance()


func _apply_guard_appearance() -> void:
	if _revealed and _rocket_walk_frames == null:
		var atlas := ROCKET_FRAMES.get_frame_texture("idle_down", 0) as AtlasTexture
		_rocket_walk_frames = ActorFrames.build_frames(atlas.atlas)
	npc_sprite_frames = _rocket_walk_frames if _revealed else DISGUISE_FRAMES
	portrait_id = ROCKET_PORTRAIT if _revealed else DISGUISE_PORTRAIT
	battle_sprite_id = portrait_id
	mugshot = TrainerPortraitCatalog.get_texture(portrait_id)
	localized_display_name_key = "npc.game_corner.rocket_guard" if _revealed else "npc.game_corner.attendant"
	display_name = LocalizationManager.text(localized_display_name_key)
	if sprite != null:
		sprite.sprite_frames = _get_directional_sprite_frames(npc_sprite_frames)
		_set_idle_frame(facing_direction)
	_sync_nameplate()
