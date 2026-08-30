extends SceneTree

const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"
const PARTY_HOVER_SCRIPT_PATH := "res://scripts/battle/battle_ui/party_hover_card.gd"
const PARTY_HOVER_SCENE := preload("res://scenes/battle/party_hover_card.tscn")
const STORAGE_ICON_PATH := "res://assets/ui/pokemon_storage.svg"

var failures := 0


func _init() -> void:
	var source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)
	var hover_source := FileAccess.get_file_as_string(PARTY_HOVER_SCRIPT_PATH)

	_check(source.contains("const PC_POPUP_SIZE := Vector2(1160, 720)"), "Pokémon Storage uses a spacious workspace")
	_check(source.contains("const PC_BOX_SLOT_SIZE := Vector2(118, 80)"), "A complete 6 by 5 box uses roomier collection cards")
	_check(source.contains('const POKEMON_STORAGE_ICON: Texture2D = preload("res://assets/ui/pokemon_storage.svg")'), "Storage has a dedicated interface icon")
	_check(FileAccess.file_exists(STORAGE_ICON_PATH), "Dedicated storage icon exists")
	_check(source.contains('_set_localized_control_property(title, "text", "ui.storage.title")'), "Storage uses a clear localized title")
	_check(source.contains('_set_localized_control_property(subtitle, "text", "ui.storage.subtitle")'), "Storage header explains its purpose")
	_check(source.contains('party_panel.name = "PartyPanel"'), "Party has a dedicated workspace rail")
	_check(source.contains('box_panel.name = "BoxWorkspacePanel"'), "Boxes have a dedicated workspace panel")
	_check(not source.contains('party_help.text ='), "Party rail avoids repeating the global interaction hint")
	_check(source.contains("pc_party_count_label.text ="), "Party rail reports occupied slots")
	_check(source.contains("pc_box_capacity_label.text ="), "Active box reports its capacity")
	_check(source.contains('_set_localized_control_property(pc_search_input, "placeholder_text", "ui.storage.search")'), "Search clearly covers every box without an oversized prompt")
	_check(source.contains('"ui.storage.search_found.one"'), "Search reports the result count")
	_check(source.contains("func _create_pc_search_empty_state("), "Search has a useful empty state")
	_check(source.contains('_set_localized_control_property(title, "text", "ui.storage.empty.title")'), "Search empty state is player friendly")
	_check(source.contains('badge.name = "SlotBadge"'), "Every storage card exposes its slot location")
	_check(source.contains('shiny_badge.name = "ShinyBadge"'), "Shiny Pokémon keep a dedicated visual marker")
	_check(source.contains('shiny_badge.text = "✦"'), "Shiny marker uses a recognizable sparkle")
	_check(source.contains('_set_localized_control_property(pc_release_mode_button, "text", "ui.storage.release")'), "Permanent release starts behind an explicit secondary action")
	_check(source.contains('"danger" if pc_release_mode_active else "secondary"'), "Release only becomes visually dangerous while its mode is active")
	_check(source.contains('_set_localized_control_property(release_warning_label, "text", "ui.storage.release.warning")'), "Release zone communicates permanence")
	_check(source.contains("status_row.add_child(pc_release_mode_button)"), "Release stays in the contextual status bar instead of global navigation")
	_check(source.contains('func _apply_pc_action_button_style(button: Button, role: String)'), "Storage owns a semantic action-button style system")
	_check(source.contains('_apply_pc_action_button_style(pc_box_selector_button, "primary")'), "Box selector is the single primary Storage action")
	_check(source.contains('_apply_pc_action_button_style(pc_box_tab_prev_button, "icon")'), "Box arrows use compact icon styling")
	_check(source.contains('_apply_pc_action_button_style(pc_close_button, "close")'), "Storage close action reserves red for hover")
	_check(source.contains('status_panel.name = "StorageStatusBar"'), "Storage feedback has a dedicated status bar")
	_check(source.contains("func _make_pc_outer_style()"), "Storage uses its own modern outer surface")
	_check(source.contains("func _make_pc_workspace_panel_style()"), "Storage panels share one semantic visual language")
	_check(source.contains("background = UI_SURFACE_INTERACTIVE.lerp(type_background, 0.10)"), "Type colors stay a restrained slot accent")
	_check(source.contains('title.text = _pc_compact_text(title_text, 12) if occupied else ""'), "Empty box slots avoid repeated EMPTY labels")
	_check(source.contains('button.modulate = Color(1.0, 1.0, 1.0, 0.50)'), "Empty box slots stay visually quiet")
	_check(source.contains("filter_grid.columns = 3"), "Advanced filters stay compact in two rows")
	_check(source.contains("func _on_pc_clear_filters_pressed()"), "Advanced filters provide one clear action")
	_check(source.contains("func _refresh_pc_filter_control()"), "Active filters stay visible in the toolbar")
	_check(source.contains('_apply_pc_action_button_style(pc_release_mode_button, "danger" if pc_release_mode_active else "secondary")'), "Release becomes dangerous only while release mode is active")
	_check(hover_source.contains("func _apply_storage_visuals()"), "Storage hover details use a dedicated restrained surface")
	_check(hover_source.contains("func position_beside_rect_within("), "Storage hover details support navigation-safe positioning")
	_check(source.contains("header.mouse_default_cursor_shape = Control.CURSOR_MOVE"), "Storage header advertises that the window can be moved")
	_check(source.contains("_set_pc_header_cursor(Control.CURSOR_DRAG)"), "Storage header switches cursor while it is being dragged")
	_check(source.contains("Control.CURSOR_DRAG if occupied else Control.CURSOR_ARROW"), "Occupied Pokémon slots advertise drag behavior")
	_check(source.contains('button.self_modulate = Color("#c9f4ff")'), "Valid storage targets receive a clear visual state")
	_check(source.contains('pc_box_selector_button.text = "%s  ▾" % box_name'), "Box navigation uses one named selector between previous and next")
	_check(not source.contains("pc_box_tab_bar"), "Storage avoids a duplicate row of box tabs")
	_check(source.contains("button.focus_mode = Control.FOCUS_NONE"), "Storage controls cannot become stale Spacebar targets")
	_check(source.contains("PokemonStorageService.move_pokemon("), "Storage revamp preserves moving Pokémon")
	_check(source.contains("PokemonStorageService.release_pokemon("), "Storage revamp preserves releasing Pokémon")
	_check(source.contains("_open_pc_box_pokemon_summary("), "Storage revamp preserves Pokémon summaries")
	_check(source.contains("MOUSE_BUTTON_RIGHT"), "Occupied box slots expose right-click actions")
	_check(source.contains("func _open_pc_slot_context_menu("), "Storage owns a focused Pokémon context menu")
	_check(source.contains("PlayerPartyStateService.take_pokemon_held_item(pokemon_id)"), "Storage reuses the atomic held-item service action")
	_check(source.contains('button.set_meta("pc_pokemon_payload"'), "Box actions retain the exact Pokémon held-item payload")
	_check(source.contains("bag_inventory_items = _normalize_bag_inventory_items(result.get(\"inventory\", []))"), "Taking an item refreshes the local Bag state")
	_check(source.contains("await _refresh_pc_state(true)"), "Taking an item reloads authoritative box state")
	_check(source.contains("PcPokemonHoverCard"), "Storage exposes battle-style Pokémon information on hover")
	_check_storage_hover_surface()

	quit(1 if failures > 0 else 0)


func _check_storage_hover_surface() -> void:
	var card := PARTY_HOVER_SCENE.instantiate() as PartyHoverCard
	card.set_show_storage_details(true)
	root.add_child(card)
	var style := card.get_theme_stylebox("panel") as StyleBoxFlat
	_check(style != null, "Storage hover surface provides a panel style")
	if style != null:
		_check(style.border_width_left == 2, "Storage hover surface uses one restrained accent edge")
		_check(style.shadow_color.a > 0.0, "Storage hover surface keeps a compact shadow")
	card.free()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
