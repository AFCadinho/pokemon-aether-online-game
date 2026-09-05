extends SceneTree

const RockSmashLevelPaletteScript := preload("res://scripts/world/interactables/rock_smash_level_palette.gd")
const EXPECTED_COLORS := {
	1: Color("#78c96b"),
	5: Color("#39d6a0"),
	10: Color("#4aa8ff"),
	20: Color("#ae70ff"),
	50: Color("#ff8954"),
	75: Color("#ffd34d"),
}
const EXPECTED_LEVELS := {
	"res://scenes/overworld/kanto/towns/pewter_city/pewter_city.tscn": {
		"kanto_pewter_city_training_rock_north": 1,
		"kanto_pewter_city_training_rock_east": 1,
		"kanto_pewter_city_training_rock_south": 1,
		"kanto_pewter_city_training_rock_west": 1,
	},
	"res://scenes/overworld/kanto/routes/kanto_route_3.tscn": {
		"kanto_route_3_rock_west": 5,
		"kanto_route_3_rock_central_west": 5,
		"kanto_route_3_rock_central_east": 10,
		"kanto_route_3_rock_east": 20,
	},
	"res://scenes/overworld/kanto/caves/mt_moon/1f.tscn": {
		"kanto_mt_moon_1f_rock_west": 5,
		"kanto_mt_moon_1f_rock_central": 5,
		"kanto_mt_moon_1f_rock_east": 5,
	},
	"res://scenes/overworld/kanto/caves/mt_moon/b1f.tscn": {
		"kanto_mt_moon_b1f_rock_west": 10,
		"kanto_mt_moon_b1f_rock_east": 10,
		"kanto_mt_moon_b1f_rock_south": 10,
	},
	"res://scenes/overworld/kanto/caves/mt_moon/b2f.tscn": {
		"kanto_mt_moon_b2f_rock_north": 20,
		"kanto_mt_moon_b2f_rock_central": 50,
		"kanto_mt_moon_b2f_rock_south": 75,
	},
	"res://scenes/overworld/kanto/routes/kanto_route_4.tscn": {
		"kanto_route_4_rock_west": 5,
		"kanto_route_4_rock_central_west": 10,
		"kanto_route_4_rock_central_east": 20,
		"kanto_route_4_rock_east": 50,
	},
	"res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn": {
		"kanto_cerulean_city_west_site_rock_north": 20,
		"kanto_cerulean_city_west_site_rock_upper": 20,
		"kanto_cerulean_city_west_site_rock_lower": 20,
		"kanto_cerulean_city_west_site_rock_south": 20,
		"kanto_cerulean_city_east_site_rock_northwest": 50,
		"kanto_cerulean_city_east_site_rock_northeast": 50,
		"kanto_cerulean_city_east_site_rock_southwest": 50,
		"kanto_cerulean_city_east_site_rock_southeast": 50,
	},
}

var failed := false


func _init() -> void:
	var colors: Array[Color] = []
	for required_level: int in [1, 5, 10, 20, 50, 75]:
		var color := RockSmashLevelPaletteScript.color_for_required_level(required_level)
		_check(color == EXPECTED_COLORS[required_level], "Rock Smash level %d keeps its reviewed tier color" % required_level)
		_check(color not in colors, "Rock Smash level %d has a unique color" % required_level)
		colors.append(color)
	var rock_source := FileAccess.get_file_as_string("res://scripts/world/interactables/daily_smashable_rock.gd")
	_check("TierOutline" not in rock_source, "Rock Smash rocks do not draw colored square outlines")
	_check(
		RockSmashLevelPaletteScript.color_for_required_level(25) == Color.WHITE,
		"unknown Rock Smash levels do not receive a misleading known-tier color"
	)

	for scene_path_value: Variant in EXPECTED_LEVELS:
		var scene_path := str(scene_path_value)
		var source := FileAccess.get_file_as_string(scene_path)
		var expected: Dictionary = EXPECTED_LEVELS[scene_path_value]
		for rock_id_value: Variant in expected:
			var rock_id := str(rock_id_value)
			var required_level := int(expected[rock_id_value])
			var rock_start := source.find('rock_id = "%s"' % rock_id)
			var next_node := source.find("\n[node ", rock_start)
			var rock_block := source.substr(
				rock_start,
				next_node - rock_start if next_node >= 0 else source.length() - rock_start
			)
			_check(
				rock_start >= 0 and 'required_rock_smash_level = %d' % required_level in rock_block,
				"%s uses the level %d color contract" % [rock_id, required_level]
			)

	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
