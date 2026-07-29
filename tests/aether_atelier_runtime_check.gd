extends SceneTree

const POPUP_SCENE := preload("res://scenes/interface/aether_atelier_popup.tscn")

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
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
		}, {
			"itemId": "adinho-chroma-trousers",
			"name": "Adinho Chroma Trousers",
			"slot": "bottom",
			"appearanceId": "Adinho_Trousers_Chroma",
			"genders": ["male"],
			"color": "#ffffff",
			"fee": 2500,
			"equipped": true,
		}],
	})
	popup.call("_select_mode", "dye")
	await process_frame

	_check(str(popup.get("active_mode")) == "dye", "Atelier switches to Character Customization")
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
	_check(
		create_button != null and not create_button.disabled,
		"Character Customization enables one combined payment"
	)
	_check(
		str(create_button.text).contains("5,000"),
		"Character Customization adds the fees of both changed items"
	)

	popup.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
