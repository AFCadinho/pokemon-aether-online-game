extends SceneTree

const PANEL_SCENE := preload("res://scenes/battle/vs_panel_container.tscn")

var failed := false


func _init() -> void:
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

	panel.queue_free()
	host.queue_free()
	quit(1 if failed else 0)


func _check_true(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
