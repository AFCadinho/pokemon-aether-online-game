extends "res://scripts/battle/battle_ui/sprite_box.gd"

# Keep the real doubles presentation and request-generation handling, but make
# the download deterministic and offline. One slot starts warm, the other cold.
var warm_species := "Pikachu"
var warm_frames: SpriteFrames
var home_frames: SpriteFrames
var downloaded_frames: SpriteFrames
var blocked := true
var requests: Array[Dictionary] = []

func _load_sprite_frames(species: String, _side: String, _shiny := false,
		_report_missing := true) -> SpriteFrames:
	return warm_frames if species == warm_species else home_frames

func request_web_sprite_frames(species: String, side: String, shiny := false) -> SpriteFrames:
	requests.append({"species": species, "side": side, "shiny": shiny})
	while blocked:
		await get_tree().process_frame
	return downloaded_frames

