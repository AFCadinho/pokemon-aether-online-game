extends SceneTree

const CATALOG_PATHS: Dictionary = {
	"en": "res://localization/content/en.json",
	"nl": "res://localization/content/nl.json",
	"pt_BR": "res://localization/content/pt_BR.json",
	"zh_CN": "res://localization/content/zh_CN.json",
}
const GENERATED_CATALOG_PATHS: Dictionary = {
	"en": "res://localization/content/generated/en.json",
	"nl": "res://localization/content/generated/nl.json",
	"pt_BR": "res://localization/content/generated/pt_BR.json",
	"zh_CN": "res://localization/content/generated/zh_CN.json",
}
const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"
const CALC_PANEL_SCRIPT := preload("res://scripts/battle/battle_ui/battle_damage_calc_panel.gd")
const PARTY_HOVER_CARD_SCRIPT := "res://scripts/battle/battle_ui/party_hover_card.gd"

var failed := false
var localization_manager: Node
var content_localization: Node
var settings_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	localization_manager = root.get_node_or_null("LocalizationManager")
	content_localization = root.get_node_or_null("ContentLocalization")
	settings_manager = root.get_node_or_null("SettingsManager")
	_check(localization_manager != null, "content-data check can access LocalizationManager")
	_check(content_localization != null, "content-data check can access ContentLocalization")
	_check(settings_manager != null, "content-data check can access SettingsManager")
	if localization_manager == null or content_localization == null or settings_manager == null:
		quit(1)
		return

	var original_locale := str(localization_manager.get("current_locale"))
	var original_settings_locale := str(settings_manager.get("locale"))
	var original_content_name_language := str(settings_manager.get("content_name_language"))
	settings_manager.set("content_name_language", "localized")
	_check_catalogs()
	_check_runtime_resolution()
	_check_independent_name_language()
	_check_search_terms_preserve_canonical_values()
	_check_runtime_consumers()
	settings_manager.set("locale", original_settings_locale)
	settings_manager.set("content_name_language", original_content_name_language)
	localization_manager.call("set_locale", original_locale)
	quit(1 if failed else 0)


func _check_catalogs() -> void:
	var catalogs: Dictionary = {}
	for locale: String in CATALOG_PATHS:
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(str(CATALOG_PATHS[locale]))
		)
		_check(parsed is Dictionary, "%s content catalog is valid JSON" % locale)
		catalogs[locale] = parsed as Dictionary if parsed is Dictionary else {}

	var english: Dictionary = catalogs.get("en", {})
	var expected_sizes := {
		"types": 18,
		"natures": 25,
		"moves": 65,
		"abilities": 20,
	}
	for kind: String in expected_sizes:
		var english_entries: Dictionary = english.get(kind, {})
		_check(
			english_entries.size() == int(expected_sizes.get(kind, 0)),
			"English %s catalog is complete" % kind
		)
		var english_ids: Array = english_entries.keys()
		english_ids.sort()
		for locale: String in CATALOG_PATHS:
			var entries: Dictionary = (catalogs.get(locale, {}) as Dictionary).get(kind, {})
			var localized_ids: Array = entries.keys()
			localized_ids.sort()
			_check(localized_ids == english_ids, "%s %s IDs match English" % [locale, kind])
			for content_id_value: Variant in english_ids:
				var content_id := str(content_id_value)
				var entry: Dictionary = entries.get(content_id, {})
				_check(not str(entry.get("name", "")).strip_edges().is_empty(), "%s %s %s has a name" % [locale, kind, content_id])
				if kind in ["moves", "abilities"]:
					_check(
						not str(entry.get("shortDesc", "")).strip_edges().is_empty(),
						"%s %s %s has a short description" % [locale, kind, content_id]
					)

	var generated_catalogs: Dictionary = {}
	for locale: String in GENERATED_CATALOG_PATHS:
		var generated_value: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(str(GENERATED_CATALOG_PATHS.get(locale, "")))
		)
		_check(generated_value is Dictionary, "generated %s content catalog is valid JSON" % locale)
		generated_catalogs[locale] = generated_value as Dictionary if generated_value is Dictionary else {}

	var generated_english: Dictionary = generated_catalogs.get("en", {})
	var expected_hidden_power_descriptions := {
		"en": "Power is always 60. Its type depends on the Pokémon using it.",
		"nl": "De kracht is altijd 60. Het type hangt af van de Pokémon die de aanval gebruikt.",
		"pt_BR": "O poder é sempre 60. O tipo depende do Pokémon que usa o golpe.",
		"zh_CN": "威力固定为 60。属性取决于使用该招式的宝可梦。",
	}
	for locale: String in GENERATED_CATALOG_PATHS:
		var generated_moves: Dictionary = (generated_catalogs.get(locale, {}) as Dictionary).get("moves", {})
		var hidden_power: Dictionary = generated_moves.get("hidden-power", {})
		_check(
			str(hidden_power.get("shortDesc", "")) == str(expected_hidden_power_descriptions.get(locale, "")),
			"generated %s Hidden Power description uses its fixed 60 Power" % locale
		)
	var summary_index_value: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/move_summary_index.json")
	)
	var summary_index: Dictionary = summary_index_value as Dictionary if summary_index_value is Dictionary else {}
	var summary_hidden_power: Dictionary = summary_index.get("hidden-power", {})
	_check(
		str(summary_hidden_power.get("shortDesc", "")).contains("always 60")
		and not str(summary_hidden_power.get("desc", "")).contains("30 and 70"),
		"Pokémon Summary uses the current Hidden Power mechanics"
	)
	for generated_kind: String in ["species", "moves", "abilities"]:
		var expected_size: int = int({
			"species": 1439,
			"moves": 919,
			"abilities": 377,
		}.get(generated_kind, 0))
		var english_generated_entries: Dictionary = generated_english.get(generated_kind, {})
		var expected_ids: Array = english_generated_entries.keys()
		expected_ids.sort()
		for locale: String in GENERATED_CATALOG_PATHS:
			var generated: Dictionary = generated_catalogs.get(locale, {})
			var generated_entries: Dictionary = generated.get(generated_kind, {})
			var localized_ids: Array = generated_entries.keys()
			localized_ids.sort()
			_check(
				generated_entries.size() == expected_size,
				"generated %s %s catalog covers the complete local index" % [locale, generated_kind]
			)
			_check(
				localized_ids == expected_ids,
				"generated %s %s IDs match English" % [locale, generated_kind]
			)
			for content_id_value: Variant in localized_ids:
				var content_id := str(content_id_value)
				var entry: Dictionary = generated_entries.get(content_id, {})
				_check(
					not str(entry.get("name", "")).strip_edges().is_empty(),
					"generated %s %s %s has a name" % [locale, generated_kind, content_id]
				)
				for entry_key_value: Variant in entry.keys():
					_check(
						str(entry_key_value) in ["name", "shortDesc"],
						"generated %s %s %s contains presentation fields only" % [
							locale,
							generated_kind,
							content_id,
						]
					)
				if generated_kind == "moves":
					_check(
						not str(entry.get("shortDesc", "")).strip_edges().is_empty(),
						"generated %s move %s has a short description" % [locale, content_id]
					)
			if generated_kind == "abilities":
				var described_ability_count := 0
				for ability_value: Variant in generated_entries.values():
					if ability_value is Dictionary and not str(
						(ability_value as Dictionary).get("shortDesc", "")
					).strip_edges().is_empty():
						described_ability_count += 1
				_check(
					described_ability_count == 317,
					"generated %s abilities preserve every available source description" % locale
				)

	for locale: String in GENERATED_CATALOG_PATHS:
		var merged_catalog: Dictionary = content_localization.call("get_catalog", locale)
		_check((merged_catalog.get("species", {}) as Dictionary).size() == 1439, "%s resolver merges all species" % locale)
		_check((merged_catalog.get("moves", {}) as Dictionary).size() == 919, "%s resolver merges all moves" % locale)
		_check((merged_catalog.get("abilities", {}) as Dictionary).size() == 377, "%s resolver merges all abilities" % locale)


func _check_runtime_resolution() -> void:
	localization_manager.call("set_locale", "nl")
	_check(content_localization.call("type_name", "fire", "Fire") == "Vuur", "Dutch type name resolves by canonical ID")
	_check(content_localization.call("nature_name", "Adamant", "Adamant") == "Vastberaden", "Dutch nature resolves by canonical value")
	_check(
		content_localization.call("display_name", "moves", "water-pulse", "Water Pulse") == "Waterpuls",
		"Dutch move name resolves by canonical ID"
	)
	_check(
		content_localization.call("short_description", "abilities", "static", "") == "Kan aanvallers die contact maken verlammen.",
		"Dutch ability description resolves by canonical ID"
	)

	localization_manager.call("set_locale", "pt_BR")
	_check(content_localization.call("type_name", "water", "Water") == "Água", "Portuguese type name resolves by canonical ID")
	_check(content_localization.call("nature_name", "Jolly", "Jolly") == "Alegre", "Portuguese nature resolves by canonical value")
	_check(
		content_localization.call("display_name", "abilities", "water-absorb", "Water Absorb") == "Absorção de Água",
		"Portuguese ability name resolves by canonical ID"
	)
	_check(
		content_localization.call("short_description", "moves", "thunder-wave", "") == "Paralisa o alvo.",
		"Portuguese move description resolves by canonical ID"
	)

	_check(
		content_localization.call("display_name", "moves", "future-move", "Future Move") == "Future Move",
		"missing content overlay keeps its English source fallback"
	)
	_check(
		content_localization.call("display_name", "moves", "absorb", "Absorb") == "Absorver",
		"generated Portuguese move presentation covers the complete source catalog"
	)
	_check(
		content_localization.call("short_description", "abilities", "adaptability", "") != "",
		"generated Portuguese ability presentation retains the available source description"
	)
	_check(
		content_localization.call("display_name", "species", "mr-mime", "Mr Mime") == "Mr. Mime",
		"species presentation resolves from the complete canonical source catalog"
	)


func _check_independent_name_language() -> void:
	localization_manager.call("set_locale", "nl")
	settings_manager.set("locale", "nl")
	settings_manager.set("content_name_language", "english")
	_check(
		content_localization.call("display_name", "moves", "water-pulse", "Water Pulse") == "Water Pulse",
		"Dutch interface can keep English Move names"
	)
	_check(
		content_localization.call("nature_name", "Adamant", "Adamant") == "Adamant",
		"Dutch interface can keep English Nature names"
	)
	_check(
		content_localization.call("short_description", "moves", "thunder-wave", "")
		== "Verlamt het doel.",
		"Dutch descriptions remain localized with English terminology"
	)
	var search_terms: Array[String] = content_localization.call(
		"search_terms",
		"moves",
		"water-pulse",
		"Water Pulse"
	)
	_check(
		search_terms.has("Water Pulse") and search_terms.has("Waterpuls"),
		"search accepts both English and interface-language terminology"
	)

	settings_manager.set("content_name_language", "localized")
	localization_manager.call("set_locale", "pt_BR")
	settings_manager.set("locale", "pt_BR")
	_check(
		content_localization.call("display_name", "abilities", "water-absorb", "Water Absorb")
		== "Absorção de Água",
		"Portuguese interface can use translated Ability names"
	)


func _check_search_terms_preserve_canonical_values() -> void:
	localization_manager.call("set_locale", "nl")
	var type_terms: Array[String] = content_localization.call("search_terms", "types", "fire", "Fire")
	_check(type_terms.has("fire"), "type search retains canonical ID")
	_check(type_terms.has("Fire"), "type search retains English fallback")
	_check(type_terms.has("Vuur"), "type search includes localized display name")

	var canonical_pokemon := {
		"types": ["fire"],
		"nature": "Adamant",
		"level": 50,
	}
	content_localization.call("type_name", canonical_pokemon.types[0], "Fire")
	content_localization.call("nature_name", canonical_pokemon.nature, canonical_pokemon.nature)
	_check(canonical_pokemon.types == ["fire"], "type localization does not mutate Pokémon mechanics")
	_check(canonical_pokemon.nature == "Adamant", "nature localization does not mutate Pokémon mechanics")
	_check(canonical_pokemon.level == 50, "content localization does not alter unrelated mechanics")

	var canonical_move := {
		"id": "water-pulse",
		"name": "Water Pulse",
		"shortDesc": "May confuse the target.",
		"basePower": 60,
		"accuracy": 100,
		"pp": 20,
		"type": "Water",
		"category": "Special",
	}
	var localized_move: Dictionary = content_localization.call(
		"localize_metadata",
		"moves",
		"water-pulse",
		canonical_move
	)
	_check(localized_move.name == "Waterpuls", "metadata overlay localizes the move name")
	_check(localized_move.shortDesc == "Kan het doel in verwarring brengen.", "metadata overlay localizes the move description")
	for mechanics_key: String in ["id", "basePower", "accuracy", "pp", "type", "category"]:
		_check(
			localized_move.get(mechanics_key) == canonical_move.get(mechanics_key),
			"metadata overlay preserves move mechanic %s" % mechanics_key
		)
	_check(canonical_move.name == "Water Pulse", "metadata overlay does not mutate its source dictionary")


func _check_runtime_consumers() -> void:
	localization_manager.call("set_locale", "nl")
	var packed := load(OVERLAY_SCENE_PATH) as PackedScene
	_check(packed != null, "UI overlay loads with canonical content localization")
	if packed == null:
		return

	var overlay := packed.instantiate()
	_check(
		overlay.call("_format_pokedex_type_list", ["fire", "water"]) == "Vuur / Water",
		"Pokédex type list uses localized display names"
	)
	var nature_filter := LineEdit.new()
	nature_filter.text = "vastberaden"
	overlay.set("pc_filter_nature_input", nature_filter)
	_check(
		overlay.call("_pc_pokemon_matches_filters", {"pokemon": {"nature": "Adamant"}}),
		"PC nature filter accepts the localized nature name"
	)
	var type_filter := LineEdit.new()
	type_filter.text = "vuur"
	overlay.set("pc_filter_nature_input", null)
	overlay.set("pc_filter_type_input", type_filter)
	_check(
		overlay.call("_pc_pokemon_matches_filters", {"pokemon": {"types": ["fire"]}}),
		"PC type filter accepts the localized type name"
	)
	var ability_filter := LineEdit.new()
	ability_filter.text = "waterabsorptie"
	overlay.set("pc_filter_type_input", null)
	overlay.set("pc_filter_ability_input", ability_filter)
	_check(
		overlay.call("_pc_pokemon_matches_filters", {"pokemon": {"ability": "water-absorb"}}),
		"PC ability filter accepts the localized ability name"
	)
	var move_filter := LineEdit.new()
	move_filter.text = "waterpuls"
	overlay.set("pc_filter_ability_input", null)
	overlay.set("pc_filter_move_input", move_filter)
	_check(
		overlay.call("_pc_pokemon_matches_filters", {
			"pokemon": {
				"moves": [{"id": "water-pulse", "name": "Water Pulse"}],
			},
		}),
		"PC move filter accepts the localized move name"
	)
	_check(
		overlay.call("_get_summary_move_name", {"id": "water-pulse", "name": "Water Pulse"}) == "Waterpuls",
		"Pokémon Summary displays a localized move name"
	)
	var legacy_summary_moves: Array[Dictionary] = [
		{
			"id": "scaryface",
			"name": "Scary Face",
			"shortDesc": "Lowers the target’s Speed by two stages.",
			"canonicalId": "scary-face",
			"localizedDesc": "Verlaagt de Snelheid van het doel met twee niveaus.",
		},
		{
			"id": "firespin",
			"name": "Fire Spin",
			"shortDesc": "Prevents the target from fleeing and inflicts damage for 2-5 turns.",
			"canonicalId": "fire-spin",
			"localizedDesc": "Sluit het doel op en brengt 2–5 beurten schade toe.",
		},
		{
			"id": "inferno",
			"name": "Inferno",
			"shortDesc": "Has a chance to burn the target.",
			"canonicalId": "inferno",
			"localizedDesc": "Kan het doel verbranden.",
		},
		{
			"id": "flareblitz",
			"name": "Flare Blitz",
			"shortDesc": "Damages the user by 1/3 the damage inflicted. Has a chance to burn the target.",
			"canonicalId": "flare-blitz",
			"localizedDesc": "De gebruiker krijgt 1/3 van de schade die wordt toegebracht tijdens de terugslag. Heeft een kans om het doelwit te verbranden.",
		},
	]
	for move_data: Dictionary in legacy_summary_moves:
		_check(
			overlay.call("_get_summary_move_id", move_data) == str(move_data.get("canonicalId", "")),
			"Pokémon Summary resolves legacy move ID %s to its canonical catalog ID" % move_data.get("id", "")
		)
		_check(
			overlay.call("_get_summary_move_description_text", move_data)
			== str(move_data.get("localizedDesc", "")),
			"Pokémon Summary localizes the legacy %s move description" % move_data.get("name", "")
		)
	_check(
		overlay.call("_get_summary_ability_display_name", "water-absorb") == "Waterabsorptie",
		"Pokémon Summary displays a localized ability name"
	)
	_check(
		overlay.call("_localized_species_name", "mr-mime", "Mr Mime") == "Mr. Mime",
		"Pokémon Summary and Pokédex share canonical species presentation"
	)
	var pokedex_move := {"id": "water-pulse", "name": "Water Pulse", "type": "water"}
	_check(
		overlay.call("_pokedex_move_matches_query", pokedex_move, "waterpuls", "Level"),
		"Pokédex move search accepts the localized move name"
	)
	nature_filter.free()
	type_filter.free()
	ability_filter.free()
	move_filter.free()
	for loader_property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader := overlay.get(loader_property) as Node
		if loader != null:
			loader.free()
	overlay.free()

	var calc_panel := CALC_PANEL_SCRIPT.new()
	var assumptions := {"nature": "Adamant"}
	_check(
		calc_panel.call("_get_nature_chip_label", assumptions) == "Vastberaden",
		"damage calculator displays a localized nature"
	)
	_check(assumptions.nature == "Adamant", "damage calculator retains canonical nature values")
	calc_panel.free()

	var party_hover_text := FileAccess.get_file_as_string(PARTY_HOVER_CARD_SCRIPT)
	_check(
		party_hover_text.contains("func _get_content_localization() -> Node:"),
		"battle party hover resolves nature presentation through the shared resolver"
	)
	for battle_script_path: String in [
		"res://scripts/battle/battle_ui/move_slot.gd",
		"res://scripts/battle/battle_ui/move_hover_card.gd",
		"res://scripts/battle/battle_ui/party_hover_card.gd",
		"res://scripts/battle/battle_ui/pokemon_hover_card.gd",
	]:
		var battle_script_text := FileAccess.get_file_as_string(battle_script_path)
		_check(
			battle_script_text.contains("\"moves\""),
			"%s resolves localized move presentation" % battle_script_path.get_file()
		)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
