extends SceneTree

const STORE := preload("res://scenes/interface/donator_store_popup.tscn")
const APPEARANCE := preload("res://scripts/services/character_appearance_service.gd")
const TRAINER := preload("res://scripts/battle/battle_ui/battle_player_trainer_catalog.gd")
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 900)
	root.add_child(host)
	var store := STORE.instantiate() as DonatorStorePopup
	host.add_child(store)
	store.show()
	await process_frame
	var baseline := store.get_rect()
	store._select_product("adinho-chroma-hair")
	_check(store.character_preview_mode_row.visible and store.character_preview_direction_row.visible, "Cosmetics start with Overworld preview and directions")
	store.character_preview_mode_buttons["trainer"].pressed.emit()
	_check(store.character_preview_mode == "trainer" and not store.character_preview_direction_row.visible, "Trainer tab switches to the fixed trainer pose")
	for gender: String in ["male", "female"]:
		var appearance := APPEARANCE.get_default_appearance(gender)
		appearance["gender"] = gender
		appearance["hair_color"] = "#247aca"
		store.set_trainer_appearance(appearance)
		_check(store.trainer_gender == gender, "Preview uses the requested trainer model")
		for item: Dictionary in store.CATALOG:
			if store._preview_parts_for_item(item).is_empty():
				continue
			store._select_product(str(item.id))
			var sprite := store.character_preview_viewport.get_node_or_null("StoreTrainerPreview") as Sprite2D
			_check(sprite != null, "%s / %s has trainer art" % [gender, item.id])
			if sprite == null:
				continue
			var rendered := sprite.texture as AtlasTexture
			var expected := TRAINER.build_dialogue_portrait(store._current_character_preview_appearance())
			_check(rendered != null and rendered.atlas.get_image().get_data() == expected.get_image().get_data(), "Trainer preview matches actual outfit, model and colours")
			var footprint := Rect2(sprite.position - sprite.texture.get_size() * sprite.scale * 0.5, sprite.texture.get_size() * sprite.scale)
			_check(Rect2(Vector2.ZERO, Vector2(store.PREVIEW_VIEWPORT_SIZE)).encloses(footprint), "Full trainer art fits without clipping")

	var male_appearance := APPEARANCE.get_default_appearance("male")
	male_appearance["gender"] = "male"
	store.set_trainer_appearance(male_appearance)
	var saved := store.trainer_appearance.duplicate(true)
	store._select_product("adinho-chroma-shirt")
	var original := _portrait_pixels(store)
	store._select_character_preview_color("#aa44ff")
	_check(original != _portrait_pixels(store), "Chroma colour changes update the trainer pixels")
	var colors := store._selected_purchase_chroma_colors()
	store.character_preview_mode_buttons["overworld"].pressed.emit()
	_check(store.character_preview_direction_row.visible and store.character_preview_viewport.get_node_or_null("StoreTrainerPreview") == null, "Overworld tab restores the walking sprite and directions")
	_check(store._selected_purchase_chroma_colors() == colors, "Switching view preserves selected purchase colours")
	store._select_character_preview_direction("up")
	store.character_preview_mode_buttons["trainer"].pressed.emit()
	store.character_preview_mode_buttons["overworld"].pressed.emit()
	_check(store.character_preview_direction == "up", "Returning to Overworld preserves its selected direction")
	_check(store.trainer_appearance == saved, "Previewing does not change the equipped appearance")
	store._select_character_preview_mode("trainer")
	for item_id: String in ["aether-credit-voucher-100", "flash-charm", "squirtle-guild-emblem-template", "glaceon-mount-box"]:
		_check(not store._catalog_item(item_id).is_empty(), "Non-cosmetic test product is available")
		store._select_product(item_id)
		_check(not store.character_preview_mode_row.visible, "Non-cosmetic product hides cosmetic tabs: " + item_id)
	store._select_product("aether-voyager-outfit")
	_check(store.character_preview_mode_row.visible and store.character_preview_mode == "trainer", "Browsing other products preserves the cosmetic view preference")
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		root.get_node("LocalizationManager").set_locale(locale)
		store._select_product("aether-voyager-outfit")
		for mode: String in ["overworld", "trainer"]:
			var button := store.character_preview_mode_buttons[mode] as Button
			_check(not button.text.begins_with("ui.store."), "Preview tab localized: " + locale + " / " + mode)
			button.pressed.emit()
			for frame in range(3):
				await process_frame
			_check(store.get_rect() == baseline, "Switching preview does not resize the Store")
	host.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _portrait_pixels(store: DonatorStorePopup) -> PackedByteArray:
	var sprite := store.character_preview_viewport.get_node("StoreTrainerPreview") as Sprite2D
	return (sprite.texture as AtlasTexture).atlas.get_image().get_data()

func _check(ok: bool, message: String) -> void:
	if ok:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL " + message)
