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
	_check(source.contains('title.text = "Pokémon Storage"'), "Storage uses a clear player-facing title")
	_check(source.contains('subtitle.text = "Organize your party and stored Pokémon"'), "Storage header explains its purpose")
	_check(source.contains('party_panel.name = "PartyPanel"'), "Party has a dedicated workspace rail")
	_check(source.contains('box_panel.name = "BoxWorkspacePanel"'), "Boxes have a dedicated workspace panel")
	_check(not source.contains('party_help.text ='), "Party rail avoids repeating the global interaction hint")
	_check(source.contains("pc_party_count_label.text ="), "Party rail reports occupied slots")
	_check(source.contains("pc_box_capacity_label.text ="), "Active box reports its capacity")
	_check(source.contains('pc_search_input.placeholder_text = "Search Pokémon across all boxes…"'), "Search clearly covers every box without an oversized prompt")
	_check(source.contains('pc_search_results_label.text = "%d FOUND"'), "Search reports the result count")
	_check(source.contains("func _create_pc_search_empty_state("), "Search has a useful empty state")
	_check(source.contains('title.text = "No Pokémon found"'), "Search empty state is player friendly")
	_check(source.contains('badge.name = "SlotBadge"'), "Every storage card exposes its slot location")
	_check(source.contains('shiny_badge.name = "ShinyBadge"'), "Shiny Pokémon keep a dedicated visual marker")
	_check(source.contains('shiny_badge.text = "✦"'), "Shiny marker uses a recognizable sparkle")
	_check(source.contains('pc_release_mode_button.text = "Release"'), "Permanent release starts behind an explicit secondary action")
	_check(source.contains('"danger" if pc_release_mode_active else "secondary"'), "Release only becomes visually dangerous while its mode is active")
	_check(source.contains('release_warning_label.text = "PERMANENT · THIS CANNOT BE UNDONE"'), "Release zone communicates permanence")
	_check(source.contains('status_panel.name = "StorageStatusBar"'), "Storage feedback has a dedicated status bar")
	_check(source.contains("func _make_pc_outer_style()"), "Storage uses its own modern outer surface")
	_check(source.contains("func _make_pc_workspace_panel_style()"), "Storage panels share one semantic visual language")
	_check(source.contains("background = UI_SURFACE_INTERACTIVE.lerp(type_background, 0.10)"), "Type colors stay a restrained slot accent")
	_check(source.contains('title.text = _pc_compact_text(title_text, 12) if occupied else ""'), "Empty box slots avoid repeated EMPTY labels")
	_check(source.contains("filter_grid.columns = 3"), "Advanced filters stay compact in two rows")
	_check(hover_source.contains("func _apply_storage_visuals()"), "Storage hover details use a dedicated restrained surface")
	_check(source.contains("button.focus_mode = Control.FOCUS_NONE"), "Storage controls cannot become stale Spacebar targets")
	_check(source.contains("PokemonStorageService.move_pokemon("), "Storage revamp preserves moving Pokémon")
	_check(source.contains("PokemonStorageService.release_pokemon("), "Storage revamp preserves releasing Pokémon")
	_check(source.contains("_open_pc_box_pokemon_summary("), "Storage revamp preserves Pokémon summaries")
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
