extends SceneTree

const CITY := "res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn"

class Actor:
	extends Node2D
	var moving := false
	var target := Vector2.ZERO
	func get_feet_position() -> Vector2: return global_position
	func get_target_feet_position() -> Vector2: return target
	func is_tile_moving() -> bool: return moving

class AccessLock:
	extends Node
	var is_unlocked := true

class ExitProbe:
	extends "res://scripts/world/map_exit.gd"
	var entered := 0
	func _on_body_entered(body: Node2D) -> void:
		if body.name == player_node_name: entered += 1

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# Load the real scene, but isolate services/NPCs: this is not a backend test.
	var city := (load(CITY) as PackedScene).instantiate()
	var visual := city.get_node("ViridianCity")
	var door := visual.get_node("PokemonCenterSlidingDoor")
	var exit_node := city.get_node("Exits/ToPokecenter")
	var collision := city.get_node("Collision") as TileMapLayer
	var arrival: Vector2 = city.get_node("Spawns/FromPokecenter").position
	_check(exit_node.target_scene_path.ends_with("viridian_city/pokemon_center.tscn") and exit_node.target_spawn_name == "FromOutside", "Existing Center destination preserved")
	_check(exit_node.contains_world_position(Vector2(1136, 1456)), "Entry trigger covers doorway")
	_check(not exit_node.contains_world_position(arrival), "Return spawn cannot retrigger entrance")
	_check(collision.get_cell_source_id(Vector2i(35,45)) == -1 and collision.get_cell_source_id(Vector2i(35,46)) == -1, "Door and approach remain walkable")

	# Actual player's completed-step exit detection still invokes this exit once.
	exit_node.set_script(ExitProbe)
	var player := load("res://scripts/world/player.gd").new() as Node2D
	player.name = "Player"
	city.get_node("Entities/Players").add_child(player)
	var state := root.get_node("GameState")
	var previous_map: Node = state.current_map
	state.current_map = city
	player.position = Vector2(1136,1456)
	_check(player.call("check_for_map_exit") and exit_node.entered == 1, "Player still detects the entry transition")
	player.position = arrival
	_check(not player.call("check_for_map_exit"), "Returning player stays outside transition")
	state.current_map = previous_map

	# Retain only the real visuals and the configured pilot, without live APIs.
	city.remove_child(visual)
	city.free()
	var map := Node2D.new()
	root.add_child(map)
	var entities := Node2D.new(); entities.name = "Entities"; map.add_child(entities)
	var players := Node2D.new(); players.name = "Players"; entities.add_child(players)
	var access := AccessLock.new(); access.name = "Access"; map.add_child(access)
	door.access_lock_path = NodePath("../../Access")
	map.add_child(visual)
	door.set_process(false)
	_check(not door.pieces.is_empty(), "Real artwork resolves into sliding panel pieces")
	var local := Actor.new(); local.name = "Player"; players.add_child(local)
	local.position = Vector2(1136,1520)
	_tick(door,0.5)
	_check(door.open_amount == 0.0, "Door rests closed away from entrance")
	local.moving = true; local.target = arrival
	_tick(door,0.2)
	_check(door.open_amount == 1.0, "Door opens during approach step")
	local.moving = false; local.position = arrival
	_tick(door,0.3)
	_check(door.open_amount == 1.0, "Door stays open while standing in front")
	local.position = Vector2(1136,1456)
	_tick(door,0.3)
	_check(door.open_amount == 1.0, "Door stays open through entry")
	var remotes := Node2D.new(); remotes.name = "RemotePlayers"; players.add_child(remotes)
	var remote := Actor.new(); remotes.add_child(remote); remote.position = arrival
	local.position = Vector2(1200,1520)
	_tick(door,0.4)
	_check(door.open_amount == 1.0, "Second player keeps the door open after first leaves")
	remote.free()
	_tick(door,0.5)
	_check(door.open_amount == 0.0, "Door closes after last player leaves or disconnects")
	_tick(door,0.5)
	_check(door.open_amount == 0.0, "Stale local movement target cannot reopen the door")
	local.position = arrival; access.is_unlocked = false
	_tick(door,0.5)
	_check(door.open_amount == 0.0, "Locked or unavailable access keeps door closed")
	access.is_unlocked = true
	_tick(door,0.05)
	_check(door.open_amount > 0.0 and door.open_amount < 1.0, "Opening has intermediate frames")
	local.position = Vector2(1200,1520)
	_tick(door,0.5)
	_check(door.open_amount == 0.0, "Interrupted approach recovers to closed")
	map.free()
	print("Viridian sliding door: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _tick(door: Node, seconds: float) -> void:
	for index in range(ceili(seconds / 0.01)):
		door.call("_process", 0.01)

func _check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	failed = failed or not ok
