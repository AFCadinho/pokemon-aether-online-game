extends SceneTree

const STORE := "res://scenes/overworld/kanto/towns/celadon_city/celadon_department_store.tscn"
const LOBBY := "res://scenes/overworld/aether_clash/aether_clash_lobby.tscn"
const VENDORS := {
	"BattlePointVendor": [Vector2(272, 240), "battle_point_exchange", "battle_point_vendor"],
	"EvolutionItemVendor": [Vector2(560, 240), "evolution_item_shop", "evolution_item_vendor"],
	"ZCrystalVendor": [Vector2(880, 240), "z_crystal_shop", "z_crystal_vendor"],
	"MegaStoneVendor": [Vector2(1168, 240), "mega_stone_shop", "mega_stone_vendor"],
	"TeamRentalNPC": [Vector2(272, 688), "team", "Team Rental"],
	"PokemonRentalNPC": [Vector2(1104, 688), "pokemon", "Pokémon Rental"],
}
var failed := false

class Customer extends Node2D:
	var last_direction := Vector2.UP
	func get_feet_position() -> Vector2:
		return position

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var store: Node2D = load(STORE).instantiate()
	var lobby: Node2D = load(LOBBY).instantiate()
	var collision: TileMapLayer = store.get_node("Tiles/Collision")
	var reached: Dictionary = _reachable(collision, Vector2i(42, 36), Vector2i(store.get_node("Spawns/FromOutside").position / 32))
	var customer := Customer.new()
	_check(store.get_node("Entities/NPCs").get_child_count() == 6, "All six lobby vendors have a department")
	for vendor_name: String in VENDORS:
		var vendor: Node2D = store.get_node("Entities/NPCs/" + vendor_name)
		var expected: Array = VENDORS[vendor_name]
		_check(not lobby.has_node("Entities/NPCs/" + vendor_name), "No duplicate left in lobby: " + vendor_name)
		_check(vendor.position == expected[0] and vendor.facing_direction == Vector2.DOWN, "Server placement and facing: " + vendor_name)
		_check(collision.get_cell_source_id(Vector2i(vendor.position / 32)) == -1, "Vendor stands on free staff floor: " + vendor_name)
		customer.position = vendor.position + Vector2(0, 96)
		_check(reached.has(Vector2i(customer.position / 32)), "Customer can walk from entrance to counter: " + vendor_name)
		vendor.feet_marker = vendor.get_node("FeetMarker")
		_check(vendor._is_player_facing_npc(customer), "Manual interaction reaches across counter: " + vendor_name)
		customer.last_direction = Vector2.DOWN
		_check(not vendor._is_player_facing_npc(customer), "Customer must face vendor: " + vendor_name)
		customer.last_direction = Vector2.UP
		var area: Area2D = vendor.get_node("InteractionArea")
		var shape: CollisionShape2D = area.get_node("CollisionShape2D")
		var local_customer := customer.position - vendor.position - area.position - shape.position
		_check(shape.shape is RectangleShape2D and Rect2(-shape.shape.size / 2, shape.shape.size).has_point(local_customer), "Interaction sensor includes customer side: " + vendor_name)
		if vendor_name.contains("Rental"):
			_check(vendor.rental_kind == expected[1] and vendor.display_name == expected[2], "Rental type and name preserved: " + vendor_name)
		else:
			_check(vendor.market_id == expected[1] and vendor.market_mode == "player_buys" and vendor.npc_definition_id == expected[2], "Existing shop and dialogue identity preserved: " + vendor_name)
	for npc_name: String in ["TransitKeeper", "ClashCoordinator", "ClashTrainingCaptain", "HealNPC", "HealNPC2"]:
		_check(lobby.has_node("Entities/NPCs/" + npc_name), "Lobby service remains available: " + npc_name)
	customer.free()
	store.free()
	lobby.free()
	print("CELADON_DEPARTMENT_VENDORS ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _reachable(collision: TileMapLayer, size: Vector2i, start: Vector2i) -> Dictionary:
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var index := 0
	while index < queue.size():
		var tile := queue[index]
		index += 1
		for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next := tile + direction
			if not Rect2i(Vector2i.ZERO, size).has_point(next) or seen.has(next) or collision.get_cell_source_id(next) != -1:
				continue
			seen[next] = true
			queue.append(next)
	return seen


