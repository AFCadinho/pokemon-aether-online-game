extends RefCounted

class_name CharacterAppearanceService

const PLAYER_DIRECTORY := "res://assets/player"
const BODY_CATEGORY := "body"
const BODY_DIRECTORY := "res://assets/player/body"
const BODY_MANIFEST_PATH := "res://assets/player/body/body_manifest.json"
const HAIR_CATEGORY := "hair"
const HEADGEAR_CATEGORY := "headgear"
const FACIAL_HAIR_CATEGORY := "facial_hair"
const FACEGEAR_CATEGORY := "facegear"
const TOP_CATEGORY := "top"
const BOTTOM_CATEGORY := "bottom"
const SHOES_CATEGORY := "shoes"
const EYES_CATEGORY := "eyes"
const EYEBROWS_CATEGORY := "eyebrows"
const UNEQUIPPED_PART_ID := "__none__"
const LEGACY_NULL_TEXT_VALUES: Array[String] = ["<null>", "null", "none"]
const PRESENCE_BODY_APPEARANCE_SEPARATOR := "#appearance="
const DEFAULT_BODY_ID := "Gen4_Base_v1"
const DEFAULT_MALE_BODY_ID := "Gen4_Base_v1"
const DEFAULT_FEMALE_BODY_ID := "Gen4_Base_F_v1"
const BASE_HAIR_ID := "Bald_Hair"
const DEFAULT_MALE_HAIR_ID := "Hair"
const DEFAULT_MALE_HEADGEAR_ID := "Cap"
const DEFAULT_MALE_FACIAL_HAIR_ID := ""
const DEFAULT_MALE_FACEGEAR_ID := ""
const DEFAULT_MALE_TOP_ID := "Shirt"
const DEFAULT_MALE_BOTTOM_ID := "Trousers"
const DEFAULT_MALE_SHOES_ID := "Shoes"
const DEFAULT_MALE_EYES_ID := "Eyes"
const DEFAULT_MALE_EYEBROWS_ID := "Eyebrows"
const DEFAULT_FEMALE_HAIR_ID := "Hair"
const DEFAULT_FEMALE_HEADGEAR_ID := "Cap"
const DEFAULT_FEMALE_FACIAL_HAIR_ID := ""
const DEFAULT_FEMALE_FACEGEAR_ID := ""
const DEFAULT_FEMALE_TOP_ID := "Shirt"
const DEFAULT_FEMALE_BOTTOM_ID := "Trousers"
const DEFAULT_FEMALE_SHOES_ID := "Shoes"
const DEFAULT_FEMALE_EYES_ID := "Eyes"
const DEFAULT_FEMALE_EYEBROWS_ID := "Eyebrows"
const EYEBROWS_BY_HAIR_ID := {
	"male:Hair": DEFAULT_MALE_EYEBROWS_ID,
	"male:Adinho_Hair": "Adinho_Eyebrows",
	"male:Aether_Male_Hair_01": DEFAULT_MALE_EYEBROWS_ID,
	"male:Aether_Male_Hair_02": DEFAULT_MALE_EYEBROWS_ID,
	"male:Aether_Male_Hair_03": DEFAULT_MALE_EYEBROWS_ID,
	"female:Hair": DEFAULT_FEMALE_EYEBROWS_ID,
	"female:Aether_Blossom_Hair": DEFAULT_FEMALE_EYEBROWS_ID,
	"female:Aether_Blossom_Hair_Chroma": DEFAULT_FEMALE_EYEBROWS_ID,
	"female:Aether_Female_Hair_01": DEFAULT_FEMALE_EYEBROWS_ID,
	"female:Aether_Female_Hair_02": DEFAULT_FEMALE_EYEBROWS_ID,
}
const LEGACY_DEFAULT_HAIR_COLOR := "#ffffff"
const LEGACY_DEFAULT_EYE_COLOR := "#0fff00"
const DEFAULT_MALE_HAIR_COLOR := "#5a3728"
const DEFAULT_FEMALE_HAIR_COLOR := "#6b4632"
const DEFAULT_HAIR_COLOR := DEFAULT_MALE_HAIR_COLOR
const DEFAULT_SKIN_TONE := "#f8d0b8"
const LEGACY_TAN_SKIN_TONE := "#c58a5c"
const LEGACY_DARK_SKIN_TONE := "#68402f"
const DEFAULT_MALE_EYE_COLOR := "#3d6f86"
const DEFAULT_FEMALE_EYE_COLOR := "#456f4a"
const DEFAULT_EYE_COLOR := DEFAULT_MALE_EYE_COLOR
const HAIR_COLOR_SWATCHES: Array[Dictionary] = [
	{"id": "#201a18", "label": "Soft Black", "color": Color("#201a18")},
	{"id": "#3b241c", "label": "Espresso", "color": Color("#3b241c")},
	{"id": "#5a3728", "label": "Dark Brown", "color": Color("#5a3728")},
	{"id": "#6b4632", "label": "Warm Brown", "color": Color("#6b4632")},
	{"id": "#7a4632", "label": "Chestnut", "color": Color("#7a4632")},
	{"id": "#813a2f", "label": "Auburn", "color": Color("#813a2f")},
	{"id": "#a85f3f", "label": "Copper", "color": Color("#a85f3f")},
	{"id": "#b99555", "label": "Dirty Blond", "color": Color("#b99555")},
	{"id": "#d6b66b", "label": "Ash Blond", "color": Color("#d6b66b")},
	{"id": "#e8dfc7", "label": "Platinum", "color": Color("#e8dfc7")},
	{"id": "#a9afb8", "label": "Silver", "color": Color("#a9afb8")},
	{"id": "#2b5f64", "label": "Deep Teal", "color": Color("#2b5f64")},
	{"id": "#6b5c91", "label": "Muted Violet", "color": Color("#6b5c91")},
	{"id": "#a64f70", "label": "Dusty Rose", "color": Color("#a64f70")},
]
const CHROMA_COLOR_SWATCHES: Array[Dictionary] = [
	{"id": "#171a21", "label": "Charcoal", "color": Color("#171a21")},
	{"id": "#555c66", "label": "Slate", "color": Color("#555c66")},
	{"id": "#aeb6c2", "label": "Silver", "color": Color("#aeb6c2")},
	{"id": "#f2f2ec", "label": "Pearl", "color": Color("#f2f2ec")},
	{"id": "#efe2c1", "label": "Cream", "color": Color("#efe2c1")},
	{"id": "#6f4935", "label": "Brown", "color": Color("#6f4935")},
	{"id": "#b53a3f", "label": "Crimson", "color": Color("#b53a3f")},
	{"id": "#e45d4f", "label": "Coral", "color": Color("#e45d4f")},
	{"id": "#d97932", "label": "Orange", "color": Color("#d97932")},
	{"id": "#d6a629", "label": "Gold", "color": Color("#d6a629")},
	{"id": "#d7dc55", "label": "Lime", "color": Color("#d7dc55")},
	{"id": "#3d8b52", "label": "Green", "color": Color("#3d8b52")},
	{"id": "#2b7f78", "label": "Teal", "color": Color("#2b7f78")},
	{"id": "#36a7b4", "label": "Cyan", "color": Color("#36a7b4")},
	{"id": "#3f6fb2", "label": "Blue", "color": Color("#3f6fb2")},
	{"id": "#314a85", "label": "Navy", "color": Color("#314a85")},
	{"id": "#6b5c91", "label": "Violet", "color": Color("#6b5c91")},
	{"id": "#8c4fa3", "label": "Purple", "color": Color("#8c4fa3")},
	{"id": "#b84f8e", "label": "Magenta", "color": Color("#b84f8e")},
	{"id": "#e77ba8", "label": "Pink", "color": Color("#e77ba8")},
]
const SKIN_TONE_SWATCHES: Array[Dictionary] = [
	{"id": "#f8d0b8", "label": "Default", "color": Color("#f8d0b8")},
	{"id": "#f2d2bd", "label": "Tone 1 · Neutral", "color": Color("#f2d2bd")},
	{"id": "#ebc0ae", "label": "Tone 2 · Cool", "color": Color("#ebc0ae")},
	{"id": "#e7b894", "label": "Tone 3 · Warm", "color": Color("#e7b894")},
	{"id": "#d6a07c", "label": "Tone 4 · Neutral", "color": Color("#d6a07c")},
	{"id": "#c58a5c", "label": "Tone 5 · Golden", "color": Color("#c58a5c")},
	{"id": "#b17a57", "label": "Tone 6 · Olive", "color": Color("#b17a57")},
	{"id": "#9b6549", "label": "Tone 7 · Neutral", "color": Color("#9b6549")},
	{"id": "#825137", "label": "Tone 8 · Warm", "color": Color("#825137")},
	{"id": "#68402f", "label": "Tone 9 · Deep", "color": Color("#68402f")},
	{"id": "#533327", "label": "Tone 10 · Deep Warm", "color": Color("#533327")},
	{"id": "#3f271f", "label": "Tone 11 · Rich Deep", "color": Color("#3f271f")},
	{"id": "#2d1c18", "label": "Tone 12 · Espresso", "color": Color("#2d1c18")},
]
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
const BODY_MOVEMENT_SURF_FISH := "surf_fish"
const BODY_MOVEMENT_MOUNT := "mount"
const LAYERED_PART_CATEGORIES: Array[String] = [
	HAIR_CATEGORY,
	HEADGEAR_CATEGORY,
	FACIAL_HAIR_CATEGORY,
	FACEGEAR_CATEGORY,
	TOP_CATEGORY,
	BOTTOM_CATEGORY,
	SHOES_CATEGORY,
	EYES_CATEGORY,
	EYEBROWS_CATEGORY,
]
const MOVEMENT_POSE_PART_CATEGORIES: Array[String] = [
	TOP_CATEGORY,
	BOTTOM_CATEGORY,
	SHOES_CATEGORY,
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
static var _skin_tinted_body_frames_cache: Dictionary = {}
static var _part_frames_cache: Dictionary = {}
static var _tinted_part_frames_cache: Dictionary = {}
static var _cosmetic_item_icon_cache: Dictionary = {}


static func resolve_cosmetic_icon_gender(gender: String, allowed_genders_value: Variant = []) -> String:
	var normalized_gender := normalize_gender(gender)
	var allowed_genders: Array[String] = []
	if allowed_genders_value is Array:
		for gender_value: Variant in allowed_genders_value as Array:
			var allowed_gender := normalize_gender(str(gender_value))
			if allowed_gender != "" and not allowed_genders.has(allowed_gender):
				allowed_genders.append(allowed_gender)
	if allowed_genders.is_empty() or allowed_genders.has(normalized_gender):
		return normalized_gender if normalized_gender != "" else "male"
	return allowed_genders[0]


static func get_default_appearance(gender: String = "") -> Dictionary:
	var normalized_gender: String = normalize_gender(gender)
	var body_id: String = DEFAULT_FEMALE_BODY_ID if normalized_gender == "female" else DEFAULT_MALE_BODY_ID
	var appearance := {
		"body": body_id,
		"hair": "",
		"headgear": "",
		"facial_hair": "",
		"facegear": "",
		"top": "",
		"bottom": "",
		"shoes": "",
		"hair_color": get_default_hair_color(normalized_gender),
		"skin_tone": DEFAULT_SKIN_TONE,
		"eye_color": get_default_eye_color(normalized_gender),
		"facial_hair_color": "#ffffff",
		"facegear_color": "#ffffff",
		"top_color": "#ffffff",
		"bottom_color": "#ffffff",
		"shoes_color": "#ffffff",
	}
	if body_supports_layered_parts(body_id, normalized_gender):
		for category: String in LAYERED_PART_CATEGORIES:
			if category == EYES_CATEGORY or category == EYEBROWS_CATEGORY:
				continue
			appearance[category] = get_default_part_id(category, normalized_gender)
	return appearance


static func get_cosmetic_item_icon(item_id: String, gender: String = "male") -> Texture2D:
	var normalized_item_id := item_id.strip_edges().to_lower()
	var normalized_gender := normalize_gender(gender)
	if normalized_gender == "":
		normalized_gender = "male"
	var cache_key := "%s:%s" % [normalized_gender, normalized_item_id]
	if _cosmetic_item_icon_cache.has(cache_key):
		return _cosmetic_item_icon_cache.get(cache_key) as Texture2D

	var layers: Array[Dictionary] = []
	match normalized_item_id:
		"aether-blossom-outfit":
			layers = [
				{"kind": "body"},
				{"category": BOTTOM_CATEGORY, "id": get_default_part_id(BOTTOM_CATEGORY, normalized_gender)},
				{"category": SHOES_CATEGORY, "id": "Aether_Blossom_Shoes"},
				{"category": TOP_CATEGORY, "id": "Aether_Blossom_Dress"},
				{"category": EYES_CATEGORY, "id": get_default_part_id(EYES_CATEGORY, normalized_gender), "tint": Color(DEFAULT_FEMALE_EYE_COLOR)},
				{"category": HAIR_CATEGORY, "id": "Aether_Blossom_Hair"},
				{"category": FACEGEAR_CATEGORY, "id": "Aether_Blossom_Earrings"},
			]
		"aether-blossom-hair":
			layers = [
				{"category": HAIR_CATEGORY, "id": "Aether_Blossom_Hair"},
			]
		"aether-blossom-earrings":
			layers = [
				{"category": FACEGEAR_CATEGORY, "id": "Aether_Blossom_Earrings"},
			]
		"aether-blossom-dress":
			layers = [
				{"category": TOP_CATEGORY, "id": "Aether_Blossom_Dress"},
			]
		"aether-blossom-shoes":
			layers = [
				{"category": SHOES_CATEGORY, "id": "Aether_Blossom_Shoes"},
			]
		"aether-blossom-chroma-hair":
			layers = [
				{"category": HAIR_CATEGORY, "id": "Aether_Blossom_Hair_Chroma", "tint": Color(DEFAULT_FEMALE_HAIR_COLOR), "preserve": true},
			]
		"aether-blossom-chroma-earrings":
			layers = [
				{"category": FACEGEAR_CATEGORY, "id": "Aether_Blossom_Earrings_Chroma", "tint": Color("#e77ba8"), "preserve": true},
			]
		"aether-blossom-chroma-shoes":
			layers = [
				{"category": SHOES_CATEGORY, "id": "Aether_Blossom_Shoes_Chroma", "tint": Color("#d6a629"), "preserve": true},
			]
		"aether-male-chroma-hair-1":
			layers = [
				{"category": HAIR_CATEGORY, "id": "Aether_Male_Hair_01", "tint": Color(DEFAULT_MALE_HAIR_COLOR), "preserve": true},
			]
		"aether-male-chroma-hair-2":
			layers = [
				{"category": HAIR_CATEGORY, "id": "Aether_Male_Hair_02", "tint": Color(DEFAULT_MALE_HAIR_COLOR), "preserve": true},
			]
		"aether-male-chroma-hair-3":
			layers = [
				{"category": HAIR_CATEGORY, "id": "Aether_Male_Hair_03", "tint": Color(DEFAULT_MALE_HAIR_COLOR), "preserve": true},
			]
		"aether-female-chroma-hair-1":
			layers = [
				{"category": HAIR_CATEGORY, "id": "Aether_Female_Hair_01", "tint": Color(DEFAULT_FEMALE_HAIR_COLOR), "preserve": true},
			]
		"aether-female-chroma-hair-2":
			layers = [
				{"category": HAIR_CATEGORY, "id": "Aether_Female_Hair_02", "tint": Color(DEFAULT_FEMALE_HAIR_COLOR), "preserve": true},
			]
		"adinho-classic-outfit":
			layers = [
				{"kind": "body"},
				{"category": BOTTOM_CATEGORY, "id": "Adinho_Trousers"},
				{"category": SHOES_CATEGORY, "id": "Adinho_Shoes"},
				{"category": TOP_CATEGORY, "id": "Adinho_Shirt"},
				{"category": EYEBROWS_CATEGORY, "id": "Adinho_Eyebrows", "tint": Color(DEFAULT_HAIR_COLOR), "preserve": true},
				{"category": EYES_CATEGORY, "id": get_default_part_id(EYES_CATEGORY, normalized_gender), "tint": Color(DEFAULT_EYE_COLOR)},
				{"category": HAIR_CATEGORY, "id": "Adinho_Hair", "tint": Color(DEFAULT_HAIR_COLOR), "preserve": true},
				{"category": FACIAL_HAIR_CATEGORY, "id": "Adinho_Beard", "tint": Color(DEFAULT_HAIR_COLOR), "preserve": true},
				{"category": FACEGEAR_CATEGORY, "id": "Adinho_Glasses"},
			]
		"adinho-classic-sunglasses":
			layers = [
				{"category": FACEGEAR_CATEGORY, "id": "Adinho_Glasses"},
			]
		"adinho-classic-shirt":
			layers = [
				{"category": TOP_CATEGORY, "id": "Adinho_Shirt"},
			]
		"adinho-classic-trousers":
			layers = [
				{"category": BOTTOM_CATEGORY, "id": "Adinho_Trousers"},
			]
		"adinho-classic-shoes":
			layers = [
				{"category": SHOES_CATEGORY, "id": "Adinho_Shoes"},
			]
		"adinho-chroma-hair":
			layers = [
				{"category": HAIR_CATEGORY, "id": "Adinho_Hair", "tint": Color(DEFAULT_HAIR_COLOR), "preserve": true},
			]
		"adinho-chroma-beard":
			layers = [
				{"category": FACIAL_HAIR_CATEGORY, "id": "Adinho_Beard", "tint": Color(DEFAULT_HAIR_COLOR), "preserve": true},
			]
		"adinho-chroma-glasses":
			layers = [
				{"category": FACEGEAR_CATEGORY, "id": "Adinho_Glasses_Chroma", "tint": Color("#aeb6c2"), "preserve": true},
			]
		"adinho-chroma-shirt":
			layers = [
				{"category": TOP_CATEGORY, "id": "Adinho_Shirt_Chroma", "tint": Color("#3f6fb2"), "preserve": true},
			]
		"adinho-chroma-trousers":
			layers = [
				{"category": BOTTOM_CATEGORY, "id": "Adinho_Trousers_Chroma", "tint": Color("#8c4fa3"), "preserve": true},
			]
		"adinho-chroma-shoes":
			layers = [
				{"category": SHOES_CATEGORY, "id": "Adinho_Shoes_Chroma", "tint": Color("#e77ba8"), "preserve": true},
			]
		_:
			return null

	var icon_image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	icon_image.fill(Color.TRANSPARENT)
	for layer: Dictionary in layers:
		var frames: SpriteFrames
		if str(layer.get("kind", "")) == "body":
			frames = get_skin_tinted_body_frames(
				DEFAULT_FEMALE_BODY_ID if normalized_gender == "female" else DEFAULT_MALE_BODY_ID,
				normalized_gender,
				BODY_MOVEMENT_DEFAULT,
				DEFAULT_SKIN_TONE
			)
		else:
			var category := str(layer.get("category", ""))
			var appearance_id := str(layer.get("id", ""))
			if layer.has("tint"):
				frames = get_tinted_part_frames(
					category,
					appearance_id,
					normalized_gender,
					BODY_MOVEMENT_DEFAULT,
					layer.get("tint", Color.WHITE) as Color,
					bool(layer.get("preserve", false))
				)
			else:
				frames = get_part_frames(category, appearance_id, normalized_gender)
		_blend_idle_front_frame(icon_image, frames)

	var used_rect := icon_image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		_cosmetic_item_icon_cache[cache_key] = null
		return null
	var padded_position := Vector2i(
		maxi(used_rect.position.x - 2, 0),
		maxi(used_rect.position.y - 2, 0)
	)
	var padded_end := Vector2i(
		mini(used_rect.end.x + 2, icon_image.get_width()),
		mini(used_rect.end.y + 2, icon_image.get_height())
	)
	var cropped_image := icon_image.get_region(Rect2i(padded_position, padded_end - padded_position))
	var icon_texture := ImageTexture.create_from_image(cropped_image)
	_cosmetic_item_icon_cache[cache_key] = icon_texture
	return icon_texture


static func _blend_idle_front_frame(target: Image, frames: SpriteFrames) -> void:
	if target == null or frames == null or not frames.has_animation(&"idle_down"):
		return
	if frames.get_frame_count(&"idle_down") <= 0:
		return
	var texture := frames.get_frame_texture(&"idle_down", 0)
	var source := _get_texture_image(texture)
	if source == null:
		return
	var copy_size := Vector2i(
		mini(source.get_width(), target.get_width()),
		mini(source.get_height(), target.get_height())
	)
	target.blend_rect(source, Rect2i(Vector2i.ZERO, copy_size), Vector2i.ZERO)


static func get_default_hair_color(gender: String = "") -> String:
	return DEFAULT_FEMALE_HAIR_COLOR if normalize_gender(gender) == "female" else DEFAULT_MALE_HAIR_COLOR


static func get_default_eye_color(gender: String = "") -> String:
	return DEFAULT_FEMALE_EYE_COLOR if normalize_gender(gender) == "female" else DEFAULT_MALE_EYE_COLOR


static func resolve_hair_color(color_text: String, gender: String = "") -> String:
	var normalized_color := normalize_legacy_optional_text(color_text)
	if normalized_color == "" or normalized_color.to_lower() == LEGACY_DEFAULT_HAIR_COLOR:
		return get_default_hair_color(gender)
	return normalized_color


static func resolve_eye_color(color_text: String, gender: String = "") -> String:
	var normalized_color := normalize_legacy_optional_text(color_text)
	if normalized_color == "" or normalized_color.to_lower() == LEGACY_DEFAULT_EYE_COLOR:
		return get_default_eye_color(gender)
	return normalized_color


static func resolve_body_model_id(body_id: String, gender: String = "") -> String:
	var normalized_gender := normalize_gender(gender)
	var normalized_body_id := _normalize_body_id(body_id)
	if normalized_body_id in [
		"Gen4_Base_M_Tan",
		"Gen4_Base_M_Dark",
		"Gen4_Base_F_Tan",
		"Gen4_Base_F_Dark",
	]:
		return DEFAULT_FEMALE_BODY_ID if normalized_gender == "female" else DEFAULT_MALE_BODY_ID
	return normalized_body_id


static func resolve_skin_tone(body_id: String, color_text: String, gender: String = "") -> String:
	var normalized_color := normalize_legacy_optional_text(color_text).to_lower()
	var normalized_body_id := _normalize_body_id(body_id)
	if normalized_color == "" or normalized_color in ["#ffffff", "#ffffffff"]:
		if normalized_body_id in ["Gen4_Base_M_Tan", "Gen4_Base_F_Tan"]:
			return LEGACY_TAN_SKIN_TONE
		if normalized_body_id in ["Gen4_Base_M_Dark", "Gen4_Base_F_Dark"]:
			return LEGACY_DARK_SKIN_TONE
		return DEFAULT_SKIN_TONE
	return normalized_color


static func get_available_body_model_ids(gender: String = "") -> Array[String]:
	var ids := get_available_body_ids(gender)
	for legacy_id: String in [
		"Gen4_Base_M_Tan",
		"Gen4_Base_M_Dark",
		"Gen4_Base_F_Tan",
		"Gen4_Base_F_Dark",
	]:
		ids.erase(legacy_id)
	return ids


static func body_supports_layered_parts(body_id: String, gender: String = "") -> bool:
	var normalized_gender: String = normalize_gender(gender)
	var normalized_body_id: String = resolve_body_model_id(body_id, normalized_gender)
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
		FACIAL_HAIR_CATEGORY:
			return DEFAULT_FEMALE_FACIAL_HAIR_ID if normalized_gender == "female" else DEFAULT_MALE_FACIAL_HAIR_ID
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
		"facialhair", "beard", "facialhairstyle":
			return FACIAL_HAIR_CATEGORY
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


static func is_free_part_id(category: String, part_id: String) -> bool:
	var normalized_category: String = normalize_part_category(category)
	var normalized_part_id: String = part_id.strip_edges()
	if normalized_part_id == "":
		return true
	return normalized_part_id == get_default_part_id(normalized_category, "male") \
		or normalized_part_id == get_default_part_id(normalized_category, "female")


static func is_tintable_part(category: String, part_id: String) -> bool:
	var normalized_category: String = normalize_part_category(category)
	var normalized_part_id: String = part_id.strip_edges()
	if normalized_category == HAIR_CATEGORY or normalized_category == FACIAL_HAIR_CATEGORY:
		return normalized_part_id != "Aether_Blossom_Hair"
	if normalized_category == FACEGEAR_CATEGORY:
		return normalized_part_id in ["Adinho_Glasses_Chroma", "Aether_Blossom_Earrings_Chroma"]
	if normalized_category == TOP_CATEGORY:
		return normalized_part_id == "Adinho_Shirt_Chroma"
	if normalized_category == BOTTOM_CATEGORY:
		return normalized_part_id == "Adinho_Trousers_Chroma"
	if normalized_category == SHOES_CATEGORY:
		return normalized_part_id in ["Adinho_Shoes_Chroma", "Aether_Blossom_Shoes_Chroma"]
	return false


static func normalize_hex_color_code(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if normalized.begins_with("#"):
		normalized = normalized.substr(1)
	if normalized.length() != 6:
		return ""
	for index: int in normalized.length():
		var character := normalized.substr(index, 1)
		if not "0123456789abcdef".contains(character):
			return ""
	return "#%s" % normalized


static func get_directional_part_z_index(
	category: String,
	part_id: String,
	direction: String,
	default_z_index: int
) -> int:
	if (
		normalize_part_category(category) == FACEGEAR_CATEGORY
		and part_id.strip_edges() in [
			"Aether_Blossom_Earrings",
			"Aether_Blossom_Earrings_Chroma",
		]
		and direction.strip_edges().to_lower() == "up"
	):
		return 5
	return default_z_index


static func get_eyebrows_for_hair(hair_id: String, gender: String = "") -> String:
	var normalized_hair_id := hair_id.strip_edges()
	if normalized_hair_id == "":
		return ""
	var mapping_key := "%s:%s" % [normalize_gender(gender), normalized_hair_id]
	return str(EYEBROWS_BY_HAIR_ID.get(mapping_key, ""))


static func serialize_part_id(part_id: String) -> String:
	var normalized_part_id := normalize_legacy_optional_text(part_id)
	return UNEQUIPPED_PART_ID if _is_empty_presence_part_id(normalized_part_id) else normalized_part_id


static func deserialize_part_id(part_id: String) -> String:
	var normalized_part_id := normalize_legacy_optional_text(part_id)
	if _is_empty_presence_part_id(normalized_part_id):
		return ""
	return normalized_part_id


static func resolve_hair_render_id(hair_id: String) -> String:
	var normalized_hair_id := deserialize_part_id(hair_id)
	return BASE_HAIR_ID if normalized_hair_id == "" else normalized_hair_id


static func _is_empty_presence_part_id(part_id: String) -> bool:
	var normalized_part_id: String = part_id.strip_edges().to_lower()
	return normalized_part_id == "" or normalized_part_id == UNEQUIPPED_PART_ID


static func normalize_legacy_optional_text(value: Variant) -> String:
	if value == null:
		return ""
	var normalized := str(value).strip_edges()
	return "" if normalized.to_lower() in LEGACY_NULL_TEXT_VALUES else normalized


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

	var texture := _load_part_texture_for_movement(
		normalized_category,
		normalized_part_id,
		normalized_gender,
		normalized_movement_style
	)
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

	var tinted_frames: SpriteFrames = _build_tinted_sprite_frames(
		base_frames,
		tint_color,
		preserve_luminance and normalized_part_id != BASE_HAIR_ID
	)
	if normalized_category == HAIR_CATEGORY and normalized_part_id != BASE_HAIR_ID:
		tinted_frames = _add_base_hair_underlay(
			tinted_frames,
			normalized_gender,
			normalized_movement_style,
			tint_color
		)
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

	var texture := _load_body_texture_for_movement(
		normalized_body_id,
		normalized_gender,
		normalized_movement_style
	)
	var fallback_body_id: String = _get_fallback_body_id(normalized_gender)
	if texture == null and normalized_body_id != fallback_body_id:
		texture = _load_body_texture_for_movement(fallback_body_id, normalized_gender, normalized_movement_style)
	if texture == null:
		_body_frames_cache[cache_key] = null
		return null

	var sprite_frames: SpriteFrames = _build_sprite_frames(texture)
	_body_frames_cache[cache_key] = sprite_frames
	return sprite_frames


static func get_skin_tinted_body_frames(
	body_id: String,
	gender: String = "",
	movement_style: String = BODY_MOVEMENT_DEFAULT,
	skin_tone: String = DEFAULT_SKIN_TONE
) -> SpriteFrames:
	var normalized_gender := normalize_gender(gender)
	var source_body_id := _normalize_body_id(body_id)
	var normalized_body_id := resolve_body_model_id(source_body_id, normalized_gender)
	if normalized_body_id == "":
		normalized_body_id = _get_fallback_body_id(normalized_gender)
	var normalized_movement_style := _normalize_movement_style(movement_style)
	var resolved_skin_tone := resolve_skin_tone(source_body_id, skin_tone, normalized_gender)
	var tint_color := Color.from_string(resolved_skin_tone, Color(DEFAULT_SKIN_TONE))

	var base_frames := get_body_frames(normalized_body_id, normalized_gender, normalized_movement_style)
	if base_frames == null or not body_supports_layered_parts(normalized_body_id, normalized_gender):
		return base_frames
	if resolved_skin_tone.to_lower() == DEFAULT_SKIN_TONE:
		return base_frames

	var cache_key := "%s:%s:%s:%s" % [
		normalized_gender,
		normalized_body_id,
		normalized_movement_style,
		tint_color.to_html(false),
	]
	if _skin_tinted_body_frames_cache.has(cache_key):
		var cached_value: Variant = _skin_tinted_body_frames_cache[cache_key]
		if cached_value is SpriteFrames:
			return cached_value as SpriteFrames
		return null

	var tinted_frames := _build_skin_tinted_sprite_frames(base_frames, tint_color)
	_skin_tinted_body_frames_cache[cache_key] = tinted_frames
	return tinted_frames


static func normalize_movement_style(movement_style: String) -> String:
	var normalized: String = movement_style.strip_edges().to_lower()
	if normalized == BODY_MOVEMENT_RUN:
		return BODY_MOVEMENT_RUN
	if normalized == BODY_MOVEMENT_SURF_FISH or normalized == "surf-fish":
		return BODY_MOVEMENT_SURF_FISH
	if normalized == BODY_MOVEMENT_FISH or normalized == "fishing":
		return BODY_MOVEMENT_FISH
	if normalized == BODY_MOVEMENT_RIDE \
			or normalized == BODY_MOVEMENT_SURF \
			or normalized == BODY_MOVEMENT_MOUNT \
			or normalized == "riding":
		return BODY_MOVEMENT_RIDE
	return BODY_MOVEMENT_DEFAULT


static func resolve_layer_movement_style(movement_style: String, _category: String = BODY_CATEGORY) -> String:
	var normalized_style := normalize_movement_style(movement_style)
	return BODY_MOVEMENT_FISH \
		if normalized_style == BODY_MOVEMENT_SURF_FISH \
		else normalized_style


static func _normalize_movement_style(movement_style: String) -> String:
	return normalize_movement_style(movement_style)


static func _load_body_texture_for_movement(body_id: String, gender: String, movement_style: String) -> Texture2D:
	var normalized_movement_style := resolve_layer_movement_style(movement_style, BODY_CATEGORY)
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
	var normalized_category := normalize_part_category(category)
	var normalized_movement_style := resolve_layer_movement_style(movement_style, category)
	if normalized_movement_style != BODY_MOVEMENT_DEFAULT:
		var movement_part_id: String = _get_movement_body_id(part_id, normalized_movement_style)
		var movement_texture: Texture2D = _load_part_texture(category, movement_part_id, gender)
		if movement_texture != null:
			return movement_texture
		if MOVEMENT_POSE_PART_CATEGORIES.has(normalized_category):
			var default_part_id := get_default_part_id(normalized_category, gender)
			var default_movement_part_id := _get_movement_body_id(
				default_part_id,
				normalized_movement_style
			)
			var default_movement_texture := _load_part_texture(
				normalized_category,
				default_movement_part_id,
				gender
			)
			if default_movement_texture != null:
				return default_movement_texture
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


static func _add_base_hair_underlay(
	hairstyle_frames: SpriteFrames,
	gender: String,
	movement_style: String,
	hair_color: Color
) -> SpriteFrames:
	if hairstyle_frames == null:
		return null

	var base_hair_frames := get_part_frames(
		HAIR_CATEGORY,
		BASE_HAIR_ID,
		gender,
		movement_style
	)
	if base_hair_frames == null:
		return hairstyle_frames

	var tinted_base_hair_frames := _build_tinted_sprite_frames(
		base_hair_frames,
		hair_color,
		false
	)
	return _build_layered_sprite_frames(tinted_base_hair_frames, hairstyle_frames)


static func _build_layered_sprite_frames(
	underlay_frames: SpriteFrames,
	overlay_frames: SpriteFrames
) -> SpriteFrames:
	if underlay_frames == null:
		return overlay_frames
	if overlay_frames == null:
		return underlay_frames

	var sprite_frames := SpriteFrames.new()
	if sprite_frames.has_animation(&"default"):
		sprite_frames.remove_animation(&"default")

	for animation_name_text: String in overlay_frames.get_animation_names():
		var animation_name := StringName(animation_name_text)
		sprite_frames.add_animation(animation_name)
		sprite_frames.set_animation_speed(
			animation_name,
			overlay_frames.get_animation_speed(animation_name)
		)
		sprite_frames.set_animation_loop(
			animation_name,
			overlay_frames.get_animation_loop(animation_name)
		)

		var overlay_frame_count := overlay_frames.get_frame_count(animation_name)
		var underlay_frame_count := (
			underlay_frames.get_frame_count(animation_name)
			if underlay_frames.has_animation(animation_name)
			else 0
		)
		for frame_index: int in range(overlay_frame_count):
			var overlay_texture := overlay_frames.get_frame_texture(animation_name, frame_index)
			var layered_texture := overlay_texture
			if frame_index < underlay_frame_count:
				layered_texture = _make_layered_texture(
					underlay_frames.get_frame_texture(animation_name, frame_index),
					overlay_texture
				)
			sprite_frames.add_frame(
				animation_name,
				layered_texture,
				overlay_frames.get_frame_duration(animation_name, frame_index)
			)

	return sprite_frames


static func _make_layered_texture(
	underlay_texture: Texture2D,
	overlay_texture: Texture2D
) -> Texture2D:
	var underlay_image := _get_texture_image(underlay_texture)
	var overlay_image := _get_texture_image(overlay_texture)
	if underlay_image == null or overlay_image == null:
		return overlay_texture
	if underlay_image.get_size() != overlay_image.get_size():
		return overlay_texture

	var layered_image := underlay_image.duplicate()
	if layered_image.get_format() != Image.FORMAT_RGBA8:
		layered_image.convert(Image.FORMAT_RGBA8)
	var source_image := overlay_image
	if source_image.get_format() != Image.FORMAT_RGBA8:
		source_image = overlay_image.duplicate()
		source_image.convert(Image.FORMAT_RGBA8)
	layered_image.blend_rect(
		source_image,
		Rect2i(Vector2i.ZERO, source_image.get_size()),
		Vector2i.ZERO
	)
	return ImageTexture.create_from_image(layered_image)


static func _build_skin_tinted_sprite_frames(base_frames: SpriteFrames, skin_tone: Color) -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	if sprite_frames.has_animation(&"default"):
		sprite_frames.remove_animation(&"default")

	for animation_name_text: String in base_frames.get_animation_names():
		var animation_name := StringName(animation_name_text)
		if not sprite_frames.has_animation(animation_name):
			sprite_frames.add_animation(animation_name)
		sprite_frames.set_animation_speed(animation_name, base_frames.get_animation_speed(animation_name))
		sprite_frames.set_animation_loop(animation_name, base_frames.get_animation_loop(animation_name))

		var frame_count := base_frames.get_frame_count(animation_name)
		for frame_index: int in range(frame_count):
			var frame_texture := base_frames.get_frame_texture(animation_name, frame_index)
			var frame_duration := base_frames.get_frame_duration(animation_name, frame_index)
			sprite_frames.add_frame(
				animation_name,
				_make_skin_tinted_texture(frame_texture, skin_tone),
				frame_duration
			)

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
	var minimum_luminance := 1.0
	var maximum_luminance := 0.0
	if preserve_luminance:
		for y: int in range(height):
			for x: int in range(width):
				var range_pixel := source_image.get_pixel(x, y)
				if range_pixel.a <= 0.001:
					continue
				var range_luminance := _color_luminance(range_pixel)
				if range_luminance <= 0.035:
					continue
				minimum_luminance = minf(minimum_luminance, range_luminance)
				maximum_luminance = maxf(maximum_luminance, range_luminance)

	for y: int in range(height):
		for x: int in range(width):
			var source_pixel: Color = source_image.get_pixel(x, y)
			var alpha: float = source_pixel.a * tint_color.a
			if source_pixel.a <= 0.001:
				tinted_image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue
			if preserve_luminance:
				var luminance := _color_luminance(source_pixel)
				if luminance <= 0.035:
					tinted_image.set_pixel(x, y, Color(
						source_pixel.r,
						source_pixel.g,
						source_pixel.b,
						alpha
					))
					continue
				var luminance_span := maxf(maximum_luminance - minimum_luminance, 0.001)
				var normalized_luminance := clampf(
					(luminance - minimum_luminance) / luminance_span,
					0.0,
					1.0
				)
				var shade_value: float = lerpf(0.38, 1.18, pow(normalized_luminance, 0.9))
				var tinted_value: float = clampf(tint_color.v * shade_value, 0.0, 1.0)
				tinted_image.set_pixel(x, y, Color.from_hsv(tint_color.h, tint_color.s, tinted_value, alpha))
			else:
				tinted_image.set_pixel(x, y, Color(tint_color.r, tint_color.g, tint_color.b, alpha))

	return ImageTexture.create_from_image(tinted_image)


static func _make_skin_tinted_texture(texture: Texture2D, skin_tone: Color) -> Texture2D:
	if texture == null:
		return null

	var source_image := _get_texture_image(texture)
	if source_image == null:
		return texture

	var width := source_image.get_width()
	var height := source_image.get_height()
	var minimum_luminance := 1.0
	var maximum_luminance := 0.0
	for y: int in range(height):
		for x: int in range(width):
			var range_pixel := source_image.get_pixel(x, y)
			if not _is_skin_palette_pixel(range_pixel):
				continue
			var range_luminance := _color_luminance(range_pixel)
			minimum_luminance = minf(minimum_luminance, range_luminance)
			maximum_luminance = maxf(maximum_luminance, range_luminance)

	if maximum_luminance <= 0.0:
		return texture

	var tinted_image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var luminance_span := maxf(maximum_luminance - minimum_luminance, 0.001)
	for y: int in range(height):
		for x: int in range(width):
			var source_pixel := source_image.get_pixel(x, y)
			if source_pixel.a <= 0.001:
				tinted_image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue
			if not _is_skin_palette_pixel(source_pixel):
				tinted_image.set_pixel(x, y, source_pixel)
				continue

			var normalized_luminance := clampf(
				(_color_luminance(source_pixel) - minimum_luminance) / luminance_span,
				0.0,
				1.0
			)
			var shade_value := lerpf(0.52, 1.24, pow(normalized_luminance, 0.9))
			var tinted_value := clampf(skin_tone.v * shade_value, 0.0, 1.0)
			tinted_image.set_pixel(
				x,
				y,
				Color.from_hsv(skin_tone.h, skin_tone.s, tinted_value, source_pixel.a * skin_tone.a)
			)

	return ImageTexture.create_from_image(tinted_image)


static func _is_skin_palette_pixel(color: Color) -> bool:
	if color.a <= 0.001:
		return false
	if _color_luminance(color) <= 0.035:
		return false
	return color.r > color.g * 1.04 and color.g >= color.b * 0.98


static func _color_luminance(color: Color) -> float:
	return clampf(
		(color.r * 0.2126) + (color.g * 0.7152) + (color.b * 0.0722),
		0.0,
		1.0
	)


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
	var normalized_body_id := normalize_legacy_optional_text(body_id)
	var normalized: String = get_presence_body_base_id(normalized_body_id).strip_edges().replace("\\", "/")
	var normalized_parts: Array[String] = []
	for part: String in normalized.split("/", false):
		var normalized_part: String = part.strip_edges()
		if normalized_part == "" or normalized_part == "." or normalized_part == "..":
			return ""
		normalized_parts.append(normalized_part)
	return "/".join(normalized_parts)
