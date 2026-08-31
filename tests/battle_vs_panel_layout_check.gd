extends SceneTree

const PANEL_SCENE := preload("res://scenes/battle/vs_panel_container.tscn")

var failed := false


func _init() -> void:
	_check_player_appearance_persistence()
	var host := Control.new()
	host.size = Vector2(1280, 720)
	root.add_child(host)
	var panel := PANEL_SCENE.instantiate()
	host.add_child(panel)
	await process_frame

	panel.set_names("A", "B")
	panel.set_player_appearances(
		{"gender": "male", "body": "Gen4_Base_v1", "skin_tone": "#f8d0b8"},
		{"gender": "female", "body": "Gen4_Base_v2", "skin_tone": "#3f271f"}
	)
	await process_frame
	_check_true(panel.player_1_portrait.visible, "local trainer portrait is visible")
	_check_true(panel.player_2_portrait.visible, "opponent trainer portrait is visible")
	_check_true(
		panel.player_1_portrait.get_index() < panel.player_1_label.get_index(),
		"local portrait remains left of the local name"
	)
	_check_true(
		panel.player_2_portrait.get_index() > panel.player_2_label.get_index(),
		"opponent portrait sits right of the opponent name"
	)
	_check_true(
		panel.player_2_portrait.appearance_state.get("skin_tone") == "#3f271f",
		"opponent trainer portrait receives its authoritative skin tone"
	)
	_check_true(
		panel.player_2_portrait.avatar != null
		and panel.player_2_portrait.avatar.find_child("BodySprite", true, false) != null,
		"opponent trainer portrait renders an avatar body"
	)
	var short_width: float = panel.names_panel.size.x
	_check_true(short_width >= 150.0, "short names respect the compact minimum")
	_check_true(short_width < 240.0, "short names do not keep the old fixed width")

	panel.set_names("Administrator", "Wild Rattata")
	await process_frame
	var medium_width: float = panel.names_panel.size.x
	_check_true(medium_width > short_width, "content grows the names panel")
	_check_true(medium_width <= 340.0, "names panel respects its maximum")

	panel.set_names("Extremely Long Player Display Name", "Extremely Long Opponent Display Name")
	await process_frame
	_check_true(panel.names_panel.size.x <= 340.0, "long names remain capped")
	panel.show_battle_limit("CLASH 07:30", Color.CYAN)
	_check_true(panel.battle_limit_label.visible, "Clash limit is visible beneath the player names")
	_check_true(panel.battle_limit_label.text == "CLASH 07:30", "Clash limit preserves the synchronized countdown text")

	panel.queue_free()
	host.queue_free()
	quit(1 if failed else 0)


func _check_player_appearance_persistence() -> void:
	var state := BattleState.new()
	state.load_from_api_response({
		"battleId": "battle-a",
		"players": {
			"p1": {"name": "Admin"},
			"p2": {
				"name": "adinho",
				"appearance": {"body": "Gen4_Base_v2", "skin_tone": "#3f271f"},
			},
		},
	})
	state.load_from_api_response({"battleId": "battle-a", "state": {"turn": 1}})
	_check_true(
		state.players.get("p2", {}).get("appearance", {}).get("skin_tone") == "#3f271f",
		"turn updates preserve opponent appearance metadata"
	)
	state.load_from_api_response({
		"battleId": "battle-a",
		"players": {"p2": {"name": "adinho"}},
		"state": {"turn": 1},
	})
	_check_true(
		state.players.get("p2", {}).get("appearance", {}).get("skin_tone") == "#3f271f",
		"name-only Team Preview updates preserve opponent appearance metadata"
	)
	state.load_from_api_response({"battleId": "battle-b", "state": {"turn": 1}})
	_check_true(state.players.is_empty(), "a new battle clears cached player identities")


func _check_true(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
