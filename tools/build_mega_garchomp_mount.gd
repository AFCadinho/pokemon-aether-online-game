extends SceneTree

# Pack the approved V7 rig onto the standard avatar ground line.
# No resampling, redrawing, recoloring or relative seat change.
const ASSETS := "res://assets/mounts/mega_garchomp/"
const FRAME := 192
const SHIFT := Vector2i(0, -2)

func _init() -> void:
	for layer: String in ["mount", "foreground", "rider_mask"]:
		var source := Image.load_from_file(ASSETS + "source/" + layer + ".png")
		assert(source.get_size() == Vector2i(FRAME * 4, FRAME * 4))
		source.convert(Image.FORMAT_RGBA8)
		var output := Image.create(FRAME * 4, FRAME * 4, false, Image.FORMAT_RGBA8)
		for row in range(4):
			for col in range(4):
				var origin := Vector2i(col * FRAME, row * FRAME)
				var tile := source.get_region(Rect2i(origin, Vector2i(FRAME, FRAME)))
				var bounds := tile.get_used_rect()
				assert(bounds.position.y + SHIFT.y >= 0)
				var packed := Image.create(FRAME, FRAME, false, Image.FORMAT_RGBA8)
				packed.blit_rect(tile, Rect2i(0, 0, FRAME, FRAME), SHIFT)
				output.blit_rect(packed, Rect2i(0, 0, FRAME, FRAME), origin)
		assert(output.save_png(ASSETS + layer + ".png") == OK)
	var approved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ASSETS + "source/approved_v7.json"))["mega_garchomp"]
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/mounts.json"))["mounts"]["mega_garchomp"]
	for direction: String in ["down", "left", "right", "up"]:
		for phase in range(4):
			var old: Array = approved["riderOffsets"][direction][phase]
			var actual: Array = catalog["riderOffsets"][direction][phase]
			assert(Vector2i(actual[0], actual[1]) == Vector2i(old[0], old[1]) + SHIFT)
	print("Built Mega Garchomp: V7 pixels and relative seat preserved; ground aligned.")
	quit()
