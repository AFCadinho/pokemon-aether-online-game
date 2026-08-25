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
	var hidden_ability_badge := overlay.get("pokemon_summary_hidden_ability_badge") as PanelContainer
	var title_label := overlay.get("pokemon_summary_title_label") as Label
	var gender_label := overlay.get("pokemon_summary_gender_label") as Label
	var id_label := overlay.get("pokemon_summary_id_label") as Label
	var nickname_button := overlay.get("pokemon_summary_nickname_button") as Button
	_check(popup != null, "Pokémon Summary popup is created")
	_check(
		popup != null and popup.get_theme_stylebox("panel", "TooltipPanel") is StyleBoxFlat,
		"all standard Summary hover hints use the styled tooltip card"
	)
	_check(content_panel != null, "Pokémon Summary content panel is created")
	_check(copy_button != null, "interactive Summary exposes the export-set copy action")
	if copy_button != null:
		_check(copy_button.text == "", "export-set action uses only an icon")
		_check(copy_button.icon != null, "export-set action shows a clipboard icon")
		_check(copy_button.tooltip_text != "", "export-set action explains itself on hover")
		_check(copy_button.get_index() == copy_button.get_parent().get_child_count() - 1, "export-set action sits in the fixed far-right identity column")
		_check(copy_button.custom_minimum_size == Vector2(24, 24), "export-set action uses the larger icon button")
		_check(
			copy_button.get_theme_stylebox("panel", "TooltipPanel") is StyleBoxFlat,
			"export-set hover uses the styled Summary tooltip card"
		)
	_check(
		hidden_ability_badge != null
		and hidden_ability_badge.get_theme_stylebox("panel", "TooltipPanel") is StyleBoxFlat,
		"Hidden Ability hover uses the styled Summary tooltip card"
	)
	_check(title_label != null and title_label.get_theme_font_size("font_size") == 15, "Pokémon name uses the larger identity text")
	_check(
		title_label != null and nickname_button != null
		and title_label.size_flags_horizontal == Control.SIZE_SHRINK_BEGIN,
		"gender and nickname edit action stay directly beside the Pokémon name"
	)
	_check(id_label != null and id_label.get_theme_font_size("font_size") == 10, "species and ID use the larger metadata text")
	_check(
		id_label != null and nickname_button != null
		and id_label.get_parent() == nickname_button.get_parent().get_parent(),
		"species and ID sit below the name and nickname edit action"
	)
	_check(copy_button != null and id_label != null and copy_button.get_parent() == id_label.get_parent().get_parent(), "export-set action spans both identity text rows")
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

	if title_label != null and gender_label != null and nickname_button != null:
		title_label.text = "Crabominable"
		gender_label.text = "♀"
		gender_label.visible = true
		overlay.call("_fit_pokemon_summary_title_label")
		await process_frame
		await process_frame
		_check(title_label.size.x > 80.0, "Pokémon name keeps its readable content width")
		_check(
			gender_label.global_position.x - (title_label.global_position.x + title_label.size.x) <= 5.0,
			"gender sits directly after the Pokémon name"
		)
		_check(
			nickname_button.global_position.x - (gender_label.global_position.x + gender_label.size.x) <= 5.0,
			"nickname edit action sits directly after gender"
		)

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
