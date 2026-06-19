extends RefCounted

class_name CharacterAppearanceService

const BODY_DIRECTORY := "res://assets/player/body"
const BODY_MANIFEST_PATH := "res://assets/player/body/body_manifest.json"
const DEFAULT_BODY_ID := "gen4_pa_base_boy"
const FRAME_COLUMNS := 4
const FRAME_ROWS := 4
const IDLE_ANIMATION_SPEED := 5.0
const WALK_ANIMATION_SPEED := 7.5

static var _body_frames_cache: Dictionary = {}


static func get_available_body_ids() -> Array[String]:
	var manifest_body_ids: Array[String] = _get_manifest_body_ids()
	if not manifest_body_ids.is_empty():
		return _sort_body_ids(manifest_body_ids)

	var body_ids: Array[String] = []
	_collect_body_ids_from_directory(BODY_DIRECTORY, "", body_ids)
	return _sort_body_ids(body_ids)


static func _collect_body_ids_from_directory(directory_path: String, prefix: String, body_ids: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return

	for file_name: String in directory.get_files():
		if not file_name.ends_with(".png"):
			continue

		var body_id: String = file_name.trim_suffix(".png")
		if body_id == "":
			continue
		body_ids.append(prefix + body_id)

	for subdirectory: String in directory.get_directories():
		if subdirectory.begins_with("."):
			continue
		_collect_body_ids_from_directory("%s/%s" % [directory_path, subdirectory], "%s%s/" % [prefix, subdirectory], body_ids)


static func _get_manifest_body_ids() -> Array[String]:
	if not FileAccess.file_exists(BODY_MANIFEST_PATH):
		return []

	var file := FileAccess.open(BODY_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return []

	var parsed_body: Variant = JSON.parse_string(file.get_as_text())
	if not parsed_body is Array:
		return []

	var body_ids: Array[String] = []
	var parsed_ids: Array = parsed_body as Array
	for body_id_value: Variant in parsed_ids:
		var body_id: String = _normalize_body_id(str(body_id_value))
		if body_id == "":
			continue
		body_ids.append(body_id)
	return body_ids


static func _sort_body_ids(body_ids: Array[String]) -> Array[String]:
	body_ids.sort()
	if body_ids.has(DEFAULT_BODY_ID):
		body_ids.erase(DEFAULT_BODY_ID)
		body_ids.push_front(DEFAULT_BODY_ID)
	return body_ids


static func get_body_frames(body_id: String) -> SpriteFrames:
	var normalized_body_id: String = _normalize_body_id(body_id)
	if normalized_body_id == "":
		normalized_body_id = _get_fallback_body_id()

	if _body_frames_cache.has(normalized_body_id):
		var cached_value: Variant = _body_frames_cache[normalized_body_id]
		if cached_value is SpriteFrames:
			return cached_value as SpriteFrames
		return null

	var texture: Texture2D = _load_body_texture(normalized_body_id)
	var fallback_body_id: String = _get_fallback_body_id()
	if texture == null and normalized_body_id != fallback_body_id:
		texture = _load_body_texture(fallback_body_id)
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


static func _get_fallback_body_id() -> String:
	if ResourceLoader.exists("%s/%s.png" % [BODY_DIRECTORY, DEFAULT_BODY_ID]):
		return DEFAULT_BODY_ID

	var body_ids: Array[String] = get_available_body_ids()
	if body_ids.is_empty():
		return DEFAULT_BODY_ID
	return body_ids[0]


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
	var normalized: String = body_id.strip_edges().replace("\\", "/")
	var normalized_parts: Array[String] = []
	for part: String in normalized.split("/", false):
		var normalized_part: String = part.strip_edges()
		if normalized_part == "" or normalized_part == "." or normalized_part == "..":
			return ""
		normalized_parts.append(normalized_part)
	return "/".join(normalized_parts)
