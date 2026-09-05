extends SceneTree

const CATALOG_PATH := "res://generated/world_access_catalog.json"
const EXPECTED_FACING := {
	"kanto_mt_moon_1f__to_b1f_1": "left",
	"kanto_mt_moon_1f__to_b1f_3": "right",
	"kanto_mt_moon_1f__to_b1f_5": "right",
	"kanto_mt_moon_1f__to_route_3": "down",
	"kanto_mt_moon_b1f__to_1f_1": "left",
	"kanto_mt_moon_b1f__to_1f_3": "left",
	"kanto_mt_moon_b1f__to_1f_5": "left",
	"kanto_mt_moon_b1f__to_b2f_2": "right",
	"kanto_mt_moon_b1f__to_b2f_4": "left",
	"kanto_mt_moon_b1f__to_b2f_6": "left",
	"kanto_mt_moon_b1f__to_b2f_7": "right",
	"kanto_mt_moon__to_route_4": "down",
	"kanto_route_4__to_cerulean_city": "right",
	"kanto_cerulean_city__to_route_4": "left",
	"kanto_mt_moon_b2f__to_b1f_2": "right",
	"kanto_mt_moon_b2f__to_b1f_4": "right",
	"kanto_mt_moon_b2f__to_b1f_6": "left",
	"kanto_mt_moon_b2f__to_b1f_7": "right",
	"kanto_route_3__to_mt_moon": "up",
	"kanto_route_4__to_mt_moon": "down",
}

var failed := false


func _init() -> void:
	var catalog_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	_check(catalog_value is Dictionary, "World access catalog is valid JSON")
	if not catalog_value is Dictionary:
		quit(1)
		return

	var transitions: Dictionary = (catalog_value as Dictionary).get("transitions", {})
	for transition_id: String in EXPECTED_FACING:
		var transition: Dictionary = transitions.get(transition_id, {})
		var destination: Dictionary = transition.get("destination", {})
		_check_equal(
			str(destination.get("facingDirection", "")),
			EXPECTED_FACING[transition_id],
			"%s has the expected arrival direction" % transition_id
		)

	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	_check(actual == expected, "%s (expected %s, got %s)" % [label, str(expected), str(actual)])
