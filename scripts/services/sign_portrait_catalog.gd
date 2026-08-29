extends RefCounted

class_name SignPortraitCatalog

const SIGN_PORTRAITS: Dictionary = {
	"kanto_pallet_town_town_sign": preload("res://assets/sprites/sign_previews/pallet_town.png"),
	"kanto_pallet_town_oaks_lab": preload("res://assets/sprites/sign_previews/oaks_lab.png"),
	"kanto_viridian_city_town_sign": preload("res://assets/sprites/sign_previews/viridian_city.png"),
	"kanto_viridian_city_jail": preload("res://assets/sprites/sign_previews/viridian_city_jail.png"),
	"kanto_viridian_city_trainer_school": preload("res://assets/sprites/sign_previews/viridian_trainer_school.png"),
	"kanto_viridian_city_gym": preload("res://assets/sprites/sign_previews/viridian_gym.png"),
	"kanto_pewter_city_gym": preload("res://assets/sprites/sign_previews/pewter_gym.png"),
	"kanto_cerulean_city_town_sign": preload("res://assets/sprites/sign_previews/cerulean_city.png"),
	"kanto_cerulean_city_gym": preload("res://assets/sprites/sign_previews/cerulean_gym.png"),
	"kanto_cerulean_city_bike_shop": preload("res://assets/sprites/sign_previews/cerulean_bike_shop.png"),
	"kanto_route_1_route_sign": preload("res://assets/sprites/sign_previews/route_1.png"),
	"kanto_route_1_viridian_city_sign": preload("res://assets/sprites/sign_previews/viridian_city.png"),
	"kanto_route_2_digletts_cave": preload("res://assets/sprites/sign_previews/digletts_cave.png"),
	"kanto_route_22_route_sign": preload("res://assets/sprites/sign_previews/route_22.png"),
	"kanto_route_3_mt_moon_sign": preload("res://assets/sprites/sign_previews/mt_moon.png"),
	"kanto_route_24_route_sign": preload("res://assets/sprites/sign_previews/route_24.png"),
	"kanto_route_25_route_sign": preload("res://assets/sprites/sign_previews/route_25.png"),
}


static func get_portrait(sign_id: String) -> Texture2D:
	return SIGN_PORTRAITS.get(sign_id.strip_edges()) as Texture2D


static func has_portrait(sign_id: String) -> bool:
	return get_portrait(sign_id) != null
