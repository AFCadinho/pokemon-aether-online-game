extends Node2D

const BATTLE_SCENE_PATH := "res://scenes/battle/battle.tscn"
const BATTLE_SCENE: PackedScene = preload(BATTLE_SCENE_PATH)

var is_in_battle := false
var battle_layer: CanvasLayer
var battle_instance: Node

@onready var player: CharacterBody2D = $Player

var is_loading_map := false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("world")
	var first_map := $CurrentMap.get_child(0)
	GameState.current_map = first_map
	MusicManager.play_map_music(first_map)
	
	move_player_to_map(first_map)
	
	player.refresh_map_layers()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func load_map(target_scene_path: String, target_spawn_name: String) -> void:
	if is_loading_map:
		push_warning("World.load_map ignored because a map is already loading: %s" % target_scene_path)
		return

	is_loading_map = true

	if target_scene_path == "":
		push_error("World.load_map failed: target_scene_path is empty.")
		is_loading_map = false
		return

	var target_scene := load(target_scene_path) as PackedScene
	if target_scene == null:
		push_error("World.load_map failed: could not load scene %s" % target_scene_path)
		is_loading_map = false
		return

	if player.get_parent() != null:
		player.get_parent().remove_child(player)

	for child in $CurrentMap.get_children():
		child.queue_free()

	var new_map := target_scene.instantiate()
	$CurrentMap.add_child(new_map)

	GameState.current_map = new_map
	MusicManager.play_map_music(new_map)

	var spawn_position := Vector2.ZERO
	var spawn := new_map.get_node_or_null("Spawns/" + target_spawn_name)
	if spawn != null:
		spawn_position = spawn.global_position
	else:
		push_warning("World.load_map: spawn '%s' not found in %s. Using Vector2.ZERO." % [target_spawn_name, target_scene_path])

	move_player_to_map(new_map)

	player.global_position = spawn_position
	player.target_position = spawn_position
	player.is_moving = false

	player.set_idle_frame()
	player.refresh_map_layers()

	await get_tree().physics_frame
	is_loading_map = false

func move_player_to_map(map: Node) -> void:
	var players := map.get_node_or_null("Entities/Players")
	if players == null:
		players = map.get_node_or_null("Characters")

	var player_parent := players if players != null else map
		
	if player.get_parent() != null:
		player.get_parent().remove_child(player)
		
	player_parent.add_child(player)

func create_dev_wild_battle_response(wild_pokemon: Pokemon) -> Dictionary:
	var battle_request := HTTPRequest.new()
	add_child(battle_request)
	
	var response: Dictionary = await BattleApiClient.create_dev_wild_battle(
		battle_request,
		BattleApiPayloads.from_player_save(PlayerSave),
		wild_pokemon.to_battle_dict()
	)
	
	battle_request.queue_free()
	return response

func create_triggered_wild_battle_response(area_id: String, encounter_type: String = "grass") -> Dictionary:
	var battle_request := HTTPRequest.new()
	add_child(battle_request)

	var response: Dictionary = await BattleApiClient.create_triggered_wild_battle(
		battle_request,
		BattleApiPayloads.from_player_save(PlayerSave),
		area_id,
		encounter_type
	)

	battle_request.queue_free()
	return response

func create_trainer_battle_response(trainer_id: String) -> Dictionary:
	var battle_request := HTTPRequest.new()
	add_child(battle_request)

	var response: Dictionary = await BattleApiClient.create_trainer_battle(
		battle_request,
		BattleApiPayloads.from_player_save(PlayerSave),
		trainer_id
	)

	battle_request.queue_free()
	return response

func start_dev_wild_battle(wild_pokemon: Pokemon) -> void:
	if is_in_battle:
		return
		
	is_in_battle = true
	_lock_overworld_for_battle()
	
	var response: Dictionary = await create_dev_wild_battle_response(wild_pokemon)
	if not response.get("success", false):
		push_warning("World.start_dev_wild_battle failed: %s" % str(response.get("error", "Unknown error")))
		_abort_battle_start()
		await GameErrorDialogService.show_report_to_staff_message()
		return
	
	battle_layer = CanvasLayer.new()
	battle_layer.layer = 10
	add_child(battle_layer)
	
	var battle_scene := BATTLE_SCENE
	if battle_scene == null:
		push_error("World.start_dev_wild_battle failed: could not load battle scene.")
		battle_layer.queue_free()
		battle_layer = null
		_abort_battle_start()
		await GameErrorDialogService.show_report_to_staff_message()
		return

	battle_instance = battle_scene.instantiate()
	battle_layer.add_child(battle_instance)

	if battle_instance.has_signal("battle_ended"):
		battle_instance.battle_ended.connect(_on_battle_ended)

	MusicManager.play_battle_music()
	
	await battle_instance.setup_wild_battle_from_response(
		PlayerSave.party[0],
		wild_pokemon,
		response
	)

func start_triggered_wild_battle_for_area(area_id: String, encounter_type: String = "grass") -> void:
	if is_in_battle:
		return

	is_in_battle = true
	_lock_overworld_for_battle()

	var response: Dictionary = await create_triggered_wild_battle_response(area_id, encounter_type)
	if not response.get("success", false):
		push_warning("World.start_triggered_wild_battle_for_area failed: %s" % str(response.get("error", "Unknown error")))
		_abort_battle_start()
		await GameErrorDialogService.show_report_to_staff_message()
		return

	var wild_pokemon_data: Dictionary = response.get("wildPokemon", {})
	var wild_pokemon: Pokemon = PokemonFactory.create_pokemon_from_backend_payload(wild_pokemon_data)
	if wild_pokemon == null:
		push_warning("World.start_triggered_wild_battle_for_area failed: backend wild Pokemon payload could not be loaded for display.")
		_abort_battle_start()
		await GameErrorDialogService.show_report_to_staff_message()
		return

	battle_layer = CanvasLayer.new()
	battle_layer.layer = 10
	add_child(battle_layer)

	var battle_scene := BATTLE_SCENE
	if battle_scene == null:
		push_error("World.start_triggered_wild_battle_for_area failed: could not load battle scene.")
		battle_layer.queue_free()
		battle_layer = null
		_abort_battle_start()
		await GameErrorDialogService.show_report_to_staff_message()
		return

	battle_instance = battle_scene.instantiate()
	battle_layer.add_child(battle_instance)

	if battle_instance.has_signal("battle_ended"):
		battle_instance.battle_ended.connect(_on_battle_ended)

	MusicManager.play_battle_music()

	await battle_instance.setup_wild_battle_from_response(
		PlayerSave.party[0],
		wild_pokemon,
		response
	)

func start_trainer_battle(trainer_data: Dictionary) -> bool:
	if is_in_battle:
		return false

	var trainer_id := str(trainer_data.get("id", ""))
	if trainer_id == "":
		push_warning("World.start_trainer_battle failed: trainer has no id.")
		return false

	is_in_battle = true
	_lock_overworld_for_battle()

	var response: Dictionary = await create_trainer_battle_response(trainer_id)
	if not response.get("success", false):
		push_warning("World.start_trainer_battle failed: %s" % str(response.get("error", "Unknown error")))
		_abort_battle_start()
		return false

	battle_layer = CanvasLayer.new()
	battle_layer.layer = 10
	add_child(battle_layer)

	var battle_scene := BATTLE_SCENE
	if battle_scene == null:
		push_error("World.start_trainer_battle failed: could not load battle scene.")
		battle_layer.queue_free()
		battle_layer = null
		_abort_battle_start()
		return false

	battle_instance = battle_scene.instantiate()
	battle_layer.add_child(battle_instance)

	if battle_instance.has_signal("battle_ended"):
		battle_instance.battle_ended.connect(_on_battle_ended)

	MusicManager.play_battle_music()

	await battle_instance.setup_trainer_battle_from_response(
		PlayerSave.party[0],
		trainer_data,
		response
	)

	return true
	
func end_wild_battle() -> void:
	if battle_layer != null:
		battle_layer.queue_free()
		
	battle_layer = null
	battle_instance = null
	is_in_battle = false
	_unlock_overworld_after_battle()
	MusicManager.play_overworld_music()
	
func _on_battle_ended(_result: Dictionary) -> void:
	end_wild_battle()

func _lock_overworld_for_battle() -> void:
	GameState.lock_input()
	player.is_moving = false
	player.target_position = player.global_position
	player.move_start_position = player.global_position
	player.move_elapsed = 0.0
	player.set_process(false)
	player.set_physics_process(false)
	player.set_idle_frame()

func _unlock_overworld_after_battle() -> void:
	player.set_process(true)
	player.set_physics_process(true)
	GameState.unlock_input()

func _abort_battle_start() -> void:
	is_in_battle = false
	_unlock_overworld_after_battle()
	MusicManager.play_overworld_music()
