extends SceneTree

const STATUS_CONDITION_OVERLAY_SCRIPT := preload("res://scripts/battle/animations/status_condition_overlay.gd")

var failed := false


func _init() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var sprite_slot := Node2D.new()
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedPokemonSprite"
	sprite.sprite_frames = _make_sprite_frames()
	sprite_slot.add_child(sprite)

	var overlay := STATUS_CONDITION_OVERLAY_SCRIPT.new()
	sprite_slot.add_child(overlay)
	root.add_child(sprite_slot)

	sprite.play()
	overlay.set_condition("frozen")
	overlay._update_sprite_tint()
	_check_true(not sprite.is_playing(), "Frozen status pauses an animated sprite")

	# PvP state refreshes can restart the front sprite while it remains frozen.
	sprite.play()
	overlay._update_sprite_tint()
	_check_true(not sprite.is_playing(), "Frozen status re-pauses a sprite restarted by a refresh")

	sprite_slot.queue_free()
	quit(1 if failed else 0)


func _make_sprite_frames() -> SpriteFrames:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.add_frame("idle", texture)
	frames.add_frame("idle", texture)
	frames.set_animation_speed("idle", 10.0)
	return frames


func _check_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return

	failed = true
	push_error("FAIL %s" % message)
