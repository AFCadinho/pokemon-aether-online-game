extends Node2D

class_name StatusConditionOverlay

var condition_key := ""
var elapsed := 0.0
var tinted_sprite: AnimatedSprite2D
var frozen_sprite: AnimatedSprite2D
var frozen_sprite_was_playing := false
var sprite_tint_applied := false
var sleep_labels: Array[Label] = []


func set_condition(value: String) -> void:
	var normalized := _normalize_condition(value)
	if condition_key == normalized:
		return

	_reset_sprite_tint()
	condition_key = normalized
	elapsed = 0.0
	visible = condition_key != ""
	set_process(visible)


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
	if condition_key == "sleeping":
		_apply_sleep_sprite_state()
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
	sprite_tint_applied = true


func _reset_sprite_tint() -> void:
	_reset_frozen_sprite_state()
	_clear_sleep_labels()
	if sprite_tint_applied and tinted_sprite != null and is_instance_valid(tinted_sprite):
		tinted_sprite.self_modulate = Color.WHITE
		tinted_sprite.modulate = Color.WHITE
	tinted_sprite = null
	sprite_tint_applied = false


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
	sprite_tint_applied = true


func _reset_frozen_sprite_state() -> void:
	if frozen_sprite != null and is_instance_valid(frozen_sprite) and frozen_sprite_was_playing:
		frozen_sprite.play()
	frozen_sprite = null
	frozen_sprite_was_playing = false


func _apply_sleep_sprite_state() -> void:
	if tinted_sprite == null:
		return

	_apply_sprite_tint(Color(0.58, 0.52, 1.0, 1.0), 0.55, 0.14, 0.12)
	_ensure_sleep_labels()
	_update_sleep_labels()


func _ensure_sleep_labels() -> void:
	while sleep_labels.size() < 3:
		var label := Label.new()
		label.text = "Z"
		label.add_theme_font_size_override("font_size", 18 - sleep_labels.size() * 2)
		label.add_theme_color_override("font_color", Color(0.72, 0.78, 1.0, 0.0))
		label.add_theme_color_override("font_outline_color", Color(0.12, 0.15, 0.42, 0.0))
		label.add_theme_constant_override("outline_size", 2)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_index = 12
		add_child(label)
		sleep_labels.append(label)


func _update_sleep_labels() -> void:
	if tinted_sprite == null:
		return

	var sprite_rect := _get_tinted_sprite_visual_rect()
	var base_position := sprite_rect.position + Vector2(sprite_rect.size.x * 0.40, sprite_rect.size.y * 0.72)
	for index in range(sleep_labels.size()):
		var label := sleep_labels[index]
		if label == null or not is_instance_valid(label):
			continue

		var phase := fmod(elapsed * 0.34 + float(index) * 0.34, 1.0)
		var fade_in := smoothstep(0.0, 0.22, phase)
		var fade_out := 1.0 - smoothstep(0.58, 1.0, phase)
		var label_alpha := clampf(fade_in * fade_out * 0.88, 0.0, 0.88)
		var drift := Vector2(float(index) * 5.0 + sin(phase * TAU) * 3.0, -phase * 26.0)
		var label_size := label.get_combined_minimum_size()
		label.position = base_position + drift - (label_size * 0.5)
		label.modulate = Color(1.0, 1.0, 1.0, label_alpha)
		label.add_theme_color_override("font_outline_color", Color(0.12, 0.15, 0.42, label_alpha * 0.85))


func _get_tinted_sprite_visual_rect() -> Rect2:
	var parent_node := get_parent()
	if parent_node != null:
		var sprite_box := parent_node.get_parent()
		if sprite_box != null:
			sprite_box = sprite_box.get_parent()
			if sprite_box != null and sprite_box.has_method("_get_sprite_visual_rect_in_parent"):
				var rect_value: Variant = sprite_box.call("_get_sprite_visual_rect_in_parent", tinted_sprite)
				if rect_value is Rect2:
					return rect_value as Rect2

	var texture := _get_current_sprite_texture(tinted_sprite)
	if texture == null:
		return Rect2(tinted_sprite.position, Vector2.ZERO)

	var frame_size := texture.get_size()
	var sprite_scale := Vector2(abs(tinted_sprite.scale.x), abs(tinted_sprite.scale.y))
	var top_left := tinted_sprite.position
	if tinted_sprite.centered:
		top_left += (tinted_sprite.offset - (frame_size * 0.5)) * sprite_scale
	else:
		top_left += tinted_sprite.offset * sprite_scale
	return Rect2(top_left, frame_size * sprite_scale)


func _get_current_sprite_texture(sprite: AnimatedSprite2D) -> Texture2D:
	if sprite == null or sprite.sprite_frames == null:
		return null
	if not sprite.sprite_frames.has_animation(sprite.animation):
		return null

	var frame_count := sprite.sprite_frames.get_frame_count(sprite.animation)
	if frame_count <= 0:
		return null

	var frame_index := clampi(sprite.frame, 0, frame_count - 1)
	return sprite.sprite_frames.get_frame_texture(sprite.animation, frame_index)


func _clear_sleep_labels() -> void:
	for label in sleep_labels:
		if label != null and is_instance_valid(label):
			label.queue_free()
	sleep_labels.clear()


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
		"slp", "sleep", "sleeping", "asleep":
			return "sleeping"
		_:
			return ""
