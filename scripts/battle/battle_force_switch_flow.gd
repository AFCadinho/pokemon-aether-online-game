extends RefCounted

class_name BattleForceSwitchFlow

const PARTY_SLOT_RESOLVER := preload("res://scripts/battle/battle_party_slot_resolver.gd")

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

static func should_preserve_chained_request(next_phase: String, local_player_needs_force_switch: bool) -> bool:
	return next_phase.strip_edges() == "awaiting_force_switch" and local_player_needs_force_switch


static func opponent_replacement_still_required(
	response_requires_switch: bool,
	rendered_state_requires_switch: bool
) -> bool:
	# A hazard faint is first authoritative in the ordered events. Some response
	# projections do not carry the next forceSwitch request until the following
	# NPC submission, so either source must keep the bounded replacement chain.
	return response_requires_switch or rendered_state_requires_switch


static func should_infer_pvp_force_switch_from_fainted_active(
	phase: String,
	request_is_waiting: bool,
	decision_allows_choice: bool,
	active_fainted_with_available_switch: bool
) -> bool:
	return (
		phase.strip_edges() == "awaiting_force_switch"
		and not request_is_waiting
		and decision_allows_choice
		and active_fainted_with_available_switch
	)


func can_switch_to_slot(slot: int, player_id := "p1") -> bool:
	if battle_state == null:
		return false

	var team := battle_state.get_player_team(player_id)
	var index := slot - 1
	if index < 0 or index >= team.size():
		return false

	var pokemon_data = team[index]
	if not (pokemon_data is Dictionary):
		return false

	return can_switch_to_pokemon_data(pokemon_data as Dictionary, player_id)


func can_switch_to_pokemon_data(pokemon_data: Dictionary, player_id := "p1") -> bool:
	if battle_state == null:
		return false

	if is_player_trapped_outside_force_switch(player_id):
		return false

	return is_available_switch_candidate(pokemon_data)


static func find_switch_candidate(canonical_slot: int, canonical_roster: Array, request_team: Array) -> Dictionary:
	# Request order changes after switches. Resolve the actual Pokemon before
	# reading its health; a visual slot or old card must never supply eligibility.
	if canonical_slot <= 0:
		return {}
	var candidate: Dictionary = {}
	for value: Variant in request_team:
		if not (value is Dictionary):
			continue
		var pokemon_data := value as Dictionary
		var resolved_slot := PARTY_SLOT_RESOLVER.resolve_selected_slot(pokemon_data, canonical_roster) if not canonical_roster.is_empty() else PARTY_SLOT_RESOLVER.get_canonical_slot(pokemon_data)
		if resolved_slot != canonical_slot:
			continue
		if not candidate.is_empty():
			return {}
		candidate = pokemon_data
	return candidate.duplicate(true)


static func is_available_switch_candidate(pokemon_data: Dictionary) -> bool:
	if pokemon_data.is_empty():
		return false
	if bool(pokemon_data.get("active", false)):
		return false

	if bool(pokemon_data.get("fainted", false)):
		return false

	var condition := str(pokemon_data.get("condition", "")).strip_edges().to_lower()
	if condition == "fnt" or condition.ends_with(" fnt"):
		return false
	var health := condition.split(" ", false, 1)[0] if condition != "" else ""
	var current_health := str(health).split("/", false, 1)[0] if health != "" else ""
	if current_health.is_valid_float():
		return float(current_health) > 0
	for key: String in ["hp", "currentHp", "current_hp"]:
		var value: Variant = pokemon_data.get(key)
		if (value is int or value is float) and float(value) <= 0:
			return false
	return true


static func refresh_switch_card(card: Dictionary, canonical_roster: Array, request_team: Array) -> Dictionary:
	var slot := PARTY_SLOT_RESOLVER.resolve_selected_slot(card, canonical_roster) if not canonical_roster.is_empty() else PARTY_SLOT_RESOLVER.get_canonical_slot(card)
	var candidate := find_switch_candidate(slot, canonical_roster, request_team)
	var refreshed := card.duplicate(true)
	if candidate.is_empty():
		return refreshed
	for key: String in ["active", "fainted", "condition", "hp", "currentHp", "current_hp", "maxHp", "max_hp", "status"]:
		if candidate.has(key):
			refreshed[key] = candidate[key]
	var condition := str(candidate.get("condition", ""))
	if condition != "":
		BattleHpEventHelper.new().apply_condition_fields(refreshed, condition)
	return refreshed


func should_hide_active_pokemon(player_id: String, defer_force_switch_active_hide: bool) -> bool:
	if battle_state == null or defer_force_switch_active_hide:
		return false

	if not battle_state.is_active_pokemon_fainted(player_id):
		return false

	return battle_state.needs_force_switch(player_id) or battle_state.is_battle_ended()
