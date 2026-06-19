extends RefCounted

class_name FollowerSpriteService

const FRAME_COLUMNS := 4
const FRAME_SIZE := Vector2i(64, 64)
const IDLE_ANIMATION_SPEED := 4.0
const WALK_ANIMATION_SPEED := 7.0

const NORMAL_FOLLOWER_DIRECTORIES: Array[String] = [
	"user://assets/followers",
	"res://assets/followers",
]

const SHINY_FOLLOWER_DIRECTORIES: Array[String] = [
	"user://assets/followers_shiny",
	"res://assets/followers_shiny",
]

static var _sprite_frames_cache: Dictionary = {}

static func get_sprite_frames(species: String, shiny: bool) -> SpriteFrames:
	var cache_key: String = "%s:%s" % [_normalize_species_key(species), str(shiny)]
	if _sprite_frames_cache.has(cache_key):
		var cached_value: Variant = _sprite_frames_cache[cache_key]
		if cached_value is SpriteFrames:
			return cached_value as SpriteFrames
		return null

	var texture: Texture2D = _load_texture_for_species(species, shiny)
	if texture == null:
		_sprite_frames_cache[cache_key] = null
		return null

	var sprite_frames: SpriteFrames = _build_sprite_frames(texture)
	_sprite_frames_cache[cache_key] = sprite_frames
	return sprite_frames

static func _load_texture_for_species(species: String, shiny: bool) -> Texture2D:
	var candidates: Array[String] = _get_species_file_candidates(species)
	var directories: Array[String] = []
	if shiny:
		directories.append_array(SHINY_FOLLOWER_DIRECTORIES)
	directories.append_array(NORMAL_FOLLOWER_DIRECTORIES)

	for directory: String in directories:
		for candidate: String in candidates:
			var file_path: String = "%s/%s.png" % [directory, candidate]
			if not _file_exists(file_path):
				continue

			return _load_texture(file_path)

	return null

static func _build_sprite_frames(texture: Texture2D) -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	if sprite_frames.has_animation(&"default"):
		sprite_frames.remove_animation(&"default")

	_add_idle_animation(sprite_frames, texture, "idle_down", 0)
	_add_idle_animation(sprite_frames, texture, "idle_left", 1)
	_add_idle_animation(sprite_frames, texture, "idle_right", 2)
	_add_idle_animation(sprite_frames, texture, "idle_up", 3)

	_add_walk_animation(sprite_frames, texture, "walk_down", 0)
	_add_walk_animation(sprite_frames, texture, "walk_left", 1)
	_add_walk_animation(sprite_frames, texture, "walk_right", 2)
	_add_walk_animation(sprite_frames, texture, "walk_up", 3)

	return sprite_frames

static func _add_idle_animation(sprite_frames: SpriteFrames, texture: Texture2D, animation_name: String, row: int) -> void:
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_speed(animation_name, IDLE_ANIMATION_SPEED)
	sprite_frames.set_animation_loop(animation_name, true)
	sprite_frames.add_frame(animation_name, _make_frame_texture(texture, 0, row))

static func _add_walk_animation(sprite_frames: SpriteFrames, texture: Texture2D, animation_name: String, row: int) -> void:
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_speed(animation_name, WALK_ANIMATION_SPEED)
	sprite_frames.set_animation_loop(animation_name, true)

	for column: int in range(FRAME_COLUMNS):
		sprite_frames.add_frame(animation_name, _make_frame_texture(texture, column, row))

static func _make_frame_texture(texture: Texture2D, column: int, row: int) -> AtlasTexture:
	var frame_texture := AtlasTexture.new()
	frame_texture.atlas = texture
	frame_texture.region = Rect2(Vector2(column * FRAME_SIZE.x, row * FRAME_SIZE.y), FRAME_SIZE)
	return frame_texture

static func _load_texture(file_path: String) -> Texture2D:
	if file_path.begins_with("res://"):
		var imported_texture := ResourceLoader.load(file_path) as Texture2D
		if imported_texture != null:
			return imported_texture

	var image := Image.new()
	var error: int = image.load(_to_global_path(file_path))
	if error != OK:
		return null

	return ImageTexture.create_from_image(image)

static func _file_exists(file_path: String) -> bool:
	if file_path.begins_with("res://") and ResourceLoader.exists(file_path):
		return true

	return FileAccess.file_exists(_to_global_path(file_path))

static func _to_global_path(file_path: String) -> String:
	if file_path.begins_with("user://"):
		return ProjectSettings.globalize_path(file_path)

	return file_path

static func _get_species_file_candidates(species: String) -> Array[String]:
	var normalized_key: String = _normalize_species_key(species)
	var compact_key: String = normalized_key.replace("_", "")
	var candidates: Array[String] = []

	_append_candidate(candidates, normalized_key)
	_append_candidate(candidates, compact_key)

	if normalized_key.contains("_"):
		var parts := normalized_key.split("_")
		if parts.size() > 0:
			_append_candidate(candidates, str(parts[0]))

	return candidates

static func _append_candidate(candidates: Array[String], candidate: String) -> void:
	if candidate == "" or candidates.has(candidate):
		return

	candidates.append(candidate)

static func _normalize_species_key(species: String) -> String:
	var key: String = species.strip_edges().to_upper()
	key = key.replace(".", "")
	key = key.replace("'", "")
	key = key.replace(":", "")
	key = key.replace("♀", "F")
	key = key.replace("♂", "M")
	key = key.replace(" ", "_")
	key = key.replace("-", "_")

	while key.contains("__"):
		key = key.replace("__", "_")

	return key
