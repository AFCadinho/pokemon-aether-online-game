extends SceneTree

const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"

var failures := 0


func _init() -> void:
	var source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)

	_check(source.contains("var pokedex_shell_style := _make_glass_panel_style(14)"), "Pokédex uses the modern glass shell")
	_check(source.contains('subtitle_label.text = "Species research and habitat data"'), "Header explains the Pokédex workspace")
	_check(source.contains('browser_label.text = "SPECIES INDEX"'), "Species browser has a clear visual hierarchy")
	_check(source.contains('pokedex_search_input.placeholder_text = "Search by name or number..."'), "Species search explains supported input")
	_check(source.contains("pokedex_results_count_label"), "Species browser exposes loading and result counts")
	_check(source.contains('pokedex_dex_selector.add_item("National Dex")'), "Pokédex offers the National Dex")
	_check(source.contains('pokedex_dex_selector.add_item("Kanto Dex")'), "Pokédex offers the Kanto Dex")
	_check(source.contains("func _on_pokedex_dex_selected"), "Changing Pokédex type refreshes the species index")
	_check(source.contains("pokedex_active_dex,\n\t\tpokedex_shiny_mode"), "Species search is scoped to the selected Pokédex and sprite variant")
	_check(source.contains("selector.get_popup()") and source.contains("func _make_pokedex_dex_popup_panel_style"), "Pokédex selector popup uses the themed interface instead of Godot defaults")
	_check(source.contains('_create_pokedex_variant_button("normal", "Normal")') and source.contains('_create_pokedex_variant_button("shiny", "✦ Shiny")'), "Each Pokédex has a separate normal and shiny view")
	_check(source.contains("func _on_pokedex_variant_selected") and source.contains("pokedex_shiny_mode"), "Changing sprite variant refreshes the Pokédex")
	_check(source.contains('"shiny" if pokedex_shiny_mode else "normal"'), "Normal and shiny species icons use separate cache entries")
	_check(source.contains('candidate,\n\t\t\t_get_pokedex_sprite_side(),\n\t\t\tpokedex_shiny_mode'), "Selected species loads its shiny battle sprite when requested")
	_check(source.contains('pokedex_results_count_label.text = "OWNED %d / %d"'), "Each Pokédex variant shows its owned-over-total progress")
	_check(source.contains("OwnedPokeballIcon") and source.contains('bool(species.get("owned", false))'), "Owned Pokédex entries show a Poké Ball beside their name")
	_check(source.contains('button.set_meta("owned"') and source.contains("owned_background"), "Owned Pokédex entries receive a restrained highlighted card")
	_check(source.contains('selection_accent := Color("#62d7ff")') and source.contains("2 if selected else 1"), "Selected species uses a distinct cyan two-pixel selection ring")
	_check(source.contains("pokedex_owned_icon.visible = PokedexService.is_species_owned"), "Selected owned species keeps the Poké Ball in its detail header")
	_check(source.contains('record_label.text = "SPECIES RECORD"'), "Selected species uses a dedicated dossier header")
	_check(source.contains("var hero_panel := PanelContainer.new()"), "Species identity and stats share a focused hero card")
	_check(source.contains("var sprite_stage_style :=") and source.contains("TEXTURE_FILTER_NEAREST"), "Species sprites use a crisp softly elevated display stage")
	_check(not source.contains("pokedex_sprite_view_label") and source.contains('pokedex_sprite_panel.tooltip_text = "Show the %s view"'), "View controls never cover the Pokémon preview")
	_check(source.contains("round(scale_value * 4.0) / 4.0"), "Animated sprites use pixel-friendly scale steps")
	_check(source.contains("var stats_panel := PanelContainer.new()"), "Base stats use their own balanced dossier surface")
	_check(source.contains("var tab_panel := PanelContainer.new()"), "Pokédex tabs use an integrated navigation surface")
	_check(source.contains("func _style_pokedex_species_button") and source.contains("func _refresh_pokedex_species_selection_state"), "Selected species stays visually marked")
	_check(source.contains("func _create_pokedex_detail_section_title"), "Detail content uses modern section cards")
	_check(source.contains("func _create_pokedex_dossier_card") and source.contains("func _create_pokedex_profile_fact"), "General data is grouped into calm dossier cards")
	_check(source.contains('var profile_card := _create_pokedex_dossier_card("Species Profile"'), "Profile facts no longer render as a stack of disconnected boxes")
	_check(source.contains("PokedexService.search_species") and source.contains("PokedexService.get_species_detail"), "Existing Pokédex data loading remains connected")
	_check(source.contains("_on_pokedex_sprite_panel_gui_input"), "Front and back sprite interaction remains available")

	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
