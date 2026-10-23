extends "res://scripts/world/npcs/museum_admission_npc.gd"

var legacy_lock_at_arrival := true
var route_lock_at_purchase := true
var purchase_count := 0
var observed_player: Node2D


func _init() -> void:
	var look := Node2D.new()
	look.name = "Look"
	add_child(look)
	var animated_sprite := AnimatedSprite2D.new()
	animated_sprite.name = "AnimatedSprite2D"
	look.add_child(animated_sprite)
	var marker := Marker2D.new()
	marker.name = "FeetMarker"
	add_child(marker)
	var area := Area2D.new()
	area.name = "InteractionArea"
	add_child(area)


func _ready() -> void:
	_bind_services()


func _process(_delta: float) -> void:
	pass


func face_world_position(_position: Vector2) -> void:
	pass


func _face_body(_body: Node2D) -> void:
	pass


func _set_idle_frame(_direction: Vector2) -> void:
	pass


func _refresh_transition_access(_force_refresh := false) -> Dictionary:
	transition_access = {"allowed": false, "reasonCode": "ENTRY_FEE_REQUIRED", "entryFee": 100}
	return {"success": true, "access": transition_access}


func _confirm_admission(_fee: int) -> bool:
	return true


func _purchase_admission() -> void:
	purchase_count += 1
	legacy_lock_at_arrival = get_node("/root/GameState").overworld_input_legacy_locked
	route_lock_at_purchase = bool(observed_player.get("route_gate_interaction_in_progress"))


class ExitMovementProbe:
	extends "res://scripts/world/player.gd"
	var test_map: Node

	func _resolve_current_map() -> Node:
		return test_map
