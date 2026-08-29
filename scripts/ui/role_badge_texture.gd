extends RefCounted

class_name RoleBadgeTexture

const ROLE_BADGE_PATHS := {
	"gamemaster": "res://assets/ui/gamemaster_emblem_readable.png",
	"developer": "res://assets/ui/developer_emblem_teal.png",
	"moderator": "res://assets/ui/moderator_emblem.png",
}

static var _texture_cache: Dictionary = {}


static func has_role_badge(role_id: String) -> bool:
	return ROLE_BADGE_PATHS.has(role_id.strip_edges().to_lower())


static func get_role_badge_texture(role_id: String) -> Texture2D:
	var normalized_role_id := role_id.strip_edges().to_lower()
	if _texture_cache.has(normalized_role_id):
		return _texture_cache[normalized_role_id] as Texture2D

	var path := str(ROLE_BADGE_PATHS.get(normalized_role_id, ""))
	if path.is_empty():
		return null
	var texture := _load_texture(path)
	if texture != null:
		_texture_cache[normalized_role_id] = texture
	return texture


static func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path, "Texture2D"):
		var imported_texture := ResourceLoader.load(path, "Texture2D") as Texture2D
		if imported_texture != null:
			return imported_texture

	if not FileAccess.file_exists(path):
		return null

	# A newly pulled PNG can exist before an open editor has generated its import metadata.
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)
