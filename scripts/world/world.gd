extends Node2D

@onready var player: CharacterBody2D = $Player

var is_loading_map := false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var first_map := $CurrentMap.get_child(0)
	GameState.current_map = first_map
	
	move_player_to_map(first_map)
	
	player.refresh_map_layers()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func load_map(target_scene_path: String, target_spawn_name: String) -> void:
	if is_loading_map:
		return

	is_loading_map = true

	if target_scene_path == "":
		is_loading_map = false
		return

	var target_scene := load(target_scene_path) as PackedScene
	if target_scene == null:
		is_loading_map = false
		return

	if player.get_parent() != null:
		player.get_parent().remove_child(player)

	for child in $CurrentMap.get_children():
		child.queue_free()

	var new_map := target_scene.instantiate()
	$CurrentMap.add_child(new_map)

	GameState.current_map = new_map

	var spawn_position := Vector2.ZERO
	var spawn := new_map.get_node_or_null("Spawns/" + target_spawn_name)
	if spawn != null:
		spawn_position = spawn.global_position

	player.global_position = spawn_position
	player.target_position = spawn_position
	player.is_moving = false

	move_player_to_map(new_map)

	player.set_idle_frame()
	player.refresh_map_layers()

	await get_tree().physics_frame
	is_loading_map = false

func move_player_to_map(map: Node) -> void:
	var characters := map.get_node_or_null("Characters")
	var player_parent := characters if characters != null else map
		
	if player.get_parent() != null:
		player.get_parent().remove_child(player)
		
	player_parent.add_child(player)
