extends RefCounted

class_name CharacterAppearanceService

const PLAYER_DIRECTORY := "res://assets/player"
const BODY_CATEGORY := "body"
const BODY_DIRECTORY := "res://assets/player/body"
const BODY_MANIFEST_PATH := "res://assets/player/body/body_manifest.json"
const HAIR_CATEGORY := "hair"
const HEADGEAR_CATEGORY := "headgear"
const FACEGEAR_CATEGORY := "facegear"
const TOP_CATEGORY := "top"
const BOTTOM_CATEGORY := "bottom"
const SHOES_CATEGORY := "shoes"
const EYES_CATEGORY := "eyes"
const EYEBROWS_CATEGORY := "eyebrows"
const UNEQUIPPED_PART_ID := "__none__"
const PRESENCE_BODY_APPEARANCE_SEPARATOR := "#appearance="
const DEFAULT_BODY_ID := "Gen4_Base_v1"
const DEFAULT_MALE_BODY_ID := "Gen4_Base_v1"
const DEFAULT_FEMALE_BODY_ID := "Gen4_Base_F_v1"
const DEFAULT_MALE_HAIR_ID := "Hair"
const DEFAULT_MALE_HEADGEAR_ID := "Cap"
const DEFAULT_MALE_FACEGEAR_ID := ""
const DEFAULT_MALE_TOP_ID := "Shirt"
const DEFAULT_MALE_BOTTOM_ID := "Trousers"
const DEFAULT_MALE_SHOES_ID := "Shoes"
const DEFAULT_MALE_EYES_ID := "Eyes"
const DEFAULT_MALE_EYEBROWS_ID := "Eyebrows"
const DEFAULT_FEMALE_HAIR_ID := "Hair"
const DEFAULT_FEMALE_HEADGEAR_ID := "Cap"
const DEFAULT_FEMALE_FACEGEAR_ID := ""
const DEFAULT_FEMALE_TOP_ID := "Shirt"
const DEFAULT_FEMALE_BOTTOM_ID := "Trousers"
const DEFAULT_FEMALE_SHOES_ID := "Shoes"
const DEFAULT_FEMALE_EYES_ID := "Eyes"
const DEFAULT_FEMALE_EYEBROWS_ID := "Eyebrows"
const DEFAULT_HAIR_COLOR := "#ffffff"
const DEFAULT_SKIN_TONE := "#ffffff"
const DEFAULT_EYE_COLOR := "#0fff00"
const FRAME_COLUMNS := 4
const FRAME_ROWS := 4
const IDLE_ANIMATION_SPEED := 5.0
const WALK_ANIMATION_SPEED := 7.5
const NON_SELECTABLE_BODY_DIRECTORIES: Array[String] = ["run", "running", "fish", "ride", "surf", "mount"]
const BODY_MOVEMENT_DEFAULT := "walk"
const BODY_MOVEMENT_RUN := "run"
const BODY_MOVEMENT_FISH := "fish"
const BODY_MOVEMENT_RIDE := "ride"
const BODY_MOVEMENT_SURF := "surf"
const BODY_MOVEMENT_MOUNT := "mount"
const LAYERED_PART_CATEGORIES: Array[String] = [
	HAIR_CATEGORY,
	HEADGEAR_CATEGORY,
	FACEGEAR_CATEGORY,
	TOP_CATEGORY,
	BOTTOM_CATEGORY,
	SHOES_CATEGORY,
	EYES_CATEGORY,
	EYEBROWS_CATEGORY,
]
const DEFAULT_LAYERED_MALE_BODY_IDS: Array[String] = [
	"Gen4_Base_v1",
	"Gen4_Base_M_Dark",
	"Gen4_Base_M_Tan",
]
const DEFAULT_LAYERED_FEMALE_BODY_IDS: Array[String] = [
	"Gen4_Base_F_v1",
	"Gen4_Base_F_Dark",
	"Gen4_Base_F_Tan",
]

static var _body_frames_cache: Dictionary = {}
static var _part_frames_cache: Dictionary = {}
static var _tinted_part_frames_cache: Dictionary = {}


static func get_default_appearance(gender: String = "") -> Dictionary:
	var normalized_gender: String = normalize_gender(gender)
	var body_id: String = DEFAULT_FEMALE_BODY_ID if normalized_gender == "female" else DEFAULT_MALE_BODY_ID
	var appearance := {
		"body": body_id,
		"hair": "",
		"headgear": "",
		"facegear": "",
		"top": "",
		"bottom": "",
		"shoes": "",
		"hair_color": DEFAULT_HAIR_COLOR,
		"skin_tone": DEFAULT_SKIN_TONE,
		"eye_color": DEFAULT_EYE_COLOR,
	}
	if body_supports_layered_parts(body_id, normalized_gender):
		for category: String in LAYERED_PART_CATEGORIES:
			if category == EYES_CATEGORY or category == EYEBROWS_CATEGORY:
				continue
			appearance[category] = get_default_part_id(category, normalized_gender)
	return appearance


static func body_supports_layered_parts(body_id: String, gender: String = "") -> bool:
	var normalized_gender: String = normalize_gender(gender)
	var normalized_body_id: String = _normalize_body_id(body_id)
	if normalized_gender == "female":
		return DEFAULT_LAYERED_FEMALE_BODY_IDS.has(normalized_body_id)
	return DEFAULT_LAYERED_MALE_BODY_IDS.has(normalized_body_id)


static func get_default_part_id(category: String, gender: String = "") -> String:
	var normalized_gender: String = normalize_gender(gender)
	match normalize_part_category(category):
		HAIR_CATEGORY:
			return DEFAULT_FEMALE_HAIR_ID if normalized_gender == "female" else DEFAULT_MALE_HAIR_ID
		HEADGEAR_CATEGORY:
			return DEFAULT_FEMALE_HEADGEAR_ID if normalized_gender == "female" else DEFAULT_MALE_HEADGEAR_ID
		FACEGEAR_CATEGORY:
			return DEFAULT_FEMALE_FACEGEAR_ID if normalized_gender == "female" else DEFAULT_MALE_FACEGEAR_ID
		TOP_CATEGORY:
			return DEFAULT_FEMALE_TOP_ID if normalized_gender == "female" else DEFAULT_MALE_TOP_ID
		BOTTOM_CATEGORY:
			return DEFAULT_FEMALE_BOTTOM_ID if normalized_gender == "female" else DEFAULT_MALE_BOTTOM_ID
		SHOES_CATEGORY:
			return DEFAULT_FEMALE_SHOES_ID if normalized_gender == "female" else DEFAULT_MALE_SHOES_ID
		EYES_CATEGORY:
			return DEFAULT_FEMALE_EYES_ID if normalized_gender == "female" else DEFAULT_MALE_EYES_ID
		EYEBROWS_CATEGORY:
			return DEFAULT_FEMALE_EYEBROWS_ID if normalized_gender == "female" else DEFAULT_MALE_EYEBROWS_ID
		_:
			return ""


static func normalize_part_category(category: String) -> String:
	var normalized: String = category.strip_edges().to_lower().replace("_", "")
	match normalized:
		"hair":
			return HAIR_CATEGORY
		"headgear", "headwear", "hat", "cap":
			return HEADGEAR_CATEGORY
		"facegear", "facewear", "faceaccessory", "faceaccessories", "glasses", "mask":
			return FACEGEAR_CATEGORY
		"top", "shirt", "upper":
			return TOP_CATEGORY
		"bottom", "legs", "trousers", "pants":
			return BOTTOM_CATEGORY
		"shoes", "feet", "footwear":
			return SHOES_CATEGORY
		"eyes":
			return EYES_CATEGORY
		"eyebrows", "brows":
			return EYEBROWS_CATEGORY
		_:
			return normalized


static func serialize_part_id(part_id: String) -> String:
	var normalized_part_id: String = part_id.strip_edges()
	return UNEQUIPPED_PART_ID if _is_empty_presence_part_id(normalized_part_id) else normalized_part_id


static func deserialize_part_id(part_id: String) -> String:
	var normalized_part_id: String = part_id.strip_edges()
	if _is_empty_presence_part_id(normalized_part_id):
		return ""
	return normalized_part_id


static func _is_empty_presence_part_id(part_id: String) -> bool:
	var normalized_part_id: String = part_id.strip_edges().to_lower()
	return ["", UNEQUIPPED_PART_ID, "<null>", "null", "none"].has(normalized_part_id)


static func encode_presence_body_with_appearance(body_id: String, appearance: Dictionary) -> String:
	var base_body_id: String = get_presence_body_base_id(body_id)
	if base_body_id == "":
		base_body_id = str(appearance.get("body", "")).strip_edges()
	if base_body_id == "":
		return ""

	var appearance_payload: Dictionary = appearance.duplicate()
	appearance_payload["body"] = base_body_id
	return "%s%s%s" % [
		base_body_id,
		PRESENCE_BODY_APPEARANCE_SEPARATOR,
		JSON.stringify(appearance_payload).uri_encode(),
	]


static func decode_presence_body_appearance(body_id: String) -> Dictionary:
	var encoded_body_id: String = body_id.strip_edges()
	var separator_index: int = encoded_body_id.find(PRESENCE_BODY_APPEARANCE_SEPARATOR)
	if separator_index < 0:
		return {}

	var encoded_payload: String = encoded_body_id.substr(separator_index + PRESENCE_BODY_APPEARANCE_SEPARATOR.length())
	var parsed_payload: Variant = JSON.parse_string(encoded_payload.uri_decode())
	if not parsed_payload is Dictionary:
		return {}

	var appearance_payload: Dictionary = parsed_payload as Dictionary
	appearance_payload["body"] = get_presence_body_base_id(encoded_body_id)
	return appearance_payload


static func get_presence_body_base_id(body_id: String) -> String:
	var encoded_body_id: String = body_id.strip_edges()
	var separator_index: int = encoded_body_id.find(PRESENCE_BODY_APPEARANCE_SEPARATOR)
	if separator_index < 0:
		return encoded_body_id
	return encoded_body_id.substr(0, separator_index)


static func get_available_part_ids(category: String, gender: String = "") -> Array[String]:
	var normalized_category: String = normalize_part_category(category)
	if not LAYERED_PART_CATEGORIES.has(normalized_category):
		return []

	var normalized_gender: String = normalize_gender(gender)
	var part_directory: String = _get_gender_part_directory(normalized_gender, normalized_category)
	var manifest_ids: Array[String] = _get_manifest_part_ids(part_directory)
	if FileAccess.file_exists("%s/parts_manifest.json" % part_directory):
		return _sort_part_ids(manifest_ids, normalized_category, normalized_gender)
	if not manifest_ids.is_empty():
		return _sort_part_ids(manifest_ids, normalized_category, normalized_gender)

	var part_ids: Array[String] = []
	_collect_part_ids_from_directory(part_directory, part_ids)
	return _sort_part_ids(part_ids, normalized_category, normalized_gender)


static func get_part_frames(category: String, part_id: String, gender: String = "", movement_style: String = BODY_MOVEMENT_DEFAULT) -> SpriteFrames:
	var normalized_category: String = normalize_part_category(category)
	var normalized_part_id: String = _normalize_body_id(part_id)
	if normalized_category == "" or normalized_part_id == "":
		return null
	if not LAYERED_PART_CATEGORIES.has(normalized_category):
		return null

	var normalized_gender: String = normalize_gender(gender)
	var normalized_movement_style: String = _normalize_movement_style(movement_style)
	var cache_key: String = "%s:%s:%s:%s" % [
		normalized_gender,
		normalized_category,
		normalized_part_id,
		normalized_movement_style,
	]
	if _part_frames_cache.has(cache_key):
		var cached_value: Variant = _part_frames_cache[cache_key]
		if cached_value is SpriteFrames:
			return cached_value as SpriteFrames
		return null

	var texture: Texture2D = _load_part_texture_for_movement(normalized_category, normalized_part_id, normalized_gender, normalized_movement_style)
	if texture == null:
		_part_frames_cache[cache_key] = null
		return null

	var sprite_frames: SpriteFrames = _build_sprite_frames(texture)
	_part_frames_cache[cache_key] = sprite_frames
	return sprite_frames


static func get_tinted_part_frames(
	category: String,
	part_id: String,
	gender: String = "",
	movement_style: String = BODY_MOVEMENT_DEFAULT,
	tint_color: Color = Color.WHITE,
	preserve_luminance: bool = false
) -> SpriteFrames:
	var normalized_category: String = normalize_part_category(category)
	var normalized_part_id: String = _normalize_body_id(part_id)
	if normalized_category == "" or normalized_part_id == "":
		return null
	if not LAYERED_PART_CATEGORIES.has(normalized_category):
		return null

	var normalized_gender: String = normalize_gender(gender)
	var normalized_movement_style: String = _normalize_movement_style(movement_style)
	var color_key: String = tint_color.to_html(true)
	var cache_key: String = "%s:%s:%s:%s:%s:%s" % [
		normalized_gender,
		normalized_category,
		normalized_part_id,
		normalized_movement_style,
		color_key,
		"luma" if preserve_luminance else "alpha",
	]
	if _tinted_part_frames_cache.has(cache_key):
		var cached_value: Variant = _tinted_part_frames_cache[cache_key]
		if cached_value is SpriteFrames:
			return cached_value as SpriteFrames
		return null

	var base_frames: SpriteFrames = get_part_frames(
		normalized_category,
		normalized_part_id,
		normalized_gender,
		normalized_movement_style
	)
	if base_frames == null:
		_tinted_part_frames_cache[cache_key] = null
		return null

	var tinted_frames: SpriteFrames = _build_tinted_sprite_frames(base_frames, tint_color, preserve_luminance)
	_tinted_part_frames_cache[cache_key] = tinted_frames
	return tinted_frames


static func get_available_body_ids(gender: String = "") -> Array[String]:
	var normalized_gender: String = normalize_gender(gender)
	var gender_directory: String = _get_gender_body_directory(normalized_gender)
	var manifest_body_ids: Array[String] = _get_manifest_body_ids(gender_directory)
	if not manifest_body_ids.is_empty():
		return _sort_body_ids(manifest_body_ids)

	var body_ids: Array[String] = []
	_collect_body_ids_from_directory(gender_directory, "", body_ids)
	if not body_ids.is_empty():
		return _sort_body_ids(body_ids)

	var legacy_gender_directory: String = _get_legacy_gender_body_directory(normalized_gender)
	if legacy_gender_directory != gender_directory:
		_collect_body_ids_from_directory(legacy_gender_directory, "", body_ids)
		if not body_ids.is_empty():
			return _sort_body_ids(body_ids)

	_collect_body_ids_from_directory(BODY_DIRECTORY, "", body_ids)
	if normalized_gender != "":
		body_ids = _filter_body_ids_for_gender(body_ids, normalized_gender)
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
		var prefixed_body_id: String = prefix + body_id
		if not _is_selectable_body_id(prefixed_body_id):
			continue
		body_ids.append(prefixed_body_id)

	for subdirectory: String in directory.get_directories():
		if subdirectory.begins_with("."):
			continue
		if NON_SELECTABLE_BODY_DIRECTORIES.has(subdirectory.to_lower()):
			continue
		_collect_body_ids_from_directory("%s/%s" % [directory_path, subdirectory], "%s%s/" % [prefix, subdirectory], body_ids)


static func _get_manifest_body_ids(directory_path: String = BODY_DIRECTORY) -> Array[String]:
	var manifest_path: String = "%s/body_manifest.json" % directory_path
	if not FileAccess.file_exists(manifest_path):
		return []

	var file := FileAccess.open(manifest_path, FileAccess.READ)
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
		if not _is_selectable_body_id(body_id):
			continue
		body_ids.append(body_id)
	return body_ids


static func _sort_body_ids(body_ids: Array[String]) -> Array[String]:
	body_ids.sort()
	if body_ids.has(DEFAULT_BODY_ID):
		body_ids.erase(DEFAULT_BODY_ID)
		body_ids.push_front(DEFAULT_BODY_ID)
	return body_ids


static func get_body_frames(body_id: String, gender: String = "", movement_style: String = BODY_MOVEMENT_DEFAULT) -> SpriteFrames:
	var normalized_gender: String = normalize_gender(gender)
	var normalized_body_id: String = _normalize_body_id(body_id)
	if normalized_body_id == "":
		normalized_body_id = _get_fallback_body_id(normalized_gender)
	var normalized_movement_style: String = _normalize_movement_style(movement_style)

	var cache_key: String = "%s:%s:%s" % [normalized_gender, normalized_body_id, normalized_movement_style]
	if _body_frames_cache.has(cache_key):
		var cached_value: Variant = _body_frames_cache[cache_key]
		if cached_value is SpriteFrames:
			return cached_value as SpriteFrames
		return null

	var texture: Texture2D = _load_body_texture_for_movement(normalized_body_id, normalized_gender, normalized_movement_style)
	var fallback_body_id: String = _get_fallback_body_id(normalized_gender)
	if texture == null and normalized_body_id != fallback_body_id:
		texture = _load_body_texture_for_movement(fallback_body_id, normalized_gender, normalized_movement_style)
	if texture == null:
		_body_frames_cache[cache_key] = null
		return null

	var sprite_frames: SpriteFrames = _build_sprite_frames(texture)
	_body_frames_cache[cache_key] = sprite_frames
	return sprite_frames


static func normalize_movement_style(movement_style: String) -> String:
	var normalized: String = movement_style.strip_edges().to_lower()
	if normalized == BODY_MOVEMENT_RUN:
		return BODY_MOVEMENT_RUN
	if normalized == BODY_MOVEMENT_FISH or normalized == "fishing":
		return BODY_MOVEMENT_FISH
	if normalized == BODY_MOVEMENT_RIDE \
			or normalized == BODY_MOVEMENT_SURF \
			or normalized == BODY_MOVEMENT_MOUNT \
			or normalized == "riding":
		return BODY_MOVEMENT_RIDE
	return BODY_MOVEMENT_DEFAULT


static func _normalize_movement_style(movement_style: String) -> String:
	return normalize_movement_style(movement_style)


static func _load_body_texture_for_movement(body_id: String, gender: String, movement_style: String) -> Texture2D:
	var normalized_movement_style: String = _normalize_movement_style(movement_style)
	if normalized_movement_style != BODY_MOVEMENT_DEFAULT:
		var movement_texture: Texture2D = _load_body_texture(_get_movement_body_id(body_id, normalized_movement_style), gender)
		if movement_texture != null:
			return movement_texture

	return _load_body_texture(body_id, gender)


static func _get_run_body_id(body_id: String) -> String:
	return _get_movement_body_id(body_id, BODY_MOVEMENT_RUN)


static func _get_movement_body_id(body_id: String, movement_style: String) -> String:
	var normalized_body_id: String = _normalize_body_id(body_id)
	var normalized_movement_style: String = _normalize_movement_style(movement_style)
	if normalized_body_id == "":
		return ""
	if normalized_movement_style == BODY_MOVEMENT_DEFAULT:
		return normalized_body_id

	var slash_index: int = normalized_body_id.rfind("/")
	if slash_index >= 0:
		var directory_path: String = normalized_body_id.substr(0, slash_index)
		var file_id: String = normalized_body_id.substr(slash_index + 1)
		return "%s/%s/%s_%s" % [directory_path, normalized_movement_style, file_id, normalized_movement_style]

	return "%s/%s_%s" % [normalized_movement_style, normalized_body_id, normalized_movement_style]


static func _load_body_texture(body_id: String, gender: String = "") -> Texture2D:
	var normalized_gender: String = normalize_gender(gender)
	if normalized_gender != "":
		var gender_path: String = "%s/%s" % [_get_gender_body_directory(normalized_gender), body_id]
		gender_path = "%s.png" % gender_path
		if ResourceLoader.exists(gender_path):
			return ResourceLoader.load(gender_path) as Texture2D

		var legacy_gender_path: String = "%s/%s.png" % [_get_legacy_gender_body_directory(normalized_gender), body_id]
		if ResourceLoader.exists(legacy_gender_path):
			return ResourceLoader.load(legacy_gender_path) as Texture2D

	var path: String = "%s/%s.png" % [BODY_DIRECTORY, body_id]
	if ResourceLoader.exists(path):
		return ResourceLoader.load(path) as Texture2D
	return null


static func _get_fallback_body_id(gender: String = "") -> String:
	var normalized_gender: String = normalize_gender(gender)
	var preferred_body_id: String = DEFAULT_FEMALE_BODY_ID if normalized_gender == "female" else DEFAULT_MALE_BODY_ID
	if _load_body_texture(preferred_body_id, normalized_gender) != null:
		return preferred_body_id

	var body_ids: Array[String] = get_available_body_ids(normalized_gender)
	if body_ids.is_empty():
		return preferred_body_id
	return body_ids[0]


static func normalize_gender(gender: String) -> String:
	var normalized: String = gender.strip_edges().to_lower()
	if normalized == "male" or normalized == "m" or normalized == "boy":
		return "male"
	if normalized == "female" or normalized == "f" or normalized == "girl":
		return "female"
	return ""


static func infer_gender_from_body_id(body_id: String) -> String:
	var normalized_body_id: String = _normalize_body_id(body_id).to_lower()
	if normalized_body_id == "":
		return ""
	if normalized_body_id.contains("_f_") \
			or normalized_body_id.contains("female") \
			or normalized_body_id.contains("girl"):
		return "female"
	if normalized_body_id.contains("_m_") \
			or normalized_body_id.contains("male") \
			or normalized_body_id.contains("boy"):
		return "male"
	return ""


static func _get_gender_body_directory(gender: String) -> String:
	var normalized_gender: String = normalize_gender(gender)
	if normalized_gender == "":
		return BODY_DIRECTORY
	return "%s/%s/%s" % [PLAYER_DIRECTORY, normalized_gender, BODY_CATEGORY]


static func _get_legacy_gender_body_directory(gender: String) -> String:
	var normalized_gender: String = normalize_gender(gender)
	if normalized_gender == "":
		return BODY_DIRECTORY
	return "%s/%s" % [BODY_DIRECTORY, normalized_gender]


static func _filter_body_ids_for_gender(body_ids: Array[String], gender: String) -> Array[String]:
	var filtered_ids: Array[String] = []
	for body_id: String in body_ids:
		if _body_id_matches_gender(body_id, gender):
			filtered_ids.append(body_id)
	return filtered_ids


static func _body_id_matches_gender(body_id: String, gender: String) -> bool:
	var normalized_body_id: String = body_id.to_lower()
	var is_female_body: bool = normalized_body_id.contains("girl") or normalized_body_id.contains("female")
	var is_male_body: bool = normalized_body_id.contains("boy") or normalized_body_id.contains("male")
	if gender == "female":
		return is_female_body
	if gender == "male":
		return not is_female_body or is_male_body
	return true


static func _is_selectable_body_id(body_id: String) -> bool:
	var normalized_body_id: String = _normalize_body_id(body_id).to_lower()
	for body_path_part: String in normalized_body_id.split("/", false):
		if NON_SELECTABLE_BODY_DIRECTORIES.has(body_path_part):
			return false
	return true


static func _load_part_texture_for_movement(category: String, part_id: String, gender: String, movement_style: String) -> Texture2D:
	var normalized_movement_style: String = _normalize_movement_style(movement_style)
	if normalized_movement_style != BODY_MOVEMENT_DEFAULT:
		var movement_part_id: String = _get_movement_body_id(part_id, normalized_movement_style)
		var movement_texture: Texture2D = _load_part_texture(category, movement_part_id, gender)
		if movement_texture != null:
			return movement_texture
	return _load_part_texture(category, part_id, gender)


static func _load_part_texture(category: String, part_id: String, gender: String = "") -> Texture2D:
	var normalized_category: String = normalize_part_category(category)
	var normalized_part_id: String = _normalize_body_id(part_id)
	if normalized_category == "" or normalized_part_id == "":
		return null

	var normalized_gender: String = normalize_gender(gender)
	if normalized_gender != "":
		var gender_path: String = "%s/%s.png" % [_get_gender_part_directory(normalized_gender, normalized_category), normalized_part_id]
		if ResourceLoader.exists(gender_path):
			return ResourceLoader.load(gender_path) as Texture2D

	var path: String = "%s/%s/%s.png" % [PLAYER_DIRECTORY, normalized_category, normalized_part_id]
	if ResourceLoader.exists(path):
		return ResourceLoader.load(path) as Texture2D
	return null


static func _get_gender_part_directory(gender: String, category: String) -> String:
	var normalized_gender: String = normalize_gender(gender)
	var normalized_category: String = normalize_part_category(category)
	if normalized_gender == "":
		return "%s/%s" % [PLAYER_DIRECTORY, normalized_category]
	return "%s/%s/%s" % [PLAYER_DIRECTORY, normalized_gender, normalized_category]


static func _get_manifest_part_ids(directory_path: String) -> Array[String]:
	var manifest_path: String = "%s/parts_manifest.json" % directory_path
	if not FileAccess.file_exists(manifest_path):
		return []

	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		return []

	var parsed_body: Variant = JSON.parse_string(file.get_as_text())
	if not parsed_body is Array:
		return []

	var part_ids: Array[String] = []
	var parsed_ids: Array = parsed_body as Array
	for part_id_value: Variant in parsed_ids:
		var part_id: String = _normalize_body_id(str(part_id_value))
		if part_id != "":
			part_ids.append(part_id)
	return part_ids


static func _collect_part_ids_from_directory(directory_path: String, part_ids: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return

	for file_name: String in directory.get_files():
		if not file_name.ends_with(".png"):
			continue
		var part_id: String = file_name.trim_suffix(".png")
		if part_id != "":
			part_ids.append(part_id)


static func _sort_part_ids(part_ids: Array[String], category: String, gender: String) -> Array[String]:
	part_ids.sort()
	var default_part_id: String = get_default_part_id(category, gender)
	if default_part_id != "" and part_ids.has(default_part_id):
		part_ids.erase(default_part_id)
		part_ids.push_front(default_part_id)
	return part_ids


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


static func _build_tinted_sprite_frames(base_frames: SpriteFrames, tint_color: Color, preserve_luminance: bool) -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	if sprite_frames.has_animation(&"default"):
		sprite_frames.remove_animation(&"default")

	for animation_name_text: String in base_frames.get_animation_names():
		var animation_name := StringName(animation_name_text)
		if not sprite_frames.has_animation(animation_name):
			sprite_frames.add_animation(animation_name)
		sprite_frames.set_animation_speed(animation_name, base_frames.get_animation_speed(animation_name))
		sprite_frames.set_animation_loop(animation_name, base_frames.get_animation_loop(animation_name))

		var frame_count: int = base_frames.get_frame_count(animation_name)
		for frame_index: int in range(frame_count):
			var frame_texture: Texture2D = base_frames.get_frame_texture(animation_name, frame_index)
			var frame_duration: float = base_frames.get_frame_duration(animation_name, frame_index)
			var tinted_texture: Texture2D = _make_tinted_texture(frame_texture, tint_color, preserve_luminance)
			sprite_frames.add_frame(animation_name, tinted_texture, frame_duration)

	return sprite_frames


static func _make_tinted_texture(texture: Texture2D, tint_color: Color, preserve_luminance: bool) -> Texture2D:
	if texture == null:
		return null

	var source_image: Image = _get_texture_image(texture)
	if source_image == null:
		return texture

	var width: int = source_image.get_width()
	var height: int = source_image.get_height()
	var tinted_image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y: int in range(height):
		for x: int in range(width):
			var source_pixel: Color = source_image.get_pixel(x, y)
			var alpha: float = source_pixel.a * tint_color.a
			if preserve_luminance:
				var luminance: float = clampf(
					(source_pixel.r * 0.2126) + (source_pixel.g * 0.7152) + (source_pixel.b * 0.0722),
					0.0,
					1.0
				)
				var normalized_luminance: float = clampf((luminance - 0.05) / 0.43, 0.0, 1.0)
				var shade_value: float = lerpf(0.45, 1.15, pow(normalized_luminance, 0.85))
				var tinted_value: float = clampf(tint_color.v * shade_value, 0.0, 1.0)
				tinted_image.set_pixel(x, y, Color.from_hsv(tint_color.h, tint_color.s, tinted_value, alpha))
			else:
				tinted_image.set_pixel(x, y, Color(tint_color.r, tint_color.g, tint_color.b, alpha))

	return ImageTexture.create_from_image(tinted_image)


static func _get_texture_image(texture: Texture2D) -> Image:
	if texture is AtlasTexture:
		var atlas_texture := texture as AtlasTexture
		if atlas_texture.atlas == null:
			return null
		var atlas_image: Image = atlas_texture.atlas.get_image()
		if atlas_image == null:
			return null
		var region: Rect2 = atlas_texture.region
		return atlas_image.get_region(Rect2i(
			int(region.position.x),
			int(region.position.y),
			int(region.size.x),
			int(region.size.y)
		))

	return texture.get_image()


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
	var normalized: String = get_presence_body_base_id(body_id).strip_edges().replace("\\", "/")
	var normalized_parts: Array[String] = []
	for part: String in normalized.split("/", false):
		var normalized_part: String = part.strip_edges()
		if normalized_part == "" or normalized_part == "." or normalized_part == "..":
			return ""
		normalized_parts.append(normalized_part)
	return "/".join(normalized_parts)
