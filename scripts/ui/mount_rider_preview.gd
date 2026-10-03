extends "res://scripts/world/remote_player_avatar.gd"

# Reuse the game renderer for seated poses, directional offsets and masking.
# This viewport has no presence, interaction, movement or nameplate behavior.
var animation_enabled := true


func _ready() -> void:
	var player_template := PLAYER_SCENE.instantiate()
	look_node = player_template.get_node("Look").duplicate() as Node2D
	player_template.free()
	add_child(look_node)
	base_look_position = Vector2.ZERO
	look_node.position = base_look_position
	mount_sprite = look_node.get_node(MOUNT_SPRITE_NAME) as AnimatedSprite2D
	mount_foreground_sprite = look_node.get_node(MOUNT_FOREGROUND_SPRITE_NAME) as AnimatedSprite2D
	rider_node = look_node.get_node("Rider") as Node2D
	base_rider_position = rider_node.position
	_collect_appearance_sprites(look_node)
	_connect_mount_frame_sync()


func configure(mount_id: String, appearance: Dictionary, direction: String, animate: bool) -> void:
	current_gender = CharacterAppearanceService.normalize_gender(str(appearance.get("gender", "male")))
	if current_mount_id != mount_id:
		current_appearance_signature = ""
		current_body_movement_style = ""
	current_mount_id = mount_id
	current_activity_style = CharacterAppearanceService.BODY_MOVEMENT_RIDE
	last_direction = _direction_from_name(direction)
	animation_enabled = animate
	_apply_appearance_state(appearance)
	_sync_mount_visual()
	_update_animation(animate)
	_sync_activity_layer_offsets()
	_sync_mount_animation(animate, last_direction)


func _process(delta: float) -> void:
	if animation_enabled and is_visible_in_tree():
		_update_mount_hover(delta)
