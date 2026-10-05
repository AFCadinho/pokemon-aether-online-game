extends SceneTree

const Followers := preload("res://scripts/services/follower_sprite_service.gd")

var failed := false


func _init() -> void:
	_check_variant("dreepy", false, {"down": 0, "left": 2, "right": 3, "up": 1})
	_check_variant("DREEPY", true, {"down": 0, "left": 1, "right": 2, "up": 3})
	_check_variant("pikachu", false, {"down": 0, "left": 1, "right": 2, "up": 3})
	_check_variant("pikachu", true, {"down": 0, "left": 1, "right": 2, "up": 3})
	quit(1 if failed else 0)


func _check_variant(species: String, shiny: bool, expected_rows: Dictionary) -> void:
	var frames := Followers.get_sprite_frames(species, shiny)
	_check(frames != null, "%s shiny=%s loads" % [species, shiny])
	if frames == null:
		return
	_check(frames == Followers.get_sprite_frames(species.to_lower(), shiny), "variant cache is reused")
	for direction: String in expected_rows:
		for mode: String in ["idle", "walk"]:
			var animation := "%s_%s" % [mode, direction]
			var expected_count := 1 if mode == "idle" else 4
			_check(frames.get_frame_count(animation) == expected_count, "%s has all frames" % animation)
			for column in range(expected_count):
				var texture := frames.get_frame_texture(animation, column) as AtlasTexture
				var size := Vector2(texture.atlas.get_size()) / 4.0
				_check(
					texture.region == Rect2(Vector2(column, expected_rows[direction]) * size, size),
					"%s shiny=%s %s frame %d selects the correct row" % [species, shiny, animation, column]
				)
	print("Checked %s shiny=%s facing directions" % [species, shiny])


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
