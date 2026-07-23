extends RefCounted

class_name PokemonAssets

const HOME_SPRITE_PATH := "res://assets/sprites/pokemon/pokemon_home/%s.png"
const SHINY_HOME_SPRITE_PATH := "res://assets/sprites/pokemon/pokemon_home_shiny/%s.png"
const FRONT_FRAME_PATH := "res://assets/sprites/pokemon/front/%s/frame_000.png"
const UNKNOWN_HOME_SPRITE_PATH := "res://assets/sprites/pokemon/pokemon_home/unknown.png"
const POKEMON_SPRITE_RES_ROOT := "res://assets/sprites/pokemon"
const POKEMON_SPRITE_RELATIVE_ROOT := "assets/sprites/pokemon"
const GEN5_SPRITE_ROOT := "gen5"
const PARTY_ICON_CROP_PADDING := 4
const PARTY_ICON_ALPHA_THRESHOLD := 0.01
const HOME_SPRITE_ALIASES := {
	"ninetales-alola": ["Ninetales-Alola"],
	"vulpix-alola": ["Vulpix-Alola"],
	"oricorio": ["Oricorio"],
	"oricorio-baile": ["Oricorio"],
	"oricoriobaile": ["Oricorio"],
	"oricorio-pau": ["Oricorio-Pau"],
	"oricoriopau": ["Oricorio-Pau"],
	"oricorio-pa'u": ["Oricorio-Pau"],
	"oricorio-pompom": ["Oricorio-Pom-Pom"],
	"oricoriopompom": ["Oricorio-Pom-Pom"],
	"oricorio-pom-pom": ["Oricorio-Pom-Pom"],
	"oricorio-sensu": ["Oricorio-Sensu"],
	"oricoriosensu": ["Oricorio-Sensu"],
}

static var party_icon_cache: Dictionary = {}
static var external_sprite_root := ""

static func get_pokemon_sprite_roots() -> Array[String]:
	var roots: Array[String] = [POKEMON_SPRITE_RES_ROOT]
	var external_root := get_external_pokemon_sprite_root()
	if not external_root.is_empty():
		roots.append(external_root)

	return roots

static func get_external_pokemon_sprite_root() -> String:
	if not external_sprite_root.is_empty():
		return external_sprite_root

	var executable_dir := OS.get_executable_path().get_base_dir()
	var candidates: Array[String] = [
		executable_dir.path_join(POKEMON_SPRITE_RELATIVE_ROOT),
		executable_dir.get_base_dir().path_join(POKEMON_SPRITE_RELATIVE_ROOT),
	]
	for candidate: String in candidates:
		if DirAccess.dir_exists_absolute(candidate):
			external_sprite_root = candidate
			return external_sprite_root

	return ""

static func build_pokemon_sprite_path(relative_path: String) -> Array[String]:
	var paths: Array[String] = []
	for root in get_pokemon_sprite_roots():
		paths.append(root.path_join(relative_path))

	return paths

static func has_optional_gen5_animated_sprites() -> bool:
	for root: String in get_pokemon_sprite_roots():
		if _has_gen5_battle_sprite_dirs(root):
			return true

	return false

static func _has_gen5_battle_sprite_dirs(root: String) -> bool:
	return (
		DirAccess.dir_exists_absolute(root.path_join(GEN5_SPRITE_ROOT).path_join("front"))
		and DirAccess.dir_exists_absolute(root.path_join(GEN5_SPRITE_ROOT).path_join("back"))
	)

static func load_texture(path: String) -> Texture2D:
	if path.begins_with("res://"):
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
		return null

	if not FileAccess.file_exists(path):
		return null

	var image := Image.new()
	var load_error: Error = image.load(path)
	if load_error != OK:
		push_error("Could not load external texture: %s" % path)
		return null

	return ImageTexture.create_from_image(image)

static func load_home_sprite(species: String, is_shiny: bool = false) -> Texture2D:
	if is_shiny:
		for sprite_name in _get_home_sprite_names(species):
			for shiny_path in build_pokemon_sprite_path("pokemon_home_shiny/%s.png" % sprite_name):
				var shiny_texture := load_texture(shiny_path)
				if shiny_texture != null:
					return shiny_texture

	for sprite_name in _get_home_sprite_names(species):
		for path in build_pokemon_sprite_path("pokemon_home/%s.png" % sprite_name):
			var texture := load_texture(path)
			if texture != null:
				return texture

	return null

static func _get_home_sprite_names(species: String) -> Array[String]:
	var names: Array[String] = []
	var cleaned := species.strip_edges()
	_add_home_sprite_name(names, cleaned)
	_add_home_sprite_name(names, cleaned.to_lower())
	_add_home_sprite_name(names, cleaned.replace(" ", "-"))
	_add_home_sprite_name(names, cleaned.replace(" ", "-").to_lower())
	_add_home_sprite_name(names, _to_showdown_compact_sprite_name(cleaned))
	_add_home_sprite_name(names, cleaned.replace(" ", "-").replace("-Mega-X", "-Megax").replace("-Mega-Y", "-Megay"))
	_add_home_sprite_name(names, _to_home_sprite_case(cleaned))
	_add_home_sprite_name(names, _to_home_sprite_case(cleaned.replace("'", "")))

	var alias_key := _normalize_home_sprite_key(cleaned)
	if HOME_SPRITE_ALIASES.has(alias_key):
		for alias: String in HOME_SPRITE_ALIASES[alias_key]:
			_add_home_sprite_name(names, alias)

	return names

static func _add_home_sprite_name(names: Array[String], sprite_name: String) -> void:
	if sprite_name.is_empty() or names.has(sprite_name):
		return
	names.append(sprite_name)

static func _to_home_sprite_case(value: String) -> String:
	var normalized := value.strip_edges().replace("_", "-").replace(" ", "-")
	var parts := normalized.split("-", false)
	var formatted_parts: Array[String] = []
	for part: String in parts:
		if part.is_empty():
			continue
		formatted_parts.append(part.substr(0, 1).to_upper() + part.substr(1).to_lower())
	return "-".join(formatted_parts)

static func _to_showdown_compact_sprite_name(value: String) -> String:
	return value.strip_edges().to_lower().replace(" ", "").replace("_", "").replace("-", "").replace("'", "").replace(".", "")

static func _normalize_home_sprite_key(value: String) -> String:
	return value.strip_edges().to_lower().replace("_", "-").replace(" ", "-").replace(".", "")

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
	for path in build_pokemon_sprite_path("pokemon_home/unknown.png"):
		var texture := load_texture(path)
		if texture != null:
			return texture
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
	
