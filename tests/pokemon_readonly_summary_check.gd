extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"
const EXPECTED_SIZE := Vector2(620, 380)

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(OVERLAY_SCENE_PATH) as PackedScene
	_check(packed != null, "read-only Summary scene loads")
	if packed == null:
		quit(1)
		return

	var overlay := packed.instantiate()
	var root_control := overlay.get_node_or_null("Control") as Control
	root_control.size = Vector2(1152, 648)
	overlay.set("root_control", root_control)
	overlay.call("_setup_pokemon_summary_ev_allocate_popup")
	var ev_allocate_popup := overlay.get("pokemon_summary_ev_allocate_popup") as PanelContainer
	var ev_allocate_input := overlay.get("pokemon_summary_ev_allocate_input") as SpinBox
	var ev_allocate_status_panel := overlay.get("pokemon_summary_ev_allocate_status_panel") as PanelContainer
	var ev_allocate_confirm := overlay.get("pokemon_summary_ev_allocate_confirm_button") as Button
	_check(ev_allocate_popup.custom_minimum_size == Vector2(380, 250), "EV allocation uses a spacious Summary dialog")
	_check(ev_allocate_input.get_line_edit().get_theme_stylebox("normal") is StyleBoxFlat, "EV allocation input replaces the default Godot field")
	_check(ev_allocate_input.get_theme_icon("updown").resource_path.ends_with("ev_allocation_spinbox_updown.svg"), "EV allocation stepper uses the Summary arrow artwork")
	_check(ev_allocate_status_panel.get_theme_stylebox("panel") is StyleBoxFlat, "EV allocation preview uses a layered Summary surface")
	_check(ev_allocate_confirm.get_theme_stylebox("disabled") is StyleBoxFlat, "EV allocation Confirm action has a styled disabled state")
	var stale_left_panel := PanelContainer.new()
	overlay.set("pokemon_summary_left_panel", stale_left_panel)
	stale_left_panel.free()
	overlay.call("_open_readonly_pokemon_summary", _sample_pokemon())
	await process_frame
	await process_frame

	var popup := overlay.get("pokemon_summary_popup") as PanelContainer
	_check(popup != null, "read-only Summary opens a dedicated card")
	_check(popup.name == "PokemonReadonlySummaryPopup", "read-only Summary uses the compact layout")
	_check(popup.size == EXPECTED_SIZE, "read-only Summary keeps its fixed production size")
	_check(popup.size == Vector2(620, 380), "read-only and interactive summaries share the same window geometry")
	_check(popup.has_meta("readonly_summary_nodes"), "read-only Summary exposes its one-page content")
	var nodes := popup.get_meta("readonly_summary_nodes", {}) as Dictionary
	var active_card_key := str(overlay.get("pokemon_summary_active_card_key"))
	var context := (overlay.get("pokemon_summary_open_cards") as Dictionary).get(active_card_key, {}) as Dictionary
	_check(not nodes.has("readonly_label"), "read-only Summary no longer shows a redundant READ ONLY badge")
	var drag_handle := nodes.get("drag_handle") as PanelContainer
	_check(drag_handle != null, "read-only Summary exposes its header as a drag handle")
	_check(drag_handle.mouse_default_cursor_shape == Control.CURSOR_MOVE, "drag handle advertises that the card can move")
	_check(drag_handle.tooltip_text != "", "drag handle explains its interaction on hover")
	_check(drag_handle.gui_input.has_connections(), "read-only header is connected to the shared drag handler")
	_check(context.get("left_panel") == null, "read-only Summary does not retain controls from a closed card")
	_check(overlay.call("_apply_pokemon_summary_card_context", active_card_key), "read-only Summary context remains safe to reactivate")
	_check((nodes.get("stat_rows", {}) as Dictionary).size() == 6, "all six stats render at once")
	var stats_grid := nodes.get("stats_grid") as GridContainer
	var stats_headings := nodes.get("stats_headings") as Array
	var last_stats_heading := stats_headings.back() as Label
	_check(
		last_stats_heading.position.x + last_stats_heading.size.x >= stats_grid.size.x - 1.0,
		"stat columns use the complete panel width"
	)
	_check((nodes.get("move_nodes", []) as Array).size() == 4, "all four moves render at once")
	_check((nodes.get("type_row") as HBoxContainer).get_child_count() == 2, "both Pokémon types render as chips")
	_check((nodes.get("name_label") as Label).text == "Garchomp", "localized Pokémon identity renders")
	_check((nodes.get("id_label") as Label).text == "#445", "header uses the National Dex number instead of the owned Pokémon id")
	_check((nodes.get("gender_label") as Label).text == "♀", "gender renders beside the Pokémon name")
	_check((nodes.get("ability_label") as Label).text != "", "ability renders on the overview")
	_check((nodes.get("ability_stack") as VBoxContainer).tooltip_text == "", "ability uses the compact hover card instead of a native tooltip")
	_check((nodes.get("nature_stack") as VBoxContainer).tooltip_text == "", "nature uses the compact hover card instead of a native tooltip")
	_check((nodes.get("iv_total_label") as Label).text.contains("186/186"), "perfect IV quality is summarized in the profile")
	_check((nodes.get("ev_total_label") as Label).text.contains("508/510"), "allocated EV total is summarized in the profile")
	_check((nodes.get("iv_total_label_panel") as PanelContainer).tooltip_text == "", "IV quality uses the compact hover card")
	_check((nodes.get("ev_total_label_panel") as PanelContainer).tooltip_text == "", "EV quality uses the compact hover card")
	_check((nodes.get("item_icon") as TextureRect).texture != null, "held item renders its icon")
	_check((nodes.get("item_panel") as PanelContainer).tooltip_text == "", "held item uses the compact hover card")
	_check((nodes.get("trainer_label") as Label).text.contains("Exchange"), "read-only Summary keeps the standard owner bar")
	_check(overlay.get("pokemon_summary_animated_sprite") is AnimatedSprite2D, "read-only Summary uses the standard animated sprite stage")
	var stat_rows := nodes.get("stat_rows", {}) as Dictionary
	_check(((stat_rows.get("atk") as Dictionary).get("iv") as Label).text == "31", "IV values render in the stat table")
	_check(((stat_rows.get("spe") as Dictionary).get("ev") as Label).text == "252", "EV values render in the stat table")
	var move_nodes := nodes.get("move_nodes", []) as Array
	_check(((move_nodes[0] as Dictionary).get("name") as Label).text == "Earthquake", "move names render in the move grid")
	var first_move_panel := (move_nodes[0] as Dictionary).get("panel") as PanelContainer
	var second_move_panel := (move_nodes[1] as Dictionary).get("panel") as PanelContainer
	var move_hover_panel := nodes.get("move_hover_panel") as PanelContainer
	_check(first_move_panel.tooltip_text == "", "moves do not use the unbounded native text tooltip")
	_check(first_move_panel.mouse_entered.has_connections(), "move tiles open the compact hover card")
	overlay.call("_show_readonly_summary_move_hover", first_move_panel, nodes)
	_check(move_hover_panel.visible, "move hover opens a dedicated detail card")
	_check(move_hover_panel.size == Vector2(254, 156), "move hover uses a consistent compact size")
	_check(popup.get_global_rect().encloses(move_hover_panel.get_global_rect()), "move hover stays inside the Summary card")
	var first_hover_position := move_hover_panel.position
	var hover_labels := move_hover_panel.find_children("*", "Label", true, false)
	_check(not hover_labels.is_empty() and (hover_labels[0] as Label).text == "Earthquake", "move hover shows the selected move details")
	overlay.call("_hide_readonly_summary_move_hover", first_move_panel, nodes)
	_check(not move_hover_panel.visible, "move hover closes when leaving a tile")
	var ability_label := nodes.get("ability_label") as Label
	var detail_hover_panel := nodes.get("detail_hover_panel") as PanelContainer
	overlay.call("_show_readonly_summary_detail_hover", ability_label, nodes)
	await process_frame
	await process_frame
	_check(detail_hover_panel.visible, "ability opens the compact hover card")
	_check(detail_hover_panel.size.y <= 100.0, "short ability details use a content-sized hover card")
	var detail_labels := detail_hover_panel.find_children("*", "Label", true, false)
	var detail_title := detail_labels.front() as Label
	var detail_description := detail_labels.back() as Label
	var expected_detail_height := detail_title.custom_minimum_size.y + 5.0 + detail_description.custom_minimum_size.y + 18.0
	_check(is_equal_approx(detail_hover_panel.size.y, expected_detail_height), "detail hover height follows its content without unused space")
	var position_source := Control.new()
	position_source.position = Vector2(300, 250)
	position_source.size = Vector2(80, 20)
	(nodes.get("move_hover_layer") as Control).add_child(position_source)
	overlay.call("_position_readonly_summary_detail_hover", detail_hover_panel, popup, position_source, detail_hover_panel.size)
	_check(not detail_hover_panel.get_global_rect().intersects(position_source.get_global_rect()), "ability hover is positioned above the hovered ability")
	_check(absf(detail_hover_panel.get_global_rect().end.y - position_source.get_global_rect().position.y) <= 5.0, "ability hover sits directly above the hovered text")
	position_source.free()
	_check((detail_hover_panel.find_children("*", "Label", true, false)[0] as Label).text == "Rough Skin", "ability hover shows its name")
	overlay.call("_hide_readonly_summary_detail_hover", nodes)
	var item_panel := nodes.get("item_panel") as PanelContainer
	overlay.call("_show_readonly_summary_detail_hover", item_panel, nodes)
	_check(detail_hover_panel.visible, "held item opens the compact hover card")
	_check((detail_hover_panel.find_children("*", "Label", true, false)[0] as Label).text == "Life Orb", "held item hover shows its name")
	overlay.call("_hide_readonly_summary_detail_hover", nodes)
	overlay.call("_show_readonly_summary_move_hover", second_move_panel, nodes)
	_check(move_hover_panel.position == first_hover_position, "every move uses the same hover position")
	_check(not popup.find_children("*", "ScrollContainer", true, false).size(), "read-only Summary needs no scrolling")

	for loader_property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader := overlay.get(loader_property) as Node
		if loader != null:
			loader.free()
	overlay.free()
	quit(1 if failed else 0)


func _sample_pokemon() -> Dictionary:
	return {
		"pokemonId": 3,
		"nationalDexNumber": 445,
		"species": "garchomp",
		"nickname": null,
		"gender": "Female",
		"level": 100,
		"nature": "Jolly",
		"ability": "rough-skin",
		"hiddenAbility": true,
		"shiny": false,
		"item": "life-orb",
		"types": ["dragon", "ground"],
		"ivs": {"hp": 31, "atk": 31, "def": 31, "spa": 31, "spd": 31, "spe": 31},
		"evs": {"hp": 0, "atk": 252, "def": 0, "spa": 0, "spd": 4, "spe": 252},
		"stats": {"hp": 357, "atk": 359, "def": 226, "spa": 176, "spd": 207, "spe": 333},
		"moves": [
			{"id": "earthquake", "name": "Earthquake", "type": "ground", "pp": 10, "maxPp": 10},
			{"id": "swords-dance", "name": "Swords Dance", "type": "normal", "pp": 20, "maxPp": 20},
			{"id": "stealth-rock", "name": "Stealth Rock", "type": "rock", "pp": 20, "maxPp": 20},
			{"id": "outrage", "name": "Outrage", "type": "dragon", "pp": 10, "maxPp": 10},
		],
		"origin": {"currentTrainerName": "Exchange"},
	}


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error(label)
