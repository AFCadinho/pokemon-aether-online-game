extends "res://scripts/world/map_metadata.gd"

const AREA := "kanto_rocket_hideout_elevator"
const FLOORS := ["b1f", "b2f", "b4f"]
var current_floor := ""
var _ride: Tween
var _ride_owner := StringName("rocket_elevator_ride_%s" % get_instance_id())


func configure_rocket_elevator_instance(instance_map_id: String) -> void:
	var parts := instance_map_id.split(":")
	current_floor = ""
	if parts.size() == 3 and parts[0] == AREA and parts[1].is_valid_int() and int(parts[1]) > 0 and parts[2] in FLOORS:
		map_id = instance_map_id
		current_floor = parts[2]
	$Entities/Interactables/Panel.current_floor = current_floor.to_upper()
	for floor: String in FLOORS:
		var shape := get_node("Exits/To" + floor.to_upper() + "/CollisionShape2D") as CollisionShape2D
		shape.set_deferred("disabled", floor != current_floor)
	_refresh_exit_hints()


func _refresh_exit_hints() -> void:
	for floor: String in FLOORS:
		get_node("Exits/To" + floor.to_upper() + "/DoorTransitionHint").visible = floor == current_floor and not $Doors.visible


func play_departure() -> void:
	GameState.acquire_overworld_input_lock(_ride_owner)
	$Doors.show()
	_refresh_exit_hints()
	_ride = create_tween()
	_ride.tween_property($Doors/Left, "position:x", 0.0, 0.18)
	_ride.parallel().tween_property($Doors/Right, "position:x", 0.0, 0.18)
	for offset in [2.0, -2.0, 2.0, -2.0, 0.0]:
		_ride.tween_property($Visual, "position:y", offset, 0.08)
	await _ride.finished


func finish_ride() -> void:
	if _ride != null and _ride.is_valid():
		_ride.kill()
	$Visual.position = Vector2.ZERO
	$Doors/Left.position.x = -16.0
	$Doors/Right.position.x = 16.0
	$Doors.hide()
	_refresh_exit_hints()
	GameState.release_overworld_input_lock(_ride_owner)


func handoff_departure_input() -> void:
	# MapExit acquires World's teleport lock synchronously on the next call.
	GameState.release_overworld_input_lock(_ride_owner)


func _exit_tree() -> void:
	if _ride != null and _ride.is_valid():
		_ride.kill()
	GameState.release_overworld_input_lock(_ride_owner)
