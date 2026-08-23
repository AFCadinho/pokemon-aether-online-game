extends SceneTree

const B1F_SCENE_PATH := "res://scenes/overworld/kanto/caves/mt_moon/b1f.tscn"

const EXPECTED_PASSAGES := {
	&"passage_1_2": Rect2(1376, 1088, 1184, 1152),
	&"passage_3_4": Rect2(1920, 0, 640, 416),
	&"passage_5_6": Rect2(0, 0, 1152, 1152),
	&"passage_7_8": Rect2(64, 1824, 768, 640),
}
const EXPECTED_MARKERS := {
	"From1F1": {"passage": &"passage_1_2", "position": Vector2(1584, 1968)},
	"FromB2F2": {"passage": &"passage_1_2", "position": Vector2(2416, 1328)},
	"From1F3": {"passage": &"passage_3_4", "position": Vector2(2128, 304)},
	"FromB2F4": {"passage": &"passage_3_4", "position": Vector2(2416, 176)},
	"From1F5": {"passage": &"passage_5_6", "position": Vector2(944, 1040)},
	"FromB2F6": {"passage": &"passage_5_6", "position": Vector2(144, 240)},
	"FromB2F7": {"passage": &"passage_7_8", "position": Vector2(336, 2192)},
	"Route4Exit8": {"passage": &"passage_7_8", "position": Vector2(512, 2112)},
}

var failed := false


func _init() -> void:
	var scene_source := FileAccess.get_file_as_string(B1F_SCENE_PATH)
	_check(not scene_source.is_empty(), "Mt. Moon B1F can be read")
	_check(scene_source.contains('[node name="FloorVisibilityMask" type="Node2D" parent="."'), "Mt. Moon B1F has a visibility mask")
	_check(scene_source.contains("constrain_camera_to_active_floor = true"), "B1F constrains the camera to the active passage")

	for passage_value: Variant in EXPECTED_PASSAGES:
		var passage := StringName(passage_value)
		var region := EXPECTED_PASSAGES[passage] as Rect2
		var serialized_region := '&"%s": Rect2(%d, %d, %d, %d)' % [
			passage,
			int(region.position.x),
			int(region.position.y),
			int(region.size.x),
			int(region.size.y),
		]
		_check(scene_source.contains(serialized_region), "B1F exposes %s" % passage)

	for marker_name: String in EXPECTED_MARKERS:
		var marker_data: Dictionary = EXPECTED_MARKERS[marker_name]
		var passage: StringName = marker_data["passage"]
		var position: Vector2 = marker_data["position"]
		var region := EXPECTED_PASSAGES[passage] as Rect2
		_check(region.has_point(position), "%s belongs to %s" % [marker_name, passage])
		_check_equal(_region_count_for_point(EXPECTED_PASSAGES, position), 1, "%s belongs to exactly one passage" % marker_name)

	quit(1 if failed else 0)


func _region_count_for_point(regions: Dictionary, point: Vector2) -> int:
	var count := 0
	for region_value: Variant in regions.values():
		if region_value is Rect2 and (region_value as Rect2).has_point(point):
			count += 1
	return count


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	_check(actual == expected, "%s (expected %s, got %s)" % [label, str(expected), str(actual)])
