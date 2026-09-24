extends RefCounted

const INSTALLATION_FILE_PATH := "user://installation_id.txt"


static func get_or_create() -> String:
	if FileAccess.file_exists(INSTALLATION_FILE_PATH):
		var existing := FileAccess.get_file_as_string(INSTALLATION_FILE_PATH).strip_edges()
		if _is_valid(existing):
			return existing

	var random_bytes := Crypto.new().generate_random_bytes(32)
	if random_bytes.size() != 32:
		return ""
	var installation_id := random_bytes.hex_encode()
	var file := FileAccess.open(INSTALLATION_FILE_PATH, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(installation_id)
	file.close()
	return installation_id


static func _is_valid(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true
