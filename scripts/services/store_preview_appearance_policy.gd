extends RefCounted

# Presentation only. No purchase contents, unlocks or saved appearance state.
const PATH := "res://data/store_preview_appearance.json"
const MODES: Array[String] = ["player", "neutral", "hidden", "custom"]
static var _configuration: Dictionary = {}


static func configuration() -> Dictionary:
	if _configuration.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_configuration = parsed as Dictionary
	return _configuration


static func resolve_hair(
	item_id: String,
	context: String,
	gender: String,
	headgear_id: String,
	includes_hair: bool,
	current_hair: String,
	current_color: String,
	player_hair_available: bool = false,
	config: Dictionary = {}
) -> Dictionary:
	# Included product hair always wins, including its fixed/Chroma colour.
	if includes_hair:
		return {"hair": current_hair, "hair_color": current_color}
	var rules: Dictionary = configuration() if config.is_empty() else config
	var normalized_gender := "female" if gender == "female" else "male"
	var neutral: Dictionary = rules.get("neutral_hair", {}).get(normalized_gender, {})
	var defaults: Dictionary = rules.get("defaults", {})
	var outfit_rule: Dictionary = rules.get("outfits", {}).get(item_id.trim_suffix("-bound"), {})
	var headgear_rule: Dictionary = rules.get("headgear", {}).get(headgear_id, {})
	var mode := str(defaults.get(context, "neutral" if context == "card" else "player"))
	var selected_rule: Dictionary = {}
	if outfit_rule.has(context):
		selected_rule = outfit_rule
		mode = str(outfit_rule[context])
	elif headgear_rule.has(context):
		selected_rule = headgear_rule
		mode = str(headgear_rule[context])
		# An explicitly bald player stays bald under ordinary compatibility rules.
		if mode == "neutral" and player_hair_available and current_hair.is_empty():
			mode = "player"
	if not MODES.has(mode):
		mode = "neutral" if context == "card" else "player"
	if mode == "hidden":
		return {"hair": "", "hair_color": current_color}
	if mode == "player" and player_hair_available and context == "detail":
		return {"hair": current_hair, "hair_color": current_color}
	var profile: Dictionary = neutral
	if mode == "custom":
		profile = selected_rule.get("hair", {}).get(normalized_gender, neutral)
	return {
		"hair": str(profile.get("id", "Hair")),
		"hair_color": str(profile.get("color", "#6b4632" if normalized_gender == "female" else "#5a3728")),
	}


static func decorate_card_layers(item_id: String, gender: String, layers: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = layers.duplicate(true)
	var is_outfit := item_id.trim_suffix("-bound").ends_with("-outfit")
	var includes_hair := false
	var headgear := ""
	for layer: Dictionary in result:
		is_outfit = is_outfit or str(layer.get("kind", "")) == "body"
		includes_hair = includes_hair or str(layer.get("category", "")) == "hair"
		if str(layer.get("category", "")) == "headgear":
			headgear = str(layer.get("id", ""))
	if not is_outfit or includes_hair:
		return result
	var hair := resolve_hair(item_id, "card", gender, headgear, false, "", "")
	if str(hair["hair"]).is_empty():
		return result
	var hair_layer := {"category": "hair", "id": hair["hair"], "tint": Color(str(hair["hair_color"])), "preserve": true}
	# Keep the authored order, inserting hair beneath beard/headgear/facegear.
	var index := result.size()
	for position: int in range(result.size()):
		if str(result[position].get("category", "")) in ["facial_hair", "headgear", "facegear"]:
			index = position
			break
	result.insert(index, hair_layer)
	return result
