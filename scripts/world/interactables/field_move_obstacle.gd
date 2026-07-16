extends WorldInteractable

class_name FieldMoveObstacle

@export_enum("cut", "rock-smash") var required_field_move := "cut"
@export_multiline var unavailable_message := "This obstacle can be cleared with Cut."
@export var clear_frames: Array[Texture2D] = []
@export var clear_frame_duration := 0.11
@export var clear_duration := 0.32

var is_cleared := false

@onready var obstacle_sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D


func _ready() -> void:
	interactable_kind = required_field_move + "_obstacle"
	_ensure_interaction_area()


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and _can_start_field_move_interaction(player):
		await _start_manual_interaction(player)


func interact_with_player(_player: Node2D) -> void:
	if is_cleared:
		return
	var field_move_result: Dictionary = FieldMoveService.can_use_field_move(required_field_move)
	if not bool(field_move_result.get("success", false)):
		await show_dialogue([str(field_move_result.get("error", unavailable_message))])
		return

	var pokemon: Pokemon = field_move_result.get("pokemon") as Pokemon
	await _show_field_move_used_message(pokemon)
	await clear_obstacle()


# Wordt straks door de Cut/Rock Smash-field-move aangeroepen. Het object is
# daarna niet meer interactief of blokkerend en speelt een korte verdwijnanimatie.
func clear_obstacle() -> void:
	if is_cleared:
		return

	is_cleared = true
	set_process(false)
	if interaction_area != null:
		interaction_area.monitoring = false
		interaction_area.monitorable = false

	await _play_clear_animation()
	blocks_movement = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, clear_duration)
	await tween.finished
	queue_free()


func _play_clear_animation() -> void:
	if obstacle_sprite == null or clear_frames.is_empty():
		return

	for clear_frame: Texture2D in clear_frames:
		obstacle_sprite.texture = clear_frame
		await get_tree().create_timer(clear_frame_duration).timeout


func _show_field_move_used_message(pokemon: Pokemon) -> void:
	var pokemon_name := pokemon.species if pokemon != null else "Pokemon"
	var message := "%s used %s!" % [pokemon_name, _format_field_move_name(required_field_move)]
	get_tree().call_group("ui_overlay", "add_system_message", message)

	var dialogue_box := _get_dialogue_box()
	if dialogue_box == null:
		return

	var home_icon: Texture2D = null
	if pokemon != null:
		home_icon = PokemonAssets.load_home_sprite(pokemon.species, pokemon.shiny)
	dialogue_box.start_dialogue([message], pokemon_name, home_icon, home_icon != null)
	await dialogue_box.dialogue_finished


func _format_field_move_name(move_id: String) -> String:
	return move_id.replace("_", "-").replace("-", " ").capitalize()


func _can_start_field_move_interaction(player: Node2D) -> bool:
	if is_cleared or is_interacting:
		return false
	if _is_overworld_input_locked() or _is_ui_typing():
		return false
	if not Input.is_action_just_pressed("interact"):
		return false

	return _is_player_adjacent_to_obstacle(player)


func _is_player_adjacent_to_obstacle(player: Node2D) -> bool:
	var player_feet_position := player.global_position
	if player.has_method("get_feet_position"):
		player_feet_position = player.call("get_feet_position") as Vector2

	var delta := global_position - player_feet_position
	var is_horizontal_neighbor := absf(absf(delta.x) - TILE_SIZE) <= 1.0 and absf(delta.y) <= 1.0
	var is_vertical_neighbor := absf(absf(delta.y) - TILE_SIZE) <= 1.0 and absf(delta.x) <= 1.0
	return is_horizontal_neighbor or is_vertical_neighbor
