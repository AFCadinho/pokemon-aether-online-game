extends RefCounted

class_name PokemonAssets

const HOME_SPRITE_PATH := "res://assets/sprites/pokemon/pokemon_home/%s.png"
const SHINY_HOME_SPRITE_PATH := "res://assets/sprites/pokemon/pokemon_home_shiny/%s.png"
const FRONT_FRAME_PATH := "res://assets/sprites/pokemon/front/%s/frame_000.png"
const UNKNOWN_HOME_SPRITE_PATH := "res://assets/sprites/pokemon/pokemon_home/unknown.png"
const PARTY_ICON_CROP_PADDING := 4
const PARTY_ICON_ALPHA_THRESHOLD := 0.01

static var party_icon_cache: Dictionary = {}

static func load_home_sprite(species: String, is_shiny: bool = false) -> Texture2D:
	if is_shiny:
		for sprite_name in _get_home_sprite_names(species):
			var shiny_path := SHINY_HOME_SPRITE_PATH % sprite_name
			if ResourceLoader.exists(shiny_path):
				return load(shiny_path)

	for sprite_name in _get_home_sprite_names(species):
		var path := HOME_SPRITE_PATH % sprite_name
		if ResourceLoader.exists(path):
			return load(path)

	return null

static func _get_home_sprite_names(species: String) -> Array[String]:
	var names: Array[String] = [
		species,
		species.replace(" ", "-"),
		species.replace(" ", "-").replace("-Mega-X", "-Megax").replace("-Mega-Y", "-Megay"),
	]

	return names

static func load_party_icon(species: String, is_shiny: bool = false) -> Texture2D:
	var cache_key := "%s|%s" % [species, str(is_shiny)]
	var cached_icon: Variant = party_icon_cache.get(cache_key)
	if cached_icon is Texture2D:
		return cached_icon

	var icon := load_home_sprite(species, is_shiny)
	if icon != null:
		var cropped_icon := _crop_icon_to_visible_bounds(icon)
		party_icon_cache[cache_key] = cropped_icon
		return cropped_icon

	var unknown_icon := load_unknown_icon()
	party_icon_cache[cache_key] = unknown_icon
	return unknown_icon

static func load_unknown_icon() -> Texture2D:
	if ResourceLoader.exists(UNKNOWN_HOME_SPRITE_PATH):
		return load(UNKNOWN_HOME_SPRITE_PATH)
	return null

static func _crop_icon_to_visible_bounds(texture: Texture2D) -> Texture2D:
	var image: Image = texture.get_image()
	if image == null:
		return texture

	var bounds: Rect2i = _get_visible_bounds(image)
	if bounds.size == Vector2i.ZERO:
		return texture

	var padded_bounds: Rect2i = _pad_bounds(bounds, image.get_size(), PARTY_ICON_CROP_PADDING)
	var cropped_image: Image = image.get_region(padded_bounds)
	return ImageTexture.create_from_image(cropped_image)

static func _get_visible_bounds(image: Image) -> Rect2i:
	var min_x: int = image.get_width()
	var min_y: int = image.get_height()
	var max_x: int = -1
	var max_y: int = -1

	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= PARTY_ICON_ALPHA_THRESHOLD:
				continue

			min_x = min(min_x, x)
			min_y = min(min_y, y)
			max_x = max(max_x, x)
			max_y = max(max_y, y)

	if max_x < min_x or max_y < min_y:
		return Rect2i()

	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

static func _pad_bounds(bounds: Rect2i, image_size: Vector2i, padding: int) -> Rect2i:
	var x: int = max(bounds.position.x - padding, 0)
	var y: int = max(bounds.position.y - padding, 0)
	var end_x: int = min(bounds.end.x + padding, image_size.x)
	var end_y: int = min(bounds.end.y + padding, image_size.y)
	return Rect2i(x, y, end_x - x, end_y - y)
	
