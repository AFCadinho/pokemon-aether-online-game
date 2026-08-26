extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"
const CATALOG_PATHS: Dictionary = {
	"en": "res://localization/items/en.json",
	"nl": "res://localization/items/nl.json",
	"pt_BR": "res://localization/items/pt_BR.json",
	"zh_CN": "res://localization/items/zh_CN.json",
}
const GENERATED_CATALOG_PATHS: Dictionary = {
	"en": "res://localization/items/generated/en.json",
	"nl": "res://localization/items/generated/nl.json",
	"pt_BR": "res://localization/items/generated/pt_BR.json",
	"zh_CN": "res://localization/items/generated/zh_CN.json",
}
const SHOP_CONSUMER_PATHS: Dictionary = {
	"Aether Atelier": "res://scripts/ui/aether_atelier_popup.gd",
	"Donator Store": "res://scripts/ui/donator_store_popup.gd",
}

var failed := false
var localization_manager: Node
var item_localization: Node
var settings_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	localization_manager = root.get_node_or_null("LocalizationManager")
	item_localization = root.get_node_or_null("ItemLocalization")
	settings_manager = root.get_node_or_null("SettingsManager")
	_check(localization_manager != null, "item-data check can access LocalizationManager")
	_check(item_localization != null, "item-data check can access ItemLocalization")
	_check(settings_manager != null, "item-data check can access SettingsManager")
	if localization_manager == null or item_localization == null or settings_manager == null:
		quit(1)
		return

	var original_locale := str(localization_manager.get("current_locale"))
	var original_settings_locale := str(settings_manager.get("locale"))
	var original_content_name_language := str(settings_manager.get("content_name_language"))
	settings_manager.set("content_name_language", "localized")
	_check_catalogs()
	_check_resolver_fallback_and_mechanics()
	_check_independent_name_language()
	_check_overlay_integration()
	_check_shop_and_cosmetic_integration()
	settings_manager.set("locale", original_settings_locale)
	settings_manager.set("content_name_language", original_content_name_language)
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
		for item_id_value: Variant in english.keys():
			var item_id := str(item_id_value)
			var entry: Dictionary = catalog.get(item_id, {})
			_check(not str(entry.get("name", "")).strip_edges().is_empty(), "%s %s has a name" % [locale, item_id])
			_check(
				not str(entry.get("shortDesc", "")).strip_edges().is_empty(),
				"%s %s has a short description" % [locale, item_id]
			)

	var generated_catalogs: Dictionary = {}
	for locale: String in GENERATED_CATALOG_PATHS:
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(str(GENERATED_CATALOG_PATHS.get(locale, "")))
		)
		_check(parsed is Dictionary, "generated %s item catalog is valid JSON" % locale)
		var catalog: Dictionary = parsed as Dictionary if parsed is Dictionary else {}
		generated_catalogs[locale] = catalog
		_check(catalog.size() == 1447, "generated %s item catalog covers the complete source index" % locale)
		for item_id_value: Variant in catalog.keys():
			var item_id := str(item_id_value)
			var entry: Dictionary = catalog.get(item_id, {})
			_check(not str(entry.get("name", "")).strip_edges().is_empty(), "generated %s %s has a name" % [locale, item_id])
			_check(
				not str(entry.get("shortDesc", "")).strip_edges().is_empty(),
				"generated %s %s has a short description" % [locale, item_id]
			)
			for entry_key_value: Variant in entry.keys():
				_check(
					str(entry_key_value) in ["name", "shortDesc"],
					"generated %s %s contains presentation fields only" % [locale, item_id]
				)

	var generated_english: Dictionary = generated_catalogs.get("en", {})
	var generated_chinese: Dictionary = generated_catalogs.get("zh_CN", {})
	_check(
		str((generated_chinese.get("ability-capsule", {}) as Dictionary).get("name", "")) == "特性胶囊",
		"generated Simplified Chinese uses the official Ability Capsule name"
	)
	_check(
		str((generated_chinese.get("tm-flare-blitz", {}) as Dictionary).get("name", ""))
		== "招式学习器：闪焰冲锋",
		"generated Simplified Chinese machine names use the official move name"
	)
	_check(
		str((generated_chinese.get("tm-flare-blitz", {}) as Dictionary).get("shortDesc", ""))
		== "让能够学习的宝可梦学会“闪焰冲锋”。",
		"generated Simplified Chinese machine descriptions use the official move name"
	)
	_check(
		str((generated_chinese.get("adinho-classic-outfit", {}) as Dictionary).get("name", ""))
		== "Adinho Classic Box",
		"unverified generated Simplified Chinese item names use the English fallback"
	)
	_check(
		str((generated_chinese.get("adinho-classic-outfit", {}) as Dictionary).get("shortDesc", ""))
		== str((generated_english.get("adinho-classic-outfit", {}) as Dictionary).get("shortDesc", "")),
		"unverified generated Simplified Chinese item prose uses the English fallback"
	)
	var expected_generated_ids: Array = generated_english.keys()
	expected_generated_ids.sort()
	for locale: String in GENERATED_CATALOG_PATHS:
		var catalog: Dictionary = generated_catalogs.get(locale, {})
		var localized_ids: Array = catalog.keys()
		localized_ids.sort()
		_check(localized_ids == expected_generated_ids, "generated %s item IDs match English" % locale)
		_check(
			(item_localization.call("get_catalog", locale) as Dictionary).size() == 1448,
			"%s complete item catalog plus virtual Escape Rope action loads into the runtime resolver" % locale
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
	var generated_dutch: Dictionary = item_localization.call("localize_item", {
		"itemId": "armorite-ore",
		"name": "Armorite Ore",
		"shortDesc": "Server-provided English description.",
		"quantity": 7,
		"sellPrice": 5,
	})
	_check(generated_dutch.get("name") == "Armorieterts", "Dutch generated catalog covers an item outside the reviewed pilot")
	_check(generated_dutch.get("quantity") == 7, "generated item localization preserves quantity")
	_check(generated_dutch.get("sellPrice") == 5, "generated item localization preserves price mechanics")
	var mega_stone_dutch: Dictionary = item_localization.call("localize_item", {
		"itemId": "raichunite-x",
		"name": "Raichunite X",
		"shortDesc": "Server-provided English description.",
		"isHoldable": true,
	})
	_check(mega_stone_dutch.get("name") == "Raichuniet X", "Dutch resolves a Mega Champions stone name")
	_check(
		str(mega_stone_dutch.get("shortDesc", "")).contains("mega-evolueren"),
		"Dutch resolves a Mega Champions stone description"
	)
	_check(mega_stone_dutch.get("isHoldable") == true, "Mega Stone localization preserves held-item mechanics")

	localization_manager.call("set_locale", "pt_BR")
	var portuguese: Dictionary = item_localization.call("localize_item", dutch)
	_check(portuguese.get("name") == "Poção", "Portuguese resolves the Potion name")
	_check(portuguese.get("shortDesc") == "Restaura 20 PS.", "Portuguese resolves the Potion description")
	var mega_stone_portuguese: Dictionary = item_localization.call("localize_item", mega_stone_dutch)
	_check(mega_stone_portuguese.get("name") == "Raichunita X", "Portuguese resolves a Mega Champions stone name")
	_check(
		str(mega_stone_portuguese.get("shortDesc", "")).contains("megaevoluir"),
		"Portuguese resolves a Mega Champions stone description"
	)

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


func _check_independent_name_language() -> void:
	localization_manager.call("set_locale", "nl")
	settings_manager.set("locale", "nl")
	settings_manager.set("content_name_language", "english")
	var english_names: Dictionary = item_localization.call("localize_item", {
		"itemId": "armorite-ore",
		"name": "Armorite Ore",
		"shortDesc": "Server-provided English description.",
	})
	_check(
		english_names.get("name") == "Armorite Ore",
		"Dutch interface can keep English item names"
	)
	_check(
		english_names.get("shortDesc") != "Server-provided English description.",
		"item descriptions remain Dutch with English item names"
	)
	settings_manager.set("content_name_language", "localized")


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
		"available": true,
	}, {
		"itemId": "ultra-ball",
		"name": "Ultra Ball",
		"category": "poke-balls",
		"costs": [{"currency": "money", "amount": 1200}],
		"requiredBadges": 6,
		"available": false,
	}])
	_check(
		market_items.size() == 2 and (market_items[0] as Dictionary).get("shortDesc") == "Herstelt 20 HP.",
		"Market normalization reuses the item resolver"
	)
	var available_market_items: Array = overlay.call("_market_available_buy_items", market_items)
	_check(
		available_market_items.size() == 1
		and (available_market_items[0] as Dictionary).get("id") == "potion",
		"Market purchase stock hides items above the player's badge tier"
	)

	for loader_property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader := overlay.get(loader_property) as Node
		if loader != null:
			loader.free()
	overlay.free()


func _check_shop_and_cosmetic_integration() -> void:
	for consumer_name: String in SHOP_CONSUMER_PATHS:
		var source := FileAccess.get_file_as_string(str(SHOP_CONSUMER_PATHS[consumer_name]))
		_check(
			source.contains("/root/ItemLocalization"),
			"%s resolves item presentation through ItemLocalization" % consumer_name
		)
		_check(
			source.contains("display_name"),
			"%s uses the shared localized item name" % consumer_name
		)
		_check(
			source.contains("short_description"),
			"%s uses the shared localized item description" % consumer_name
		)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
