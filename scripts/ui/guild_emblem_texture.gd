extends RefCounted

class_name GuildEmblemTexture

const EMBLEM_SIZE := 32
const EMBLEM_PIXEL_COUNT := EMBLEM_SIZE * EMBLEM_SIZE


static func create_texture(emblem: Dictionary) -> Texture2D:
	var image := _image_from_emblem(emblem)
	return ImageTexture.create_from_image(image) if image != null else null


static func create_nameplate_texture(emblem: Dictionary) -> Texture2D:
	var image := _image_from_emblem(emblem)
	if image == null:
		return null
	var used_rect := image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return null
	var crop_size := maxi(used_rect.size.x, used_rect.size.y)
	var thumbnail := Image.create(crop_size, crop_size, false, Image.FORMAT_RGBA8)
	thumbnail.blit_rect(
		image,
		used_rect,
		Vector2i(
			(crop_size - used_rect.size.x) / 2,
			(crop_size - used_rect.size.y) / 2
		)
	)
	return ImageTexture.create_from_image(thumbnail)


static func _image_from_emblem(emblem: Dictionary) -> Image:
	var palette_value: Variant = emblem.get("palette", [])
	var pixels_value: Variant = emblem.get("pixels", [])
	if not palette_value is Array or not pixels_value is Array:
		return null

	var palette: Array = palette_value as Array
	var pixels: Array = pixels_value as Array
	if palette.is_empty() or pixels.size() != EMBLEM_PIXEL_COUNT:
		return null

	var image := Image.create(EMBLEM_SIZE, EMBLEM_SIZE, false, Image.FORMAT_RGBA8)
	var has_visible_pixel := false
	for pixel_index: int in range(EMBLEM_PIXEL_COUNT):
		var color_index := int(pixels[pixel_index])
		var color := Color(0, 0, 0, 0)
		if color_index >= 0 and color_index < palette.size():
			color = Color(str(palette[color_index]))
			has_visible_pixel = has_visible_pixel or color.a > 0.0
		image.set_pixel(pixel_index % EMBLEM_SIZE, pixel_index / EMBLEM_SIZE, color)

	if not has_visible_pixel:
		return null
	return image
