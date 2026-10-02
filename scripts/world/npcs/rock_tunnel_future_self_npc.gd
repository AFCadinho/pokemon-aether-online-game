@tool
extends TrainerNPC

class_name RockTunnelFutureSelfNPC

const FutureSelfAppearance := preload("res://scripts/world/story/future_self_appearance.gd")
const PlayerTrainerCatalog := preload("res://scripts/battle/battle_ui/battle_player_trainer_catalog.gd")

const FUTURE_SELF_TRAINER_ID := "kanto_rock_tunnel_future_self"


func _ready() -> void:
	trainer_id = FUTURE_SELF_TRAINER_ID
	display_name = "Future Self"
	portrait_id = ""
	var save := get_node_or_null("/root/PlayerSave")
	var appearance := FutureSelfAppearance.build_state(save.to_appearance_state() if save != null else {})
	npc_sprite_frames = FutureSelfAppearance.build_overworld_frames(appearance)
	mugshot = PlayerTrainerCatalog.build_dialogue_portrait(appearance)
	super._ready()


func _resolve_catalog_mugshot() -> void:
	# This portrait follows the player, rather than a trainer class catalog entry.
	pass


func _resolve_battle_sprite_id() -> String:
	# Battle staging must use the same composed Mysterious frames as the map.
	return ""


func start_mandatory_battle(player: Node2D) -> void:
	if not trainer_progress_loaded:
		await _load_trainer_progress()
	if trainer_progress_state in [STATE_DEFEATED, STATE_COMPLETED]:
		return
	if not _claim_battle_interaction():
		return
	triggered = true
	GameState.lock_overworld_input()
	if player.has_method("face_world_position"):
		player.face_world_position(get_feet_position())
	await show_intro_dialogue()


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
	if trainer_progress_state in [STATE_DEFEATED, STATE_COMPLETED]:
		visible = false


func apply_battle_victory_progress(progress_trainer_id: String, progress: Dictionary) -> void:
	super.apply_battle_victory_progress(progress_trainer_id, progress)
	if progress_trainer_id.strip_edges() != FUTURE_SELF_TRAINER_ID:
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.45)
	await tween.finished
	visible = false
