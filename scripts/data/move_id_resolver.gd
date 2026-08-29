extends RefCounted

class_name MoveIdResolver

const MOVE_VALUE_KEYS: Array[String] = ["id", "move", "moveId", "move_id", "name"]


static func normalize(value: String) -> String:
	return value.strip_edges().to_lower().replace("_", "-").replace(" ", "-")


static func compact(value: String) -> String:
	var result := ""
	for byte: int in value.strip_edges().to_lower().to_utf8_buffer():
		if (byte >= 97 and byte <= 122) or (byte >= 48 and byte <= 57):
			result += String.chr(byte)
	return result


static func equivalent(left: String, right: String) -> bool:
	var left_compact := compact(left)
	return left_compact != "" and left_compact == compact(right)


static func value_matches(value: Variant, expected_move_id: String) -> bool:
	if value is Dictionary:
		var move_data := value as Dictionary
		for key: String in MOVE_VALUE_KEYS:
			if move_data.has(key) and equivalent(str(move_data.get(key, "")), expected_move_id):
				return true
		return false
	return equivalent(str(value), expected_move_id)
