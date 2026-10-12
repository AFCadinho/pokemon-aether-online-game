extends "res://scripts/world/npcs/museum_admission_npc.gd"

var legacy_lock_at_arrival := true


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


func show_gate_dialogue() -> void:
	pending_admission_state = {"mapId": "kanto_pewter_city_museum"}


func _apply_pending_admission() -> void:
	legacy_lock_at_arrival = get_node("/root/GameState").overworld_input_legacy_locked
