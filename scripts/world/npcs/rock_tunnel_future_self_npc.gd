@tool
extends TrainerNPC

class_name RockTunnelFutureSelfNPC

const FutureSelfAppearance := preload("res://scripts/world/story/future_self_appearance.gd")
const PlayerTrainerCatalog := preload("res://scripts/battle/battle_ui/battle_player_trainer_catalog.gd")

const FUTURE_SELF_TRAINER_ID := "kanto_rock_tunnel_future_self"

var mysterious_appearance: Dictionary = {}
var farewell_pending := false


func _ready() -> void:
	if Engine.is_editor_hint():
		# Unowned preview nodes stay out of the saved scene. Runtime-generated
		# resources must never be assigned to exported NPC properties here.
		var preview := AnimatedSprite2D.new()
		preview.name = "MysteriousEditorPreview"
		preview.position = sprite_offset
		preview.sprite_frames = FutureSelfAppearance.build_overworld_frames(FutureSelfAppearance.build_state({}))
		$Look.add_child(preview)
		preview.play(_get_idle_animation_name(facing_direction))
		preview.stop()
		return
	trainer_id = FUTURE_SELF_TRAINER_ID
	display_name = "Mysterious Trainer"
	portrait_id = ""
	var save := get_node_or_null("/root/PlayerSave")
	mysterious_appearance = FutureSelfAppearance.build_state(save.to_appearance_state() if save != null else {})
	npc_sprite_frames = FutureSelfAppearance.build_overworld_frames(mysterious_appearance)
	mugshot = PlayerTrainerCatalog.build_dialogue_portrait(mysterious_appearance)
	super._ready()


func _resolve_catalog_mugshot() -> void:
	# This portrait follows the player, rather than a trainer class catalog entry.
	pass


func _resolve_battle_sprite_id() -> String:
	# Layered trainer art is supplied separately from the overworld frames.
	return ""


func build_battle_trainer_metadata(metadata: Dictionary) -> Dictionary:
	var presentation := super.build_battle_trainer_metadata(metadata)
	presentation["_hide_pokemon_level"] = true
	presentation["_battle_appearance"] = mysterious_appearance.duplicate(true)
	presentation.erase("_battle_sprite_frames")
	return presentation


func supports_trainer_rematches() -> bool:
	return false


func finish_trainer_battle(finished_trainer_id: String, player_won: bool) -> void:
	if finished_trainer_id == FUTURE_SELF_TRAINER_ID:
		farewell_pending = true
	super.finish_trainer_battle(finished_trainer_id, player_won)


func start_mandatory_battle(player: Node2D) -> void:
	if not trainer_progress_loaded:
		await _load_trainer_progress()
	if trainer_progress_state in [STATE_DEFEATED, STATE_COMPLETED]:
		return
	if not _claim_battle_interaction():
		return
	triggered = true
	GameState.lock_overworld_input()
	_position_for_mandatory_battle(player)
	if player.has_method("face_world_position"):
		player.face_world_position(get_feet_position())
	await show_intro_dialogue()


func _position_for_mandatory_battle(player: Node2D) -> bool:
	# Exit enforcement can happen on the other side of the cave. Bring the
	# masked visitor into view on a nearby walkable, unoccupied tile.
	var player_feet := _get_body_target_feet_position(player)
	var player_tile := _to_tile(player_feet)
	for distance: int in [1, 2]:
		for direction: Vector2i in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
			var target := _tile_to_world(player_tile + direction * distance)
			if not _can_story_npc_move_to(target):
				continue
			global_position += target - get_feet_position()
			movement_origin_tile = _to_tile(target)
			visible = true
			modulate.a = 1.0
			_set_idle_frame(player_feet - target)
			_update_directional_sensors()
			_update_sort_z()
			return true
	return false


func _recover_overworld_after_failed_battle_start() -> void:
	# A failed request must leave this mandatory encounter pending; the base
	# trainer fallback completes optional trainers after a failed start.
	trainer_progress_loaded = true
	trainer_progress_state = STATE_FIRST_ENCOUNTER
	battle_in_progress = false
	triggered = false
	_refresh_rematch_marker()
	_configure_vision_area()
	var world := get_tree().get_first_node_in_group("world")
	if world != null and world.has_method("recover_failed_trainer_battle_start"):
		world.call("recover_failed_trainer_battle_start")
	else:
		GameState.unlock_overworld_input()


func _load_trainer_progress() -> void:
	await super._load_trainer_progress()
	if not farewell_pending:
		visible = trainer_progress_state not in [STATE_DEFEATED, STATE_COMPLETED]
		if visible:
			modulate.a = 1.0


func _can_start_manual_interaction() -> bool:
	if not is_visible_in_tree() or trainer_progress_state in [STATE_DEFEATED, STATE_COMPLETED]:
		return false
	return super._can_start_manual_interaction()


func interact_with_player(player: Node2D) -> void:
	if not is_visible_in_tree() or trainer_progress_state in [STATE_DEFEATED, STATE_COMPLETED]:
		return
	await super.interact_with_player(player)


func _can_auto_challenge() -> bool:
	# The fixed C staircase owns the mandatory encounter, not line of sight.
	return false


func blocks_world_position(world_position: Vector2) -> bool:
	if not is_visible_in_tree() or modulate.a <= 0.0:
		return false
	if not farewell_pending and trainer_progress_state in [STATE_DEFEATED, STATE_COMPLETED]:
		return false
	return super.blocks_world_position(world_position)


func _apply_story_visibility(allow_deferred_hide := false) -> void:
	super._apply_story_visibility(allow_deferred_hide)
	# Story refreshes must not resurrect a completed trainer at zero opacity.
	if not farewell_pending and trainer_progress_state in [STATE_DEFEATED, STATE_COMPLETED]:
		visible = false


func finish_story_battle_presentation(finished_trainer_id: String) -> void:
	if finished_trainer_id != FUTURE_SELF_TRAINER_ID or not farewell_pending:
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.45)
	await tween.finished
	farewell_pending = false
	visible = false
