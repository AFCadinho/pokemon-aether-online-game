extends SceneTree

const MARKET_ATTENDANT_SCRIPT := "res://scripts/world/npcs/market_attendant_npc.gd"
const MARKET_ATTENDANT_SCENE := "res://scenes/npcs/market_attendant_npc.tscn"
const MARKET_SELLER_SCENE := "res://scenes/npcs/market_seller_npc.tscn"
const MARKET_BUYER_SCENE := "res://scenes/npcs/market_buyer_npc.tscn"
const BATTLE_POINT_VENDOR_SCENE := "res://scenes/npcs/battle_point_vendor_npc.tscn"
const Z_CRYSTAL_VENDOR_SCENE := "res://scenes/npcs/z_crystal_vendor_npc.tscn"
const PALLET_TOWN_SCENE := "res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn"
const VIRIDIAN_POKEMON_CENTER_SCENE := "res://scenes/overworld/kanto/towns/viridian_city/pokemon_center.tscn"

var failed := false


func _init() -> void:
	_check_market_attendant_script()
	_check_market_attendant_scene()
	_check_z_crystal_vendor_localization()

	quit(1 if failed else 0)


func _check_market_attendant_script() -> void:
	var text := _read_text(MARKET_ATTENDANT_SCRIPT)
	_check_true(text.contains("extends DialogueNPC"), "MarketAttendantNPC extends DialogueNPC")
	_check_true(text.contains("class_name MarketAttendantNPC"), "MarketAttendantNPC class exists")
	_check_true(text.contains("@export var market_id := \"standard\""), "MarketAttendantNPC exports market_id")
	_check_true(text.contains('@export_enum("player_buys", "player_sells")'), "MarketAttendantNPC exports an explicit market mode")
	_check_true(text.contains("get_node_or_null(\"/root/MarketService\")"), "MarketAttendantNPC uses MarketService autoload")
	_check_true(text.contains('world.call("save_current_player_state_now")'), "MarketAttendantNPC saves authoritative proximity before opening")
	_check_true(text.contains("await _load_npc_metadata()"), "MarketAttendantNPC loads shared NPC metadata")
	_check_true(text.contains('market_service.call("load_market", market_id)'), "MarketAttendantNPC loads its configured market")
	_check_true(text.contains("openingDialogueId"), "MarketAttendantNPC supports opening dialogue metadata")
	_check_true(text.contains('ui_overlay.call("open_market", market, market_mode, inventory_items)'), "MarketAttendantNPC opens its configured market mode")
	_check_true(text.contains('inventory_service.call("load_inventory")'), "Market buyer loads the player's inventory")
	_check_true(text.contains("failure_dialogue_lines"), "MarketAttendantNPC has fallback failure dialogue")
	_check_true(text.contains("questRewardId"), "MarketAttendantNPC supports catalog-driven quest rewards")
	_check_true(text.contains('claim_npc_item_reward", quest_reward_id'), "MarketAttendantNPC claims quest items authoritatively")


func _check_market_attendant_scene() -> void:
	var text := _read_text(MARKET_ATTENDANT_SCENE)
	_check_true(text.contains("res://scripts/world/npcs/market_attendant_npc.gd"), "MarketAttendant scene uses script")
	_check_true(text.contains("display_name = \"Clerk\""), "MarketAttendant scene has display name")
	_check_true(text.contains("InteractionArea"), "MarketAttendant scene has interaction area")
	_check_true(text.contains("FeetMarker"), "MarketAttendant scene has feet marker")
	_check_true(
		text.contains("manual_interaction_reach_tiles = 2")
		and text.contains("size = Vector2(160, 32)")
		and text.contains("position = Vector2(-32, 0)"),
		"Market attendants can be reached cardinally across the counter"
	)
	var seller_source := _read_text(MARKET_SELLER_SCENE)
	var buyer_source := _read_text(MARKET_BUYER_SCENE)
	_check_true(seller_source.contains('npc_definition_id = "pokemart_seller"'), "Seller scene uses the generic seller definition")
	_check_true(seller_source.contains('market_mode = "player_buys"'), "Seller scene opens player buying")
	_check_true(buyer_source.contains('npc_definition_id = "pokemart_buyer"'), "Buyer scene uses the generic buyer definition")
	_check_true(buyer_source.contains('market_mode = "player_sells"'), "Buyer scene opens player selling")
	var battle_point_vendor_source := _read_text(BATTLE_POINT_VENDOR_SCENE)
	_check_true(
		battle_point_vendor_source.contains('npc_definition_id = "battle_point_vendor"')
		and battle_point_vendor_source.contains('market_id = "battle_point_exchange"')
		and battle_point_vendor_source.contains("res://assets/sprites/mugshots/market_attendance.png")
		and not battle_point_vendor_source.contains("npc_sprite_frames =")
		and not battle_point_vendor_source.contains("showdown_pokefan_gen6"),
		"One reusable Battle Point vendor scene backs the lobby placement"
	)
	var z_crystal_vendor_source := _read_text(Z_CRYSTAL_VENDOR_SCENE)
	_check_true(
		z_crystal_vendor_source.contains('npc_definition_id = "z_crystal_vendor"')
		and z_crystal_vendor_source.contains('market_id = "z_crystal_shop"')
		and z_crystal_vendor_source.contains('market_mode = "player_buys"')
		and z_crystal_vendor_source.contains("res://assets/sprites/mugshots/market_attendance.png"),
		"One reusable Z-Crystal vendor scene backs the temporary lobby placement"
	)

	var pallet_source := _read_text(PALLET_TOWN_SCENE)
	_check_true(
		not pallet_source.contains('[node name="MarketSellerNPC" parent="Entities/NPCs"'),
		"Pallet Town no longer places an exterior market clerk"
	)
	var viridian_center_source := _read_text(VIRIDIAN_POKEMON_CENTER_SCENE)
	_check_true(
		viridian_center_source.contains('npc_id = "kanto_viridian_city_pokemon_center_clerk"')
		and viridian_center_source.contains('npc_definition_id = "kanto_viridian_city_pokemon_center_clerk"')
		and not viridian_center_source.contains("npc_metadata_id")
		and viridian_center_source.contains("preload_quest_markers = true"),
		"Viridian item seller loads its parcel metadata and quest marker"
	)


func _check_z_crystal_vendor_localization() -> void:
	for locale in {
		"en": "Z-Crystal Seller",
		"nl": "Z-Crystal-verkoper",
		"pt_BR": "Vendedor de Cristais Z",
		"zh_CN": "Z纯晶商人",
	}:
		var catalog_value: Variant = JSON.parse_string(_read_text("res://localization/%s.json" % locale))
		var catalog: Dictionary = catalog_value if catalog_value is Dictionary else {}
		_check_true(
			str(catalog.get("ui.item_dex.shop.z_crystal_shop", "")) == {
				"en": "Z-Crystal Seller",
				"nl": "Z-Crystal-verkoper",
				"pt_BR": "Vendedor de Cristais Z",
				"zh_CN": "Z纯晶商人",
			}[locale],
			"Z-Crystal Seller has an Item Dex name in %s" % locale
		)


func _read_text(path: String) -> String:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _check_true(condition: bool, message: String) -> void:
	if condition:
		return

	failed = true
	push_error("FAIL %s" % message)
