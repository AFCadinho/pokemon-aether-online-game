extends RefCounted

class_name RoleBadgeTexture

const GM_BADGE_PATH := "res://assets/ui/gamemaster_emblem_readable.png"

static var _gm_badge_texture: Texture2D


static func get_gm_badge_texture() -> Texture2D:
	if _gm_badge_texture != null:
		return _gm_badge_texture

	if ResourceLoader.exists(GM_BADGE_PATH, "Texture2D"):
		_gm_badge_texture = ResourceLoader.load(GM_BADGE_PATH, "Texture2D") as Texture2D
		if _gm_badge_texture != null:
			return _gm_badge_texture

	if not FileAccess.file_exists(GM_BADGE_PATH):
		return null

	# A newly pulled PNG can exist before an open editor has generated its import metadata.
	var image := Image.load_from_file(ProjectSettings.globalize_path(GM_BADGE_PATH))
	if image == null or image.is_empty():
		return null
	_gm_badge_texture = ImageTexture.create_from_image(image)
	return _gm_badge_texture
