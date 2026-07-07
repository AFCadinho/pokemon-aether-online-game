extends Node2D

class_name StatusConditionOverlay

var condition_key := ""
var elapsed := 0.0
var tinted_sprite: AnimatedSprite2D
var frozen_sprite: AnimatedSprite2D
var frozen_sprite_was_playing := false


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

	if condition_key == "paralysis":
		_apply_sprite_tint(Color(1.0, 0.78, 0.04, 1.0), 1.45, 0.48, 0.42)
		return
	if condition_key == "poisoned":
		_apply_sprite_tint(Color(0.56, 0.26, 0.82, 1.0), 0.95, 0.26, 0.24)
		return
	if condition_key == "badly_poisoned":
		_apply_sprite_tint(Color(0.62, 0.0, 1.0, 1.0), 1.05, 0.62, 0.34)
		return
	if condition_key == "burned":
		_apply_sprite_tint(Color(1.0, 0.32, 0.08, 1.0), 1.12, 0.42, 0.32)
		return
	if condition_key == "frozen":
		_apply_frozen_sprite_state()
		return

	_reset_sprite_tint()


func _apply_sprite_tint(target_color: Color, speed: float, base_amount: float, pulse_amount: float) -> void:
	if tinted_sprite == null:
		return

	var pulse := 0.5 + 0.5 * sin(elapsed * TAU * speed)
	var flash := base_amount + pulse * pulse_amount
	var tint := Color(
		lerpf(1.0, target_color.r, flash),
		lerpf(1.0, target_color.g, flash),
		lerpf(1.0, target_color.b, flash),
		1.0
	)
	tinted_sprite.self_modulate = tint
	tinted_sprite.modulate = tint


func _reset_sprite_tint() -> void:
	_reset_frozen_sprite_state()
	if tinted_sprite != null and is_instance_valid(tinted_sprite):
		tinted_sprite.self_modulate = Color.WHITE
		tinted_sprite.modulate = Color.WHITE
	tinted_sprite = null


func _apply_frozen_sprite_state() -> void:
	if tinted_sprite == null:
		return

	if frozen_sprite != tinted_sprite:
		_reset_frozen_sprite_state()
		frozen_sprite = tinted_sprite
		frozen_sprite_was_playing = frozen_sprite.is_playing()
		frozen_sprite.pause()

	var pulse := 0.5 + 0.5 * sin(elapsed * TAU * 0.35)
	var flash := 0.36 + pulse * 0.12
	var tint := Color(
		lerpf(1.0, 0.58, flash),
		lerpf(1.0, 0.9, flash),
		1.0,
		1.0
	)
	tinted_sprite.self_modulate = tint
	tinted_sprite.modulate = tint


func _reset_frozen_sprite_state() -> void:
	if frozen_sprite != null and is_instance_valid(frozen_sprite) and frozen_sprite_was_playing:
		frozen_sprite.play()
	frozen_sprite = null
	frozen_sprite_was_playing = false


func _get_parent_sprite() -> AnimatedSprite2D:
	var parent_node := get_parent()
	if parent_node == null:
		return null

	var sprite := parent_node.get_node_or_null("AnimatedPokemonSprite") as AnimatedSprite2D
	if sprite != null:
		return sprite
	return parent_node.get_node_or_null("AnimatedPokemonSprite2") as AnimatedSprite2D


func _normalize_condition(value: String) -> String:
	match value.strip_edges().to_lower().replace(" ", "").replace("_", "").replace("-", ""):
		"par", "paralysis", "paralyzed":
			return "paralysis"
		"psn", "poison", "poisoned":
			return "poisoned"
		"tox", "toxic", "badlypoisoned", "toxicpoison":
			return "badly_poisoned"
		"brn", "burn", "burned":
			return "burned"
		"frz", "freeze", "frozen":
			return "frozen"
		_:
			return ""
