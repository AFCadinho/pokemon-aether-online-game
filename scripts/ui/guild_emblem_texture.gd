extends RefCounted

class_name GuildEmblemTexture

const EMBLEM_SIZE := 32
const EMBLEM_PIXEL_COUNT := EMBLEM_SIZE * EMBLEM_SIZE


static func create_texture(emblem: Dictionary) -> Texture2D:
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
	return ImageTexture.create_from_image(image)
