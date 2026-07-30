extends SceneTree

const POPUP_SCENE := preload("res://scenes/interface/aether_atelier_popup.tscn")

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var localization_manager := root.get_node_or_null("LocalizationManager")
	if localization_manager != null:
		localization_manager.set_locale("en")
	var popup := POPUP_SCENE.instantiate() as AetherAtelierPopup
	root.add_child(popup)
	await process_frame
	popup.call("_apply_catalog", {
		"wallet": {"money": 10000},
		"outfits": [],
		"chromaItems": [{
			"itemId": "adinho-chroma-shirt",
			"name": "Adinho Chroma Shirt",
			"slot": "top",
			"appearanceId": "Adinho_Shirt_Chroma",
			"genders": ["male"],
			"color": "#ffffff",
			"fee": 2500,
			"equipped": true,
			"tintable": true,
		}, {
			"itemId": "adinho-chroma-trousers",
			"name": "Adinho Chroma Trousers",
			"slot": "bottom",
			"appearanceId": "Adinho_Trousers_Chroma",
			"genders": ["male"],
			"color": "#ffffff",
			"fee": 2500,
			"equipped": true,
			"tintable": true,
		}, {
			"itemId": "adinho-classic-sunglasses",
			"name": "Adinho Classic Sunglasses",
			"slot": "facegear",
			"appearanceId": "Adinho_Glasses",
			"genders": ["male", "female"],
			"color": "#ffffff",
			"fee": 0,
			"equipped": false,
			"tintable": false,
		}],
	})
	popup.call("_select_mode", "dye")
	await process_frame

	_check(str(popup.get("active_mode")) == "dye", "Atelier switches to Character Customization")
	var catalog_caption := popup.get("catalog_caption_label") as Label
	_check(
		catalog_caption != null and catalog_caption.text == "APPEARANCE WEAR",
		"Character Customization labels the catalog as Appearance Wear"
	)
	var catalog_list := popup.get("outfit_list") as VBoxContainer
	var section_labels: Array[String] = []
	for child: Node in catalog_list.get_children():
		if child is Label:
			section_labels.append((child as Label).text)
	_check(
		section_labels == ["FACEGEAR", "TOPS", "BOTTOMS"],
		"Appearance Wear parts use a stable slot order with section headings"
	)
	_check(
		str(popup.get("selected_chroma_item_id")) == "adinho-chroma-shirt",
		"Atelier selects a worn Chroma item"
	)
	var preview_container := popup.get("preview_container") as SubViewportContainer
	_check(
		preview_container != null and preview_container.visible,
		"Character Customization displays the trainer preview"
	)
	popup.call("_select_dye_color", "#7a46c5")
	_check(
		str(popup.get("selected_chroma_color")) == "#7a46c5",
		"Character Customization accepts a preview colour without applying it"
	)
	var create_button := popup.get("create_button") as Button
	popup.call("_select_chroma_item", "adinho-chroma-trousers")
	popup.call("_select_dye_color", "#285f9e")
	popup.call("_select_chroma_item", "adinho-classic-sunglasses")
	_check(
		create_button != null and not create_button.disabled,
		"Character Customization enables one combined payment"
	)
	_check(
		str(create_button.text).contains("5,000"),
		"Character Customization adds the fees of both changed items"
	)
	_check(
		str((popup.get("selected_wear_item_ids") as Dictionary).get("facegear", ""))
			== "adinho-classic-sunglasses",
		"Character Customization can switch to a non-Chroma Appearance Wear item for free"
	)
	if localization_manager != null:
		localization_manager.set_locale("nl")
		await process_frame
		var search := popup.get("search_input") as LineEdit
		_check(
			search != null and search.placeholder_text == "Zoek in Appearance Wear...",
			"Atelier search refreshes live in Dutch"
		)
		var money_label := popup.get("money_label") as Label
		_check(
			money_label != null and money_label.text.begins_with("Geld:"),
			"Atelier wallet label refreshes live in Dutch"
		)
		localization_manager.set_locale("en")
		await process_frame

	popup.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
