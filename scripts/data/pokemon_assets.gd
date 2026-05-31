extends RefCounted

class_name PokemonAssets

const HOME_SPRITE_PATH := "res://assets/sprites/pokemon/pokemon_home/%s.png"
const FRONT_FRAME_PATH := "res://assets/sprites/pokemon/front/%s/frame_000.png"
const UNKNOWN_HOME_SPRITE_PATH := "res://assets/sprites/pokemon/pokemon_home/unknown.png"

static func load_home_sprite(species: String) -> Texture2D:
	var path := HOME_SPRITE_PATH % species
	if ResourceLoader.exists(path):
			return load(path)

	return null

static func load_party_icon(species: String) -> Texture2D:
	return load_home_sprite(species)

static func load_unknown_icon() -> Texture2D:
	if ResourceLoader.exists(UNKNOWN_HOME_SPRITE_PATH):
		return load(UNKNOWN_HOME_SPRITE_PATH)
	return null
	
