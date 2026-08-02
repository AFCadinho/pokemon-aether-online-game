extends SceneTree

const MARKET_ATTENDANT_SCRIPT := "res://scripts/world/npcs/market_attendant_npc.gd"
const MARKET_ATTENDANT_SCENE := "res://scenes/npcs/market_attendant_npc.tscn"
const MARKET_SELLER_SCENE := "res://scenes/npcs/market_seller_npc.tscn"
const MARKET_BUYER_SCENE := "res://scenes/npcs/market_buyer_npc.tscn"
const PALLET_TOWN_SCENE := "res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn"
const VIRIDIAN_POKEMON_CENTER_SCENE := "res://scenes/overworld/kanto/towns/viridian_city/pokemon_center.tscn"

var failed := false


func _init() -> void:
	_check_market_attendant_script()
	_check_market_attendant_scene()

	quit(1 if failed else 0)


func _check_market_attendant_script() -> void:
	var text := _read_text(MARKET_ATTENDANT_SCRIPT)
	_check_true(text.contains("extends DialogueNPC"), "MarketAttendantNPC extends DialogueNPC")
	_check_true(text.contains("class_name MarketAttendantNPC"), "MarketAttendantNPC class exists")
	_check_true(text.contains("@export var market_id := \"standard\""), "MarketAttendantNPC exports market_id")
	_check_true(text.contains('@export_enum("player_buys", "player_sells")'), "MarketAttendantNPC exports an explicit market mode")
	_check_true(text.contains("get_node_or_null(\"/root/MarketService\")"), "MarketAttendantNPC uses MarketService autoload")
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
	var seller_source := _read_text(MARKET_SELLER_SCENE)
	var buyer_source := _read_text(MARKET_BUYER_SCENE)
	_check_true(seller_source.contains('npc_definition_id = "pokemart_seller"'), "Seller scene uses the generic seller definition")
	_check_true(seller_source.contains('market_mode = "player_buys"'), "Seller scene opens player buying")
	_check_true(buyer_source.contains('npc_definition_id = "pokemart_buyer"'), "Buyer scene uses the generic buyer definition")
	_check_true(buyer_source.contains('market_mode = "player_sells"'), "Buyer scene opens player selling")

	var pallet_source := _read_text(PALLET_TOWN_SCENE)
	var clerk_start := pallet_source.find('[node name="MarketSellerNPC" parent="Entities/NPCs"')
	var players_start := pallet_source.find('[node name="Players"', clerk_start)
	var placed_clerk_source := pallet_source.substr(clerk_start, players_start - clerk_start)
	_check_true(
		not placed_clerk_source.contains("npc_sprite_frames"),
		"Pallet Town clerk inherits sprite frames from the shared clerk scene"
	)
	var viridian_center_source := _read_text(VIRIDIAN_POKEMON_CENTER_SCENE)
	_check_true(
		viridian_center_source.contains('npc_id = "kanto_viridian_city_pokemon_center_clerk"')
		and viridian_center_source.contains('npc_definition_id = "kanto_viridian_city_pokemon_center_clerk"')
		and viridian_center_source.contains("preload_quest_markers = true"),
		"Viridian item seller loads its parcel metadata and quest marker"
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
