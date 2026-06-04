extends RefCounted

class_name PokemonAssets

const HOME_SPRITE_PATH := "res://assets/sprites/pokemon/pokemon_home/%s.png"
const FRONT_FRAME_PATH := "res://assets/sprites/pokemon/front/%s/frame_000.png"
const UNKNOWN_HOME_SPRITE_PATH := "res://assets/sprites/pokemon/pokemon_home/unknown.png"

static func load_home_sprite(species: String) -> Texture2D:
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

static func load_party_icon(species: String) -> Texture2D:
	var icon := load_home_sprite(species)
	if icon != null:
		return icon

	return load_unknown_icon()

static func load_unknown_icon() -> Texture2D:
	if ResourceLoader.exists(UNKNOWN_HOME_SPRITE_PATH):
		return load(UNKNOWN_HOME_SPRITE_PATH)
	return null
	
