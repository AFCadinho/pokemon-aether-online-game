class_name MoveDisplayType

const HIDDEN_POWER_TYPES := {
	"bug": true,
	"dark": true,
	"dragon": true,
	"electric": true,
	"fighting": true,
	"fire": true,
	"flying": true,
	"ghost": true,
	"grass": true,
	"ground": true,
	"ice": true,
	"poison": true,
	"psychic": true,
	"rock": true,
	"steel": true,
	"water": true,
}

const IDENTITY_KEYS := ["variantId", "variant_id", "id", "move", "moveId", "move_id", "name"]
const TYPE_KEYS := ["hiddenPowerType", "hidden_power_type"]
const MOVE_TYPE_KEYS := ["type", "moveType", "move_type"]


static func resolve(move_data: Dictionary) -> String:
	var sources: Array[Dictionary] = [move_data]
	var metadata_value: Variant = move_data.get("metadata", move_data.get("data", {}))
	if metadata_value is Dictionary:
		sources.append(metadata_value as Dictionary)

	if _is_hidden_power(sources):
		for source: Dictionary in sources:
			for key: String in TYPE_KEYS:
				var explicit_type := _valid_hidden_power_type(source.get(key, ""))
				if explicit_type != "":
					return explicit_type
		for source: Dictionary in sources:
			for key: String in IDENTITY_KEYS:
				var identifier_type := _hidden_power_type_from_identifier(source.get(key, ""))
				if identifier_type != "":
					return identifier_type

	for source: Dictionary in sources:
		for key: String in MOVE_TYPE_KEYS:
			var move_type := str(source.get(key, "")).strip_edges()
			if move_type != "":
				return move_type

	return ""


static func _is_hidden_power(sources: Array[Dictionary]) -> bool:
	for source: Dictionary in sources:
		for key: String in IDENTITY_KEYS:
			var compact_identifier := _compact_identifier(source.get(key, ""))
			if compact_identifier == "hiddenpower":
				return true
			if _hidden_power_type_from_compact_identifier(compact_identifier) != "":
				return true
	return false


static func _hidden_power_type_from_identifier(value: Variant) -> String:
	return _hidden_power_type_from_compact_identifier(_compact_identifier(value))


static func _hidden_power_type_from_compact_identifier(compact_identifier: String) -> String:
	if not compact_identifier.begins_with("hiddenpower"):
		return ""
	var type_suffix := compact_identifier.trim_prefix("hiddenpower")
	if type_suffix.ends_with("60"):
		type_suffix = type_suffix.trim_suffix("60")
	return _valid_hidden_power_type(type_suffix)


static func _valid_hidden_power_type(value: Variant) -> String:
	var normalized_type := str(value).strip_edges().to_lower()
	return normalized_type if HIDDEN_POWER_TYPES.has(normalized_type) else ""


static func _compact_identifier(value: Variant) -> String:
	return str(value).strip_edges().to_lower().replace("-", "").replace("_", "").replace(" ", "")
