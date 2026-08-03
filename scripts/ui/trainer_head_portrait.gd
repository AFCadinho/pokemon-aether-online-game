extends Control

class_name TrainerHeadPortrait

const REMOTE_PLAYER_AVATAR_SCRIPT := preload("res://scripts/world/remote_player_avatar.gd")

var viewport: SubViewport
var avatar: RemotePlayerAvatar
var appearance_state: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resolve_size()
	_set_up_viewport()
	if appearance_state.is_empty():
		var player_save := get_node_or_null("/root/PlayerSave")
		if player_save != null and player_save.has_method("to_appearance_state"):
			set_appearance_state(player_save.call("to_appearance_state"))


func set_appearance_state(state: Dictionary) -> void:
	appearance_state = state.duplicate(true)
	if not is_inside_tree():
		return
	_set_up_viewport()
	if avatar != null and is_instance_valid(avatar):
		avatar.queue_free()
		avatar = null
	avatar = REMOTE_PLAYER_AVATAR_SCRIPT.new() as RemotePlayerAvatar
	if avatar == null:
		return
	viewport.add_child(avatar)
	avatar.apply_state({
		"appearance": appearance_state,
		"position": {"x": 0.0, "y": 0.0},
		"facingDirection": "down",
	})
	_configure_head_only(avatar)
	avatar.position = Vector2(viewport.size.x * 0.5, viewport.size.y * 0.62)
	avatar.scale = Vector2.ONE * _portrait_scale()
	var nameplate := avatar.get_node_or_null("Nameplate") as Control
	if nameplate != null:
		nameplate.visible = false
	_disable_processing(avatar)
	_set_idle_frame(avatar)


func _set_up_viewport() -> void:
	if viewport != null and is_instance_valid(viewport):
		return
	viewport = SubViewport.new()
	viewport.name = "PortraitViewport"
	viewport.transparent_bg = true
	viewport.size = Vector2i(64, 64)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var container := SubViewportContainer.new()
	container.name = "PortraitViewportContainer"
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	container.add_child(viewport)


func _resolve_size() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(42, 42)


func _portrait_scale() -> float:
	return clampf(minf(size.x, size.y) / 30.0, 0.9, 2.2)


func _disable_processing(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	node.set_process_unhandled_key_input(false)
	for child in node.get_children():
		_disable_processing(child)


func _configure_head_only(node: Node) -> void:
	if node is AnimatedSprite2D:
		var sprite := node as AnimatedSprite2D
		match sprite.name:
			"BodySprite":
				# AnimatedSprite2D has no region_enabled property. Replace its
				# current 64x64 atlas frame with a Sprite2D showing head rows.
				var head_texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
				if head_texture != null:
					var head_sprite := Sprite2D.new()
					head_sprite.name = "HeadBaseSprite"
					if head_texture is AtlasTexture:
						var source_frame := head_texture as AtlasTexture
						var head_atlas := AtlasTexture.new()
						head_atlas.atlas = source_frame.atlas
						var frame_region := source_frame.region
						head_atlas.region = Rect2(
							frame_region.position,
							Vector2(frame_region.size.x, minf(frame_region.size.y, 34.0))
						)
						head_sprite.texture = head_atlas
					else:
						var source_image := head_texture.get_image()
						if source_image != null and source_image.get_width() >= 64 and source_image.get_height() >= 34:
							var head_image := source_image.get_region(Rect2i(0, 0, 64, 34))
							head_sprite.texture = ImageTexture.create_from_image(head_image)
						else:
							head_sprite.texture = head_texture
					head_sprite.position = sprite.position + Vector2(0.0, -15.0)
					head_sprite.z_index = sprite.z_index
					sprite.get_parent().add_child(head_sprite)
					sprite.visible = false
			"TopSprite", "BottomSprite", "ShoesSprite":
				sprite.visible = false
	for child in node.get_children():
		_configure_head_only(child)


func _set_idle_frame(node: Node) -> void:
	for child in node.get_children():
		if child is AnimatedSprite2D:
			var sprite := child as AnimatedSprite2D
			if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("idle_down"):
				sprite.play("idle_down")
				sprite.frame = 0
				sprite.pause()
		_set_idle_frame(child)
