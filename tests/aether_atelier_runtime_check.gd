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
		"wallet": {"money": 5000},
		"outfits": [],
		"chromaItems": [{
			"itemId": "adinho-chroma-shirt",
			"name": "Adinho Chroma Shirt",
			"slot": "top",
			"appearanceId": "Adinho_Shirt_Chroma",
			"genders": ["male"],
			"color": "#ffffff",
			"fee": 2500,
		}],
	})
	popup.call("_select_mode", "dye")
	await process_frame

	_check(str(popup.get("active_mode")) == "dye", "Atelier switches to Chroma Dye")
	_check(
		str(popup.get("selected_chroma_item_id")) == "adinho-chroma-shirt",
		"Atelier selects an owned Chroma wardrobe item"
	)
	var preview_container := popup.get("preview_container") as SubViewportContainer
	_check(
		preview_container != null and preview_container.visible,
		"Chroma Dye displays the trainer preview"
	)
	popup.call("_select_dye_color", "#7a46c5")
	_check(
		str(popup.get("selected_chroma_color")) == "#7a46c5",
		"Chroma Dye accepts a preview colour without applying it"
	)
	var create_button := popup.get("create_button") as Button
	_check(
		create_button != null and not create_button.disabled,
		"Chroma Dye enables payment for a changed affordable colour"
	)

	popup.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
