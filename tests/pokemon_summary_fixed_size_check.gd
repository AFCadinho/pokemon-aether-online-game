extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"
var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(OVERLAY_SCENE_PATH) as PackedScene
	_check(packed != null, "Pokémon Summary scene loads")
	if packed == null:
		quit(1)
		return

	var overlay := packed.instantiate()
	var host := Control.new()
	host.size = Vector2(1280, 720)
	root.add_child(host)
	overlay.set("root_control", host)
	overlay.call("_setup_pokemon_summary_popup", "fixed_size_check")

	var popup := overlay.get("pokemon_summary_popup") as PanelContainer
	var content_panel := overlay.get("pokemon_summary_content_panel") as PanelContainer
	var copy_button := overlay.get("pokemon_summary_copy_button") as Button
	_check(popup != null, "Pokémon Summary popup is created")
	_check(content_panel != null, "Pokémon Summary content panel is created")
	_check(copy_button != null, "interactive Summary exposes the PokéPaste copy action")
	if copy_button != null:
		_check(copy_button.text == "", "PokéPaste action uses only an icon")
		_check(copy_button.icon != null, "PokéPaste action shows a clipboard icon")
		_check(copy_button.tooltip_text != "", "PokéPaste action explains itself on hover")
		_check(copy_button.get_index() == copy_button.get_parent().get_child_count() - 1, "PokéPaste action sits at the far right of the name row")
	if popup == null or content_panel == null:
		host.queue_free()
		overlay.free()
		quit(1)
		return

	var content_viewport := content_panel.get_node_or_null("SummaryContentViewport") as Control
	_check(content_viewport != null, "tab content is isolated in a fixed-size viewport")
	_check(content_panel.clip_contents, "tab content is clipped to the fixed content panel")
	overlay.call("_set_pokemon_summary_popup_size")
	await process_frame
	await process_frame
	var fixed_summary_size := popup.size

	var pokemon := Pokemon.new(
		"Pikachu",
		50,
		"",
		"static",
		"Timid",
		{},
		{},
		{"hp": 120, "atk": 75, "def": 80, "spa": 130, "spd": 95, "spe": 140},
		[],
		"summary-size-check",
		1,
		false,
		false,
		["electric"],
		["static"],
		"A location name long enough to exercise Info layout",
		{
			"originalTrainerName": "A trainer name long enough to exercise Info layout",
			"caughtAt": "2026-08-18T12:00:00Z",
			"method": "caught",
			"metLevel": 5,
		}
	)

	var tab_sizes: Dictionary = {}
	for tab_id: String in ["general", "ivs", "evs"]:
		overlay.set("pokemon_summary_active_tab", tab_id)
		overlay.call("_render_pokemon_summary_content", pokemon)
		overlay.call("_set_pokemon_summary_popup_size")
		await process_frame
		await process_frame
		tab_sizes[tab_id] = popup.size
		_check(
			popup.size.is_equal_approx(fixed_summary_size),
			"%s tab keeps the fixed summary size (received %s)" % [tab_id, popup.size]
		)

	_check(tab_sizes.get("general") == tab_sizes.get("ivs"), "Info and IV tabs use the same card size")
	_check(tab_sizes.get("general") == tab_sizes.get("evs"), "Info and EV tabs use the same card size")

	for loader_property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader := overlay.get(loader_property) as Node
		if loader != null:
			loader.free()
	overlay.free()
	host.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
