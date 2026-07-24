extends SceneTree

const STORE_SCENE := preload("res://scenes/interface/donator_store_popup.tscn")
const STORE_SCRIPT_PATH := "res://scripts/ui/donator_store_popup.gd"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var store := STORE_SCENE.instantiate() as DonatorStorePopup
	root.add_child(store)
	await process_frame

	_check(store != null, "Donator Store scene instantiates")
	if store == null:
		quit(1)
		return

	var source := FileAccess.get_file_as_string(STORE_SCRIPT_PATH)
	_check(source.contains('const COSMETIC_SUBCATEGORY_ORDER: Array[String]'), "cosmetics define a second category layer")
	for subcategory_id: String in [
		"all",
		"outfits",
		"body",
		"hair",
		"headgear",
		"face",
		"facegear",
		"top",
		"bottom",
		"shoes",
	]:
		_check(source.contains('"%s",' % subcategory_id), "cosmetics include %s" % subcategory_id)

	_check(source.contains('"appearance_slots": ["headgear", "top", "bottom", "shoes"]'), "complete outfits declare their included appearance slots")
	_check(source.contains('"name": "Trailblazer Beard"') and source.contains('"cosmetic_subcategory": "face"'), "Face prepares a beard-style product")
	_check(source.contains("ScrollContainer.SCROLL_MODE_AUTO"), "cosmetic subtabs can scroll on smaller layouts")

	store.call("_select_category", "cosmetics")
	_check(store.cosmetic_subcategory_bar.visible, "cosmetic subtabs appear inside Cosmetics")
	_check(store.cosmetic_subcategory_buttons.size() == 10, "all cosmetic subtabs are built")

	store.call("_select_cosmetic_subcategory", "face")
	_check(store.active_cosmetic_subcategory == "face", "Face can become the active cosmetic subtab")
	_check(store.product_buttons.has("trailblazer_beard"), "Face filters the catalog to beard and face styles")
	_check(not store.product_buttons.has("aurora_outfit"), "Face hides unrelated outfit products")

	store.call("_select_cosmetic_subcategory", "outfits")
	_check(store.product_buttons.has("aurora_outfit"), "Outfits expose complete appearance bundles")

	store.call("_select_category", "membership")
	_check(not store.cosmetic_subcategory_bar.visible, "cosmetic subtabs stay out of other Store categories")

	store.queue_free()
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return

	failed = true
	push_error("FAIL %s" % message)
