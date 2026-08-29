extends RefCounted

class_name SignPortraitCatalog

const SIGN_PORTRAIT_PATHS: Dictionary = {
	"kanto_pallet_town_town_sign": "res://assets/sprites/sign_previews/pallet_town.png",
	"kanto_pallet_town_oaks_lab": "res://assets/sprites/sign_previews/oaks_lab.png",
	"kanto_viridian_city_town_sign": "res://assets/sprites/sign_previews/viridian_city.png",
	"kanto_viridian_city_jail": "res://assets/sprites/sign_previews/viridian_city_jail.png",
	"kanto_viridian_city_trainer_school": "res://assets/sprites/sign_previews/viridian_trainer_school.png",
	"kanto_viridian_city_gym": "res://assets/sprites/sign_previews/viridian_gym.png",
	"kanto_pewter_city_gym": "res://assets/sprites/sign_previews/pewter_gym.png",
	"kanto_cerulean_city_town_sign": "res://assets/sprites/sign_previews/cerulean_city.png",
	"kanto_cerulean_city_gym": "res://assets/sprites/sign_previews/cerulean_gym.png",
	"kanto_cerulean_city_bike_shop": "res://assets/sprites/sign_previews/cerulean_bike_shop.png",
	"kanto_route_1_route_sign": "res://assets/sprites/sign_previews/route_1.png",
	"kanto_route_1_viridian_city_sign": "res://assets/sprites/sign_previews/viridian_city.png",
	"kanto_route_2_digletts_cave": "res://assets/sprites/sign_previews/digletts_cave.png",
	"kanto_route_22_route_sign": "res://assets/sprites/sign_previews/route_22.png",
	"kanto_route_3_mt_moon_sign": "res://assets/sprites/sign_previews/mt_moon.png",
	"kanto_route_24_route_sign": "res://assets/sprites/sign_previews/route_24.png",
	"kanto_route_25_route_sign": "res://assets/sprites/sign_previews/route_25.png",
}

static var portrait_cache: Dictionary = {}


static func get_portrait(sign_id: String) -> Texture2D:
	var normalized_sign_id := sign_id.strip_edges()
	if portrait_cache.has(normalized_sign_id):
		return portrait_cache[normalized_sign_id] as Texture2D

	var path := get_portrait_path(normalized_sign_id)
	if path.is_empty():
		return null

	var portrait := _load_texture(path)
	if portrait != null:
		portrait_cache[normalized_sign_id] = portrait
	return portrait


static func has_portrait(sign_id: String) -> bool:
	var path := get_portrait_path(sign_id)
	return not path.is_empty() and (ResourceLoader.exists(path, "Texture2D") or FileAccess.file_exists(path))


static func get_portrait_path(sign_id: String) -> String:
	return str(SIGN_PORTRAIT_PATHS.get(sign_id.strip_edges(), ""))


static func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path, "Texture2D"):
		var imported_texture := ResourceLoader.load(path, "Texture2D") as Texture2D
		if imported_texture != null:
			return imported_texture

	if not FileAccess.file_exists(path):
		return null

	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)
