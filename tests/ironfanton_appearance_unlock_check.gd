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
	_check_underlay_coverage(
		"res://assets/player/male/top/Shirt.png",
		"res://assets/player/male/top/IronFanton_Shirt.png",
		"IronFanton walking shirt keeps an opaque undershirt"
	)
	_check_underlay_coverage(
		"res://assets/player/male/top/fish/Shirt_fish.png",
		"res://assets/player/male/top/fish/IronFanton_Shirt_fish.png",
		"IronFanton fishing shirt keeps an opaque undershirt"
	)
	_check_underlay_coverage(
		"res://assets/player/male/top/ride/Shirt_ride.png",
		"res://assets/player/male/top/ride/IronFanton_Shirt_ride.png",
		"IronFanton Surf and mount shirt keeps an opaque undershirt"
	)
	quit(1 if failed else 0)


func _check_underlay_coverage(default_path: String, ironfanton_path: String, label: String) -> void:
	var default_texture := load(default_path) as Texture2D
	var ironfanton_texture := load(ironfanton_path) as Texture2D
	if default_texture == null or ironfanton_texture == null:
		_check(false, label)
		return
	var default_image := default_texture.get_image()
	var ironfanton_image := ironfanton_texture.get_image()
	if default_image == null or ironfanton_image == null or default_image.get_size() != ironfanton_image.get_size():
		_check(false, label)
		return
	for y: int in default_image.get_height():
		for x: int in default_image.get_width():
			if default_image.get_pixel(x, y).a > 0.0 and ironfanton_image.get_pixel(x, y).a <= 0.0:
				_check(false, label)
				return
	_check(true, label)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
