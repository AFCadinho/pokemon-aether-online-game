extends SceneTree

const MAP_CONTRACTS := {
	"res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn": [
		'position = Vector2(784, 240)',
		'local_destination_id = "kanto_pallet_town"',
		'position = Vector2(784, 208)',
		'interactable_id = "kanto_pallet_town_aether_beacon"',
		'destination_id = "kanto_pallet_town"',
	],
	"res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn": [
		'position = Vector2(1072, 1136)',
		'local_destination_id = "kanto_viridian_city"',
		'position = Vector2(1072, 1104)',
		'interactable_id = "kanto_viridian_city_aether_beacon"',
		'destination_id = "kanto_viridian_city"',
	],
	"res://scenes/overworld/kanto/towns/pewter_city/pewter_city.tscn": [
		'position = Vector2(1520, 976)',
		'local_destination_id = "kanto_pewter_city"',
		'position = Vector2(1488, 976)',
		'position = Vector2(1520, 944)',
		'interactable_id = "kanto_pewter_city_aether_beacon"',
		'destination_id = "kanto_pewter_city"',
	],
}

const TILE_CENTER_CONTRACTS := {
	"res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn": {
		"TransitArrival": Vector2i(784, 240),
		"TransitKeeper": Vector2i(720, 240),
		"AetherBeacon": Vector2i(784, 208),
	},
	"res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn": {
		"TransitArrival": Vector2i(1072, 1136),
		"AetherBeacon": Vector2i(1072, 1104),
	},
	"res://scenes/overworld/kanto/towns/pewter_city/pewter_city.tscn": {
		"TransitArrival": Vector2i(1520, 976),
		"TransitKeeper": Vector2i(1488, 976),
		"AetherBeacon": Vector2i(1520, 944),
	},
}

var failures := 0


func _init() -> void:
	for scene_path: String in MAP_CONTRACTS:
		var source := FileAccess.get_file_as_string(scene_path)
		_check(source.contains('[node name="TransitArrival"'), "%s has TransitArrival" % scene_path)
		_check(source.contains('[node name="TransitKeeper"'), "%s has TransitKeeper" % scene_path)
		_check(source.contains('[node name="AetherBeacon"'), "%s has an Aether Beacon" % scene_path)
		for expected: String in MAP_CONTRACTS[scene_path]:
			_check(source.contains(expected), "%s contains %s" % [scene_path, expected])

	for scene_path: String in TILE_CENTER_CONTRACTS:
		var source := FileAccess.get_file_as_string(scene_path)
		for node_name: String in TILE_CENTER_CONTRACTS[scene_path]:
			var expected_position: Vector2i = TILE_CENTER_CONTRACTS[scene_path][node_name]
			var node_source := _node_block(source, node_name)
			_check(
				node_source.contains(
					"position = Vector2(%d, %d)" % [expected_position.x, expected_position.y]
				),
				"%s %s is at %s" % [scene_path, node_name, expected_position]
			)
			_check(
				posmod(expected_position.x, 32) == 16 and posmod(expected_position.y, 32) == 16,
				"%s %s is centered on the 32px tile grid" % [scene_path, node_name]
			)

	var lobby_source := FileAccess.get_file_as_string(
		"res://scenes/overworld/aether_clash/aether_clash_lobby.tscn"
	)
	_check(lobby_source.contains('[node name="TransitKeeper"'), "Aether Clash Lobby has a Transit Keeper")

	var texture := load(
		"res://assets/npcs/gen5-g4-ow-sprites/OW PACK/trPsychic_M.png"
	) as Texture2D
	_check(texture != null and texture.get_size() == Vector2(256, 256), "Transit Keeper uses the selected 4x4 overworld sheet")
	var keeper_source := FileAccess.get_file_as_string(
		"res://scripts/world/npcs/transit_keeper_npc.gd"
	)
	var keeper_scene_source := FileAccess.get_file_as_string(
		"res://scenes/npcs/transit_keeper_npc.tscn"
	)
	_check(keeper_scene_source.contains('display_name = "Aethernet Keeper"'), "Transit NPC uses the Aethernet name")
	_check(keeper_scene_source.contains('sprite_offset = Vector2(0, -16)'), "Aethernet Keeper sprite aligns with its collision")
	_check(keeper_scene_source.contains('portrait_id = "showdown_psychic_gen6"'), "Aethernet Keeper uses the Psychic catalog portrait")
	_check(keeper_scene_source.contains('groups=["aethernet_keeper"]'), "Aethernet Keepers are centrally discoverable by Beacons")
	_check(not keeper_source.contains("TransitService.attune"), "Transit Keeper does not attune players automatically")
	_check(keeper_source.contains("TransitService.load_network"), "Transit Keeper loads the travel network")
	_check(keeper_source.contains("npc.transit.attune_beacon_hint"), "Transit Keeper explains that the local Beacon must be attuned")
	_check(keeper_source.contains('network.get("anchorDestinationId"'), "Transit Keeper travels directly to the selected Aether Anchor")
	_check(not keeper_source.contains("TransitMenuScript"), "Transit Keeper no longer opens the destination selection menu")
	_check(keeper_source.contains("begin_authorized_teleport"), "Transit Keeper uses the authorized teleport flow")
	_check(keeper_source.contains("PlayerWalletService.apply_wallet_result"), "Transit travel updates the local wallet projection")
	var beacon_source := FileAccess.get_file_as_string(
		"res://scripts/world/interactables/aether_beacon.gd"
	)
	var transit_service_source := FileAccess.get_file_as_string(
		"res://scripts/services/transit_service.gd"
	)
	var english_localization := FileAccess.get_file_as_string("res://localization/en.json")
	_check(beacon_source.contains("TransitService.attune"), "Aether Beacon attunes through the server")
	_check(beacon_source.contains("destination_id, global_position"), "Aether Beacon supplies its placed world position")
	_check(transit_service_source.contains("save_current_player_state_now"), "Attunement synchronizes the player's current position first")
	_check(transit_service_source.contains('"beaconPosition"'), "Attunement sends the placed Beacon position")
	_check(transit_service_source.contains('TRANSIT_ENDPOINT + "/anchor"'), "Aether Anchor changes use the transit service")
	_check(beacon_source.contains("await super._process(delta)"), "Aether Beacon awaits the shared interaction coroutine")
	_check(beacon_source.contains("requires_facing = false"), "Aether Beacon enforces omnidirectional interaction at runtime")
	_check(beacon_source.contains("interaction_shape_size = Vector2(80, 80)"), "Aether Beacon enforces its local interaction radius at runtime")
	_check(
		beacon_source.contains("z_as_relative = false")
		and beacon_source.contains("floori(global_position.y)"),
		"Aether Beacon sorts its complete visual from the pedestal depth"
	)
	_check(beacon_source.contains("_refresh_activation_state"), "Aether Beacon restores its attuned visual state")
	_check(beacon_source.contains("_apply_activation_state(true)"), "Aether Beacon activates after attunement")
	_check(beacon_source.contains('_find_local_keeper()'), "Aether Beacon delegates its dialogue to the local Keeper")
	_check(beacon_source.contains('"add_system_message"'), "Aether Beacon announces a new attunement in system chat")
	_check(beacon_source.contains("AetherBeaconMenuScript"), "Aether Beacon owns the attuned Beacon action menu")
	_check(beacon_source.contains("AetherBeaconMenu.ACTION_EXPLAIN"), "Aether Beacon offers Aethernet explanation on demand")
	_check(not beacon_source.contains("_offer_anchor_change"), "New attunements do not force an Anchor choice")
	_check(beacon_source.contains("TransitService.set_anchor"), "Aether Beacon owns Anchor selection")
	_check(english_localization.contains('"ui.transit.attuned_system"'), "Aethernet attunement has a localized system message")
	var placeholder_source := FileAccess.get_file_as_string(
		"res://scenes/world/interactables/aether_beacon_placeholder.tscn"
	)
	_check(placeholder_source.contains('type="Polygon2D"'), "Aether Beacon has a code-native crystal placeholder")
	_check(placeholder_source.contains('[node name="Ring"'), "Aether Beacon placeholder has an animated ring")
	_check(placeholder_source.contains('[node name="Sparks"'), "Activated Aether Beacon has particle-like sparks")
	_check(placeholder_source.contains("requires_facing = false"), "Aether Beacon can be attuned from every side")
	_check(placeholder_source.contains("interaction_shape_size = Vector2(80, 80)"), "Aether Beacon interaction stays local to the crystal")
	_check(placeholder_source.contains("z_as_relative = false"), "Aether Beacon uses absolute character-compatible depth sorting")
	var menu_source := FileAccess.get_file_as_string("res://scripts/ui/transit_menu.gd")
	_check(english_localization.contains('"ui.transit.title": "Aethernet"'), "Transit UI is branded as Aethernet")
	_check(menu_source.contains("_destinations_by_region"), "Transit UI groups destinations by region")
	_check(menu_source.contains("_global_hubs"), "Transit UI separates worldwide hubs from regional destinations")
	_check(menu_source.contains("_global_hub_card"), "Transit UI gives worldwide hubs their own visual treatment")
	_check(menu_source.contains('destination.get("guildBenefitActive"'), "Transit UI displays the free Guild Lobby benefit")
	_check(english_localization.contains('"ui.transit.hubs": "Aethernet hubs"'), "Transit UI labels its worldwide hub section")
	_check(menu_source.contains("ScrollContainer.new()"), "Transit UI remains scrollable as towns are added")
	_check(menu_source.contains('destination.get("isAnchor"'), "Transit UI identifies the Aether Anchor")
	_check(menu_source.contains('ui.transit.travel_free'), "Transit UI labels Anchor travel as free without a price")
	_check(
		menu_source.contains("AetherConfirmationDialogScene.instantiate()"),
		"Transit travel uses the shared styled confirmation dialog"
	)
	_check(menu_source.contains("sourceRegionId") and menu_source.contains('== "all"'), "Only the Lobby exposes cross-region selection")

	if failures == 0:
		print("Transit network checks passed.")
	quit(failures)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	failures += 1
	push_error("FAIL: %s" % label)


func _node_block(source: String, node_name: String) -> String:
	var start := source.find('[node name="%s"' % node_name)
	if start < 0:
		return ""
	var end := source.find("\n[node ", start + 1)
	if end < 0:
		return source.substr(start)
	return source.substr(start, end - start)
