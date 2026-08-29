extends SceneTree

const APPEARANCE := preload("res://scripts/services/character_appearance_service.gd")

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(APPEARANCE.get_available_part_ids("hair", "male").has("IronFanton_Hair"), "IronFanton hair is imported")
	_check(APPEARANCE.get_available_part_ids("facial_hair", "male").has("IronFanton_Beard"), "IronFanton beard is imported")
	_check(APPEARANCE.get_available_part_ids("top", "male").has("IronFanton_Shirt"), "IronFanton shirt is imported")
	_check(not APPEARANCE.get_available_part_ids("hair", "female").has("IronFanton_Hair"), "IronFanton set is male-only")
	_check(APPEARANCE.is_tintable_part("hair", "IronFanton_Hair"), "IronFanton hair supports Chroma colours")
	_check(APPEARANCE.is_tintable_part("facial_hair", "IronFanton_Beard"), "IronFanton beard supports Chroma colours")
	_check(not APPEARANCE.is_tintable_part("top", "IronFanton_Shirt"), "IronFanton shirt preserves its authored colours")
	_check(APPEARANCE.get_eyebrows_for_hair("IronFanton_Hair", "male") == "Eyebrows", "IronFanton hair keeps the starter eyebrows")
	_check(APPEARANCE.get_part_frames("top", "IronFanton_Shirt", "male", "fish") != null, "IronFanton shirt has a fishing pose")
	_check(APPEARANCE.get_part_frames("top", "IronFanton_Shirt", "male", "ride") != null, "IronFanton shirt has a Surf and mount pose")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
