extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(OVERLAY_SCENE_PATH) as PackedScene
	_check(packed != null, "Summary overlay scene loads")
	if packed == null:
		quit(1)
		return

	var overlay := packed.instantiate()
	root.add_child(overlay)
	await process_frame
	var pokemon := Pokemon.new("Pikachu", 18)
	pokemon.nickname = "Sparky"
	pokemon.owned_pokemon_id = 42
	pokemon.instance_id = "owned-42"
	var player_save := root.get_node_or_null("PlayerSave")
	_check(player_save != null, "Nickname UI check can access PlayerSave")
	if player_save == null:
		overlay.free()
		quit(1)
		return
	player_save.set("party", [pokemon])

	var card_key := "interactive:owned:42"
	overlay.call("_setup_pokemon_summary_popup", card_key)
	overlay.set("pokemon_summary_mode", "interactive")
	overlay.set("pokemon_summary_selected_slot", 0)
	overlay.set("pokemon_summary_active_card_key", card_key)
	overlay.set("pokemon_summary_preview_pokemon", pokemon)
	var context: Dictionary = overlay.call("_capture_pokemon_summary_card_context", card_key, pokemon, "interactive", 0)
	var cards := {card_key: context}
	overlay.set("pokemon_summary_open_cards", cards)
	overlay.call("_refresh_pokemon_summary")

	var summary_popup := overlay.get("pokemon_summary_popup") as PanelContainer
	var title_label := overlay.get("pokemon_summary_title_label") as Label
	var id_label := overlay.get("pokemon_summary_id_label") as Label
	var edit_button := overlay.get("pokemon_summary_nickname_button") as Button
	_check(summary_popup != null and summary_popup.custom_minimum_size == Vector2(620, 380), "Nickname keeps the Summary card's fixed 620x380 contract")
	_check(title_label != null and title_label.text == "Sparky", "Summary title shows nickname (got %s)" % str(title_label.text if title_label != null else "<missing>"))
	_check(id_label != null and id_label.text.contains("Pikachu") and id_label.text.contains("42"), "Summary subtitle keeps species and id (got %s)" % str(id_label.text if id_label != null else "<missing>"))
	_check(edit_button != null and edit_button.visible, "Owned Summary shows nickname edit button")

	var summary_size_before := summary_popup.size
	overlay.call("_show_pokemon_nickname_popup", card_key, pokemon)
	var nickname_popup := overlay.get("pokemon_nickname_popup") as PanelContainer
	_check(nickname_popup != null and nickname_popup.get_parent() != summary_popup, "Nickname editor is a separate overlay")
	_check(summary_popup.size == summary_size_before, "Opening nickname editor does not resize Summary")
	var nickname_input := overlay.get("pokemon_nickname_input") as LineEdit
	_check(nickname_input != null and nickname_input.max_length == 18, "Nickname editor enforces the visible length limit")

	for loader_property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader := overlay.get(loader_property) as Node
		if loader != null:
			loader.free()
	overlay.queue_free()
	await process_frame
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
