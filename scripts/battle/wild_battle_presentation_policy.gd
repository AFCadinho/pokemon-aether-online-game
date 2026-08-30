extends RefCounted

class_name WildBattlePresentationPolicy


static func should_fast_finish_win(
	is_wild_battle: bool,
	is_pvp_battle: bool,
	battle_animations_enabled: bool,
	battle_ended: bool,
	winner: Variant,
	local_player_id: String = "p1",
	local_display_name: String = ""
) -> bool:
	if not is_wild_battle or is_pvp_battle or battle_animations_enabled or not battle_ended:
		return false

	return _is_local_winner(winner, local_player_id, local_display_name)


static func _is_local_winner(winner: Variant, local_player_id: String, local_display_name: String) -> bool:
	var normalized_winner := str(winner).strip_edges().to_lower()
	if normalized_winner == "" or normalized_winner in ["none", "null", "<null>", "nil"]:
		return false

	var normalized_local_player_id := local_player_id.strip_edges().to_lower()
	if normalized_winner in ["p1", "player 1", "player1"]:
		return normalized_local_player_id == "p1"
	if normalized_winner in ["p2", "player 2", "player2"]:
		return normalized_local_player_id == "p2"

	var normalized_local_display_name := local_display_name.strip_edges().to_lower()
	return normalized_local_display_name != "" and normalized_winner == normalized_local_display_name
