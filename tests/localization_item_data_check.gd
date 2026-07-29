extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"
const CATALOG_PATHS: Dictionary = {
	"en": "res://localization/items/en.json",
	"nl": "res://localization/items/nl.json",
	"pt_BR": "res://localization/items/pt_BR.json",
}

var failed := false
var localization_manager: Node
var item_localization: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	localization_manager = root.get_node_or_null("LocalizationManager")
	item_localization = root.get_node_or_null("ItemLocalization")
	_check(localization_manager != null, "item-data check can access LocalizationManager")
	_check(item_localization != null, "item-data check can access ItemLocalization")
	if localization_manager == null or item_localization == null:
		quit(1)
		return

	var original_locale := str(localization_manager.get("current_locale"))
	_check_catalogs()
	_check_resolver_fallback_and_mechanics()
	_check_overlay_integration()
	localization_manager.call("set_locale", original_locale)
	await process_frame
	quit(1 if failed else 0)


func _check_catalogs() -> void:
	var catalogs: Dictionary = {}
	for locale: String in CATALOG_PATHS:
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(str(CATALOG_PATHS[locale]))
		)
		_check(parsed is Dictionary, "%s item catalog is valid JSON" % locale)
		catalogs[locale] = parsed as Dictionary if parsed is Dictionary else {}

	var english: Dictionary = catalogs.get("en", {})
	_check(english.size() == 69, "initial item overlay covers 69 current item IDs")
	var english_item_ids: Array = english.keys()
	english_item_ids.sort()
	for locale: String in CATALOG_PATHS:
		var catalog: Dictionary = catalogs.get(locale, {})
		var localized_item_ids: Array = catalog.keys()
		localized_item_ids.sort()
		_check(localized_item_ids == english_item_ids, "%s item IDs match English" % locale)
		_check(
			(item_localization.call("get_catalog", locale) as Dictionary).size() == english.size(),
			"%s item catalog loads into the runtime resolver" % locale
		)
		for item_id_value: Variant in english.keys():
			var item_id := str(item_id_value)
			var entry: Dictionary = catalog.get(item_id, {})
			_check(not str(entry.get("name", "")).strip_edges().is_empty(), "%s %s has a name" % [locale, item_id])
			_check(
				not str(entry.get("shortDesc", "")).strip_edges().is_empty(),
				"%s %s has a short description" % [locale, item_id]
			)


func _check_resolver_fallback_and_mechanics() -> void:
	var source_item := {
		"itemId": "potion",
		"name": "Potion",
		"shortDesc": "Server-provided English description.",
		"quantity": 4,
		"gameplay": {"target": "pokemon"},
	}

	localization_manager.call("set_locale", "nl")
	var dutch: Dictionary = item_localization.call("localize_item", source_item)
	_check(dutch.get("name") == "Potion", "Dutch keeps the approved Potion display name")
	_check(dutch.get("shortDesc") == "Herstelt 20 HP.", "Dutch resolves the Potion description by item ID")
	_check(dutch.get("quantity") == 4, "item localization preserves quantity")
	_check(dutch.get("gameplay") == {"target": "pokemon"}, "item localization preserves mechanics")

	localization_manager.call("set_locale", "pt_BR")
	var portuguese: Dictionary = item_localization.call("localize_item", dutch)
	_check(portuguese.get("name") == "Poção", "Portuguese resolves the Potion name")
	_check(portuguese.get("shortDesc") == "Restaura 20 PS.", "Portuguese resolves the Potion description")

	localization_manager.call("set_locale", "en")
	var english: Dictionary = item_localization.call("localize_item", portuguese)
	_check(english.get("name") == "Potion", "English overlay remains the canonical display fallback")
	_check(english.get("shortDesc") == "Restores 20 HP.", "English overlay restores canonical description")

	localization_manager.call("set_locale", "nl")
	var unknown: Dictionary = item_localization.call("localize_item", {
		"id": "future-event-item",
		"name": "Future Event Item",
		"shortDesc": "Server fallback remains visible.",
	})
	_check(unknown.get("name") == "Future Event Item", "unknown item keeps its server name")
	_check(
		unknown.get("shortDesc") == "Server fallback remains visible.",
		"unknown item keeps its server description"
	)


func _check_overlay_integration() -> void:
	var packed := load(OVERLAY_SCENE_PATH) as PackedScene
	_check(packed != null, "UI overlay loads with item localization")
	if packed == null:
		return

	var overlay := packed.instantiate()
	localization_manager.call("set_locale", "nl")
	var normalized: Array = overlay.call("_normalize_bag_inventory_items", [{
		"itemId": "potion",
		"name": "Potion",
		"category": "medicine",
		"shortDesc": "Restores 20 HP.",
		"quantity": 2,
	}])
	_check(normalized.size() == 2, "Bag normalization retains inventory plus virtual Escape Rope")
	var potion: Dictionary = normalized[0]
	var escape_rope: Dictionary = normalized[1]
	_check(potion.get("shortDesc") == "Herstelt 20 HP.", "Bag normalization applies Dutch item data")
	_check(
		escape_rope.get("name") == "Escape Rope · Belangrijk item",
		"virtual Escape Rope name renders in Dutch"
	)
	_check(
		escape_rope.get("shortDesc") == "Keer terug naar de laatste veilige binnenlocatie die je hebt bezocht.",
		"virtual Escape Rope description renders in Dutch"
	)

	var market_items: Array = overlay.call("_normalize_market_items", [{
		"itemId": "potion",
		"name": "Potion",
		"category": "medicine",
		"shortDesc": "Restores 20 HP.",
		"costs": [{"currency": "money", "amount": 300}],
	}])
	_check(
		market_items.size() == 1 and (market_items[0] as Dictionary).get("shortDesc") == "Herstelt 20 HP.",
		"Market normalization reuses the item resolver"
	)

	for loader_property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader := overlay.get(loader_property) as Node
		if loader != null:
			loader.free()
	overlay.free()


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
