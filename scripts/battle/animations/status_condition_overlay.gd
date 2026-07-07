extends Node2D

class_name StatusConditionOverlay

var condition_key := ""
var elapsed := 0.0
var tinted_sprite: AnimatedSprite2D


func set_condition(value: String) -> void:
	var normalized := _normalize_condition(value)
	if condition_key == normalized:
		return

	condition_key = normalized
	elapsed = 0.0
	visible = condition_key != ""
	set_process(visible)
	if condition_key == "":
		_reset_sprite_tint()


func _ready() -> void:
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	elapsed += delta
	_update_sprite_tint()


func _exit_tree() -> void:
	_reset_sprite_tint()


func _update_sprite_tint() -> void:
	var sprite := _get_parent_sprite()
	if sprite != tinted_sprite:
		_reset_sprite_tint()
		tinted_sprite = sprite

	if tinted_sprite == null:
		return

	if condition_key != "paralysis":
		_reset_sprite_tint()
		return

	var pulse := 0.5 + 0.5 * sin(elapsed * TAU * 1.45)
	var flash := 0.48 + pulse * 0.42
	tinted_sprite.self_modulate = Color(
		1.0,
		lerpf(1.0, 0.78, flash),
		lerpf(1.0, 0.04, flash),
		1.0
	)


func _reset_sprite_tint() -> void:
	if tinted_sprite != null and is_instance_valid(tinted_sprite):
		tinted_sprite.self_modulate = Color.WHITE
	tinted_sprite = null


func _get_parent_sprite() -> AnimatedSprite2D:
	var parent_node := get_parent()
	if parent_node == null:
		return null

	var sprite := parent_node.get_node_or_null("AnimatedPokemonSprite") as AnimatedSprite2D
	if sprite != null:
		return sprite
	return parent_node.get_node_or_null("AnimatedPokemonSprite2") as AnimatedSprite2D


func _normalize_condition(value: String) -> String:
	match value.strip_edges().to_lower():
		"par", "paralysis", "paralyzed":
			return "paralysis"
		_:
			return ""
