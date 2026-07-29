extends SceneTree

const STATUS_PANEL_SCENE := preload("res://scenes/battle/battle_status_panel.tscn")
const TIMER_PANEL_SCENE := preload("res://scenes/battle/vs_panel_container.tscn")
const PARTY_SLOT_SCENE := preload("res://scenes/battle/party_slot.tscn")

var failed := false
var localization_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	localization_manager = root.get_node_or_null("LocalizationManager")
	_check(localization_manager != null, "battle localization check can access LocalizationManager")
	if localization_manager == null:
		quit(1)
		return

	var original_locale := str(localization_manager.get("current_locale"))
	var host := Control.new()
	root.add_child(host)
	var status_panel := STATUS_PANEL_SCENE.instantiate()
	var timer_panel := TIMER_PANEL_SCENE.instantiate()
	var party_slot := PARTY_SLOT_SCENE.instantiate()
	party_slot.icon_only_mode = true
	host.add_child(status_panel)
	host.add_child(timer_panel)
	host.add_child(party_slot)
	await process_frame

	status_panel.set_turn(3)
	timer_panel.show_decision_timers(
		{
			"effectiveDecisionRemainingMs": 45_000,
			"decisionMaximumMs": 45_000,
			"decisionKind": "TEAM_PREVIEW",
			"state": "DECIDING",
		},
		{"state": "WAITING"}
	)
	party_slot.set_pokemon_data({
		"species": "Pikachu",
		"condition": "0 fnt",
		"hp": 0,
		"maxHp": 100,
		"fainted": true,
	})

	await _check_locale(
		"en",
		status_panel,
		timer_panel,
		party_slot,
		"Turn: 3",
		"Team Preview · Choosing",
		"Time 00:45",
		"FNT"
	)
	await _check_locale(
		"nl",
		status_panel,
		timer_panel,
		party_slot,
		"Beurt: 3",
		"Teamvoorbeeld · Kiezen",
		"Tijd 00:45",
		"K.O."
	)
	await _check_locale(
		"pt_BR",
		status_panel,
		timer_panel,
		party_slot,
		"Turno: 3",
		"Prévia da Equipe · Escolhendo",
		"Tempo 00:45",
		"FNT"
	)

	localization_manager.call("set_locale", original_locale)
	host.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check_locale(
	locale: String,
	status_panel: Node,
	timer_panel: Node,
	party_slot: Node,
	expected_turn: String,
	expected_state: String,
	expected_time: String,
	expected_fainted: String
) -> void:
	localization_manager.call("set_locale", locale)
	await process_frame
	var turn_label := status_panel.get_node("MarginContainer/HBoxContainer/TurnLabel") as Label
	var faint_badge := party_slot.get_node(
		"MarginContainer/HBoxContainer/PokemonIcon/IconStatusBadge"
	) as Label
	_check(turn_label.text == expected_turn, "%s battle turn text updates at runtime" % locale)
	_check(
		timer_panel.player_1_timer_state_label.text == expected_state,
		"%s decision state updates at runtime" % locale
	)
	_check(
		timer_panel.player_1_timer_label.text == expected_time,
		"%s decision timer updates at runtime" % locale
	)
	_check(faint_badge.text == expected_fainted, "%s fainted badge updates at runtime" % locale)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
