extends RefCounted

class_name FollowerSpriteService

const FRAME_COLUMNS := 4
const FRAME_ROWS := 4
const IDLE_ANIMATION_SPEED := 4.0
const WALK_ANIMATION_SPEED := 7.0
const FOLLOWER_SPRITE_MAP_PATH := "res://data/follower_sprite_map.json"

const NORMAL_FOLLOWER_DIRECTORIES: Array[String] = [
	"user://assets/followers",
	"res://assets/followers",
]

const SHINY_FOLLOWER_DIRECTORIES: Array[String] = [
	"user://assets/followers_shiny",
	"res://assets/followers_shiny",
]

const FORM_FOLLOWER_SPRITE_ALIASES := {
	"AEGISLASH_SHIELD": ["AEGISLASH"],
	"HOOPA_UNBOUND": ["HOOPA_1"],
	"LYCANROC_DUSK": ["LYCANROC_2"],
	"LYCANROC_MIDNIGHT": ["LYCANROC_1"],
	"MELOETTA_PIROUETTE": ["MELOETTA_1"],
	"SLOWBRO_GALAR": ["SLOWBRO_1"],
	"SLOWKING_GALAR": ["SLOWKING_1"],
	"TOXTRICITY_LOW_KEY": ["TOXTRICITY_1"],
	"URSHIFU_RAPID_STRIKE": ["URSHIFU_1"],
}

# Dreepy's artwork was authored with the directional rows in a different
# order from the shared follower spritesheet convention.
const SPECIES_DIRECTION_ROWS := {
	"DREEPY": {"down": 0, "left": 2, "right": 3, "up": 1},
}

static var _sprite_frames_cache: Dictionary = {}
static var _follower_sprite_map: Dictionary = {}
static var _follower_sprite_map_loaded := false

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

	var sprite_frames: SpriteFrames = _build_sprite_frames(texture, species)
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

static func _build_sprite_frames(texture: Texture2D, species: String) -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	if sprite_frames.has_animation(&"default"):
		sprite_frames.remove_animation(&"default")

	var frame_size := _get_frame_size(texture)

	var direction_rows := _get_direction_rows(species)
	_add_idle_animation(sprite_frames, texture, frame_size, "idle_down", direction_rows.down)
	_add_idle_animation(sprite_frames, texture, frame_size, "idle_left", direction_rows.left)
	_add_idle_animation(sprite_frames, texture, frame_size, "idle_right", direction_rows.right)
	_add_idle_animation(sprite_frames, texture, frame_size, "idle_up", direction_rows.up)

	_add_walk_animation(sprite_frames, texture, frame_size, "walk_down", direction_rows.down)
	_add_walk_animation(sprite_frames, texture, frame_size, "walk_left", direction_rows.left)
	_add_walk_animation(sprite_frames, texture, frame_size, "walk_right", direction_rows.right)
	_add_walk_animation(sprite_frames, texture, frame_size, "walk_up", direction_rows.up)

	return sprite_frames

static func _get_frame_size(texture: Texture2D) -> Vector2i:
	return Vector2i(
		maxi(texture.get_width() / FRAME_COLUMNS, 1),
		maxi(texture.get_height() / FRAME_ROWS, 1)
	)

static func _get_direction_rows(species: String) -> Dictionary:
	return SPECIES_DIRECTION_ROWS.get(_normalize_species_key(species), {"down": 0, "left": 1, "right": 2, "up": 3})

static func _add_idle_animation(sprite_frames: SpriteFrames, texture: Texture2D, frame_size: Vector2i, animation_name: String, row: int) -> void:
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_speed(animation_name, IDLE_ANIMATION_SPEED)
	sprite_frames.set_animation_loop(animation_name, true)
	sprite_frames.add_frame(animation_name, _make_frame_texture(texture, frame_size, 0, row))

static func _add_walk_animation(sprite_frames: SpriteFrames, texture: Texture2D, frame_size: Vector2i, animation_name: String, row: int) -> void:
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_speed(animation_name, WALK_ANIMATION_SPEED)
	sprite_frames.set_animation_loop(animation_name, true)

	for column: int in range(FRAME_COLUMNS):
		sprite_frames.add_frame(animation_name, _make_frame_texture(texture, frame_size, column, row))

static func _make_frame_texture(texture: Texture2D, frame_size: Vector2i, column: int, row: int) -> AtlasTexture:
	var frame_texture := AtlasTexture.new()
	frame_texture.atlas = texture
	frame_texture.region = Rect2(Vector2(column * frame_size.x, row * frame_size.y), frame_size)
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

	_append_manifest_candidates(candidates, species)
	_append_candidate(candidates, normalized_key)
	_append_candidate(candidates, compact_key)
	_append_alias_candidates(candidates, normalized_key)

	if normalized_key.contains("_"):
		var parts := normalized_key.split("_")
		if parts.size() > 0:
			_append_candidate(candidates, str(parts[0]))

	return candidates

static func _append_manifest_candidates(candidates: Array[String], species: String) -> void:
	var sprite_map := _get_follower_sprite_map()
	var manifest_key := _normalize_manifest_species_key(species)
	var mapped_value: Variant = sprite_map.get(manifest_key, "")
	if mapped_value is Array:
		for candidate: Variant in mapped_value:
			_append_candidate(candidates, str(candidate))
		return

	_append_candidate(candidates, str(mapped_value))

static func _get_follower_sprite_map() -> Dictionary:
	if _follower_sprite_map_loaded:
		return _follower_sprite_map

	_follower_sprite_map_loaded = true
	var file := FileAccess.open(FOLLOWER_SPRITE_MAP_PATH, FileAccess.READ)
	if file == null:
		push_warning("Follower sprite map not found: %s" % FOLLOWER_SPRITE_MAP_PATH)
		return _follower_sprite_map

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("Follower sprite map is not a JSON object: %s" % FOLLOWER_SPRITE_MAP_PATH)
		return _follower_sprite_map

	_follower_sprite_map = parsed as Dictionary
	return _follower_sprite_map

static func _normalize_manifest_species_key(species: String) -> String:
	var key := species.strip_edges().to_lower()
	key = key.replace("_", "-")
	key = key.replace(" ", "-")
	key = key.replace(".", "")
	key = key.replace("'", "")
	key = key.replace(":", "")
	while key.contains("--"):
		key = key.replace("--", "-")
	return key

static func _append_alias_candidates(candidates: Array[String], normalized_key: String) -> void:
	var aliases: Variant = FORM_FOLLOWER_SPRITE_ALIASES.get(normalized_key, [])
	if not (aliases is Array):
		return

	for alias: Variant in aliases:
		_append_candidate(candidates, str(alias))

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
