extends "res://docs/forum-guides/all-guides/capture/base.gd"

func _run() -> void:
	await setup()
	var pokemon := sample_pokemon()
	var party: Array[Pokemon] = [pokemon,pokemon]
	root.get_node("PlayerSave").party = party
	var queues: Array[Dictionary] = [{"id":"ranked_queue_v1","name":"Aether OU","mode":"ranked","formatKey":"aether-ou","formatName":"Aether OU"},{"id":"ranked_aether_uu_queue_v1","name":"Aether UU","mode":"ranked","formatKey":"aether-uu","formatName":"Aether UU"}]
	overlay.call("_populate_pvp_queue_select",queues)
	overlay.set("pvp_active_queue_id","ranked_queue_v1")
	overlay.call("_render_pvp_team_preview")
	overlay.call("_refresh_pvp_team_validator")
	var popup := overlay.get("pvp_room_popup") as Control
	overlay.call("_select_pvp_root_tab","Ranked")
	(overlay.get("pvp_popup_title_label") as Label).text = "Ranked"
	popup.show()
	await settle()
	center(popup)
	await shot(71,"01-ranked-team-validation",popup,"Example validation issue: Species Clause prevents duplicate species. Select a format and fix the listed Party issues before finding a match.","## Joining Ranked")
	party = [pokemon]
	root.get_node("PlayerSave").party = party
	overlay.call("_select_pvp_root_tab","Custom / Casual")
	overlay.call("_on_pvp_room_mode_selected","create")
	(overlay.get("pvp_popup_title_label") as Label).text = "Custom / Casual"
	overlay.call("_set_pvp_popup_subtitle",root.get_node("LocalizationManager").text("ui.pvp.mode.private"))
	(overlay.get("pvp_timer_enabled_check") as CheckBox).button_pressed = true
	overlay.call("_on_pvp_timer_enabled_toggled",true)
	await shot(58,"02-room-timer-option",popup,"Example Custom Room: enable Battle Timer and select a speed before creating the room. Room timers differ from Ranked's time bank.","## Custom and Training Rooms")
	clear()
	var detached: Node = load("res://scenes/interface/ui_overlay.tscn").instantiate()
	detached.set("root_control",detached.get_node("Control"))
	detached.call("_setup_pvp_room_popup")
	var setup_panel: Control = detached.find_child("AiSparringPracticeHero",true,false).get_parent()
	setup_panel.reparent(overlay.get("root_control"))
	setup_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	setup_panel.size = Vector2(880,650)
	(detached.get("pvp_training_ai_bot_select") as OptionButton).clear()
	(detached.get("pvp_training_ai_bot_select") as OptionButton).add_item("AI4 Scholar")
	(detached.get("pvp_training_ai_mode_select") as OptionButton).clear()
	(detached.get("pvp_training_ai_mode_select") as OptionButton).add_item("Beginner")
	(detached.get("pvp_training_team_input") as TextEdit).text = "Bulbasaur\nAbility: Overgrow\nModest Nature\n- Vine Whip\n- Tackle\n- Growl"
	var catalog_entries: Array[Dictionary] = [read_fixture("rental-team.json")]
	detached.set("pvp_training_ai_catalog_entries",catalog_entries)
	detached.set("pvp_training_ai_resolved_team_id","smogon-ndou-screens-lameflame")
	detached.call("_refresh_pvp_training_ai_opponent_preview")
	setup_panel.show()
	await settle()
	setup_panel.size = Vector2(880,0)
	await settle()
	setup_panel.size = Vector2(880,0)
	await settle()
	setup_panel.show()
	center(setup_panel)
	print("SETUP_DEBUG ", setup_panel.get_global_rect(), " visible ",setup_panel.is_visible_in_tree())
	await shot(90,"01-sparring-setup",setup_panel,"Example AI Sparring setup: choose the opponent and difficulty, provide a team, and decide whether to allow spectators before starting practice.","## Start your first battle")
	detached.free()
	clear()
	var vs := load("res://scenes/battle/vs_panel_container.tscn").instantiate() as Control
	(overlay.get("root_control") as Control).add_child(vs)
	vs.custom_minimum_size = Vector2(950,110)
	vs.get("player_1_label").text = "You"
	vs.get("player_2_label").text = "Rival"
	vs.call("show_decision_timers",{"bankRemainingMs":160000,"bankMaximumMs":180000,"effectiveDecisionRemainingMs":90000,"decisionMaximumMs":90000,"decisionKind":"MOVE_SELECTION","state":"DECIDING"},{"effectiveDecisionRemainingMs":63000,"decisionMaximumMs":90000,"decisionId":"example","decisionKind":"MOVE_SELECTION","state":"WAITING"})
	vs.show()
	await settle()
	center(vs)
	await shot(58,"01-choice-and-waiting-timers",vs,"Example Ranked timer: your visible choice allowance is capped at 01:30. An accepted opponent choice shows Waiting with its remaining time frozen.","## Ranked Battles")
	finish("battles")
