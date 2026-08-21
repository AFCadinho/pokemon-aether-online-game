extends SceneTree

const CatalogScript := preload("res://scripts/data/mega_champions_catalog.gd")

var failed := false


func _init() -> void:
	_check_manifest()
	_check_round_trips()
	_check_special_relationships()
	_check_negative_names()
	quit(1 if failed else 0)


func _check_manifest() -> void:
	var manifest: Dictionary = CatalogScript.catalog_manifest()
	_check_equal(manifest.get("success"), true, "catalog loads")
	_check_equal(manifest.get("catalogId"), "mega-champions-v1", "catalog id")
	_check_equal(manifest.get("schemaVersion"), 1, "schema version")
	_check_equal(manifest.get("pokemonShowdownVersion"), "0.11.11", "Showdown version")
	_check_equal(manifest.get("formCount"), 49, "form count")
	_check_equal(manifest.get("activationItemCount"), 45, "activation item count")
	_check_equal(manifest.get("calculatorPendingCount"), 0, "calculator pending count")
	_check_equal(manifest.get("calculatorSupportedCount"), 49, "calculator supported count")
	_check_equal(manifest.get("publicAvailability"), "disabled", "public availability")
	_check_equal(
		(manifest.get("readinessCounts", {}) as Dictionary).get("engine_only"),
		49,
		"engine-only count"
	)
	var revision := str(manifest.get("catalogRevision", ""))
	_check_equal(revision.begins_with("sha256:") and revision.length() == 71, true, "revision")


func _check_round_trips() -> void:
	for entry: Dictionary in CatalogScript.all_entries():
		var entry_id := str(entry.get("catalogEntryId", ""))
		_check_equal(entry.get("readiness"), "engine_only", "%s dormant" % entry_id)
		_check_equal(
			(entry.get("calculator", {}) as Dictionary).get("supportStatus"),
			"supported",
			"%s calculator support" % entry_id
		)
		_check_equal(
			CatalogScript.get_entry_for_mega_species(
				str(entry.get("showdownSpeciesName", ""))
			).get("catalogEntryId"),
			entry_id,
			"%s Mega lookup" % entry_id
		)
		var activation: Dictionary = entry.get("activation", {})
		for base: Dictionary in entry.get("baseForms", []):
			_check_equal(
				CatalogScript.get_entry_for_base_and_item(
					str(base.get("pokeaetherSpeciesId", "")),
					str(activation.get("pokeaetherItemId", ""))
				).get("catalogEntryId"),
				entry_id,
				"%s base + item lookup" % entry_id
			)


func _check_special_relationships() -> void:
	var zygarde: Dictionary = CatalogScript.get_entry_for_mega_species("Zygarde-Mega")
	var zygarde_bases: Array[String] = []
	for base: Dictionary in zygarde.get("baseForms", []):
		zygarde_bases.append(str(base.get("pokeaetherSpeciesId", "")))
	_check_equal(zygarde_bases, ["zygarde-50", "zygarde-10"], "Zygarde legal bases")
	var zygarde_sources: Array[String] = []
	var zygarde_activation: Dictionary = zygarde.get("activation", {})
	for base: Dictionary in zygarde_activation.get("engineSourceForms", []):
		zygarde_sources.append(str(base.get("pokeaetherSpeciesId", "")))
	_check_equal(zygarde_sources, ["zygarde-complete"], "Zygarde engine source")

	_check_equal(
		CatalogScript.get_entry_for_mega_species("Floette-Mega").get("defaultBaseSpeciesId"),
		"floette-eternal",
		"Floette Eternal base"
	)
	_check_equal(
		CatalogScript.get_entry_for_base_and_item(
			"Magearna-Original", "Magearnite"
		).get("pokeaetherSpeciesId"),
		"magearna-original-mega",
		"Magearna Original shared stone"
	)
	_check_equal(
		CatalogScript.get_entry_for_base_and_item(
			"Tatsugiri-Droopy", "Tatsugirinite"
		).get("pokeaetherSpeciesId"),
		"tatsugiri-droopy-mega",
		"Tatsugiri shared stone"
	)


func _check_negative_names() -> void:
	_check_equal(CatalogScript.is_mega_champions_species("Yanmega"), false, "Yanmega exclusion")
	_check_equal(
		CatalogScript.is_mega_champions_species("Rayquaza-Mega"),
		false,
		"existing move-activated Mega exclusion"
	)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
