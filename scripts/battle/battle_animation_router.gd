extends RefCounted

class_name BattleAnimationRouter

var player_sprite_box: Node
var enemy_sprite_box: Node


func setup(player_box: Node, enemy_box: Node) -> void:
	player_sprite_box = player_box
	enemy_sprite_box = enemy_box


func play_attack_tween_for_actor(actor_ident: String) -> void:
	match _get_player_id_from_ident(actor_ident):
		"p1":
			await player_sprite_box.play_attack_tween(Vector2(28, -6))
		"p2":
			await enemy_sprite_box.play_attack_tween(Vector2(-28, 6))


func play_damage_tween_for_target(target_ident: String) -> void:
	match _get_player_id_from_ident(target_ident):
		"p1":
			await player_sprite_box.play_damage_tween()
		"p2":
			await enemy_sprite_box.play_damage_tween()


func play_heal_tween_for_target(target_ident: String) -> void:
	match _get_player_id_from_ident(target_ident):
		"p1":
			await player_sprite_box.play_heal_tween()
		"p2":
			await enemy_sprite_box.play_heal_tween()


func play_faint_tween_for_target(target_ident: String) -> void:
	match _get_player_id_from_ident(target_ident):
		"p1":
			await player_sprite_box.play_faint_tween()
		"p2":
			await enemy_sprite_box.play_faint_tween()


func play_stat_change_tween_for_target(target_ident: String, amount: int) -> void:
	if amount == 0:
		return

	match _get_player_id_from_ident(target_ident):
		"p1":
			if amount > 0:
				await player_sprite_box.play_stat_raise_tween()
			else:
				await player_sprite_box.play_stat_drop_tween()
		"p2":
			if amount > 0:
				await enemy_sprite_box.play_stat_raise_tween()
			else:
				await enemy_sprite_box.play_stat_drop_tween()


func _get_player_id_from_ident(ident: String) -> String:
	if ident.begins_with("p1"):
		return "p1"
	if ident.begins_with("p2"):
		return "p2"

	return ""
