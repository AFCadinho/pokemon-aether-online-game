extends Area2D

@export_file("*.tscn") var target_scene_path := "res://scenes/overworld/kanto/towns/pallet_town/oaks_lab.tscn" 
@export var target_spawn_name := "FromPalletTown"

var is_transitioning := false


func _on_body_entered(body: Node2D) -> void:
	if is_transitioning:
		return
	if body.name != "Player":
		return
		
	var world := GameState.get_world()
	if world == null or not world.has_method("load_map"):
		push_error("ToOaksLab failed: could not resolve World.")
		return

	is_transitioning = true
	world.call_deferred("load_map", target_scene_path, target_spawn_name)
