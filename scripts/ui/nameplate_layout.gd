extends RefCounted

const Mounts := preload("res://scripts/services/mount_service.gd")
const MOUNT_CLEARANCE := 6.0
const BASE_POSITION_META := &"nameplate_base_position"
const FRAME_TOP_META := &"nameplate_frame_top"
static var _mount_envelopes: Dictionary = {}

const NAMEPLATE_CENTER_X := 82.0
const NAMEPLATE_STACK_BOTTOM := 63.0
const NAMEPLATE_CARD_VERTICAL_PADDING := 2.0
const NAMEPLATE_CARD_HORIZONTAL_PADDING := 5.0
const GUILD_EMBLEM_DISPLAY_SIZE := 24.0
const GUILD_EMBLEM_BADGE_SIZE := 28.0
const GUILD_EMBLEM_CARD_GAP := 2.0


static func calculate_name_card(name_size: Vector2, has_guild_emblem: bool) -> Dictionary:
	var card_width := name_size.x + (NAMEPLATE_CARD_HORIZONTAL_PADDING * 2.0)
	var content_height := name_size.y
	var card_height := content_height + (NAMEPLATE_CARD_VERTICAL_PADDING * 2.0)
	var card_left := NAMEPLATE_CENTER_X - (card_width * 0.5)
	var card_top := NAMEPLATE_STACK_BOTTOM - card_height
	var content_left := card_left + NAMEPLATE_CARD_HORIZONTAL_PADDING
	var label_rect := Rect2(
		Vector2(
			content_left,
			card_top + NAMEPLATE_CARD_VERTICAL_PADDING
		),
		name_size
	)
	var background_rect := Rect2(
		Vector2(card_left, card_top),
		Vector2(card_width, card_height)
	)
	var emblem_rect := Rect2()
	var emblem_background_rect := Rect2()
	if has_guild_emblem:
		emblem_background_rect = Rect2(
			Vector2(
				card_left - GUILD_EMBLEM_CARD_GAP - GUILD_EMBLEM_BADGE_SIZE,
				card_top + ((card_height - GUILD_EMBLEM_BADGE_SIZE) * 0.5)
			),
			Vector2(GUILD_EMBLEM_BADGE_SIZE, GUILD_EMBLEM_BADGE_SIZE)
		)
		emblem_rect = Rect2(
			emblem_background_rect.position
			+ Vector2.ONE * ((GUILD_EMBLEM_BADGE_SIZE - GUILD_EMBLEM_DISPLAY_SIZE) * 0.5),
			Vector2(GUILD_EMBLEM_DISPLAY_SIZE, GUILD_EMBLEM_DISPLAY_SIZE)
		)
	return {
		"backgroundRect": background_rect,
		"labelRect": label_rect,
		"emblemRect": emblem_rect,
		"emblemBackgroundRect": emblem_background_rect,
	}


# Use the whole animation envelope instead of the current wing/rider frame.
# Cache bounds on the shared immutable SpriteFrames, so idle updates never
# download textures or inspect pixels again (and evicted frames release them).
static func sync_mount_position(
	plate: Control, look: Node2D, mount: AnimatedSprite2D,
	rider: Node2D, parts: Array[AnimatedSprite2D], mount_id: String,
	hover_offset: Vector2
) -> float:
	if plate == null:
		return 0.0
	if not plate.has_meta(BASE_POSITION_META):
		plate.set_meta(BASE_POSITION_META, plate.position)
	var base: Vector2 = plate.get_meta(BASE_POSITION_META)
	var next := base
	if mount_id != "" and look != null and mount != null and mount.visible:
		var envelope := _mount_envelope(mount_id)
		var top := _sprite_top(mount)
		# Reserve the complete water-contact envelope, including the rear wake.
		# Its cached frame bounds keep the nameplate steady during swimming.
		var water := look.get_node_or_null("MountForegroundSprite/MountWaterContact") as AnimatedSprite2D
		if water != null and water.visible and water.sprite_frames != null:
			var parent_offset := look.to_local(water.get_parent().global_position).y
			top = minf(top, parent_offset + _sprite_top(water))
		if rider != null:
			var direction := str(mount.animation).get_slice("_", 1)
			var current_offset := Mounts.get_rider_frame_offset(mount_id, direction, mount.frame, str(mount.animation).begins_with("idle_"))
			var rider_y := rider.position.y - current_offset.y + envelope.x
			for part: AnimatedSprite2D in parts:
				if part.visible:
					top = minf(top, rider_y + _sprite_top(part))
		if is_finite(top):
			var stack_bottom := NAMEPLATE_STACK_BOTTOM
			for child: Node in plate.get_children():
				if child is Control and child.visible:
					stack_bottom = maxf(stack_bottom, child.position.y + child.size.y)
			# Reserve the highest hover position; do not bob the text every frame.
			var look_y := look.position.y - hover_offset.y - envelope.y
			next.y = minf(base.y, floorf(look_y + top - MOUNT_CLEARANCE - stack_bottom))
	plate.position = next
	return next.y - base.y


static func _mount_envelope(mount_id: String) -> Vector2:
	if _mount_envelopes.has(mount_id):
		return _mount_envelopes[mount_id]
	var rider_top := INF
	for direction: String in ["down", "left", "right", "up"]:
		for frame in range(Mounts.FRAME_COLUMNS):
			for idle: bool in [false, true]:
				rider_top = minf(rider_top, Mounts.get_rider_frame_offset(mount_id, direction, frame, idle).y)
	var definition := Mounts.get_mount_definition(mount_id)
	var height := maxf(float(definition.get("hoverHeight", 0.0)), 0.0)
	var amplitude := clampf(float(definition.get("hoverAmplitude", 2.0)), 0.0, height)
	var envelope := Vector2(rider_top, height + amplitude)
	_mount_envelopes[mount_id] = envelope
	return envelope


static func _sprite_top(sprite: AnimatedSprite2D) -> float:
	var frames := sprite.sprite_frames
	if frames == null:
		return INF
	if not frames.has_meta(FRAME_TOP_META):
		var top := Vector2(INF, INF)
		for animation: StringName in frames.get_animation_names():
			for frame in range(frames.get_frame_count(animation)):
				var texture := frames.get_frame_texture(animation, frame)
				if texture == null:
					continue
				var pixels := texture.get_image()
				if pixels == null:
					continue
				if pixels.is_compressed() and pixels.decompress() != OK:
					continue
				var used := pixels.get_used_rect()
				if not used.has_area():
					continue
				top.x = minf(top.x, used.position.y)
				top.y = minf(top.y, used.position.y - texture.get_height() * 0.5)
		frames.set_meta(FRAME_TOP_META, top)
	var top: Vector2 = frames.get_meta(FRAME_TOP_META)
	return sprite.position.y + (sprite.offset.y + (top.y if sprite.centered else top.x)) * sprite.scale.y
