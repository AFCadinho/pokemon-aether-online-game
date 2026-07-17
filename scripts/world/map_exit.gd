extends Area2D

@export_file("*.tscn") var target_scene_path := ""
@export var target_spawn_name := ""
@export var player_node_name := "Player"

var is_transitioning := false


func _on_body_entered(body: Node2D) -> void:
	if is_transitioning:
		return
	if body.name != player_node_name:
		return

	if target_scene_path.strip_edges() == "":
		push_error("MapExit failed: target_scene_path is empty on %s." % get_path())
		return
	if target_spawn_name.strip_edges() == "":
		push_error("MapExit failed: target_spawn_name is empty on %s." % get_path())
		return

	var world := GameState.get_world()
	if world == null or not world.has_method("load_map"):
		push_error("MapExit failed: could not resolve World.")
		return
	if world.has_method("is_map_transition_in_progress") and bool(world.call("is_map_transition_in_progress")):
		return

	is_transitioning = true
	world.call_deferred("load_map", target_scene_path, target_spawn_name)
