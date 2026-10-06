extends "res://scripts/world/remote_player_avatar.gd"

# Reuse the game renderer for seated poses, directional offsets and masking.
# This viewport has no presence, interaction, movement or nameplate behavior.
const PREVIEW_PADDING := Vector2(16, 12)
var animation_enabled := true
var preview_bounds := Rect2()
var _fit_mount_id := ""
var _fit_appearance: Dictionary = {}
var _texture_bounds: Dictionary = {}


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


func configure(
	mount_id: String, appearance: Dictionary, direction: String, animate: bool,
	viewport_size := Vector2i(258, 174)
) -> void:
	if mount_id != _fit_mount_id or appearance != _fit_appearance:
		# Measure the rendered layers, not transparent sheet cells or world size.
		# One envelope for every direction/frame avoids zooming during animation.
		preview_bounds = _measure_preview_bounds(mount_id, appearance)
		_fit_mount_id = mount_id
		_fit_appearance = appearance.duplicate(true)
		_texture_bounds.clear()
	_configure_visual(mount_id, appearance, direction, animate)
	if preview_bounds.has_area():
		var available := Vector2(viewport_size) - PREVIEW_PADDING * 2.0
		var zoom := minf(available.x / preview_bounds.size.x, available.y / preview_bounds.size.y)
		scale = Vector2.ONE * zoom
		position = Vector2(viewport_size) * 0.5 - preview_bounds.get_center() * zoom


func _configure_visual(mount_id: String, appearance: Dictionary, direction: String, animate: bool) -> void:
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


func _measure_preview_bounds(mount_id: String, appearance: Dictionary) -> Rect2:
	var bounds := Rect2()
	for direction: String in ["down", "left", "right", "up"]:
		for animate: bool in [false, true]:
			_configure_visual(mount_id, appearance, direction, animate)
			if mount_sprite.sprite_frames == null:
				continue
			mount_sprite.pause()
			for frame in range(mount_sprite.sprite_frames.get_frame_count(mount_sprite.animation)):
				mount_sprite.frame = frame
				_on_mount_frame_changed()
				var frame_bounds := _get_artwork_bounds(look_node)
				# Reserve both hover extremes, including its whole-pixel rounding.
				# The ground shadow is fitted separately below.
				if frame_bounds.has_area() and mount_hover_visual != null and mount_hover_visual.visible:
					var top := roundf(-mount_hover_visual.height - mount_hover_visual.amplitude)
					var bottom := roundf(-mount_hover_visual.height + mount_hover_visual.amplitude)
					frame_bounds.position.y += top - _get_mount_hover_offset().y
					frame_bounds.size.y += bottom - top
				bounds = _merge_bounds(bounds, frame_bounds)
	if mount_hover_visual != null and mount_hover_visual.visible:
		var points := mount_hover_visual.shadow_points
		if not points.is_empty():
			var shadow := Rect2(points[0], Vector2.ZERO)
			for point: Vector2 in points:
				shadow = shadow.expand(point)
			var transform := global_transform.affine_inverse() * mount_hover_visual.global_transform
			bounds = _merge_bounds(bounds, transform * shadow)
	mount_sprite.frame = 0
	return bounds


func _get_artwork_bounds(node: Node) -> Rect2:
	var bounds := Rect2()
	if node is CanvasItem and not node.is_visible_in_tree():
		return bounds
	if node is AnimatedSprite2D:
		var sprite := node as AnimatedSprite2D
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(sprite.animation):
			var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
			if texture != null:
				if not _texture_bounds.has(texture):
					var image := MountService._get_texture_image(texture)
					_texture_bounds[texture] = image.get_used_rect() if image != null else Rect2i()
				var used := Rect2(_texture_bounds[texture])
				if used.has_area():
					used.position += sprite.offset
					if sprite.centered:
						used.position -= texture.get_size() * 0.5
					var transform := global_transform.affine_inverse() * sprite.global_transform
					bounds = transform * used
	for child: Node in node.get_children():
		bounds = _merge_bounds(bounds, _get_artwork_bounds(child))
	return bounds


func _merge_bounds(left: Rect2, right: Rect2) -> Rect2:
	if not left.has_area():
		return right
	return left.merge(right) if right.has_area() else left


func _process(delta: float) -> void:
	if animation_enabled and is_visible_in_tree():
		_update_mount_hover(delta)
