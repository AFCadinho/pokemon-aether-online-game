extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var overlay := (load(OVERLAY_SCENE_PATH) as PackedScene).instantiate()
	var root_control := overlay.get_node("Control") as Control
	root_control.size = Vector2(1152, 648)
	overlay.set("root_control", root_control)
	overlay.call("_open_readonly_pokemon_summary", {
		"pokemonId": 3,
		"nationalDexNumber": 149,
		"species": "dragonite",
		"level": 55,
		"types": ["dragon", "flying"],
		"stats": {"hp": 200, "atk": 150, "def": 120, "spa": 130, "spd": 130, "spe": 100},
	})
	var card_key := str(overlay.get("pokemon_summary_active_card_key"))
	_check(card_key != "", "Summary card opens")
	_check(overlay.get("pokemon_summary_popup") != null, "Summary popup is available")
	overlay.call("_hide_pokemon_summary_popup", card_key)
	_check((overlay.get("pokemon_summary_open_cards") as Dictionary).is_empty(), "closed card is removed")
	_check(overlay.get("pokemon_summary_popup") == null, "closed popup reference is cleared")
	_check(overlay.get("pokemon_summary_ball_picker") == null, "closed ball picker reference is cleared")
	_check(overlay.get("pokemon_summary_item_picker") == null, "closed item picker reference is cleared")
	_check((overlay.call("_get_active_escape_close_candidate") as Dictionary).is_empty(), "Escape finds no freed Summary controls")
	_check(not overlay.call("_close_active_overlay_for_escape"), "Escape can continue to settings after Summary closes")
	_check_interactive_card_close(overlay)

	for loader_property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader := overlay.get(loader_property) as Node
		if loader != null:
			loader.free()
	overlay.free()
	if failed:
		push_error("Summary close and Escape check failed")
		quit(1)
	else:
		print("Summary close and Escape check passed.")
		quit()


func _check_interactive_card_close(overlay: Node) -> void:
	var card_key := "interactive-dragonite"
	overlay.call("_setup_pokemon_summary_popup", card_key)
	var popup := overlay.get("pokemon_summary_popup") as PanelContainer
	var ball_picker := overlay.get("pokemon_summary_ball_picker") as Control
	var item_picker := overlay.get("pokemon_summary_item_picker") as Control
	_check(ball_picker != null and item_picker != null, "interactive Summary creates both pickers")
	popup.visible = true
	overlay.set("pokemon_summary_active_card_key", card_key)
	overlay.set("pokemon_summary_open_cards", {
		card_key: overlay.call("_capture_pokemon_summary_card_context", card_key, Pokemon.new("dragonite", 55), "interactive", 0),
	})
	overlay.call("_hide_pokemon_summary_popup", card_key)
	_check(overlay.get("pokemon_summary_popup") == null, "interactive popup reference is cleared")
	_check(overlay.get("pokemon_summary_ball_picker") == null, "interactive ball picker reference is cleared")
	_check(overlay.get("pokemon_summary_item_picker") == null, "interactive item picker reference is cleared")
	_check((overlay.call("_get_active_escape_close_candidate") as Dictionary).is_empty(), "Escape skips closed interactive card")


func _check(condition: bool, description: String) -> void:
	if condition:
		return
	failed = true
	push_error(description)
