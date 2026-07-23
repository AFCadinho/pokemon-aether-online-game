extends SceneTree

const FIELD_TIMERS_SCRIPT_PATH := "res://scripts/battle/battle_ui/field_timers.gd"
const FRAME_SIZE := Vector2i(40, 24)
const TERRAIN_SHEETS := {
	"grassyterrain": "res://assets/battles/field/animated/terraingrassy.png",
	"mistyterrain": "res://assets/battles/field/animated/terrainmisty.png",
	"psychicterrain": "res://assets/battles/field/animated/terrainpsychic.png",
	"electricterrain": "res://assets/battles/field/animated/terrainelectric.png",
}

var failed := false


func _init() -> void:
	var field_timers_source := FileAccess.get_file_as_string(FIELD_TIMERS_SCRIPT_PATH)
	for terrain_key: String in TERRAIN_SHEETS:
		var sheet_path: String = TERRAIN_SHEETS[terrain_key]
		var file_name := sheet_path.get_file()
		_check_true(
			field_timers_source.contains('"%s":\n\t\t\tfile_name = "%s"' % [terrain_key, file_name]),
			"%s uses its animated indicator sheet" % terrain_key
		)
		_check_true(ResourceLoader.exists(sheet_path), "%s indicator sheet exists" % terrain_key)
		var texture := load(sheet_path) as Texture2D
		_check_true(texture != null, "%s indicator sheet loads" % terrain_key)
		if texture == null:
			continue
		_check_true(texture.get_height() == FRAME_SIZE.y, "%s frames are 24 pixels high" % terrain_key)
		_check_true(
			texture.get_width() % FRAME_SIZE.x == 0,
			"%s sheet width is divisible into 40-pixel frames" % terrain_key
		)
		_check_true(texture.get_width() / FRAME_SIZE.x > 1, "%s indicator has multiple loop frames" % terrain_key)
		var image := texture.get_image()
		var background_color := image.get_pixel(0, 0)
		var frame_count := texture.get_width() / FRAME_SIZE.x
		for frame_index in range(frame_count):
			_check_true(
				_frame_border_is_solid(image, frame_index, background_color),
				"%s frame %d keeps a solid background border" % [terrain_key, frame_index]
			)

	quit(1 if failed else 0)


func _frame_border_is_solid(image: Image, frame_index: int, background_color: Color) -> bool:
	var left := frame_index * FRAME_SIZE.x
	var right := left + FRAME_SIZE.x - 1
	var bottom := FRAME_SIZE.y - 1
	for x in range(left, right + 1):
		if image.get_pixel(x, 0) != background_color or image.get_pixel(x, bottom) != background_color:
			return false
	for y in range(FRAME_SIZE.y):
		if image.get_pixel(left, y) != background_color or image.get_pixel(right, y) != background_color:
			return false
	return true


func _check_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
