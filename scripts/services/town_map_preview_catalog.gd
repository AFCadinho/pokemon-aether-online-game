extends RefCounted

class_name TownMapPreviewCatalog

const SignPortraitCatalogScript := preload("res://scripts/services/sign_portrait_catalog.gd")

# Exact location illustrations shared with the overworld signs.
const LOCATION_SIGN_IDS: Dictionary = {
	"kanto_pallet_town": "kanto_pallet_town_town_sign",
	"kanto_viridian_city": "kanto_viridian_city_town_sign",
	"kanto_cerulean_city": "kanto_cerulean_city_town_sign",
	"kanto_map_point_14": "kanto_lavender_town_town_sign",
	"kanto_route_1": "kanto_route_1_route_sign",
	"kanto_route_segment_06": "kanto_route_6_route_sign",
	"kanto_route_segment_09": "kanto_route_9_route_sign",
	"kanto_route_segment_11": "kanto_route_11_route_sign",
	"kanto_route_segment_22": "kanto_route_22_route_sign",
	"kanto_route_segment_24": "kanto_route_24_route_sign",
	"kanto_route_segment_25": "kanto_route_25_route_sign",
	"kanto_map_point_05": "kanto_route_3_mt_moon_sign",
	"kanto_map_point_11": "kanto_route_11_digletts_cave_sign",
	"kanto_map_point_12": "kanto_route_10_rock_tunnel_sign",
	"kanto_map_point_15": "kanto_lavender_town_pokemon_tower_sign",
	"kanto_map_point_16": "kanto_route_2_digletts_cave",
}

const LOCATION_PORTRAIT_PATHS: Dictionary = {
	"kanto_route_2": "res://assets/sprites/sign_previews/route_2.png",
	"kanto_viridian_forest": "res://assets/sprites/sign_previews/viridian_forest.png",
	"kanto_pewter_city": "res://assets/sprites/sign_previews/pewter_city.png",
	"kanto_map_point_01": "res://assets/sprites/sign_previews/indigo_plateau.png",
	"kanto_map_point_02": "res://assets/sprites/sign_previews/victory_road.png",
	"kanto_map_point_03": "res://assets/sprites/sign_previews/cinnabar_island.png",
	"kanto_map_point_04": "res://assets/sprites/sign_previews/seafoam_islands.png",
	"kanto_map_point_06": "res://assets/sprites/sign_previews/celadon_city.png",
	"kanto_map_point_07": "res://assets/sprites/sign_previews/fuchsia_city.png",
	"kanto_map_point_09": "res://assets/sprites/sign_previews/saffron_city.png",
	"kanto_map_point_10": "res://assets/sprites/sign_previews/vermilion_city.png",
	"kanto_map_point_13": "res://assets/sprites/sign_previews/power_plant.png",
	"kanto_map_point_17": "res://assets/sprites/sign_previews/viridian_forest_gate.png",
	"kanto_cerulean_cave": "res://assets/sprites/sign_previews/cerulean_cave.png",
	"kanto_route_3": "res://assets/sprites/sign_previews/route_3.png",
	"kanto_route_4": "res://assets/sprites/sign_previews/route_4.png",
	"kanto_route_segment_05": "res://assets/sprites/sign_previews/route_5.png",
	"kanto_route_segment_07": "res://assets/sprites/sign_previews/route_7.png",
	"kanto_route_segment_08": "res://assets/sprites/sign_previews/route_8.png",
	"kanto_route_segment_10": "res://assets/sprites/sign_previews/route_10.png",
	"kanto_route_segment_12": "res://assets/sprites/sign_previews/route_12.png",
	"kanto_route_13": "res://assets/sprites/sign_previews/route_13.png",
	"kanto_route_segment_14": "res://assets/sprites/sign_previews/route_14.png",
	"kanto_route_segment_15": "res://assets/sprites/sign_previews/route_15.png",
	"kanto_route_segment_16": "res://assets/sprites/sign_previews/route_16.png",
	"kanto_route_segment_17": "res://assets/sprites/sign_previews/route_17.png",
	"kanto_route_segment_18": "res://assets/sprites/sign_previews/route_18.png",
	"kanto_route_segment_19": "res://assets/sprites/sign_previews/route_19.png",
	"kanto_route_segment_20": "res://assets/sprites/sign_previews/route_20.png",
	"kanto_route_segment_21": "res://assets/sprites/sign_previews/route_21.png",
	"kanto_route_segment_23": "res://assets/sprites/sign_previews/route_23.png",
}

static var portrait_cache: Dictionary = {}


static func get_portrait(location_id: String) -> Texture2D:
	var normalized_id := location_id.strip_edges()
	if LOCATION_SIGN_IDS.has(normalized_id):
		return SignPortraitCatalogScript.get_portrait(str(LOCATION_SIGN_IDS[normalized_id]))
	if portrait_cache.has(normalized_id):
		return portrait_cache[normalized_id] as Texture2D
	var path := get_portrait_path(normalized_id)
	if path.is_empty():
		return null
	var portrait: Texture2D
	if ResourceLoader.exists(path, "Texture2D"):
		portrait = ResourceLoader.load(path, "Texture2D") as Texture2D
	elif FileAccess.file_exists(path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			portrait = ImageTexture.create_from_image(image)
	if portrait != null:
		portrait_cache[normalized_id] = portrait
	return portrait


static func get_portrait_path(location_id: String) -> String:
	var normalized_id := location_id.strip_edges()
	if LOCATION_SIGN_IDS.has(normalized_id):
		return SignPortraitCatalogScript.get_portrait_path(str(LOCATION_SIGN_IDS[normalized_id]))
	return str(LOCATION_PORTRAIT_PATHS.get(normalized_id, ""))
