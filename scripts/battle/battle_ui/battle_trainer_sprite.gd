extends Node2D

class_name BattleTrainerSprite

const REMOTE_PLAYER_AVATAR_SCRIPT_PATH := "res://scripts/world/remote_player_avatar.gd"
const DEFAULT_DISPLAY_SCALE := 2.0

@export_range(0.5, 4.0, 0.05) var display_scale := DEFAULT_DISPLAY_SCALE

@onready var npc_sprite: AnimatedSprite2D = $NpcSprite

var player_avatar: Node2D


func clear() -> void:
	visible = false
	if player_avatar != null and is_instance_valid(player_avatar):
		player_avatar.free()
	player_avatar = null
	if npc_sprite != null:
		npc_sprite.visible = false
		npc_sprite.sprite_frames = null


func show_player(appearance_state: Dictionary, facing_direction: Vector2) -> void:
	clear()
	var avatar_script := load(REMOTE_PLAYER_AVATAR_SCRIPT_PATH) as Script
	if avatar_script == null:
		return
	player_avatar = avatar_script.new() as Node2D
	if player_avatar == null:
		return

	add_child(player_avatar)
	player_avatar.call("apply_state", {
		"appearance": appearance_state.duplicate(true),
		"facingDirection": _direction_name(facing_direction),
		"position": {"x": 0.0, "y": 0.0},
	})
	# RemotePlayerAvatar accepts world coordinates. Battle staging owns the final
	# local position, so restore the avatar to this marker after applying state.
	player_avatar.position = Vector2.ZERO
	player_avatar.scale = Vector2.ONE * display_scale
	player_avatar.z_index = 0
	player_avatar.call("set_interaction_enabled", false)
	player_avatar.call("set_creator_nameplate_visible", false)
	player_avatar.process_mode = Node.PROCESS_MODE_DISABLED
	visible = true


func show_npc(
	sprite_frames: SpriteFrames,
	facing_direction: Vector2,
	sprite_offset := Vector2(0.0, -16.0)
) -> void:
	clear()
	if sprite_frames == null or npc_sprite == null:
		return

	npc_sprite.sprite_frames = sprite_frames
	npc_sprite.animation = _resolve_npc_animation(sprite_frames, facing_direction)
	npc_sprite.frame = 0
	npc_sprite.frame_progress = 0.0
	npc_sprite.position = sprite_offset
	npc_sprite.scale = Vector2.ONE * display_scale
	npc_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	npc_sprite.stop()
	npc_sprite.visible = true
	visible = true


func _resolve_npc_animation(sprite_frames: SpriteFrames, facing_direction: Vector2) -> StringName:
	var direction := _direction_name(facing_direction)
	for animation_name: StringName in [
		StringName("idle_%s" % direction),
		StringName("walk_%s" % direction),
		StringName(direction),
		&"default",
	]:
		if sprite_frames.has_animation(animation_name):
			return animation_name

	var animations := sprite_frames.get_animation_names()
	return animations[0] if not animations.is_empty() else &"default"


func _direction_name(direction: Vector2) -> String:
	if absf(direction.x) >= absf(direction.y):
		return "right" if direction.x >= 0.0 else "left"
	return "down" if direction.y >= 0.0 else "up"
