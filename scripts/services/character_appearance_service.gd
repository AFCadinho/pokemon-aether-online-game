extends RefCounted

class_name CharacterAppearanceService

const BODY_DIRECTORY := "res://assets/player/body"
const DEFAULT_BODY_ID := "boy_run"
const FRAME_COLUMNS := 4
const FRAME_ROWS := 4
const IDLE_ANIMATION_SPEED := 5.0
const WALK_ANIMATION_SPEED := 7.5

static var _body_frames_cache: Dictionary = {}


static func get_body_frames(body_id: String) -> SpriteFrames:
	var normalized_body_id: String = _normalize_body_id(body_id)
	if normalized_body_id == "":
		normalized_body_id = DEFAULT_BODY_ID

	if _body_frames_cache.has(normalized_body_id):
		var cached_value: Variant = _body_frames_cache[normalized_body_id]
		if cached_value is SpriteFrames:
			return cached_value as SpriteFrames
		return null

	var texture: Texture2D = _load_body_texture(normalized_body_id)
	if texture == null and normalized_body_id != DEFAULT_BODY_ID:
		texture = _load_body_texture(DEFAULT_BODY_ID)
	if texture == null:
		_body_frames_cache[normalized_body_id] = null
		return null

	var sprite_frames: SpriteFrames = _build_sprite_frames(texture)
	_body_frames_cache[normalized_body_id] = sprite_frames
	return sprite_frames


static func _load_body_texture(body_id: String) -> Texture2D:
	var path: String = "%s/%s.png" % [BODY_DIRECTORY, body_id]
	if ResourceLoader.exists(path):
		return ResourceLoader.load(path) as Texture2D
	return null


static func _build_sprite_frames(texture: Texture2D) -> SpriteFrames:
	var texture_size: Vector2 = texture.get_size()
	var frame_size: Vector2 = Vector2(
		texture_size.x / float(FRAME_COLUMNS),
		texture_size.y / float(FRAME_ROWS)
	)
	var sprite_frames := SpriteFrames.new()
	if sprite_frames.has_animation(&"default"):
		sprite_frames.remove_animation(&"default")

	_add_idle_animation(sprite_frames, texture, frame_size, "idle_down", 0)
	_add_idle_animation(sprite_frames, texture, frame_size, "idle_left", 1)
	_add_idle_animation(sprite_frames, texture, frame_size, "idle_right", 2)
	_add_idle_animation(sprite_frames, texture, frame_size, "idle_up", 3)

	_add_walk_animation(sprite_frames, texture, frame_size, "walk_down", 0)
	_add_walk_animation(sprite_frames, texture, frame_size, "walk_left", 1)
	_add_walk_animation(sprite_frames, texture, frame_size, "walk_right", 2)
	_add_walk_animation(sprite_frames, texture, frame_size, "walk_up", 3)

	return sprite_frames


static func _add_idle_animation(
	sprite_frames: SpriteFrames,
	texture: Texture2D,
	frame_size: Vector2,
	animation_name: String,
	row: int
) -> void:
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_speed(animation_name, IDLE_ANIMATION_SPEED)
	sprite_frames.set_animation_loop(animation_name, true)
	sprite_frames.add_frame(animation_name, _make_frame_texture(texture, frame_size, 0, row))


static func _add_walk_animation(
	sprite_frames: SpriteFrames,
	texture: Texture2D,
	frame_size: Vector2,
	animation_name: String,
	row: int
) -> void:
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_speed(animation_name, WALK_ANIMATION_SPEED)
	sprite_frames.set_animation_loop(animation_name, true)

	for column: int in range(FRAME_COLUMNS):
		sprite_frames.add_frame(animation_name, _make_frame_texture(texture, frame_size, column, row))


static func _make_frame_texture(texture: Texture2D, frame_size: Vector2, column: int, row: int) -> AtlasTexture:
	var frame_texture := AtlasTexture.new()
	frame_texture.atlas = texture
	frame_texture.region = Rect2(Vector2(column * frame_size.x, row * frame_size.y), frame_size)
	return frame_texture


static func _normalize_body_id(body_id: String) -> String:
	var normalized: String = body_id.strip_edges()
	normalized = normalized.replace("/", "")
	normalized = normalized.replace("\\", "")
	return normalized
