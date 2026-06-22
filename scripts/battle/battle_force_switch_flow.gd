extends RefCounted

class_name BattleForceSwitchFlow

var battle_state: BattleState


func setup(state: BattleState) -> void:
	battle_state = state


func player_needs_force_switch(player_id := "p1") -> bool:
	return battle_state != null and battle_state.needs_force_switch(player_id)


func opponent_needs_auto_force_switch() -> bool:
	if battle_state == null or battle_state.is_battle_ended():
		return false

	return battle_state.needs_force_switch("p2")


func is_player_trapped_outside_force_switch(player_id := "p1") -> bool:
	if battle_state == null:
		return false

	return battle_state.is_active_trapped(player_id) and not battle_state.needs_force_switch(player_id)


func should_show_player_force_switch() -> bool:
	if battle_state == null or battle_state.is_battle_ended():
		return false

	return battle_state.needs_force_switch("p1")


func can_switch_to_slot(slot: int, player_id := "p1") -> bool:
	if battle_state == null:
		return false

	if is_player_trapped_outside_force_switch(player_id):
		return false

	var team := battle_state.get_player_team(player_id)
	var index := slot - 1
	if index < 0 or index >= team.size():
		return false

	var pokemon_data = team[index]
	if not (pokemon_data is Dictionary):
		return false

	if bool(pokemon_data.get("active", false)):
		return false

	if bool(pokemon_data.get("fainted", false)):
		return false

	var condition := str(pokemon_data.get("condition", "")).strip_edges().to_lower()
	return condition != "0 fnt" and not condition.ends_with(" fnt")


func should_hide_active_pokemon(player_id: String, defer_force_switch_active_hide: bool) -> bool:
	if battle_state == null or defer_force_switch_active_hide:
		return false

	if not battle_state.is_active_pokemon_fainted(player_id):
		return false

	return battle_state.needs_force_switch(player_id) or battle_state.is_battle_ended()
