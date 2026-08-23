extends SceneTree

const FLOOR_SCENES := {
	"1F": "res://scenes/overworld/kanto/caves/mt_moon/1f.tscn",
	"B1F": "res://scenes/overworld/kanto/caves/mt_moon/b1f.tscn",
	"B2F": "res://scenes/overworld/kanto/caves/mt_moon/b2f.tscn",
}
const EXPECTED_TRAINER_IDS := {
	"1F": [
		"kanto_mt_moon_1f_hiker_marcos",
		"kanto_mt_moon_1f_youngster_josh",
		"kanto_mt_moon_1f_lass_miriam",
		"kanto_mt_moon_1f_lass_iris",
		"kanto_mt_moon_1f_super_nerd_jovan",
		"kanto_mt_moon_1f_bug_catcher_kent",
		"kanto_mt_moon_1f_bug_catcher_robby",
	],
	"B1F": [],
	"B2F": [
		"kanto_mt_moon_b2f_rocket_grunt_1",
		"kanto_mt_moon_b2f_rocket_grunt_2",
		"kanto_mt_moon_b2f_rocket_grunt_3",
		"kanto_mt_moon_b2f_rocket_grunt_4",
		"kanto_mt_moon_b2f_super_nerd_miguel",
	],
}

var failures := 0


func _init() -> void:
	for floor_name: String in FLOOR_SCENES:
		_check_floor(floor_name, FLOOR_SCENES[floor_name])
	quit(1 if failures > 0 else 0)


func _check_floor(floor_name: String, scene_path: String) -> void:
	var file := FileAccess.open(scene_path, FileAccess.READ)
	_check(file != null, "%s scene can be read" % floor_name)
	if file == null:
		return
	var scene_text := file.get_as_text()
	var actual_ids: Array[String] = []
	for block: String in scene_text.split("[node "):
		var trainer_id := _property_value(block, "trainer_id")
		if trainer_id.is_empty():
			continue
		actual_ids.append(trainer_id)
		var position_text := _property_value(block, "position")
		_check(_is_grid_center(position_text), "%s is centered on the movement grid" % trainer_id)
	actual_ids.sort()
	var expected_ids: Array[String] = []
	for trainer_id: String in EXPECTED_TRAINER_IDS[floor_name]:
		expected_ids.append(trainer_id)
	expected_ids.sort()
	_check(actual_ids == expected_ids, "%s has the canonical Trainer roster" % floor_name)


func _property_value(block: String, property_name: String) -> String:
	var prefix := "%s = " % property_name
	for line: String in block.split("\n"):
		if not line.begins_with(prefix):
			continue
		var value := line.trim_prefix(prefix).strip_edges()
		if value.begins_with('"') and value.ends_with('"'):
			return value.substr(1, value.length() - 2)
		return value
	return ""


func _is_grid_center(position_text: String) -> bool:
	if not position_text.begins_with("Vector2(") or not position_text.ends_with(")"):
		return false
	var coordinates := position_text.trim_prefix("Vector2(").trim_suffix(")").split(",")
	if coordinates.size() != 2:
		return false
	var x := int(float(coordinates[0].strip_edges()))
	var y := int(float(coordinates[1].strip_edges()))
	return x % 32 == 16 and y % 32 == 16


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
