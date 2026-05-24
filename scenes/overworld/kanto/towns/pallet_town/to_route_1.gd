extends Area2D

@export_file("*.tscn") var target_scene_path := "res://scenes/overworld/kanto/routes/kanto_route_1.tscn"
@export var target_spawn_name := "FromPalletTown"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return
		
	var world := get_tree().current_scene
	world.load_map(target_scene_path, target_spawn_name)
	
