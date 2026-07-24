extends SceneTree

const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"
const STORAGE_ICON_PATH := "res://assets/ui/pokemon_storage.svg"

var failures := 0


func _init() -> void:
	var source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)

	_check(source.contains("const PC_POPUP_SIZE := Vector2(1160, 720)"), "Pokémon Storage uses a spacious workspace")
	_check(source.contains("const PC_BOX_SLOT_SIZE := Vector2(116, 76)"), "A complete 6 by 5 box remains visible without oversized cards")
	_check(source.contains('const POKEMON_STORAGE_ICON: Texture2D = preload("res://assets/ui/pokemon_storage.svg")'), "Storage has a dedicated interface icon")
	_check(FileAccess.file_exists(STORAGE_ICON_PATH), "Dedicated storage icon exists")
	_check(source.contains('title.text = "Pokémon Storage"'), "Storage uses a clear player-facing title")
	_check(source.contains('subtitle.text = "Organize your party and stored Pokémon"'), "Storage header explains its purpose")
	_check(source.contains('party_panel.name = "PartyPanel"'), "Party has a dedicated workspace rail")
	_check(source.contains('box_panel.name = "BoxWorkspacePanel"'), "Boxes have a dedicated workspace panel")
	_check(source.contains('party_help.text = "Click to inspect  ·  Drag to move"'), "Party rail explains core interactions")
	_check(source.contains("pc_party_count_label.text ="), "Party rail reports occupied slots")
	_check(source.contains("pc_box_capacity_label.text ="), "Active box reports its capacity")
	_check(source.contains('pc_search_input.placeholder_text = "Search all boxes by species, type, ability or held item"'), "Search clearly covers every box")
	_check(source.contains('pc_search_results_label.text = "%d FOUND"'), "Search reports the result count")
	_check(source.contains("func _create_pc_search_empty_state("), "Search has a useful empty state")
	_check(source.contains('title.text = "No Pokémon found"'), "Search empty state is player friendly")
	_check(source.contains('badge.name = "SlotBadge"'), "Every storage card exposes its slot location")
	_check(source.contains('shiny_badge.name = "ShinyBadge"'), "Shiny Pokémon keep a dedicated visual marker")
	_check(source.contains('shiny_badge.text = "✦"'), "Shiny marker uses a recognizable sparkle")
	_check(source.contains('pc_release_mode_button.text = "Release Mode"'), "Permanent release starts behind an explicit mode")
	_check(source.contains('release_warning_label.text = "PERMANENT · THIS CANNOT BE UNDONE"'), "Release zone communicates permanence")
	_check(source.contains('status_panel.name = "StorageStatusBar"'), "Storage feedback has a dedicated status bar")
	_check(source.contains("func _make_pc_outer_style()"), "Storage uses its own modern outer surface")
	_check(source.contains("func _make_pc_workspace_panel_style()"), "Storage panels share one semantic visual language")
	_check(source.contains("button.focus_mode = Control.FOCUS_NONE"), "Storage controls cannot become stale Spacebar targets")
	_check(source.contains("PokemonStorageService.move_pokemon("), "Storage revamp preserves moving Pokémon")
	_check(source.contains("PokemonStorageService.release_pokemon("), "Storage revamp preserves releasing Pokémon")
	_check(source.contains("_open_pc_box_pokemon_summary("), "Storage revamp preserves Pokémon summaries")

	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
