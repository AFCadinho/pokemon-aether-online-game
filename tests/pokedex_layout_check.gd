extends SceneTree

const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"

var failures := 0


func _init() -> void:
	var source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)

	_check(source.contains("var pokedex_shell_style := _make_glass_panel_style(14)"), "Pokédex uses the modern glass shell")
	_check(source.contains('"ui.pokedex.subtitle"'), "Header explains the localized Pokédex workspace")
	_check(source.contains('"ui.pokedex.species_index"'), "Species browser has a localized visual hierarchy")
	_check(source.contains('"ui.pokedex.search"'), "Species search explains supported input")
	_check(source.contains("pokedex_results_count_label"), "Species browser exposes loading and result counts")
	_check(source.contains('"ui.pokedex.dex.national"'), "Pokédex offers the localized National Dex")
	_check(source.contains('"ui.pokedex.dex.kanto"'), "Pokédex offers the localized Kanto Dex")
	_check(source.contains("func _on_pokedex_dex_selected"), "Changing Pokédex type refreshes the species index")
	_check(source.contains("pokedex_active_dex,\n\t\tpokedex_shiny_mode"), "Species search is scoped to the selected Pokédex and sprite variant")
	_check(source.contains("selector.get_popup()") and source.contains("func _make_pokedex_dex_popup_panel_style"), "Pokédex selector popup uses the themed interface instead of Godot defaults")
	_check(source.contains('"ui.pokedex.variant.normal"') and source.contains('"ui.pokedex.variant.shiny"'), "Each Pokédex has a localized normal and shiny view")
	_check(source.contains("func _on_pokedex_variant_selected") and source.contains("pokedex_shiny_mode"), "Changing sprite variant refreshes the Pokédex")
	_check(source.contains('"shiny" if pokedex_shiny_mode else "normal"'), "Normal and shiny species icons use separate cache entries")
	_check(source.contains('candidate,\n\t\t\t_get_pokedex_sprite_side(),\n\t\t\tpokedex_shiny_mode'), "Selected species loads its shiny battle sprite when requested")
	_check(source.contains('"ui.pokedex.owned_count"'), "Each Pokédex variant shows localized owned-over-total progress")
	_check(source.contains("OwnedPokeballIcon") and source.contains('bool(species.get("owned", false))'), "Owned Pokédex entries show a Poké Ball beside their name")
	_check(source.contains('button.set_meta("owned"') and source.contains("owned_background"), "Owned Pokédex entries receive a restrained highlighted card")
	_check(source.contains('selection_accent := Color("#62d7ff")') and source.contains("2 if selected else 1"), "Selected species uses a distinct cyan two-pixel selection ring")
	_check(source.contains("pokedex_owned_icon.visible = PokedexService.is_species_owned"), "Selected owned species keeps the Poké Ball in its detail header")
	_check(source.contains('"ui.pokedex.species_record"'), "Selected species uses a localized dossier header")
	_check(source.contains("var hero_panel := PanelContainer.new()"), "Species identity and stats share a focused hero card")
	_check(source.contains("var sprite_stage_style :=") and source.contains("TEXTURE_FILTER_NEAREST"), "Species sprites use a crisp softly elevated display stage")
	_check(not source.contains("pokedex_sprite_view_label") and source.contains('"ui.pokedex.sprite.show_view"'), "Localized view controls never cover the Pokémon preview")
	_check(source.contains("round(scale_value * 4.0) / 4.0"), "Animated sprites use pixel-friendly scale steps")
	_check(source.contains("var stats_panel := PanelContainer.new()"), "Base stats use their own balanced dossier surface")
	_check(source.contains("var tab_panel := PanelContainer.new()"), "Pokédex tabs use an integrated navigation surface")
	_check(source.contains("func _style_pokedex_species_button") and source.contains("func _refresh_pokedex_species_selection_state"), "Selected species stays visually marked")
	_check(source.contains("func _create_pokedex_detail_section_title"), "Detail content uses modern section cards")
	_check(source.contains("func _create_pokedex_dossier_card") and source.contains("func _create_pokedex_profile_fact"), "General data is grouped into calm dossier cards")
	_check(source.contains('"ui.pokedex.profile.title"'), "Localized profile facts no longer render as disconnected boxes")
	_check(source.contains("PokedexService.search_species") and source.contains("PokedexService.get_species_detail"), "Existing Pokédex data loading remains connected")
	_check(source.contains("_warm_up_pokedex.call_deferred()"), "Owning the Pokédex warms its default catalog in the background")
	_check(source.contains("await PokedexService.warm_up_default_catalog()") and source.contains("index % 8 == 0"), "Pokédex icons warm incrementally without blocking one frame")
	var service_source := FileAccess.get_file_as_string("res://scripts/services/pokedex_service.gd")
	_check(service_source.contains("_species_search_cache") and service_source.contains("_species_detail_cache"), "Pokédex warm-up caches the species list and first detail")
	_check(service_source.contains("await default_catalog_warmup_finished"), "Opening during warm-up reuses the active catalog request")
	_check(source.contains('{"key": "evolution", "i18n": "evolution"'), "Pokédex has a dedicated evolution move section")
	_check(source.contains("_on_pokedex_sprite_panel_gui_input"), "Front and back sprite interaction remains available")

	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
