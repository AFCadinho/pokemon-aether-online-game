extends SceneTree

const Blocking := preload("res://scripts/world/map_character_blocking.gd")
var failures := 0

class Blocker extends Node2D:
	var open := false
	func blocks_world_position(point: Vector2) -> bool:
		return not open and point == position
	func is_gate_open() -> bool:
		return open

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var map := Node.new()
	var entities := Node.new()
	entities.name = "Entities"
	map.add_child(entities)
	var npcs := Node.new()
	npcs.name = "NPCs"
	entities.add_child(npcs)
	var blocker := Blocker.new()
	blocker.position = Vector2(32, 32)
	npcs.add_child(blocker)
	for _i in 200:
		blocker.add_child(Node.new())
	root.add_child(map)
	_check(Blocking.is_position_blocked_by_character(map, blocker.position), "first query finds blocker")
	var index: Node = map.get_meta("character_blocker_index")
	_check(index.get("candidates").size() == 1, "decorative descendants are excluded from repeated scans")
	blocker.position = Vector2(64, 32)
	_check(not Blocking.is_position_blocked_by_character(map, Vector2(32, 32)), "moving blockers do not leave stale occupancy")
	_check(Blocking.get_closed_route_gate_npc(map, blocker.position) == blocker, "gate uses current position")
	blocker.open = true
	_check(not Blocking.is_position_blocked_by_character(map, blocker.position), "story state remains live")
	var added := Blocker.new()
	added.position = Vector2(96, 32)
	npcs.add_child(added)
	_check(Blocking.is_position_blocked_by_character(map, added.position), "dynamic additions invalidate topology")
	added.free()
	_check(not Blocking.is_position_blocked_by_character(map, Vector2(96, 32)), "dynamic removal invalidates topology")
	map.free()
	await process_frame
	print("map_blocker_index_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
