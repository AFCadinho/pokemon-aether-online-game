extends SceneTree

const STATUS_PANEL_SCENE := preload("res://scenes/battle/battle_status_panel.tscn")
const TIMER_PANEL_SCENE := preload("res://scenes/battle/vs_panel_container.tscn")
const PARTY_SLOT_SCENE := preload("res://scenes/battle/party_slot.tscn")
const FIELD_TIMERS_SCENE := preload("res://scenes/battle/field_timers.tscn")
const STAT_STAGE_SCENE := preload("res://scenes/battle/stat_stage_panel.tscn")
const CALC_PANEL_SCRIPT := preload("res://scripts/battle/battle_ui/battle_damage_calc_panel.gd")

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
	var calc_panel := CALC_PANEL_SCRIPT.new()
	var field_timers := FIELD_TIMERS_SCENE.instantiate()
	var stat_stage_panel := STAT_STAGE_SCENE.instantiate()
	var calc_content := VBoxContainer.new()
	calc_content.name = "VBoxContainer"
	calc_panel.add_child(calc_content)
	party_slot.icon_only_mode = true
	host.add_child(status_panel)
	host.add_child(timer_panel)
	host.add_child(party_slot)
	host.add_child(calc_panel)
	host.add_child(field_timers)
	host.add_child(stat_stage_panel)
	await process_frame
	calc_panel.show_idle()
	field_timers.set_effects([{
		"effect": "RainDance",
		"effectType": "weather",
		"minRemainingTurns": 3,
		"maxRemainingTurns": 3,
	}], 1)
	stat_stage_panel.set_stat_stages({"atk": 1})

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
		calc_panel,
		field_timers,
		stat_stage_panel,
		"Turn: 3",
		"Team Preview · Choosing",
		"Time 00:45",
		"FNT",
		"Your Dmg",
		"Rain: 3",
		"Atk"
	)
	await _check_locale(
		"nl",
		status_panel,
		timer_panel,
		party_slot,
		calc_panel,
		field_timers,
		stat_stage_panel,
		"Beurt: 3",
		"Teamvoorbeeld · Kiezen",
		"Tijd 00:45",
		"K.O.",
		"Jouw schade",
		"Regen: 3",
		"Aan"
	)
	await _check_locale(
		"pt_BR",
		status_panel,
		timer_panel,
		party_slot,
		calc_panel,
		field_timers,
		stat_stage_panel,
		"Turno: 3",
		"Prévia da Equipe · Escolhendo",
		"Tempo 00:45",
		"FNT",
		"Seu dano",
		"Chuva: 3",
		"Atq"
	)
	_check_command_localization()

	localization_manager.call("set_locale", original_locale)
	host.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check_command_localization() -> void:
	localization_manager.call("set_locale", "en")
	_check(
		localization_manager.call("text", "battle.command.move", {"pokemon": "Lopunny", "move": "Fake Out"}) == "Lopunny, use Fake Out!",
		"English trainer move command is localized"
	)
	_check(
		localization_manager.call("text", "battle.command.switch", {"from": "Lopunny", "to": "Garchomp"}) == "Lopunny, return! Go, Garchomp!",
		"English trainer switch command is localized"
	)
	_check(
		localization_manager.call("text", "battle.command.dodge", {"pokemon": "Garchomp"}) == "Garchomp, dodge!",
		"English trainer dodge command is localized"
	)
	localization_manager.call("set_locale", "nl")
	_check(
		localization_manager.call("text", "battle.command.go", {"pokemon": "Garchomp"}) == "Ga ervoor, Garchomp!",
		"Dutch trainer send-out command is localized"
	)
	_check(
		localization_manager.call("text", "battle.command.dodge", {"pokemon": "Garchomp"}) == "Garchomp, dodge!",
		"trainer dodge meme stays recognizable across locales"
	)


func _check_locale(
	locale: String,
	status_panel: Node,
	timer_panel: Node,
	party_slot: Node,
	calc_panel: Node,
	field_timers: Node,
	stat_stage_panel: Node,
	expected_turn: String,
	expected_state: String,
	expected_time: String,
	expected_fainted: String,
	expected_calc_tab: String,
	expected_field_timer: String,
	expected_stat: String
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
	var calc_content := calc_panel.get_node("VBoxContainer") as VBoxContainer
	var calc_tabs := calc_content.get_child(0) as HBoxContainer
	var your_damage_button := calc_tabs.get_child(0) as Button
	_check(
		your_damage_button.text == expected_calc_tab,
		"%s damage calculator updates at runtime" % locale
	)
	var field_row := field_timers.effects_container.get_child(1) as HBoxContainer
	var field_label := field_row.get_node("ConditionLabel") as Label
	_check(field_label.text == expected_field_timer, "%s field timer updates at runtime" % locale)
	var stat_badge := stat_stage_panel.stat_stage_row.get_child(1) as PanelContainer
	var stat_label := stat_badge.get_node("MarginContainer/HBoxContainer/StatLabel") as Label
	_check(stat_label.text == expected_stat, "%s stat badge updates at runtime" % locale)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
