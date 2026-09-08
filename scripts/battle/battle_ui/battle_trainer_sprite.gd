extends Node2D

class_name BattleTrainerSprite

const BattleRenderLayers := preload("res://scripts/battle/battle_render_layers.gd")
const REMOTE_PLAYER_AVATAR_SCRIPT_PATH := "res://scripts/world/remote_player_avatar.gd"
const DEFAULT_DISPLAY_SCALE := 2.0
## Catalog sprites are 80px-square poses, while the legacy overworld frames
## are 64px-square. Preserve their shared foot baseline and leave clearance
## between the opponent pose and the right-side party rail.
const CATALOG_SPRITE_OFFSET := Vector2(-24.0, -16.0)

@export_range(0.5, 4.0, 0.05) var display_scale := DEFAULT_DISPLAY_SCALE

@onready var npc_sprite: AnimatedSprite2D = $NpcSprite
@onready var catalog_sprite: Sprite2D = $CatalogSprite
@onready var command_callout: Control = $TrainerCommandCallout

var player_avatar: Node2D
var facing_direction := Vector2.RIGHT


func _ready() -> void:
	# Trainer figures are staged behind their Pokemon. Their command callouts
	# are a separate overlay so they remain legible above foreground move art.
	z_as_relative = true
	z_index = BattleRenderLayers.TRAINER_ART
	if command_callout != null:
		command_callout.z_as_relative = false
		command_callout.z_index = BattleRenderLayers.TRAINER_CALLOUTS


func clear() -> void:
	if command_callout != null:
		command_callout.call("clear_command")
	visible = false
	if player_avatar != null and is_instance_valid(player_avatar):
		player_avatar.free()
	player_avatar = null
	if npc_sprite != null:
		npc_sprite.visible = false
		npc_sprite.sprite_frames = null
	if catalog_sprite != null:
		catalog_sprite.visible = false
		catalog_sprite.texture = null


func show_player(appearance_state: Dictionary, facing_direction: Vector2) -> void:
	clear()
	self.facing_direction = facing_direction
	var avatar_script := load(REMOTE_PLAYER_AVATAR_SCRIPT_PATH) as Script
	if avatar_script == null:
		return
	player_avatar = avatar_script.new() as Node2D
	if player_avatar == null:
		return

	add_child(player_avatar)
	# Avatar animation updates are skipped while hidden. Show this staging
	# marker before applying the pose, since processing is disabled below.
	visible = true
	player_avatar.call("apply_state", {
		"appearance": appearance_state.duplicate(true),
		"facingDirection": _direction_name(facing_direction),
		"position": {"x": 0.0, "y": 0.0},
	})
	# RemotePlayerAvatar accepts world coordinates. Battle staging owns the final
	# local position, so restore the avatar to this marker after applying state.
	player_avatar.position = Vector2.ZERO
	player_avatar.scale = Vector2.ONE * display_scale
	# RemotePlayerAvatar is absolute in the overworld. In battle it must inherit
	# this trainer's render band or its layered body parts fall back below moves.
	player_avatar.z_as_relative = true
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
	self.facing_direction = facing_direction
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


## Shows an unmodified static trainer pose from the local trainer catalog.
## This path intentionally accepts a Texture2D instead of manufacturing a
## four-direction SpriteFrames resource: Showdown poses are battle art, not
## overworld animation sheets. Future player battle art can use this same path.
func show_catalog_sprite(
	texture: Texture2D,
	facing_direction: Vector2,
	sprite_offset := Vector2(0.0, -16.0)
) -> void:
	clear()
	self.facing_direction = facing_direction
	if texture == null or catalog_sprite == null:
		return

	catalog_sprite.texture = texture
	catalog_sprite.position = sprite_offset + CATALOG_SPRITE_OFFSET
	catalog_sprite.scale = Vector2.ONE * display_scale
	catalog_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	catalog_sprite.visible = true
	visible = true


func show_command(message: String) -> void:
	if not visible or command_callout == null:
		return
	command_callout.call("show_command", message, facing_direction.x < 0.0)


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
