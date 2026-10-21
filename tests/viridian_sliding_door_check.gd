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
var house_door := false
var gym_door := false
var pewter_gym := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# Load the real scene, but isolate services/NPCs: this is not a backend test.
	var city := (load("res://scenes/overworld/kanto/towns/pewter_city/pewter_city.tscn" if pewter_gym else CITY) as PackedScene).instantiate()
	var visual := city.get_node("PewterCity" if pewter_gym else "ViridianCity")
	var door := visual.get_node(("GymDoubleSlidingDoor" if gym_door else ("House1HingedDoor" if house_door else "PokemonCenterSlidingDoor")))
	city.call("prepare_player_arrival", "FromRoute2")
	_check(door.open_amount == 0.0, "Other arrivals do not open tested door")
	city.call("prepare_player_arrival", ("FromGym" if gym_door else ("FromHouse1" if house_door else "FromPokecenter")))
	_check(door.open_amount == 1.0, "Matching return configures an already-open door")
	var other_door := visual.get_node_or_null("PokemonCenterSlidingDoor" if house_door else "House1HingedDoor")
	_check((pewter_gym and other_door == null) or (other_door != null and other_door.open_amount == 0.0), "Arrival opens only the matching building door")
	door.open_amount = 0.0; door.arrival_open = false; door.close_delay = 0.0
	var exit_node := city.get_node(("Exits/ToGym" if pewter_gym else ("Exits/ToHouse1" if house_door else "Exits/ToPokecenter")))
	var arrival: Vector2 = city.get_node(("Spawns/FromGym" if gym_door else ("Spawns/FromHouse1" if house_door else "Spawns/FromPokecenter"))).position
	if gym_door and not pewter_gym:
		_check(city.get_node("Exits/ToGym").get_script() == null, "Unavailable gym entrance remains unconfigured")
	else:
		_check(exit_node.target_scene_path.ends_with(("pewter_city/pewter_gym.tscn" if pewter_gym else ("viridian_city/house1.tscn" if house_door else "viridian_city/pokemon_center.tscn"))) and exit_node.target_spawn_name == ("FromPewterCity" if pewter_gym else ("FromViridianCity" if house_door else "FromOutside")), "Existing destination preserved")
		var threshold := _feet(Vector2(1136, 1456))
		var trigger := exit_node.get_node("CollisionShape2D") as CollisionShape2D
		_check(trigger.global_position == threshold - Vector2(0, 16) and trigger.shape.size == Vector2(32, 32), "Entry follows Pallet trigger standard")
		_check(not exit_node.contains_world_position(arrival), "Return spawn cannot retrigger entrance")
		# Real player-body entry and safe return are exercised for every building
		# by door_entrance_reachability_check.gd; feet alone sit on the lower edge.

	if pewter_gym:
		var interior := (load("res://scenes/overworld/kanto/towns/pewter_city/pewter_gym.tscn") as PackedScene).instantiate()
		var return_exit := interior.get_node("Exits/ToPewterCity")
		_check(return_exit.target_scene_path.ends_with("pewter_city/pewter_city.tscn") and return_exit.target_spawn_name == "FromGym", "Gym interior returns through the silent-open arrival hook")
		interior.free()

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
	_check(not door.pieces.is_empty(), "Real artwork resolves into door panel pieces")
	var local := Actor.new(); local.name = "Player"; players.add_child(local)
	var sfx := root.get_node("SfxManager")
	var sounds_before := sfx.get_child_count()
	local.position = _feet(Vector2(1136,1520))
	_tick(door,0.5)
	_check(door.open_amount == 0.0, "Door rests closed away from entrance")
	local.moving = true; local.target = arrival
	_tick(door,door.animation_seconds + 0.02)
	_check(door.open_amount == 1.0, "Door opens during approach step")
	_check(sfx.get_child_count() == sounds_before + 1, "Opening plays exactly one sound")
	var sound := sfx.get_child(sfx.get_child_count() - 1) as AudioStreamPlayer
	_check(sound != null and sound.stream.get_length() > 0.30 and sound.stream.get_length() < 0.35, "Short door sound loads as audio")
	_check(sound != null and sound.bus == root.get_node("SettingsManager").get_audio_output_bus("Overworld SFX"), "Door uses the user's SFX bus")
	local.moving = false; local.position = arrival
	_tick(door,0.3)
	_check(door.open_amount == 1.0, "Door stays open while standing in front")
	local.position = _feet(Vector2(1136,1456))
	_tick(door,0.3)
	_check(door.open_amount == 1.0, "Door stays open through entry")
	var remotes := Node2D.new(); remotes.name = "RemotePlayers"; players.add_child(remotes)
	var remote := Actor.new(); remotes.add_child(remote); remote.position = arrival
	local.position = _feet(Vector2(1200,1520))
	_tick(door,0.4)
	_check(door.open_amount == 1.0, "Second player keeps the door open after first leaves")
	_check(sfx.get_child_count() == sounds_before + 1, "Holding open for two players does not repeat sound")
	remote.free()
	_tick(door,0.5)
	_check(door.open_amount == 0.0, "Door closes after last player leaves or disconnects")
	_check(sfx.get_child_count() == sounds_before + 2, "Closing plays exactly one sound")
	_tick(door,0.5)
	_check(door.open_amount == 0.0, "Stale local movement target cannot reopen the door")
	local.position = arrival; access.is_unlocked = false
	_tick(door,0.5)
	_check(door.open_amount == 0.0, "Locked or unavailable access keeps door closed")
	_check(sfx.get_child_count() == sounds_before + 2, "Stationary and locked doors remain silent")
	access.is_unlocked = true
	_tick(door,0.05)
	_check(door.open_amount > 0.0 and door.open_amount < 1.0, "Opening has intermediate frames")
	local.position = _feet(Vector2(1200,1520))
	_tick(door,0.5)
	_check(door.open_amount == 0.0, "Interrupted approach recovers to closed")
	var before_distant := sfx.get_child_count()
	local.position = Vector2(2000,2000)
	var distant_trigger := Actor.new(); remotes.add_child(distant_trigger); distant_trigger.position = arrival
	_tick(door,0.5)
	_check(door.open_amount == 1.0 and sfx.get_child_count() == before_distant, "Remote player opens door silently for a distant listener")
	distant_trigger.free()
	_tick(door,0.5)
	_check(sfx.get_child_count() == before_distant, "Distant closing remains silent")
	var before_arrival := sfx.get_child_count()
	local.position = arrival; local.target = arrival; access.is_unlocked = false
	door.prepare_for_arrival()
	door.prepare_for_arrival()
	_tick(door,0.5)
	_check(door.open_amount == 1.0 and sfx.get_child_count() == before_arrival, "Return starts silently open, including repeated placement and pending access")
	local.position = _feet(Vector2(1200,1520))
	_tick(door,0.5)
	_check(door.open_amount == 0.0 and sfx.get_child_count() == before_arrival + 1, "Return door closes once after player walks away")
	access.is_unlocked = true; local.position = arrival
	_tick(door,0.5)
	map.free()
	print("Viridian gym door: " if gym_door else ("Viridian house door: " if house_door else "Viridian sliding door: "), "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _tick(door: Node, seconds: float) -> void:
	for index in range(ceili(seconds / 0.01)):
		door.call("_process", 0.01)

func _check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	failed = failed or not ok

func _feet(center_position: Vector2) -> Vector2:
	if pewter_gym:
		return center_position + Vector2(-544, -928)
	return center_position + (Vector2(192, -1056) if gym_door else (Vector2(416, -576) if house_door else Vector2.ZERO))
