extends RefCounted

class_name BattleEventRenderer

var battle_log_panel: BattleLogPanel
var current_action_panel: CurrentActionPanel
var animation_router: BattleAnimationRouter
var message_timing: BattleMessageTiming
var host_node: Node
var set_active_hud_hp_from_event: Callable
var last_battle_log_player_id := ""


func setup(
	battle_log: BattleLogPanel,
	action_panel: CurrentActionPanel,
	router: BattleAnimationRouter,
	timing: BattleMessageTiming,
	host: Node,
	hp_event_callback: Callable
) -> void:
	battle_log_panel = battle_log
	current_action_panel = action_panel
	animation_router = router
	message_timing = timing
	host_node = host
	set_active_hud_hp_from_event = hp_event_callback


func reset_battle_log_player_gap() -> void:
	last_battle_log_player_id = ""


func add_turn_header(turn: int) -> void:
	if battle_log_panel == null:
		return

	battle_log_panel.add_turn_header(turn)
	reset_battle_log_player_gap()


func render_event(event_data: Dictionary, presentation: Dictionary) -> void:
	var pre_log_message := str(presentation.get("pre_log_message", ""))
	var log_message := str(presentation.get("log_message", ""))
	var battle_message := str(presentation.get("battle_message", ""))
	var add_blank_after := bool(presentation.get("add_blank_after", false))
	var suppress_player_gap := bool(presentation.get("suppress_player_gap", false))
	var attack_actor_ident := str(presentation.get("attack_actor_ident", ""))
	var move_animation_name := str(presentation.get("move_animation_name", ""))
	var move_animation_actor_ident := str(presentation.get("move_animation_actor_ident", ""))
	var move_animation_target_ident := str(presentation.get("move_animation_target_ident", ""))
	var damage_target_ident := str(presentation.get("damage_target_ident", ""))
	var heal_target_ident := str(presentation.get("heal_target_ident", ""))
	var faint_target_ident := str(presentation.get("faint_target_ident", ""))
	var stat_change_target_ident := str(presentation.get("stat_change_target_ident", ""))
	var stat_change_amount := int(presentation.get("stat_change_amount", 0))
	var ability_boost_target_ident := str(presentation.get("ability_boost_target_ident", ""))
	var effect_animation_key: String = str(presentation.get("effect_animation_key", ""))
	var effect_animation_target_ident: String = str(presentation.get("effect_animation_target_ident", ""))

	if pre_log_message != "":
		if not suppress_player_gap:
			_add_battle_log_player_gap(event_data)
		battle_log_panel.add_message(pre_log_message)

	if log_message != "":
		if not suppress_player_gap:
			_add_battle_log_player_gap(event_data)
		battle_log_panel.add_message(log_message)

	if add_blank_after:
		battle_log_panel.add_blank_line()

	if battle_message != "":
		current_action_panel.set_message(battle_message)

	if effect_animation_key != "" and heal_target_ident == "":
		await animation_router.play_effect_animation(effect_animation_key, effect_animation_target_ident)
	if attack_actor_ident != "":
		await animation_router.play_attack_tween_for_actor(attack_actor_ident)
		if move_animation_name != "":
			await animation_router.play_move_animation(move_animation_name, move_animation_actor_ident, move_animation_target_ident)
		await _wait(message_timing.get_move_animation_hold_seconds())
	if damage_target_ident != "":
		_set_active_hud_hp_from_event(damage_target_ident, event_data, true)
		await animation_router.play_damage_tween_for_target(damage_target_ident)
		_set_active_hud_hp_from_event(damage_target_ident, event_data, false)
		await _wait(message_timing.get_damage_animation_hold_seconds())
	if heal_target_ident != "":
		var heal_target_visible := true
		if animation_router != null:
			heal_target_visible = animation_router.is_target_ident_currently_visible(heal_target_ident)
		if heal_target_visible:
			_set_active_hud_hp_from_event(heal_target_ident, event_data, true)
			if effect_animation_key != "":
				await animation_router.play_effect_animation(effect_animation_key, effect_animation_target_ident)
			await animation_router.play_heal_tween_for_target(heal_target_ident)
			_set_active_hud_hp_from_event(heal_target_ident, event_data, false)
	if stat_change_target_ident != "":
		await animation_router.play_stat_change_tween_for_target(stat_change_target_ident, stat_change_amount)
		await _wait(message_timing.get_stat_change_animation_hold_seconds())
	if ability_boost_target_ident != "":
		await animation_router.play_stat_change_tween_for_target(ability_boost_target_ident, 1)
		await _wait(message_timing.get_stat_change_animation_hold_seconds())
	if faint_target_ident != "":
		await animation_router.play_faint_tween_for_target(faint_target_ident)
	if battle_message != "":
		await _wait(message_timing.get_battle_message_hold_seconds(event_data, battle_message))


func _set_active_hud_hp_from_event(target_ident: String, event: Dictionary, use_previous_hp: bool) -> void:
	if set_active_hud_hp_from_event.is_valid():
		set_active_hud_hp_from_event.call(target_ident, event, use_previous_hp)


func _wait(seconds: float) -> void:
	if seconds <= 0.0 or host_node == null:
		return

	await host_node.get_tree().create_timer(seconds).timeout


func _add_battle_log_player_gap(event: Dictionary) -> void:
	var player_id := _get_battle_log_event_player_id(event)
	if player_id == "":
		return

	if last_battle_log_player_id != "" and last_battle_log_player_id != player_id:
		battle_log_panel.add_gap()

	last_battle_log_player_id = player_id


func _get_battle_log_event_player_id(event: Dictionary) -> String:
	var event_type := str(event.get("type", ""))
	match event_type:
		"switch":
			return str(event.get("playerId", ""))
		"move", "cant", "fail", "miss":
			return _get_player_id_from_ident(str(event.get("actor", "")))
		"hitCount", "criticalHit":
			return _get_player_id_from_ident(str(event.get("target", "")))
		"mega":
			return _get_player_id_from_ident(str(event.get("target", "")))
		"ability":
			return _get_ability_event_player_id(event)
		"statChange":
			return _get_stat_change_event_player_id(event)
		"status":
			return _get_player_id_from_ident(str(event.get("target", event.get("pokemon", ""))))
		"pokemonEffect":
			return _get_pokemon_effect_event_player_id(event)
		"fieldEffect":
			return _get_field_effect_event_player_id(event)

	return ""


func _get_field_effect_event_player_id(event: Dictionary) -> String:
	var player_id := _get_player_id_from_ident(str(event.get("sourcePokemon", "")))
	if player_id != "":
		return player_id

	player_id = _get_player_id_from_ident(str(event.get("sourceTarget", "")))
	if player_id != "":
		return player_id

	return _get_player_id_from_ident(str(event.get("actor", "")))


func _get_ability_event_player_id(event: Dictionary) -> String:
	for key in ["target", "actor", "pokemon", "sourcePokemon", "sourceTarget"]:
		var player_id := _get_player_id_from_ident(str(event.get(str(key), "")))
		if player_id != "":
			return player_id

	return ""


func _get_stat_change_event_player_id(event: Dictionary) -> String:
	for key in ["target", "pokemon", "actor", "sourceTarget"]:
		var player_id := _get_player_id_from_ident(str(event.get(str(key), "")))
		if player_id != "":
			return player_id

	return ""


func _get_pokemon_effect_event_player_id(event: Dictionary) -> String:
	for key in ["target", "pokemon", "actor"]:
		var player_id := _get_player_id_from_ident(str(event.get(str(key), "")))
		if player_id != "":
			return player_id

	return ""


func _get_player_id_from_ident(ident: String) -> String:
	if ident.begins_with("p1"):
		return "p1"
	if ident.begins_with("p2"):
		return "p2"

	return ""
