extends RefCounted

class_name BattleEventRenderer

const DODGE_RESPONSE_DELAY_SECONDS := 0.10
const FALLBACK_MOVE_ACTION_LEAD_SECONDS := 0.40
const FALLBACK_DODGE_ACTION_LEAD_SECONDS := 0.70

var battle_log_panel: BattleLogPanel
var mini_battle_feed: MiniBattleFeed
var current_action_panel: CurrentActionPanel
var animation_router: BattleAnimationRouter
var message_timing: BattleMessageTiming
var host_node: Node
var set_active_hud_hp_from_event: Callable
var animation_guard: Callable
var show_trainer_command: Callable
var last_battle_log_player_id := ""


func setup(
	battle_log: BattleLogPanel,
	mini_feed: MiniBattleFeed,
	action_panel: CurrentActionPanel,
	router: BattleAnimationRouter,
	timing: BattleMessageTiming,
	host: Node,
	hp_event_callback: Callable,
	animation_guard_callback: Callable = Callable(),
	trainer_command_callback: Callable = Callable()
) -> void:
	battle_log_panel = battle_log
	mini_battle_feed = mini_feed
	current_action_panel = action_panel
	animation_router = router
	message_timing = timing
	host_node = host
	set_active_hud_hp_from_event = hp_event_callback
	animation_guard = animation_guard_callback
	show_trainer_command = trainer_command_callback


func reset_battle_log_player_gap() -> void:
	last_battle_log_player_id = ""


func add_turn_header(turn: int) -> void:
	if battle_log_panel == null:
		return

	battle_log_panel.add_turn_header(turn)
	if mini_battle_feed != null:
		mini_battle_feed.add_turn_header(turn)
	reset_battle_log_player_gap()


func render_event(event_data: Dictionary, presentation: Dictionary) -> void:
	var pre_log_message := str(presentation.get("pre_log_message", ""))
	var pre_log_kind := str(presentation.get("pre_log_kind", ""))
	var log_message := str(presentation.get("log_message", ""))
	var log_kind := str(presentation.get("log_kind", ""))
	var battle_message := str(presentation.get("battle_message", ""))
	var add_blank_after := bool(presentation.get("add_blank_after", false))
	var suppress_player_gap := bool(presentation.get("suppress_player_gap", false))
	var attack_actor_ident := str(presentation.get("attack_actor_ident", ""))
	var move_animation_name := str(presentation.get("move_animation_name", ""))
	var move_animation_actor_ident := str(presentation.get("move_animation_actor_ident", ""))
	var move_animation_target_ident := str(presentation.get("move_animation_target_ident", ""))
	var move_animation_result := str(presentation.get("move_animation_result", ""))
	var damage_target_ident := str(presentation.get("damage_target_ident", ""))
	var heal_target_ident := str(presentation.get("heal_target_ident", ""))
	var heal_followup_effect_animation_key := str(presentation.get("heal_followup_effect_animation_key", ""))
	var faint_target_ident := str(presentation.get("faint_target_ident", ""))
	var stat_change_target_ident := str(presentation.get("stat_change_target_ident", ""))
	var stat_change_amount := int(presentation.get("stat_change_amount", 0))
	var ability_boost_target_ident := str(presentation.get("ability_boost_target_ident", ""))
	var effect_animation_key: String = str(presentation.get("effect_animation_key", ""))
	var effect_animation_target_ident: String = str(presentation.get("effect_animation_target_ident", ""))

	if pre_log_message != "":
		if not suppress_player_gap:
			_add_battle_log_player_gap(event_data)
		_add_log_message(pre_log_message, pre_log_kind)

	if log_message != "":
		if not suppress_player_gap:
			_add_battle_log_player_gap(event_data)
		_add_log_message(log_message, log_kind)

	if add_blank_after:
		battle_log_panel.add_blank_line()

	if battle_message != "":
		current_action_panel.set_message(battle_message)

	var artificial_hold_seconds := 0.0
	var has_animation_action := (
		effect_animation_key != ""
		or attack_actor_ident != ""
		or move_animation_name != ""
		or damage_target_ident != ""
		or heal_target_ident != ""
		or heal_followup_effect_animation_key != ""
		or faint_target_ident != ""
		or stat_change_target_ident != ""
		or ability_boost_target_ident != ""
	)
	var animations_allowed := true
	if has_animation_action:
		animations_allowed = _can_start_battle_animation("event_renderer.render_event", {
			"event_type": str(event_data.get("type", "")),
			"attack_actor": attack_actor_ident,
			"move": move_animation_name,
			"effect": effect_animation_key,
			"damage_target": damage_target_ident,
		"heal_target": heal_target_ident,
		"heal_followup_effect": heal_followup_effect_animation_key,
			"faint_target": faint_target_ident,
			"stat_target": stat_change_target_ident,
		})
	if animations_allowed and attack_actor_ident != "" and move_animation_name != "":
		await _show_trainer_move_commands(
			event_data,
			attack_actor_ident,
			move_animation_name,
			move_animation_target_ident,
			move_animation_result
		)
	var defer_stat_change_effect := (
		stat_change_target_ident != ""
		and effect_animation_key in ["stat_up", "stat_down"]
	)
	if effect_animation_key != "" and heal_target_ident == "" and not defer_stat_change_effect:
		if animations_allowed:
			await animation_router.play_effect_animation(effect_animation_key, effect_animation_target_ident)
	if attack_actor_ident != "":
		var substitute_revealed := false
		if animations_allowed:
			substitute_revealed = await animation_router.reveal_pokemon_from_substitute_for_move(attack_actor_ident)
			await animation_router.play_attack_tween_for_actor(attack_actor_ident)
		if animations_allowed and move_animation_name != "":
			await animation_router.play_move_animation(move_animation_name, move_animation_actor_ident, move_animation_target_ident, {
				"result": move_animation_result,
			})
		if substitute_revealed:
			await animation_router.restore_substitute_after_move(attack_actor_ident)
		var move_hold_seconds := message_timing.get_move_animation_hold_seconds()
		artificial_hold_seconds += move_hold_seconds
		await _wait(move_hold_seconds)
	if damage_target_ident != "":
		_set_active_hud_hp_from_event(damage_target_ident, event_data, true)
		if animations_allowed:
			await animation_router.play_damage_tween_for_target(damage_target_ident)
		_set_active_hud_hp_from_event(damage_target_ident, event_data, false)
		var damage_hold_seconds := message_timing.get_damage_animation_hold_seconds()
		artificial_hold_seconds += damage_hold_seconds
		await _wait(damage_hold_seconds)
	if heal_target_ident != "":
		var heal_target_visible := true
		if animation_router != null:
			heal_target_visible = animation_router.is_event_target_currently_visible(heal_target_ident, event_data)
		if heal_target_visible:
			_set_active_hud_hp_from_event(heal_target_ident, event_data, true)
			if animations_allowed:
				if heal_followup_effect_animation_key != "":
					if effect_animation_key != "":
						await animation_router.play_effect_animation(effect_animation_key, effect_animation_target_ident)
					await animation_router.play_heal_presentation_for_target(
						heal_target_ident,
						heal_followup_effect_animation_key,
						event_data
					)
				else:
					await animation_router.play_heal_presentation_for_target(
						heal_target_ident,
						effect_animation_key,
						event_data
					)
			_set_active_hud_hp_from_event(heal_target_ident, event_data, false)
	if animations_allowed and stat_change_target_ident != "":
		await animation_router.play_stat_change_presentation_for_target(
			stat_change_target_ident,
			stat_change_amount,
			effect_animation_key
		)
		var stat_change_hold_seconds := message_timing.get_stat_change_animation_hold_seconds()
		artificial_hold_seconds += stat_change_hold_seconds
		await _wait(stat_change_hold_seconds)
	if animations_allowed and ability_boost_target_ident != "":
		await animation_router.play_stat_change_presentation_for_target(ability_boost_target_ident, 1, "stat_up")
		var ability_boost_hold_seconds := message_timing.get_stat_change_animation_hold_seconds()
		artificial_hold_seconds += ability_boost_hold_seconds
		await _wait(ability_boost_hold_seconds)
	if faint_target_ident != "":
		_set_active_hud_hp_from_event(faint_target_ident, event_data, false)
		if animations_allowed:
			await animation_router.play_faint_tween_for_target(faint_target_ident)
	if battle_message != "":
		var message_hold_seconds := message_timing.get_battle_message_hold_seconds(event_data, battle_message)
		await _wait(max(message_hold_seconds - artificial_hold_seconds, 0.0))


func _set_active_hud_hp_from_event(target_ident: String, event: Dictionary, use_previous_hp: bool) -> void:
	if set_active_hud_hp_from_event.is_valid():
		set_active_hud_hp_from_event.call(target_ident, event, use_previous_hp)

func _add_log_message(message: String, kind := "") -> void:
	if battle_log_panel != null:
		battle_log_panel.add_message(message, kind)
	if mini_battle_feed != null:
		mini_battle_feed.add_message(message, kind)


func _wait(seconds: float) -> void:
	if seconds <= 0.0 or host_node == null:
		return

	await host_node.get_tree().create_timer(seconds).timeout


func _can_start_battle_animation(source: String, details: Dictionary = {}) -> bool:
	if not animation_guard.is_valid():
		return true

	return bool(animation_guard.call(source, details))


func _show_trainer_move_commands(
	event_data: Dictionary,
	actor_ident: String,
	move_name: String,
	target_ident: String,
	animation_result: String
) -> void:
	if not show_trainer_command.is_valid():
		return
	var attack_command_result: Variant = show_trainer_command.call({
		"kind": "move",
		"player_id": _get_player_id_from_ident(actor_ident),
		"pokemon": actor_ident,
		"move": move_name,
		"event": event_data,
	})
	var attack_command_shown := _command_was_shown(attack_command_result)
	if attack_command_shown:
		await _wait(_get_command_minimum_read_seconds(
			attack_command_result,
			FALLBACK_MOVE_ACTION_LEAD_SECONDS
		))
	if not attack_command_shown or animation_result != "miss" or target_ident == "":
		return

	await _wait(DODGE_RESPONSE_DELAY_SECONDS)
	var dodge_command_result: Variant = show_trainer_command.call({
		"kind": "dodge",
		"player_id": _get_player_id_from_ident(target_ident),
		"pokemon": target_ident,
		"event": event_data,
	})
	if _command_was_shown(dodge_command_result):
		await _wait(_get_command_minimum_read_seconds(
			dodge_command_result,
			FALLBACK_DODGE_ACTION_LEAD_SECONDS
		))


func _command_was_shown(result: Variant) -> bool:
	if result is Dictionary:
		return bool((result as Dictionary).get("shown", false))
	return bool(result)


func _get_command_minimum_read_seconds(result: Variant, fallback_seconds: float) -> float:
	if not (result is Dictionary):
		return fallback_seconds
	return clampf(
		float((result as Dictionary).get("minimum_read_seconds", fallback_seconds)),
		0.0,
		0.80
	)


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
		"switch", "drag":
			return str(event.get("playerId", ""))
		"move", "cant", "fail", "miss":
			return _get_player_id_from_ident(str(event.get("actor", "")))
		"prepare":
			return _get_player_id_from_ident(str(event.get("actor", "")))
		"hitCount", "criticalHit":
			return _get_player_id_from_ident(str(event.get("target", "")))
		"mega", "primal", "zPower":
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
