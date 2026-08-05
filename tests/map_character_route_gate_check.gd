extends SceneTree

const MapCharacterBlockingScript := preload("res://scripts/world/map_character_blocking.gd")
const MAP_GUARDS := {
	"res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn": [
		{"guard": "Entities/NPCs/RouteGateNPC", "exit": "Exits/ToRoute1"},
	],
	"res://scenes/overworld/kanto/routes/kanto_route_1.tscn": [
		{"guard": "Entities/NPCs/Dialogue/ViridianGuide", "exit": "Exits/ToViridianCity"},
	],
	"res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn": [
		{"guard": "Entities/NPCs/RouteGuards/NorthRouteGuard", "exit": "Exits/ToRoute2"},
		{"guard": "Entities/NPCs/RouteGuards/SouthRouteGuard", "exit": "Exits/ToRoute1"},
		{"guard": "Entities/NPCs/RouteGuards/WestRouteGuard", "exit": "Exits/ToRoute22"},
	],
}
const ATTENDANT_SCENE := "res://scenes/overworld/kanto/transition_buildings/route_2_gate.tscn"

var failed := false


class FakeGate extends Node2D:
	var guarded_rect := Rect2()
	var transition_guard := true
	var open := false

	func is_gate_open() -> bool:
		return open

	func guards_world_position(world_position: Vector2) -> bool:
		return transition_guard and not open and guarded_rect.has_point(world_position)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_guard_owned_zones()
	_check_map_guard_bindings()
	_check_transition_attendant()
	quit(1 if failed else 0)


func _check_guard_owned_zones() -> void:
	var map := Node2D.new()
	var entities := Node2D.new()
	entities.name = "Entities"
	map.add_child(entities)
	var npcs := Node2D.new()
	npcs.name = "NPCs"
	entities.add_child(npcs)

	var north_gate := _add_gate(npcs, Rect2(32, 32, 32, 32))
	var south_gate := _add_gate(npcs, Rect2(64, 64, 32, 32))
	var attendant := _add_gate(npcs, Rect2(96, 96, 32, 32))
	attendant.transition_guard = false

	_check_equal(
		MapCharacterBlockingScript.get_closed_route_gate_npc(map, Vector2(48, 48)),
		north_gate,
		"a closed transition guard owns its transition zone"
	)
	_check_equal(
		MapCharacterBlockingScript.get_closed_route_gate_npc(map, Vector2(80, 80)),
		south_gate,
		"each transition guard resolves its own zone"
	)

	north_gate.open = true
	_check_equal(
		MapCharacterBlockingScript.get_closed_route_gate_npc(map, Vector2(48, 48)),
		null,
		"an open matching guard does not fall back to another closed guard"
	)
	_check_equal(
		MapCharacterBlockingScript.get_closed_route_gate_npc(map, Vector2(112, 112)),
		null,
		"an attendant never creates a route blocking zone"
	)

	map.free()


func _check_map_guard_bindings() -> void:
	for scene_path: String in MAP_GUARDS:
		var packed := load(scene_path) as PackedScene
		_check(packed != null, "%s loads" % scene_path.get_file())
		if packed == null:
			continue
		var map := packed.instantiate()
		_check(map.get_node_or_null("RouteGates") == null, "%s has no separate RouteGates layer" % scene_path.get_file())
		for binding_value: Variant in MAP_GUARDS[scene_path]:
			var binding := binding_value as Dictionary
			var guard := map.get_node_or_null(str(binding.get("guard", "")))
			var exit := map.get_node_or_null(str(binding.get("exit", "")))
			_check(guard != null, "%s places %s" % [scene_path.get_file(), str(binding.get("guard", "")).get_file()])
			_check(exit != null, "%s places %s" % [scene_path.get_file(), str(binding.get("exit", "")).get_file()])
			if guard == null or exit == null:
				continue
			_check(str(guard.get("guard_role")) == "transition_guard", "%s is a transition guard" % guard.name)
			_check(guard.call("_resolve_guarded_exit") == exit, "%s resolves its own MapExit" % guard.name)
			var collision_shape := exit.get_node_or_null("CollisionShape2D") as CollisionShape2D
			_check(collision_shape != null, "%s exposes its transition shape" % exit.name)
			if collision_shape != null:
				_check(bool(exit.call("contains_world_position", collision_shape.global_position)), "%s owns the exit center" % guard.name)
				_check(not bool(exit.call("contains_world_position", collision_shape.global_position + Vector2(10000, 10000))), "%s excludes unrelated map positions" % guard.name)
			if guard.name == "RouteGateNPC":
				_check(
					guard.get("guard_blocking_offset") == Vector2(-64, -32)
					and guard.get("guard_blocking_size") == Vector2(160, 32),
					"Pallet route guard owns the former five-tile passage barrier"
				)
				_check(
					bool(guard.call("guards_world_position", Vector2(976, 176))),
					"Pallet route guard blocks the approach before visiting Oak"
				)
				var story_service := get_root().get_node("StoryService")
				story_service.call("apply_story", {
					"revision": 1,
					"quests": [{
						"questId": "choose_starter",
						"status": "completed",
						"steps": [{"stepId": "choose_starter", "status": "completed"}],
					}],
				})
				var player_save := get_root().get_node("PlayerSave")
				var party_value: Variant = player_save.get("party")
				if party_value is Array:
					(party_value as Array).clear()
				_check(
					bool(guard.call("guards_world_position", Vector2(976, 176))),
					"Pallet route guard stays closed after Oak when the party is empty"
				)
				_check(
					not bool(guard.call("guards_world_position", Vector2(976, 208))),
					"Pallet route guard leaves the town-side row walkable"
				)
				story_service.call("reset_story")
		map.free()


func _check_transition_attendant() -> void:
	var packed := load(ATTENDANT_SCENE) as PackedScene
	_check(packed != null, "transition building loads")
	if packed == null:
		return
	var map := packed.instantiate()
	var attendant := map.get_node_or_null("Entities/NPCs/GateNPC")
	_check(attendant != null, "transition building places its attendant")
	if attendant != null:
		_check(str(attendant.get("guard_role")) == "attendant", "counter guard keeps the attendant role")
		_check(not bool(attendant.call("guards_world_position", attendant.global_position)), "counter attendant creates no route blocking zone")
	map.free()


func _add_gate(parent: Node, guarded_rect: Rect2) -> FakeGate:
	var gate := FakeGate.new()
	gate.guarded_rect = guarded_rect
	parent.add_child(gate)
	return gate


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		print("PASS ", label)
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
