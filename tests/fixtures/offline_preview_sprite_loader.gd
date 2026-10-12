extends "res://scripts/battle/battle_ui/sprite_box.gd"

func request_web_sprite_frames(_species: String, _side: String, _is_shiny: bool = false) -> SpriteFrames:
	return null # Offline summon checks use bundled fallback sprites, without CDN work.
