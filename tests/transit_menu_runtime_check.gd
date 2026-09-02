extends SceneTree

const TransitMenuScript := preload("res://scripts/ui/transit_menu.gd")
const REQUIRED_KEYS: Array[String] = [
	"ui.transit.available",
	"ui.transit.locked_destinations",
	"ui.transit.no_available",
	"ui.transit.select_destination",
	"ui.transit.travel_to",
	"ui.transit.travel_to_free",
	"ui.transit.free",
]

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var localization_manager := root.get_node_or_null("LocalizationManager")
	var original_locale := str(localization_manager.get("current_locale")) if localization_manager != null else "en"
	if localization_manager != null:
		localization_manager.call("set_locale", "en")

	var menu := TransitMenuScript.new() as TransitMenu
	root.add_child(menu)
	menu.open(_network_fixture())
	await process_frame
	await process_frame

	_check(menu.find_child("RegionSelect", true, false) == null, "single-region travel omits a redundant region selector")
	_check(menu.find_child("AvailableHeading", true, false) != null, "available destinations have a clear section")
	_check(menu.find_child("LockedHeading", true, false) != null, "locked destinations have a separate section")
	var pallet := menu.find_child("Destination_kanto_pallet_town", true, false) as Button
	var pewter := menu.find_child("Destination_kanto_pewter_city", true, false) as Button
	var cerulean := menu.find_child("Locked_kanto_cerulean_city", true, false) as PanelContainer
	var hub := menu.find_child("Destination_aether_clash_lobby", true, false) as Button
	var travel := menu.find_child("TravelButton", true, false) as Button
	_check(pallet != null and pewter != null, "unlocked destinations render as full-row buttons")
	_check(cerulean != null, "locked destinations render as quiet non-interactive rows")
	_check(menu.find_child("CurrentLocation", true, false) != null, "the current location is shown in a separate status card")
	_check(hub == null, "the current worldwide hub is omitted from travel destinations")
	_check(travel != null and not travel.disabled and travel.text.contains("Pallet Town"), "the first usable destination selects a clear footer action")
	if pallet != null:
		var selected_style := pallet.get_theme_stylebox("normal") as StyleBoxFlat
		_check(selected_style != null and selected_style.get_border_width(SIDE_LEFT) == 2, "the selected destination has one strong visual accent")
	if pewter != null:
		pewter.pressed.emit()
		await process_frame
		_check(travel.text.contains("Pewter City") and travel.text.contains("₽200"), "selecting a row updates the single travel action and fare")
		travel.pressed.emit()
		await process_frame
		var confirmation := menu.get("_confirmation") as AetherConfirmationDialog
		_check(confirmation != null and confirmation.visible, "the footer action retains the travel confirmation safety step")
		_check(str(menu.get("_pending_destination_id")) == "kanto_pewter_city", "confirmation targets the selected destination")
	menu.queue_free()
	await process_frame

	var regional_menu := TransitMenuScript.new() as TransitMenu
	root.add_child(regional_menu)
	var regional_network := _network_fixture()
	regional_network["sourceRegionId"] = "all"
	(regional_network["destinations"] as Array).append({
		"destinationId": "johto_new_bark_town",
		"regionId": "johto",
		"name": "New Bark Town",
		"attuned": true,
		"isAnchor": false,
		"fare": 200,
	})
	regional_menu.open(regional_network)
	await process_frame
	_check(regional_menu.find_child("RegionSelect", true, false) != null, "worldwide travel keeps region selection when it is useful")
	regional_menu.queue_free()
	await process_frame

	var poor_menu := TransitMenuScript.new() as TransitMenu
	root.add_child(poor_menu)
	poor_menu.open({
		"sourceRegionId": "kanto",
		"sourceMapId": "aether_clash_lobby",
		"wallet": {"money": 0},
		"destinations": [{
			"destinationId": "kanto_pewter_city",
			"regionId": "kanto",
			"name": "Pewter City",
			"attuned": true,
			"fare": 200,
		}],
	})
	await process_frame
	var poor_travel := poor_menu.find_child("TravelButton", true, false) as Button
	_check(poor_travel != null and poor_travel.disabled and poor_travel.text == "Not enough funds", "an unaffordable selection explains why travel is unavailable")
	poor_menu.queue_free()

	var current_menu := TransitMenuScript.new() as TransitMenu
	root.add_child(current_menu)
	var current_network := _network_fixture()
	current_network["sourceMapId"] = "kanto_viridian_city"
	current_menu.open(current_network)
	await process_frame
	var current_button := current_menu.find_child("Destination_kanto_viridian_city", true, false)
	_check(current_button == null, "the current regional location is omitted from travel destinations")
	_check(current_menu.find_child("CurrentLocation", true, false) != null, "the current regional location gets its own status card")
	current_menu.queue_free()

	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://localization/%s.json" % locale))
		var catalog := parsed as Dictionary if parsed is Dictionary else {}
		_check(not catalog.is_empty(), "%s transit catalog is valid JSON" % locale)
		for key: String in REQUIRED_KEYS:
			_check(catalog.has(key), "%s contains %s" % [locale, key])
	if localization_manager != null:
		localization_manager.call("set_locale", original_locale)
	quit(1 if failed else 0)


func _network_fixture() -> Dictionary:
	return {
		"sourceRegionId": "kanto",
		"sourceMapId": "aether_clash_lobby",
		"wallet": {"money": 9999},
		"membershipDiscountActive": false,
		"destinations": [
			{
				"destinationId": "kanto_cerulean_city",
				"regionId": "kanto",
				"name": "Cerulean City",
				"attuned": false,
				"isAnchor": false,
				"fare": 200,
			},
			{
				"destinationId": "kanto_pallet_town",
				"regionId": "kanto",
				"name": "Pallet Town",
				"attuned": true,
				"isAnchor": true,
				"fare": 0,
			},
			{
				"destinationId": "kanto_pewter_city",
				"regionId": "kanto",
				"name": "Pewter City",
				"attuned": true,
				"isAnchor": false,
				"fare": 200,
			},
			{
				"destinationId": "kanto_viridian_city",
				"regionId": "kanto",
				"name": "Viridian City",
				"attuned": false,
				"isAnchor": false,
				"fare": 200,
			},
			{
				"destinationId": "aether_clash_lobby",
				"regionId": "all",
				"name": "Aether Clash Lobby",
				"isGlobalHub": true,
				"guildBenefitActive": true,
				"fare": 0,
			},
		],
	}


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	failed = true
	push_error("FAIL: %s" % label)
