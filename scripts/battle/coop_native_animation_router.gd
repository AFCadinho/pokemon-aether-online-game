extends "res://scripts/battle/coop_animation_router.gd"

# A native double battle still uses the singles move catalog. Map its two
# animation aliases to the actual pair of the four visible Pokémon sprites.
var _sprites_by_alias: Dictionary = {}
var _boxes_by_alias: Dictionary = {}
var _controllers_by_alias: Dictionary = {}
var _sprite_tweens: Dictionary = {}
var _sprite_poses: Dictionary = {}


func bind_native_pair(actor: String, target: String, sprites: Dictionary, boxes: Dictionary) -> Dictionary:
	var actor_sprite := sprites.get(actor) as AnimatedSprite2D
	var target_sprite := sprites.get(target) as AnimatedSprite2D
	var actor_box := boxes.get(actor) as Control
	var target_box := boxes.get(target) as Control
	if actor_sprite == null or target_sprite == null or actor_box == null or target_box == null:
		return {}
	if not actor_sprite.visible or not target_sprite.visible:
		return {}
	var actor_alias := "p2" if actor in ["p2", "p4"] else "p1"
	var target_alias := "p1" if actor_alias == "p2" else "p2"
	_sprites_by_alias = {actor_alias: actor_sprite, target_alias: target_sprite}
	_boxes_by_alias = {actor_alias: actor_box, target_alias: target_box}
	_controllers_by_alias = {actor_alias: actor, target_alias: target}
	return {"actor": actor_alias, "target": target_alias}


func _get_effect_target_anchor_in_parent(player_id: String, parent_node: Node, anchor_point := "center") -> Vector2:
	if not _sprites_by_alias.has(player_id) or not parent_node is CanvasItem:
		return Vector2.ZERO
	var sprite := _sprites_by_alias[player_id] as AnimatedSprite2D
	var box := _boxes_by_alias[player_id] as Control
	if sprite == null or box == null or not sprite.visible:
		return Vector2.ZERO
	var global_rect: Rect2 = box.call("_get_sprite_visual_rect_global", sprite)
	if global_rect.size.x <= 0.0 or global_rect.size.y <= 0.0:
		return Vector2.ZERO
	var transform := (parent_node as CanvasItem).get_global_transform().affine_inverse()
	var top_left := transform * global_rect.position
	var bottom_right := transform * global_rect.end
	var rect := Rect2(top_left, bottom_right - top_left)
	if anchor_point in ["feet", "battle"]:
		return Vector2(rect.get_center().x, rect.end.y)
	if anchor_point == "mouth":
		var facing := -1.0 if _controllers_by_alias[player_id] in ["p2", "p4"] else 1.0
		return rect.position + rect.size * Vector2(0.5 + facing * 0.38, 0.38)
	return rect.get_center()


# The SpriteBox helpers animate every visible Pokémon on one side. In doubles,
# only the concrete attacker or target may move, so these equivalents operate on
# the sprite selected by bind_native_pair instead.
func _play_move_actor_motion_if_needed(config: Dictionary, actor_ident: String) -> void:
	var motion_value: Variant = config.get("actor_motion", {})
	if not motion_value is Dictionary:
		return
	var motion_config := motion_value as Dictionary
	if not bool(motion_config.get("enabled", false)):
		return
	var sprite := _get_sprite_for_ident(actor_ident)
	if sprite == null:
		return
	var points_value: Variant = motion_config.get("points", [])
	if not points_value is Array or (points_value as Array).is_empty():
		return
	var direction := Vector2.ONE
	if _is_right_side(actor_ident):
		direction = Vector2(-1.0, -1.0)
		if not bool(config.get("actor_motion_mirror_vertical", true)):
			direction.y = 1.0
	var duration := maxf(float(motion_config.get("duration", 0.45)), 0.05)
	var tween := _begin_sprite_tween(sprite)
	if tween == null:
		return
	var base_pose: Dictionary = _sprite_poses.get(sprite.get_instance_id(), {})
	var base_position: Vector2 = base_pose.get("position", sprite.position)
	var base_scale: Vector2 = base_pose.get("scale", sprite.scale)
	for point_value: Variant in points_value as Array:
		if not point_value is Dictionary:
			continue
		var point := point_value as Dictionary
		var delay := clampf(float(point.get("at", 0.0)), 0.0, 1.0) * duration
		var segment_duration := maxf(float(point.get("duration", 0.05)), 0.01)
		var offset := _motion_offset(point.get("offset", [0, 0])) * direction
		var rotation := deg_to_rad(float(point.get("rotation_degrees", 0.0)) * direction.x)
		var scale_multiplier := maxf(float(point.get("scale", 1.0)), 0.1)
		tween.tween_property(sprite, "position", base_position + offset, segment_duration).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(sprite, "rotation", rotation, segment_duration).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(sprite, "scale", base_scale * scale_multiplier, segment_duration).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if point.has("opacity"):
			tween.tween_property(sprite, "modulate:a", clampf(float(point.get("opacity", 1.0)), 0.0, 1.0), segment_duration).set_delay(delay)
	_finish_sprite_tween(tween, sprite)


func _hide_move_actor_sprite_if_needed(config: Dictionary, actor_ident: String) -> Array:
	if not bool(config.get("hide_actor_sprite", false)):
		return []
	var sprite := _get_sprite_for_ident(actor_ident)
	if sprite == null or not sprite.visible:
		return []
	sprite.visible = false
	return [sprite]


func _restore_move_actor_sprite_if_needed(config: Dictionary, _actor_ident: String, hidden_sprites: Array) -> void:
	if not bool(config.get("hide_actor_sprite", false)):
		return
	for sprite_value: Variant in hidden_sprites:
		if sprite_value is AnimatedSprite2D and is_instance_valid(sprite_value):
			(sprite_value as AnimatedSprite2D).visible = true


func _play_move_target_shake_if_needed(config: Dictionary, target_ident: String, animation_options: Dictionary = {}) -> void:
	if target_ident == "" or _should_suppress_target_feedback_for_miss(config, animation_options):
		return
	var shake_config: Dictionary = (config.get("target_shake", {}) as Dictionary).duplicate(true)
	if not bool(shake_config.get("enabled", false)):
		return
	var sprite := _get_sprite_for_ident(target_ident)
	if sprite == null:
		return
	var duration := maxf(float(shake_config.get("duration", 0.65)), 0.05)
	var interval := maxf(float(shake_config.get("interval", 0.045)), 0.01)
	var amplitude := maxf(float(shake_config.get("amplitude", 8.0)), 0.0)
	var vertical_scale := maxf(float(shake_config.get("vertical_scale", 0.35)), 0.0)
	var decay := bool(shake_config.get("decay", true))
	var delay := maxf(float(shake_config.get("delay", 0.0)), 0.0)
	var steps := maxi(int(ceil(duration / interval)), 1)
	var tween := _begin_sprite_tween(sprite)
	if tween == null:
		return
	var base_position: Vector2 = (_sprite_poses.get(sprite.get_instance_id(), {}) as Dictionary).get("position", sprite.position)
	for step in range(steps):
		var progress := float(step) / float(maxi(steps - 1, 1))
		var strength := amplitude * (1.0 - progress) if decay else amplitude
		var direction := -1.0 if step % 2 == 0 else 1.0
		tween.tween_property(sprite, "position", base_position + Vector2(strength * direction, strength * vertical_scale * direction), interval).set_delay(delay + interval * step)
	tween.tween_property(sprite, "position", base_position, interval).set_delay(delay + duration)
	_finish_sprite_tween(tween, sprite)


func _play_move_target_hit_flash_if_needed(config: Dictionary, target_ident: String, animation_options: Dictionary = {}) -> void:
	if target_ident == "" or _should_suppress_target_feedback_for_miss(config, animation_options):
		return
	var flash_config: Dictionary = (config.get("target_hit_flash", {}) as Dictionary).duplicate(true)
	if not bool(flash_config.get("enabled", false)):
		return
	var sprite := _get_sprite_for_ident(target_ident)
	if sprite == null:
		return
	var delay := maxf(float(flash_config.get("delay", 0.0)), 0.0)
	var duration := maxf(float(flash_config.get("duration", 0.09)), 0.02)
	var tween := _begin_sprite_tween(sprite)
	if tween == null:
		return
	var base_modulate: Color = (_sprite_poses.get(sprite.get_instance_id(), {}) as Dictionary).get("modulate", sprite.modulate)
	tween.tween_property(sprite, "modulate", Color(1.0, 0.8, 0.8, base_modulate.a), duration * 0.36).set_delay(delay)
	tween.tween_property(sprite, "modulate", base_modulate, duration * 0.64).set_delay(delay + duration * 0.36)
	_finish_sprite_tween(tween, sprite)


func _play_move_target_dodge(target_ident: String, animation_options: Dictionary, returning := false) -> void:
	if not _is_miss_animation(animation_options):
		return
	if not returning and not bool(animation_options.get("dodge_started", false)):
		animation_options["dodge_started"] = true
		await _notify_dodge_started(animation_options)
	var sprite := _get_sprite_for_ident(target_ident)
	if sprite == null:
		return
	var tween := _begin_sprite_tween(sprite)
	if tween == null:
		return
	var base_position: Vector2 = (_sprite_poses.get(sprite.get_instance_id(), {}) as Dictionary).get("position", sprite.position)
	var direction := 1.0 if _is_right_side(target_ident) else -1.0
	var offset := Vector2.ZERO if returning else Vector2(20.0 * direction, -4.0)
	tween.tween_property(sprite, "position", base_position + offset, 0.14 if returning else 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	if returning:
		_reset_sprite_pose(sprite)


func _get_sprite_box_for_ident(_ident: String) -> Node:
	return null


func play_stat_change_tween_for_target(target_ident: String, amount: int) -> void:
	if amount == 0 or not SettingsManager.battle_animations:
		return
	var sprite := _get_sprite_for_ident(target_ident)
	if sprite == null:
		return
	var tween := _begin_sprite_tween(sprite)
	if tween == null:
		return
	var base_pose: Dictionary = _sprite_poses.get(sprite.get_instance_id(), {})
	var base_scale: Vector2 = base_pose.get("scale", sprite.scale)
	var base_modulate: Color = base_pose.get("modulate", sprite.modulate)
	var flash := Color("72e5a1") if amount > 0 else Color("ff6b76")
	tween.tween_property(sprite, "modulate", Color(flash.r, flash.g, flash.b, base_modulate.a), 0.10)
	tween.tween_property(sprite, "scale", base_scale * (1.10 if amount > 0 else 0.90), 0.10)
	tween.tween_property(sprite, "modulate", base_modulate, 0.18).set_delay(0.10)
	tween.tween_property(sprite, "scale", base_scale, 0.18).set_delay(0.10)
	_finish_sprite_tween(tween, sprite)


func cancel_render() -> void:
	for sprite_value: Variant in _sprites_by_alias.values():
		if sprite_value is AnimatedSprite2D and is_instance_valid(sprite_value):
			_reset_sprite_pose(sprite_value as AnimatedSprite2D)
	_sprite_tweens.clear()
	_sprite_poses.clear()
	super.cancel_render()


func _get_sprite_for_ident(ident: String) -> AnimatedSprite2D:
	var sprite := _sprites_by_alias.get(ident) as AnimatedSprite2D
	return sprite if sprite != null and is_instance_valid(sprite) and sprite.visible else null


func _is_right_side(ident: String) -> bool:
	return str(_controllers_by_alias.get(ident, "")) in ["p2", "p4"]


func _motion_offset(value: Variant) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Vector2:
		return value
	return Vector2.ZERO


func _begin_sprite_tween(sprite: AnimatedSprite2D) -> Tween:
	var key := sprite.get_instance_id()
	_reset_sprite_pose(sprite)
	_sprite_poses[key] = {
		"position": sprite.position,
		"rotation": sprite.rotation,
		"scale": sprite.scale,
		"modulate": sprite.modulate,
	}
	var tween := sprite.create_tween().set_parallel(true)
	_sprite_tweens[key] = tween
	return tween


func _finish_sprite_tween(tween: Tween, sprite: AnimatedSprite2D) -> void:
	tween.finished.connect(func() -> void:
		if is_instance_valid(sprite) and _sprite_tweens.get(sprite.get_instance_id()) == tween:
			_reset_sprite_pose(sprite)
	)


func _reset_sprite_pose(sprite: AnimatedSprite2D) -> void:
	var key := sprite.get_instance_id()
	var active_tween := _sprite_tweens.get(key) as Tween
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	var pose_value: Variant = _sprite_poses.get(key, {})
	if pose_value is Dictionary:
		var pose := pose_value as Dictionary
		sprite.position = pose.get("position", sprite.position)
		sprite.rotation = pose.get("rotation", sprite.rotation)
		sprite.scale = pose.get("scale", sprite.scale)
		sprite.modulate = pose.get("modulate", sprite.modulate)
	_sprite_tweens.erase(key)
	_sprite_poses.erase(key)
