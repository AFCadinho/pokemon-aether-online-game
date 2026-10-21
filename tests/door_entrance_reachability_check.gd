extends SceneTree

const PALLET_SCENE := "res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn"
# Approved map geometry: trigger centers differ from the visible door/step tile.
# Keep these expectations independent of the scene so offset regressions fail.
const PALLET_GEOMETRY := {
	"ToRivalsHouse": {
		"center": Vector2(1136, 384), "size": Vector2(32, 32),
		"arrival": Vector2(1136, 432), "return_spawn": "FromRivalsHouse",
		"interior": "res://scenes/overworld/kanto/towns/pallet_town/rivals_house.tscn",
	},
	"ToOaksLab": {
		"center": Vector2(1296, 800), "size": Vector2(32, 32),
		"arrival": Vector2(1296, 848), "return_spawn": "FromOaksLab",
		"interior": "res://scenes/overworld/kanto/towns/pallet_town/oaks_lab.tscn",
	},
}
const ENTRANCES := [
	[PALLET_SCENE, "ToRivalsHouse", "FromRivalsHouse", Vector2(1136, 400)],
	[PALLET_SCENE, "ToOaksLab", "FromOaksLab", Vector2(1296, 816)],
	["res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn", "ToBikeStore", "FromBikeStore", Vector2(624, 1648)],
	["res://scenes/overworld/kanto/towns/vermilion_city/vermilion_city.tscn", "ToPokecenter", "FromPokecenter", Vector2(400, 464)],
]
const PLAYER_SCRIPT := "res://scripts/world/player.gd"

class ExitProbe:
	extends "res://scripts/world/map_exit.gd"
	var entered := 0

	func _on_body_entered(body: Node2D) -> void:
		if body.name == player_node_name:
			entered += 1

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for entrance: Array in ENTRANCES:
		await _check_entrance(entrance[0], entrance[1], entrance[2], entrance[3])
	await _check_world_doors()
	quit(1 if failed else 0)


func _check_entrance(scene_path: String, exit_name: String, spawn_name: String, door_tile: Vector2) -> void:
	print("Checking ", exit_name)
	var town := (load(scene_path) as PackedScene).instantiate()
	var door := town.get_node("Exits/" + exit_name) as Area2D
	var hint := door.get_node("DoorTransitionHint") as Node2D
	var collision := town.find_child("Collision", true, false) as TileMapLayer
	var arrival := town.get_node("Spawns/" + spawn_name) as Marker2D
	_check(not door.call("contains_world_position", door_tile), "door trigger uses body overlap at the threshold")
	_check(hint.global_position == door_tile, "the hint marks the same door tile")
	_check(not door.call("contains_world_position", arrival.global_position),
		"returning from the house does not immediately re-enter")

	if scene_path == PALLET_SCENE:
		_check_pallet_geometry(town, door, exit_name, door_tile, arrival)
		await _check_physics_entry(door, door_tile, arrival.global_position)
	else:
		await _check_physics_entry(door, door_tile, arrival.global_position)

	town.free()


func _check_pallet_geometry(town: Node, door: Area2D, exit_name: String, door_tile: Vector2, arrival: Marker2D) -> void:
	var expected: Dictionary = PALLET_GEOMETRY[exit_name]
	var shape := door.get_node("CollisionShape2D") as CollisionShape2D
	var rectangle := shape.shape as RectangleShape2D
	_check(shape.global_position == expected.center, exit_name + " keeps the adjusted global trigger center")
	_check(rectangle != null and rectangle.size == expected.size, exit_name + " keeps the approved trigger size")
	_check(arrival.global_position == expected.arrival, exit_name + " keeps its exterior return marker")
	_check(not door.call("contains_world_position", door_tile + Vector2(0, 8)), exit_name + " excludes the former lower trigger strip")
	_check(door.is_connected("body_entered", Callable(door, "_on_body_entered")), exit_name + " retains its physics entry signal")

	# A position-only test missed this: the old trigger started overlapping
	# the player's real detection shape while still approaching the threshold.
	var actor := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	var detection := actor.get_node("DetectionShape") as CollisionShape2D
	var detector_size: Vector2 = (detection.shape as RectangleShape2D).size
	var approaching := Rect2(door_tile + Vector2(0, 24) + detection.position - detector_size / 2, detector_size)
	var trigger := Rect2(shape.global_position - rectangle.size / 2, rectangle.size)
	_check(not approaching.intersects(trigger), exit_name + " cannot fire early during the approach step")
	var former_trigger := Rect2(trigger.position + Vector2(0, 16), trigger.size)
	_check(approaching.intersects(former_trigger), exit_name + " regression detects the former early overlap")
	actor.free()

	_check(str(door.get("target_scene_path")) == expected.interior and str(door.get("target_spawn_name")) == "FromPalletTown", exit_name + " enters the matching interior")
	var interior := (load(expected.interior) as PackedScene).instantiate()
	var return_door := interior.get_node("Exits/ToPalletTown") as Area2D
	var return_path := str(return_door.get("target_scene_path"))
	if return_path.begins_with("uid://"):
		return_path = ResourceUID.get_id_path(ResourceUID.text_to_id(return_path))
	_check(return_path == PALLET_SCENE and str(return_door.get("target_spawn_name")) == expected.return_spawn, exit_name + " returns to the matching Pallet marker")
	var interior_arrival := interior.get_node("Spawns/FromPalletTown") as Marker2D
	_check(not return_door.call("contains_world_position", interior_arrival.global_position), exit_name + " interior arrival cannot immediately leave again")
	_check_player_detection(interior, return_door, return_door.global_position, interior_arrival.global_position)
	interior.free()


func _check_physics_entry(source: Area2D, door_tile: Vector2, arrival_position: Vector2) -> void:
	# Preserve the actual Area/shape/signal and the real player's body shape,
	# while isolating gameplay services and server transition handling.
	var fixture := Node2D.new()
	root.add_child(fixture)
	var trigger := source.duplicate() as Area2D
	trigger.set_script(ExitProbe)
	fixture.add_child(trigger)
	var actor := (load("res://scenes/player.tscn") as PackedScene).instantiate() as CharacterBody2D
	actor.set_script(null)
	for child: Node in actor.get_children():
		if child.name != &"DetectionShape":
			actor.remove_child(child)
			child.free()
	actor.name = "Player"
	actor.position = arrival_position
	fixture.add_child(actor)
	await _settle_physics()
	_check(trigger.entered == 0 and not trigger.overlaps_body(actor), "outside return marker cannot fire the physics exit")
	actor.position = door_tile + Vector2(0, 24)
	await _settle_physics()
	_check(trigger.entered == 0 and not trigger.overlaps_body(actor), "actual physics exit stays inactive early in the approach")
	actor.position = door_tile
	await _settle_physics()
	_check(trigger.entered == 1 and trigger.overlaps_body(actor), "actual player body enters the adjusted exit exactly once")
	actor.position = arrival_position
	await _settle_physics()
	_check(trigger.entered == 1 and not trigger.overlaps_body(actor), "leaving the trigger cannot dispatch another transition")
	fixture.free()


func _settle_physics() -> void:
	for step in range(3):
		await physics_frame
		await process_frame


func _check_player_detection(map: Node, door: Area2D, door_tile: Vector2, arrival_position: Vector2) -> void:
	# Exercise the player's completed-step fallback without depending on a
	# physics overlap signal or running the backend/network transition.
	door.set_script(ExitProbe)
	var player := load(PLAYER_SCRIPT).new() as Node2D
	player.name = "Player"
	map.get_node("Entities/Players").add_child(player)
	var game_state := root.get_node("GameState")
	var previous_map: Node = game_state.current_map
	game_state.current_map = map
	player.global_position = arrival_position
	_check(not player.call("check_for_map_exit"), "arrival stays outside the transition")
	player.global_position = door_tile
	_check(player.call("check_for_map_exit"), "a completed step onto the door detects an exit")
	_check(door.get("entered") == 1, "the completed step invokes the map transition once")
	player.global_position = arrival_position
	_check(not player.call("check_for_map_exit"), "returning to the arrival position cannot retrigger the exit")
	game_state.current_map = previous_map


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL %s" % message)


func _check_world_doors() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/world/map_doors.json"))
	catalog["res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn"] = [
		{"exit": "Exits/ToPokecenter", "enabled": true, "threshold": Vector2(1136, 1456), "arrivals": ["FromPokecenter"]},
		{"exit": "Exits/ToHouse1", "enabled": true, "threshold": Vector2(1552, 880), "arrivals": ["FromHouse1"]},
		{"exit": "Exits/ToTrainerSchool", "enabled": true, "threshold": Vector2(1904, 880), "arrivals": ["FromTrainerSchool"]},
	]
	catalog["res://scenes/overworld/kanto/towns/pewter_city/pewter_city.tscn"].append(
		{"exit": "Exits/ToGym", "enabled": true, "threshold": Vector2(592, 528), "arrivals": ["FromGym"]})
	var count := 0
	for path: String in catalog:
		var map := (load(path) as PackedScene).instantiate()
		if path.ends_with("/viridian_city/viridian_city.tscn"):
			var locked := map.get_node("Exits/ToGym") as Area2D
			var locked_shape := locked.get_node("CollisionShape2D") as CollisionShape2D
			_check(locked.get_script() == null, "Viridian gym remains unavailable")
			_check(locked_shape.global_position == Vector2(1328, 384) and locked_shape.shape.size == Vector2(32, 32), "locked gym also follows the trigger standard")
		for entry: Dictionary in catalog[path]:
			if not entry.enabled:
				continue
			count += 1
			print("Checking standard ", path, " ", entry.exit)
			var threshold: Vector2
			if entry.has("threshold"):
				threshold = entry.threshold
			else:
				# Last art row identifies the walkable doorway tile independently
				# of the exit/hint position being tested (32px movement grid).
				var bounds: Array = entry.bounds
				threshold = Vector2(floor((bounds[0] + bounds[2] / 2.0) / 32.0) * 32 + 16,
					floor((bounds[1] + bounds[3] - 1) / 32.0) * 32 + 16)
			if path.ends_with("/celadon_condominiums_roof.tscn"):
				# The raised facade has collision on the art's last row.
				# Its reachable entrance is the next tile down.
				threshold = Vector2(144, 496)
			var double_door: bool = entry.get("kind", "") == "double"
			if double_door:
				threshold.x = snappedf(float(entry.bounds[0]) + float(entry.bounds[2]) / 2.0, 32.0)
			var door := map.get_node(entry.exit) as Area2D
			var shape := door.get_node("CollisionShape2D") as CollisionShape2D
			_check(shape.shape is RectangleShape2D and shape.shape.size == Vector2(64 if double_door else 32, 32), "trigger matches the configured doorway width")
			_check(shape.global_position == threshold - Vector2(0, 16), "trigger bottom aligns with visible threshold")
			var hint := door.get_node_or_null("DoorTransitionHint") as Node2D
			if hint == null:
				hint = door.get_node("TransitionHint") as Node2D
			_check(hint.global_position == threshold, "hint identifies the actual doorway tile")
			var collision := map.find_child("Collision", true, false) as TileMapLayer
			_check(door.is_connected("body_entered", Callable(door, "_on_body_entered")), "physics signal remains connected")
			# Some entrances share a return door (department store); still test
			# their approach and use every configured return marker where present.
			await _check_physics_entry(door, threshold, threshold + Vector2(0, 32))
			for spawn: String in entry.arrivals:
				var arrival := map.get_node("Spawns/" + spawn) as Node2D
				await _check_physics_entry(door, threshold, arrival.global_position)
		map.free()
	print("Checked %d configured building door entrances" % count)
