extends SceneTree

const PokemonAssets := preload("res://scripts/data/pokemon_assets.gd")
const BattleSpriteRenderScale := preload("res://scripts/battle/battle_ui/battle_sprite_render_scale.gd")
const CATALOG_PATH := "res://data/mega_champions_catalog.generated.json"
const ASSET_READINESS_PATH := "res://data/mega_champions_asset_readiness.generated.json"
const SPRITE_IMPORT_MANIFEST_PATH := "res://data/mega_champions_sprite_imports.generated.json"
const ITEM_LOCALE_PATHS: Dictionary = {
	"en": "res://localization/items/generated/en.json",
	"nl": "res://localization/items/generated/nl.json",
	"pt_BR": "res://localization/items/generated/pt_BR.json",
}
var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := _read_dictionary(CATALOG_PATH)
	var readiness := _read_dictionary(ASSET_READINESS_PATH)
	_check(not catalog.is_empty(), "Phase 3 catalog loads")
	_check(not readiness.is_empty(), "Phase 3 asset readiness manifest loads")
	if catalog.is_empty() or readiness.is_empty():
		quit(1)
		return

	_check_manifest(catalog, readiness)
	_check_sprite_import_manifest()
	_check_localizations_and_item_icons(catalog)
	_check_sprite_mappings(catalog, readiness)
	_check_rendering_consumers()
	_check_static_front_sprite_scale()
	if not failed:
		print("PASS mega_champions_phase3_data_check")
	quit(1 if failed else 0)


func _check_manifest(catalog: Dictionary, readiness: Dictionary) -> void:
	_check(catalog.get("catalogRevision") == readiness.get("catalogRevision"), "asset manifest matches the canonical catalog revision")
	_check(int(readiness.get("schemaVersion", 0)) == 2, "asset manifest uses the provenance-aware schema")
	_check(int(readiness.get("expectedFormCount", 0)) == 49, "asset manifest covers 49 forms")
	_check(int(readiness.get("exactItemIconCount", 0)) == 45, "all 45 unique Mega Stone icons are exact")
	_check(int(readiness.get("exactFormItemIconCount", 0)) == 49, "all 49 form mappings resolve an exact item icon")
	_check(int(readiness.get("exactBattleSpriteCount", 0)) == 49, "all 49 forms have complete exact battle sprite sets")
	_check(int(readiness.get("fallbackOnlyOrMissingBattleSpriteCount", -1)) == 0, "no form remains blocked on an exact battle sprite")
	var provenance: Dictionary = readiness.get("provenance", {})
	_check(provenance.get("pokemonSpriteLicenseStatus") == "not_declared_in_source_bundle", "sprite bundle license status is recorded without inventing a license")
	_check(provenance.get("licensingReview") == "credits_recorded_license_not_declared", "asset provenance records credits and the absent license declaration")
	for form_value: Variant in readiness.get("forms", []):
		if not (form_value is Dictionary):
			continue
		var form := form_value as Dictionary
		_check(form.get("publicAssetReady") == false, "%s cannot become public through Phase 3 assets" % form.get("catalogEntryId", "unknown"))


func _check_sprite_import_manifest() -> void:
	var manifest := _read_dictionary(SPRITE_IMPORT_MANIFEST_PATH)
	_check(int(manifest.get("schemaVersion", 0)) == 1, "sprite import manifest schema loads")
	_check(int(manifest.get("mappingCount", 0)) == 15, "sprite import manifest covers twelve missing and three corrected mappings")
	_check(int(manifest.get("shinyHomeBackfillCount", 0)) == 34, "sprite import manifest covers all 34 missing shiny HOME sprites")
	var source: Dictionary = manifest.get("source", {})
	_check(source.get("name") == "Generation 9 Pack", "sprite import source name is pinned")
	_check(source.get("version") == "3.3.6", "sprite import source version is pinned")
	_check(source.get("licenseStatus") == "not_declared_in_source_bundle", "source bundle's absent license declaration remains explicit")
	var mapped_ids: Dictionary = {}
	for form_value: Variant in manifest.get("forms", []):
		if not (form_value is Dictionary):
			continue
		var form := form_value as Dictionary
		var entry_id := str(form.get("catalogEntryId", ""))
		mapped_ids[entry_id] = str(form.get("sourceStem", ""))
		for output_value: Variant in form.get("outputs", []):
			var output_path := "res://%s" % str(output_value)
			_check(FileAccess.file_exists(output_path), "%s imported output exists" % output_path)
	_check(mapped_ids.size() == 15, "sprite import mappings are unique")
	_check(mapped_ids.has("floette-mega"), "Floette's previous wrong form-index mapping is corrected")
	_check(mapped_ids.get("greninja-mega") == "GRENINJA_3", "Greninja-Mega resolves through its exact GRENINJA_3 import")
	_check(mapped_ids.has("magearna-mega"), "Magearna's previous wrong form-index mapping is corrected")
	_check(mapped_ids.has("zygarde-mega"), "Zygarde's previous wrong form-index mapping is corrected")
	var shiny_backfill_ids: Dictionary = {}
	for form_value: Variant in manifest.get("shinyHomeBackfills", []):
		if not (form_value is Dictionary):
			continue
		var form := form_value as Dictionary
		var entry_id := str(form.get("catalogEntryId", ""))
		shiny_backfill_ids[entry_id] = true
		var output_path := "res://%s" % str(form.get("output", ""))
		_check(FileAccess.file_exists(output_path), "%s shiny HOME backfill exists" % entry_id)
	_check(shiny_backfill_ids.size() == 34, "shiny HOME backfill mappings are unique")
	_check(shiny_backfill_ids.has("meganium-mega"), "Meganium's shiny HOME sprite is backfilled")


func _check_localizations_and_item_icons(catalog: Dictionary) -> void:
	var locale_catalogs: Dictionary = {}
	for locale: String in ITEM_LOCALE_PATHS:
		var locale_catalog := _read_dictionary(str(ITEM_LOCALE_PATHS[locale]))
		locale_catalogs[locale] = locale_catalog
		_check(locale_catalog.size() == 1442, "%s generated item catalog contains all 1442 items" % locale)

	var unique_items: Dictionary = {}
	for form_value: Variant in catalog.get("forms", []):
		if not (form_value is Dictionary):
			continue
		var form := form_value as Dictionary
		var activation: Dictionary = form.get("activation", {})
		var item_id := str(activation.get("pokeaetherItemId", ""))
		var assets: Dictionary = form.get("assets", {})
		var icon_key := str(assets.get("itemIconKey", ""))
		_check(not item_id.is_empty(), "%s has an item id" % form.get("catalogEntryId", "unknown"))
		_check(icon_key == item_id, "%s uses its stable item id as icon key" % form.get("catalogEntryId", "unknown"))
		unique_items[item_id] = true
		for locale: String in ITEM_LOCALE_PATHS:
			var locale_catalog: Dictionary = locale_catalogs.get(locale, {})
			var entry: Dictionary = locale_catalog.get(item_id, {})
			_check(not str(entry.get("name", "")).strip_edges().is_empty(), "%s %s has a localized name" % [locale, item_id])
			_check(not str(entry.get("shortDesc", "")).strip_edges().is_empty(), "%s %s has a localized description" % [locale, item_id])

		var normalized_icon_key := icon_key.to_upper().replace("-", "").replace("_", "").replace(" ", "")
		var icon_path := "res://assets/items/icons/%s.png" % normalized_icon_key
		_check(ResourceLoader.exists(icon_path), "%s has an exact UI icon" % item_id)
		_check(load(icon_path) is Texture2D, "%s exact UI icon is loadable" % item_id)

	_check(unique_items.size() == 45, "catalog forms map to 45 unique Mega Stones")


func _check_sprite_mappings(catalog: Dictionary, readiness: Dictionary) -> void:
	var readiness_by_id: Dictionary = {}
	for value: Variant in readiness.get("forms", []):
		if value is Dictionary:
			var row := value as Dictionary
			readiness_by_id[str(row.get("catalogEntryId", ""))] = row

	var actual_blockers: Array[String] = []
	for form_value: Variant in catalog.get("forms", []):
		if not (form_value is Dictionary):
			continue
		var form := form_value as Dictionary
		var entry_id := str(form.get("catalogEntryId", ""))
		var species_name := str(form.get("showdownSpeciesName", ""))
		var sprite_key := str((form.get("assets", {}) as Dictionary).get("spriteKey", ""))
		var row: Dictionary = readiness_by_id.get(entry_id, {})
		_check(str(row.get("spriteKey", "")) == sprite_key, "%s readiness uses the canonical sprite key" % entry_id)
		if row.get("battleSpriteStatus") != "exact":
			actual_blockers.append(entry_id)
			continue

		_check(PokemonAssets.get_battle_sprite_ids(species_name).has(sprite_key), "%s battle HUD resolves the exact sprite key" % entry_id)
		for folder: String in ["front", "back", "shiny_front", "shiny_back"]:
			var sprite_root := "res://assets/sprites/pokemon/%s/%s" % [folder, sprite_key]
			_check(FileAccess.file_exists(sprite_root + "/sheet.png"), "%s %s sheet exists" % [entry_id, folder])
			_check(FileAccess.file_exists(sprite_root + "/animation.json"), "%s %s animation metadata exists" % [entry_id, folder])
		_check(PokemonAssets.load_home_sprite(species_name, false) != null, "%s has a normal party/storage/Calcdex render" % entry_id)
		_check(PokemonAssets.load_home_sprite(species_name, true) != null, "%s has a shiny party/storage/Calcdex render" % entry_id)
		_check(FileAccess.file_exists("res://assets/sprites/pokemon/pokemon_home/%s.png" % species_name), "%s has an exact normal HOME sprite" % entry_id)
		_check(FileAccess.file_exists("res://assets/sprites/pokemon/pokemon_home_shiny/%s.png" % species_name), "%s has an exact shiny HOME sprite" % entry_id)

	actual_blockers.sort()
	_check(actual_blockers.is_empty(), "all 49 catalog forms resolve exact sprite sets")


func _check_rendering_consumers() -> void:
	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	var party_source := FileAccess.get_file_as_string("res://scripts/ui/party_slot.gd")
	var battle_sprite_source := FileAccess.get_file_as_string("res://scripts/battle/battle_ui/sprite_box.gd")
	var calcdex_source := FileAccess.get_file_as_string("res://scripts/battle/battle_ui/battle_damage_calc_panel.gd")
	_check(overlay_source.contains('BAG_ICON_ROOT + normalized + ".png"'), "Bag and summary use the canonical normalized item icon key")
	_check(overlay_source.contains("_load_item_icon(held_item_id)"), "held-item summary uses the shared icon resolver")
	_check(overlay_source.contains("_add_pc_held_item_marker(icon, held_item_id)"), "storage renders held-item state from the serialized item id")
	_check(overlay_source.contains("PlayerPartyStateService.dev_create_pokemon("), "developer generator preserves the serialized Pokemon payload path")
	_check(party_source.contains("PokemonAssets.load_party_icon(species, is_shiny)"), "party rendering uses the shared species sprite resolver")
	_check(battle_sprite_source.contains("PokemonAssets.get_battle_sprite_ids(species)"), "battle HUD uses the shared battle sprite mapping")
	_check(calcdex_source.contains("PokemonAssets.load_party_icon(sprite_species)"), "Calcdex renders through the shared species sprite mapping")


func _check_static_front_sprite_scale() -> void:
	var metadata := {
		"frame_width": 192,
		"frame_height": 192,
		"scale": 1,
		"resample": "static-source",
	}
	_check(
		is_equal_approx(BattleSpriteRenderScale.resolve(metadata, "showdown/front"), 2.0),
		"192 px static Champions ZA front sprites render at their authored 2x resolution"
	)
	_check(
		is_equal_approx(BattleSpriteRenderScale.resolve(metadata, "showdown/back"), 1.0),
		"the static front scale rule does not change back sprites"
	)
	metadata["resample"] = "lanczos"
	_check(
		is_equal_approx(BattleSpriteRenderScale.resolve(metadata, "showdown/front"), 1.0),
		"animated front sprites keep their existing render scale"
	)


func _read_dictionary(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Dictionary, "%s is valid JSON" % path)
	return parsed as Dictionary if parsed is Dictionary else {}


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
