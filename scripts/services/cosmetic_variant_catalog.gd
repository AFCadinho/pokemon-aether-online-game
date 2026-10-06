extends RefCounted

class_name CosmeticVariantCatalog

const PATH := "res://data/cosmetic_variants.json"
static var _catalog: Dictionary = {}


static func _data() -> Dictionary:
	if _catalog.is_empty():
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if value is Dictionary:
			_catalog = value as Dictionary
	return _catalog


static func part_definition(category: String, logical_id: String) -> Dictionary:
	return _data().get("parts", {}).get(category, {}).get(logical_id, {}) as Dictionary


static func render_part_id(category: String, logical_id: String, gender: String) -> String:
	var definition := part_definition(category, logical_id)
	if definition.is_empty():
		return logical_id
	# An unsupported variant stays absent; never borrow another model's artwork.
	return str(definition.get("render_variants", {}).get(gender, ""))


static func logical_part_id(category: String, sprite_id: String, gender: String) -> String:
	var definitions: Dictionary = _data().get("parts", {}).get(category, {})
	for logical_id: String in definitions:
		if str(definitions[logical_id].get("render_variants", {}).get(gender, "")) == sprite_id:
			return logical_id
	return sprite_id


static func item_definition(item_id: String) -> Dictionary:
	return _data().get("items", {}).get(item_id, {}) as Dictionary


static func icon_layers(item_id: String, gender: String) -> Array[Dictionary]:
	var definition := item_definition(item_id)
	var layers: Array[Dictionary] = []
	if bool(definition.get("bundle", false)):
		layers.append({"kind": "body"})
	for value: Variant in definition.get("layers", []):
		var part: Dictionary = value as Dictionary
		var genders: Array = part.get("genders", [])
		if genders.is_empty() or genders.has(gender):
			layers.append({"category": part["category"], "id": part["id"]})
	var order: Array[String] = ["body", "cape", "bottom", "shoes", "top", "hair", "facial_hair", "headgear", "facegear"]
	layers.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return order.find(str(left.get("category", left.get("kind", "")))) < order.find(str(right.get("category", right.get("kind", ""))))
	)
	return layers
