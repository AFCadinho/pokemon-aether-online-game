extends "res://scripts/battle/coop_animation_router.gd"

# A native double battle still uses the singles move catalog. Map its two
# animation aliases to the actual pair of the four visible Pokémon sprites.
var _sprites_by_alias: Dictionary = {}
var _boxes_by_alias: Dictionary = {}
var _controllers_by_alias: Dictionary = {}


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


# The SpriteBox motion helpers affect both doubles sprites. Native co-op already
# animates the individual attacker and hit; never move/hide an entire side here.
func _play_move_actor_motion_if_needed(_config: Dictionary, _actor_ident: String) -> void:
	pass


func _hide_move_actor_sprite_if_needed(_config: Dictionary, _actor_ident: String) -> Array:
	return []


func _play_move_target_shake_if_needed(_config: Dictionary, _target_ident: String, _animation_options: Dictionary = {}) -> void:
	pass


func _play_move_target_hit_flash_if_needed(_config: Dictionary, _target_ident: String, _animation_options: Dictionary = {}) -> void:
	pass


func _get_sprite_box_for_ident(_ident: String) -> Node:
	return null
