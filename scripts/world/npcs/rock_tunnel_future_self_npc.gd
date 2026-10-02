@tool
extends TrainerNPC

class_name RockTunnelFutureSelfNPC

const FutureSelfAppearance := preload("res://scripts/world/story/future_self_appearance.gd")
const PlayerTrainerCatalog := preload("res://scripts/battle/battle_ui/battle_player_trainer_catalog.gd")

const RIFT_TEXTURE := preload("res://assets/npcs/Ultimate Gen 4 Overworlds Pack/Animations & Others/DistortionWorld_Portal.png")

const FUTURE_SELF_TRAINER_ID := "kanto_rock_tunnel_future_self"

var mysterious_appearance: Dictionary = {}
var farewell_pending := false
var arrival_started := false


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
	visible = false
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
	if not _position_for_mandatory_battle(player):
		_recover_overworld_after_failed_battle_start()
		return
	await _reveal_at_staircase()
	if player.has_method("face_world_position"):
		player.face_world_position(get_feet_position())
	await show_intro_dialogue()


func _position_for_mandatory_battle(player: Node2D) -> bool:
	var player_feet := _get_body_target_feet_position(player)
	var player_tile := _to_tile(player_feet)
	var direction_value: Variant = player.get("last_direction")
	var approach := Vector2i(direction_value) if direction_value is Vector2 else Vector2i.RIGHT
	if approach == Vector2i.ZERO:
		approach = Vector2i.RIGHT
	# Stay behind the player's approach to the staircase, even if a follower
	# occupies the nearest tile. Never reveal him ahead of the player.
	for distance: int in [1, 2, 3]:
		var target := _tile_to_world(player_tile - approach * distance)
		if not _can_story_npc_move_to(target):
			continue
		global_position += target - get_feet_position()
		movement_origin_tile = _to_tile(target)
		_set_idle_frame(player_feet - target)
		_update_directional_sensors()
		_update_sort_z()
		return true
	return false


func _reveal_at_staircase() -> void:
	# Match Mt. Moon's rift, blue fade and 16-pixel descent. Keep the rift a
	# sibling so it can open while the trainer himself is still hidden.
	var rift := Sprite2D.new()
	rift.texture = RIFT_TEXTURE
	rift.z_index = -1
	rift.scale = Vector2(0.05, 0.05)
	rift.modulate = Color(0.7, 0.82, 1.0, 0.0)
	get_parent().add_child(rift)
	rift.global_position = global_position + Vector2(0, -12)
	var open_tween := create_tween().set_parallel(true)
	open_tween.tween_property(rift, "scale", Vector2(0.72, 0.9), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open_tween.tween_property(rift, "modulate:a", 0.95, 0.28)
	open_tween.tween_property(rift, "rotation", 0.5, 0.45)
	await open_tween.finished
	arrival_started = true
	modulate = Color(0.5, 0.65, 1.0, 0.0)
	visible = true
	var look: Node2D = $Look
	var look_origin := look.position
	look.position.y -= 16.0
	var reveal_tween := create_tween().set_parallel(true)
	reveal_tween.tween_property(self, "modulate", Color(0.72, 0.82, 1.0, 0.95), 0.35)
	reveal_tween.tween_property(look, "position", look_origin, 0.35)
	await reveal_tween.finished
	var close_tween := create_tween().set_parallel(true)
	close_tween.tween_property(rift, "scale", Vector2(0.04, 0.1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	close_tween.tween_property(rift, "modulate:a", 0.0, 0.24)
	close_tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	await close_tween.finished
	rift.queue_free()


func _recover_overworld_after_failed_battle_start() -> void:
	# A failed request must leave this mandatory encounter pending; the base
	# trainer fallback completes optional trainers after a failed start.
	trainer_progress_loaded = true
	trainer_progress_state = STATE_FIRST_ENCOUNTER
	battle_in_progress = false
	triggered = false
	arrival_started = false
	visible = false
	modulate = Color.WHITE
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
		if trainer_progress_state in [STATE_DEFEATED, STATE_COMPLETED] or not battle_in_progress:
			arrival_started = false
		visible = arrival_started and trainer_progress_state not in [STATE_DEFEATED, STATE_COMPLETED]


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
	# Story refreshes cannot reveal him before the staircase or resurrect him
	# after completion. During the encounter, preserve the cinematic visibility.
	if not farewell_pending and (not arrival_started or trainer_progress_state in [STATE_DEFEATED, STATE_COMPLETED]):
		visible = false


func finish_story_battle_presentation(finished_trainer_id: String) -> void:
	if finished_trainer_id != FUTURE_SELF_TRAINER_ID or not farewell_pending:
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.45)
	await tween.finished
	farewell_pending = false
	arrival_started = false
	visible = false
