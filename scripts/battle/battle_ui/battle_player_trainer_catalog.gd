extends RefCounted

class_name BattlePlayerTrainerCatalog

const CharacterAppearanceService := preload("res://scripts/services/character_appearance_service.gd")
const MANIFEST_PATH := "res://assets/battles/trainers/player/manifest.json"
# Authored male/female battle bases share these three skin shades. The ball's
# red and dark red also satisfy the overworld skin heuristic, so keep all other
# pixels out of both the recolour mask and its luminance calculation.
const BASE_SKIN_PALETTE: Array[Color] = [Color("#f8d0b8"), Color("#d8a078"), Color("#b87860")]
const REQUIRED_CLOTHING_CATEGORIES: Array[String] = ["bottom", "top"]
const OPTIONAL_CATEGORIES: Array[String] = [
	"shoes", "top_accessory", "eyebrows", "hair", "facial_hair", "headgear", "facegear"
]
const APPEARANCE_CATEGORY_ALIASES := {"top_accessory": "top", "eyebrows": "hair"}

static var _manifest: Dictionary = {}
static var _texture_cache: Dictionary = {}
static var _variant_cache: Dictionary = {}


static func build_layers(appearance_state: Dictionary) -> Array[Dictionary]:
	var manifest := _get_manifest()
	var gender := CharacterAppearanceService.normalize_gender(str(appearance_state.get("gender", "")))
	if gender != "female":
		gender = "male"
	var gender_value: Variant = manifest.get("genders", {}).get(gender, {})
	if not (gender_value is Dictionary):
		return []
	var gender_data := gender_value as Dictionary
	var layers: Array[Dictionary] = []
	var base_path := str(gender_data.get("base", ""))
	var base_texture := _load_texture(base_path)
	if base_texture == null:
		return []
	var skin_tone := CharacterAppearanceService.resolve_skin_tone(
		str(appearance_state.get("body", "")),
		str(appearance_state.get("skin_tone", "")),
		gender
	)
	layers.append({
		"category": "body",
		"part_id": str(appearance_state.get("body", "")),
		"texture": _skin_variant(base_path, base_texture, skin_tone),
		"scale": 1.0,
		"fallback": false,
	})

	var layer_order_value: Variant = manifest.get(
		"layerOrder",
		["bottom", "shoes", "top", "hair", "headgear"]
	)
	if not (layer_order_value is Array):
		return layers
	for category_value: Variant in layer_order_value as Array:
		var category := str(category_value)
		if category not in REQUIRED_CLOTHING_CATEGORIES and category not in OPTIONAL_CATEGORIES:
			continue
		var layer := _resolve_part_layer(gender_data, appearance_state, gender, category)
		if not layer.is_empty():
			layers.append(layer)
	return layers


static func _resolve_part_layer(
	gender_data: Dictionary,
	appearance_state: Dictionary,
	gender: String,
	category: String
) -> Dictionary:
	var selected_id := _selected_part_id(appearance_state, category)
	var is_required := category in REQUIRED_CLOTHING_CATEGORIES
	if selected_id.is_empty() and not is_required:
		return {}
	var categories_value: Variant = gender_data.get("categories", {})
	if not (categories_value is Dictionary):
		return {}
	var category_value: Variant = (categories_value as Dictionary).get(category, {})
	if not (category_value is Dictionary):
		return {}
	var category_data := category_value as Dictionary
	var parts_value: Variant = category_data.get("parts", {})
	if not (parts_value is Dictionary):
		return {}
	var parts := parts_value as Dictionary
	var resolved_id := selected_id
	var used_fallback := false
	if not parts.has(resolved_id) and is_required:
		resolved_id = str(category_data.get("fallback", ""))
		used_fallback = not selected_id.is_empty()
	if resolved_id.is_empty() or not parts.has(resolved_id):
		return {}
	var part_value: Variant = parts.get(resolved_id, {})
	if not (part_value is Dictionary):
		return {}
	var part := part_value as Dictionary
	var path := str(part.get("path", ""))
	var texture := _load_texture(path)
	if texture == null:
		return {}
	var tint_key := str(part.get("tint", "")).strip_edges()
	if tint_key.is_empty() and category == "hair" and CharacterAppearanceService.is_tintable_part(category, resolved_id):
		tint_key = "hair_color"
	if not tint_key.is_empty():
		var tint_colour := _appearance_tint(appearance_state, tint_key, gender)
		if not tint_colour.is_empty():
			texture = _colour_variant(path, texture, tint_colour)
	return {
		"category": category,
		"part_id": resolved_id,
		"requested_part_id": selected_id,
		"texture": texture,
		"scale": float(part.get("scale", 1.0)),
		"fallback": used_fallback,
	}


static func _appearance_tint(appearance_state: Dictionary, tint_key: String, gender: String) -> String:
	var colour := str(appearance_state.get(tint_key, "")).strip_edges()
	if tint_key == "hair_color":
		return CharacterAppearanceService.resolve_hair_color(colour, gender)
	return CharacterAppearanceService.normalize_hex_color_code(colour)

static func _selected_part_id(appearance_state: Dictionary, category: String) -> String:
	var appearance_category := str(APPEARANCE_CATEGORY_ALIASES.get(category, category))
	var value: Variant = appearance_state.get(appearance_category, "")
	if appearance_category == "bottom" and str(value).strip_edges().is_empty():
		value = appearance_state.get("legs", "")
	elif appearance_category == "shoes" and str(value).strip_edges().is_empty():
		value = appearance_state.get("feet", "")
	return CharacterAppearanceService.deserialize_part_id(str(value))


static func _get_manifest() -> Dictionary:
	if not _manifest.is_empty():
		return _manifest
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("BattlePlayerTrainerCatalog: missing %s" % MANIFEST_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if parsed is Dictionary:
		_manifest = parsed as Dictionary
	else:
		push_warning("BattlePlayerTrainerCatalog: invalid player battle trainer manifest")
	return _manifest


static func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache.get(path) as Texture2D
	# Fresh battle-art PNGs may exist on disk before Godot's editor importer has
	# generated their .import resource.  Read those directly so a newly added
	# outfit never renders as an empty layer during that window.
	var texture: Texture2D = null
	if ResourceLoader.exists(path, "Texture2D"):
		texture = ResourceLoader.load(path, "Texture2D") as Texture2D
	if texture == null and FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image != null and not image.is_empty():
			texture = ImageTexture.create_from_image(image)
	_texture_cache[path] = texture
	return texture


static func _skin_variant(path: String, texture: Texture2D, skin_tone: String) -> Texture2D:
	var key := "skin:%s:%s" % [path, skin_tone.to_lower()]
	if not _variant_cache.has(key):
		var source := texture.get_image()
		var mask := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
		var used := source.get_used_rect()
		for y: int in range(used.position.y, used.end.y):
			for x: int in range(used.position.x, used.end.x):
				var pixel := source.get_pixel(x, y)
				if pixel in BASE_SKIN_PALETTE:
					mask.set_pixel(x, y, pixel)
		var tinted := CharacterAppearanceService.tint_skin_texture(
			ImageTexture.create_from_image(mask),
			Color.from_string(skin_tone, Color(CharacterAppearanceService.DEFAULT_SKIN_TONE))
		).get_image()
		var result := source.duplicate() as Image
		for y: int in range(used.position.y, used.end.y):
			for x: int in range(used.position.x, used.end.x):
				if mask.get_pixel(x, y).a > 0.0:
					result.set_pixel(x, y, tinted.get_pixel(x, y))
		_variant_cache[key] = ImageTexture.create_from_image(result)
	return _variant_cache.get(key) as Texture2D


static func _colour_variant(path: String, texture: Texture2D, colour: String) -> Texture2D:
	var key := "colour:%s:%s" % [path, colour.to_lower()]
	if not _variant_cache.has(key):
		_variant_cache[key] = CharacterAppearanceService.tint_texture(
			texture,
			Color.from_string(colour, Color.WHITE),
			true
		)
	return _variant_cache.get(key) as Texture2D
