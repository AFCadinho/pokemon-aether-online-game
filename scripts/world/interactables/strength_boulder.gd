extends WorldInteractable

class_name StrengthBoulder

@export_range(0.1, 1.0, 0.01) var push_duration := 0.28

var is_being_pushed := false

@onready var boulder_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


func _ready() -> void:
	interactable_kind = "strength_boulder"
	display_name = LocalizationManager.text("ui.field_move.strength.boulder")
	blocks_movement = true
	requires_facing = true
	super._ready()


func interact_with_player(player: Node2D) -> void:
	if is_being_pushed:
		return
	var push_direction := _push_direction_from_player(player)
	if push_direction == Vector2.ZERO:
		return

	var field_move_result: Dictionary = FieldMoveService.can_use_field_move("strength")
	if not bool(field_move_result.get("success", false)):
		await show_dialogue(
			[str(field_move_result.get("error", LocalizationManager.text("ui.field_move.strength.unavailable")))],
			display_name
		)
		return

	var destination := global_position + push_direction * TILE_SIZE
	if not player.has_method("can_move_to") or not bool(player.call("can_move_to", destination)):
		await show_dialogue(
			[LocalizationManager.text("ui.field_move.strength.blocked")],
			display_name
		)
		return

	_show_field_move_used_message(field_move_result)
	await _push_to(destination)


func _push_direction_from_player(player: Node2D) -> Vector2:
	if player == null:
		return Vector2.ZERO
	var player_feet_position := player.global_position
	if player.has_method("get_feet_position"):
		player_feet_position = player.call("get_feet_position") as Vector2
	var delta := global_position - player_feet_position
	if absf(absf(delta.x) - TILE_SIZE) <= 1.0 and absf(delta.y) <= 1.0:
		return Vector2(signf(delta.x), 0.0)
	if absf(absf(delta.y) - TILE_SIZE) <= 1.0 and absf(delta.x) <= 1.0:
		return Vector2(0.0, signf(delta.y))
	return Vector2.ZERO


func _push_to(destination: Vector2) -> void:
	is_being_pushed = true
	if boulder_sprite != null:
		boulder_sprite.play("push")
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "global_position", destination, push_duration)
	await tween.finished
	global_position = destination
	if boulder_sprite != null:
		boulder_sprite.play("idle")
	is_being_pushed = false


func _show_field_move_used_message(field_move_result: Dictionary) -> void:
	var charm_name := str(field_move_result.get("itemName", "")).strip_edges()
	if charm_name != "":
		get_tree().call_group(
			"ui_overlay",
			"add_system_message",
			LocalizationManager.text("ui.field_move.item_used", {"item": charm_name})
		)
		return
	var pokemon: Pokemon = field_move_result.get("pokemon") as Pokemon
	var pokemon_name := (
		ContentLocalization.display_name("species", pokemon.species, pokemon.species)
		if pokemon != null
		else LocalizationManager.text("pokemon.generic")
	)
	get_tree().call_group(
		"ui_overlay",
		"add_system_message",
		LocalizationManager.text("ui.field_move.pokemon_used", {
			"pokemon": pokemon_name,
			"move": ContentLocalization.display_name("moves", "strength", "Strength"),
		})
	)
