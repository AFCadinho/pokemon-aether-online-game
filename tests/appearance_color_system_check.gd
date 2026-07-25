extends SceneTree

const APPEARANCE := preload("res://scripts/services/character_appearance_service.gd")
const PLAYER_DATA := preload("res://scripts/data/player_data.gd")
const STORE_SCRIPT_PATH := "res://scripts/ui/donator_store_popup.gd"
const UI_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"
const INVENTORY_SERVICE_PATH := "res://scripts/services/inventory_service.gd"
const PLAYER_SCRIPT_PATH := "res://scripts/world/player.gd"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(APPEARANCE.HAIR_COLOR_SWATCHES.size() >= 14, "hair palette offers natural and expressive choices")
	_check(APPEARANCE.CHROMA_COLOR_SWATCHES.size() >= 20, "Chroma palette covers a broad colour range")
	_check(APPEARANCE.SKIN_TONE_SWATCHES.size() >= 13, "skin palette includes Default plus twelve curated tones")
	_check(
		str(APPEARANCE.SKIN_TONE_SWATCHES[0].get("label", "")) == "Default"
			and str(APPEARANCE.SKIN_TONE_SWATCHES[0].get("id", "")) == APPEARANCE.DEFAULT_SKIN_TONE,
		"skin palette exposes the unchanged original body colour"
	)
	_check(
		not APPEARANCE.get_available_body_model_ids("male").has("Gen4_Base_M_Tan")
			and not APPEARANCE.get_available_body_model_ids("male").has("Gen4_Base_M_Dark"),
		"legacy skin-specific bodies are hidden from the body-model selector"
	)
	_check(
		APPEARANCE.resolve_body_model_id("Gen4_Base_M_Tan", "male") == APPEARANCE.DEFAULT_MALE_BODY_ID,
		"legacy tan body resolves to the male base model"
	)
	_check(
		APPEARANCE.resolve_skin_tone("Gen4_Base_M_Tan", "#ffffff", "male") == APPEARANCE.LEGACY_TAN_SKIN_TONE,
		"legacy tan body retains its visual skin tone"
	)
	_check(
		APPEARANCE.resolve_skin_tone("Gen4_Base_M_Dark", "", "male") == APPEARANCE.LEGACY_DARK_SKIN_TONE,
		"legacy dark body retains its visual skin tone"
	)

	var player_data := PLAYER_DATA.new() as PlayerData
	player_data.gender = "male"
	player_data.apply_appearance_state({
		"body": "Gen4_Base_M_Dark",
		"skin_tone": "#ffffff",
	})
	_check(player_data.appearance_body_id == APPEARANCE.DEFAULT_MALE_BODY_ID, "loaded legacy body migrates to the base model")
	_check(player_data.appearance_skin_tone == APPEARANCE.LEGACY_DARK_SKIN_TONE, "loaded legacy body migrates its skin tone")
	player_data.free()

	var shirt_frames := APPEARANCE.get_tinted_part_frames(
		"top",
		"Adinho_Shirt_Chroma",
		"male",
		APPEARANCE.BODY_MOVEMENT_DEFAULT,
		Color("#3f6fb2"),
		true
	)
	_check(shirt_frames != null, "Chroma shirt can be tinted")
	if shirt_frames != null:
		var shirt_image := APPEARANCE._get_texture_image(
			shirt_frames.get_frame_texture(&"idle_down", 0)
		)
		_check(_count_opaque_colours(shirt_image, true) >= 5, "Chroma tint preserves multiple authored shade levels")

	var base_body_frames := APPEARANCE.get_body_frames(APPEARANCE.DEFAULT_MALE_BODY_ID, "male")
	var default_body_frames := APPEARANCE.get_skin_tinted_body_frames(
		APPEARANCE.DEFAULT_MALE_BODY_ID,
		"male",
		APPEARANCE.BODY_MOVEMENT_DEFAULT,
		APPEARANCE.DEFAULT_SKIN_TONE
	)
	var light_body_frames := APPEARANCE.get_skin_tinted_body_frames(
		APPEARANCE.DEFAULT_MALE_BODY_ID,
		"male",
		APPEARANCE.BODY_MOVEMENT_DEFAULT,
		"#f2d2bd"
	)
	var deep_body_frames := APPEARANCE.get_skin_tinted_body_frames(
		APPEARANCE.DEFAULT_MALE_BODY_ID,
		"male",
		APPEARANCE.BODY_MOVEMENT_DEFAULT,
		"#3f271f"
	)
	_check(light_body_frames != null and deep_body_frames != null, "skin-tone body frames render")
	_check(default_body_frames == base_body_frames, "Default skin tone keeps the original body frames unchanged")
	if base_body_frames != null and light_body_frames != null and deep_body_frames != null:
		var base_image := APPEARANCE._get_texture_image(base_body_frames.get_frame_texture(&"idle_down", 0))
		var light_image := APPEARANCE._get_texture_image(light_body_frames.get_frame_texture(&"idle_down", 0))
		var deep_image := APPEARANCE._get_texture_image(deep_body_frames.get_frame_texture(&"idle_down", 0))
		_check(_count_changed_pixels(light_image, deep_image) > 0, "different skin tones create visibly different body pixels")
		_check(_non_skin_pixels_are_preserved(base_image, deep_image), "skin tint preserves outlines and non-skin body details")

	var store_source := FileAccess.get_file_as_string(STORE_SCRIPT_PATH)
	var ui_source := FileAccess.get_file_as_string(UI_SCRIPT_PATH)
	var inventory_service_source := FileAccess.get_file_as_string(INVENTORY_SERVICE_PATH)
	var player_source := FileAccess.get_file_as_string(PLAYER_SCRIPT_PATH)
	_check(not store_source.contains("PREVIEW_COLOR_SWATCHES"), "Store preview no longer keeps a divergent local palette")
	_check(store_source.contains("CharacterAppearanceService.CHROMA_COLOR_SWATCHES"), "Store preview uses the shared Chroma palette")
	_check(store_source.contains("ColorPickerButton.new()"), "Store preview includes a custom colour picker")
	_check(ui_source.contains("CharacterAppearanceService.SKIN_TONE_SWATCHES"), "customization uses the shared skin palette")
	_check(ui_source.contains('"skin_tone":'), "customization can read and update skin tone")
	_check(ui_source.contains("ColorPickerButton.new()"), "customization includes custom Hair and Chroma colours")
	for cosmetic_item_id: String in [
		"adinho-classic-outfit",
		"adinho-classic-sunglasses",
		"adinho-classic-shirt",
		"adinho-classic-trousers",
		"adinho-classic-shoes",
		"adinho-chroma-hair",
		"adinho-chroma-beard",
		"adinho-chroma-glasses",
		"adinho-chroma-shirt",
		"adinho-chroma-trousers",
		"adinho-chroma-shoes",
	]:
		var cosmetic_icon := APPEARANCE.get_cosmetic_item_icon(cosmetic_item_id, "male")
		_check(cosmetic_icon != null, "%s has a spritesheet-frame icon" % cosmetic_item_id)
		if cosmetic_icon != null:
			var icon_image := cosmetic_icon.get_image()
			_check(
				icon_image.get_width() <= 64 and icon_image.get_height() <= 64,
				"%s icon uses no more than one frame" % cosmetic_item_id
			)
	_check(
		APPEARANCE.get_cosmetic_item_icon("adinho-chroma-shirt", "male")
			== APPEARANCE.get_cosmetic_item_icon("adinho-chroma-shirt", "male"),
		"cosmetic frame icons are cached"
	)
	_check(
		store_source.contains("get_cosmetic_item_icon(item_id, trainer_gender)"),
		"Store cards use the shared spritesheet-frame icons"
	)
	_check(
		ui_source.contains("get_cosmetic_item_icon(item_id, \"male\")"),
		"Bag slots use the shared spritesheet-frame icons"
	)
	_check(
		inventory_service_source.contains("APPEARANCE_ITEM_RETURN_ENDPOINT")
			and inventory_service_source.contains("func return_appearance_item"),
		"inventory service exposes the wardrobe-to-Bag return action"
	)
	_check(
		player_source.contains(
			'CharacterAppearanceService.get_eyebrows_for_hair(\n'
				+ "\t\t\t\tPlayerSave.appearance_hair_id,"
		),
		"equipping hair refreshes its linked eyebrows on the overworld player"
	)
	_check(
		inventory_service_source.contains('"slotLimit"')
			and inventory_service_source.contains('"slotCounts"')
			and inventory_service_source.contains('"appearanceSlotLimit"')
			and inventory_service_source.contains('"appearanceSlotCounts"'),
		"inventory service preserves authoritative per-slot wardrobe capacity"
	)
	_check(
		inventory_service_source.contains('"grantedItems"')
			and ui_source.contains('use_action == "open_item_bundle"')
			and ui_source.contains('return "Open Box"'),
		"Bag can open the Classic box and refresh its granted component items"
	)
	_check(
		ui_source.contains('return_button.text = "×"')
			and ui_source.contains("InventoryService.return_appearance_item(source_item_id)"),
		"Character Customization exposes a return-to-Bag cross"
	)
	_check(
		ui_source.contains("const DEFAULT_APPEARANCE_SLOT_LIMIT := 8")
			and ui_source.contains("func _refresh_trainer_card_appearance_capacity_label()")
			and ui_source.contains('"%s wardrobe · %d/%d unlocked"'),
		"Character Customization shows the eight-item limit for each cosmetic slot"
	)
	_check(
		not player_source.contains("_apply_face_gear_frame_alignment")
			and not player_source.contains("_get_frame_opaque_center_y"),
		"facegear uses authored walking frames without per-frame pixel alignment"
	)
	_check(
		player_source.contains("_apply_activity_layer_offset(sprite, normalized_category)"),
		"facegear shares the normal cosmetic activity-offset path"
	)

	quit(1 if failed else 0)


func _count_opaque_colours(image: Image, exclude_near_black: bool = false) -> int:
	if image == null:
		return 0
	var colours := {}
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.001:
				continue
			if exclude_near_black and _luminance(pixel) <= 0.035:
				continue
			colours[pixel.to_html(false)] = true
	return colours.size()


func _count_changed_pixels(first: Image, second: Image) -> int:
	if first == null or second == null:
		return 0
	var changed := 0
	for y: int in range(mini(first.get_height(), second.get_height())):
		for x: int in range(mini(first.get_width(), second.get_width())):
			if not first.get_pixel(x, y).is_equal_approx(second.get_pixel(x, y)):
				changed += 1
	return changed


func _non_skin_pixels_are_preserved(source: Image, tinted: Image) -> bool:
	if source == null or tinted == null:
		return false
	for y: int in range(mini(source.get_height(), tinted.get_height())):
		for x: int in range(mini(source.get_width(), tinted.get_width())):
			var source_pixel := source.get_pixel(x, y)
			if source_pixel.a <= 0.001 or APPEARANCE._is_skin_palette_pixel(source_pixel):
				continue
			if not source_pixel.is_equal_approx(tinted.get_pixel(x, y)):
				return false
	return true


func _luminance(color: Color) -> float:
	return (color.r * 0.2126) + (color.g * 0.7152) + (color.b * 0.0722)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
