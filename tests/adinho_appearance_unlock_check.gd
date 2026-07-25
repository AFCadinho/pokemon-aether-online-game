extends SceneTree

const APPEARANCE := preload("res://scripts/services/character_appearance_service.gd")

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(APPEARANCE.get_available_part_ids("hair", "male").has("Adinho_Hair"), "Adinho hair asset is imported")
	_check(APPEARANCE.get_available_part_ids("facial_hair", "male").has("Adinho_Beard"), "facial-hair slot loads the beard")
	_check(not APPEARANCE.get_available_part_ids("hair", "female").has("Adinho_Hair"), "male delivery is not exposed to female models")
	_check(APPEARANCE.get_available_part_ids("facegear", "female").has("Adinho_Glasses"), "Classic sunglasses are available to female models")
	_check(APPEARANCE.get_part_frames("facegear", "Adinho_Glasses", "female") != null, "female Classic sunglasses frames render")
	_check(not APPEARANCE.is_free_part_id("hair", "Adinho_Hair"), "Adinho hair is not a starter cosmetic")
	_check(APPEARANCE.is_free_part_id("hair", "Hair"), "starter hair remains free")
	_check(APPEARANCE.is_tintable_part("hair", "Adinho_Hair"), "grayscale hair supports colour")
	_check(APPEARANCE.is_tintable_part("facegear", "Adinho_Glasses_Chroma"), "grayscale glasses support colour")
	_check(not APPEARANCE.is_tintable_part("facegear", "Adinho_Glasses"), "original glasses preserve authored colours")
	_check(APPEARANCE.is_tintable_part("top", "Adinho_Shirt_Chroma"), "grayscale shirt supports colour")
	_check(APPEARANCE.get_available_part_ids("bottom", "male").has("Adinho_Trousers_Chroma"), "separate Chroma trousers asset is imported")
	_check(APPEARANCE.is_tintable_part("bottom", "Adinho_Trousers_Chroma"), "Chroma trousers support colour")
	_check(APPEARANCE.get_available_part_ids("shoes", "male").has("Adinho_Shoes_Chroma"), "separate Chroma shoes asset is imported")
	_check(APPEARANCE.is_tintable_part("shoes", "Adinho_Shoes_Chroma"), "Chroma shoes support colour")
	_check(APPEARANCE.get_eyebrows_for_hair("Adinho_Hair", "male") == "Adinho_Eyebrows", "Adinho hair selects matching eyebrows")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
