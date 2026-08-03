extends HBoxContainer

class_name BattleVsPanelContainer

const TRAINER_HEAD_PORTRAIT_SCRIPT := preload("res://scripts/ui/trainer_head_portrait.gd")

const MIN_NAMES_PANEL_WIDTH := 150.0
const MAX_NAMES_PANEL_WIDTH := 340.0
# Margins, four HBox gaps, two portraits, the VS label, and the panel borders.
const NAMES_PANEL_CHROME_WIDTH := 131.0
const MIN_PLAYER_NAME_WIDTH := 40.0

@onready var names_panel: PanelContainer = $NamesPanel
@onready var player_1_label: Label = $NamesPanel/MarginContainer/HBoxContainer/Player1
@onready var player_2_label: Label = $NamesPanel/MarginContainer/HBoxContainer/Player2
@onready var player_1_timer_panel: PanelContainer = $Player1TimerPanel
@onready var player_2_timer_panel: PanelContainer = $Player2TimerPanel
@onready var player_1_timer_state_label: Label = $Player1TimerPanel/MarginContainer/VBoxContainer/Player1TimerStateLabel
@onready var player_2_timer_state_label: Label = $Player2TimerPanel/MarginContainer/VBoxContainer/Player2TimerStateLabel
@onready var player_1_timer_label: Label = $Player1TimerPanel/MarginContainer/VBoxContainer/Player1TimerLabel
@onready var player_2_timer_label: Label = $Player2TimerPanel/MarginContainer/VBoxContainer/Player2TimerLabel
@onready var player_1_timer_bar: ProgressBar = $Player1TimerPanel/MarginContainer/VBoxContainer/Player1TimerBar
@onready var player_2_timer_bar: ProgressBar = $Player2TimerPanel/MarginContainer/VBoxContainer/Player2TimerBar

var _player_1_timer: Dictionary = {}
var _player_2_timer: Dictionary = {}
var _player_1_reconnect: Dictionary = {}
var _player_2_reconnect: Dictionary = {}
var _localization_manager: Node
var player_1_portrait: TrainerHeadPortrait
var player_2_portrait: TrainerHeadPortrait


func _ready() -> void:
	_create_player_portraits()
	_localization_manager = get_tree().root.get_node_or_null("LocalizationManager")
	if (
		_localization_manager != null
		and not _localization_manager.locale_changed.is_connected(_on_locale_changed)
	):
		_localization_manager.locale_changed.connect(_on_locale_changed)
	_refresh_names_panel_width()


func set_names(player_1_name: String, player_2_name: String) -> void:
	player_1_label.text = player_1_name
	player_2_label.text = player_2_name
	_refresh_names_panel_width()


func set_player_appearances(player_1_state: Dictionary, player_2_state: Dictionary) -> void:
	if player_1_portrait != null:
		player_1_portrait.visible = not player_1_state.is_empty()
		if player_1_portrait.visible:
			player_1_portrait.set_appearance_state(player_1_state)
	if player_2_portrait != null:
		player_2_portrait.visible = not player_2_state.is_empty()
		if player_2_portrait.visible:
			player_2_portrait.set_appearance_state(player_2_state)


func _create_player_portraits() -> void:
	var name_row := player_1_label.get_parent() as HBoxContainer
	if name_row == null:
		return
	player_1_portrait = TRAINER_HEAD_PORTRAIT_SCRIPT.new() as TrainerHeadPortrait
	player_2_portrait = TRAINER_HEAD_PORTRAIT_SCRIPT.new() as TrainerHeadPortrait
	for portrait: TrainerHeadPortrait in [player_1_portrait, player_2_portrait]:
		portrait.custom_minimum_size = Vector2(28, 28)
		portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(player_1_portrait)
	name_row.add_child(player_2_portrait)
	name_row.move_child(player_1_portrait, player_1_label.get_index())
	name_row.move_child(player_2_portrait, player_2_label.get_index())


func _refresh_names_panel_width() -> void:
	var player_1_width: float = _measure_name_width(player_1_label)
	var player_2_width: float = _measure_name_width(player_2_label)
	var maximum_names_width := MAX_NAMES_PANEL_WIDTH - NAMES_PANEL_CHROME_WIDTH
	var desired_names_width := player_1_width + player_2_width
	if desired_names_width > maximum_names_width:
		var flexible_width := maximum_names_width - (MIN_PLAYER_NAME_WIDTH * 2.0)
		var player_1_demand := maxf(player_1_width - MIN_PLAYER_NAME_WIDTH, 0.0)
		var player_2_demand := maxf(player_2_width - MIN_PLAYER_NAME_WIDTH, 0.0)
		var total_demand := player_1_demand + player_2_demand
		if total_demand > 0.0:
			player_1_width = MIN_PLAYER_NAME_WIDTH + flexible_width * (player_1_demand / total_demand)
			player_2_width = MIN_PLAYER_NAME_WIDTH + flexible_width * (player_2_demand / total_demand)

	player_1_label.custom_minimum_size.x = ceilf(player_1_width)
	player_2_label.custom_minimum_size.x = ceilf(player_2_width)
	var content_width := player_1_label.custom_minimum_size.x + player_2_label.custom_minimum_size.x + NAMES_PANEL_CHROME_WIDTH
	names_panel.custom_minimum_size.x = clampf(content_width, MIN_NAMES_PANEL_WIDTH, MAX_NAMES_PANEL_WIDTH)


func _measure_name_width(label: Label) -> float:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	return maxf(ceilf(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x) + 4.0, MIN_PLAYER_NAME_WIDTH)


func _process(_delta: float) -> void:
	if not _player_1_reconnect.is_empty():
		_render_reconnect(player_1_timer_state_label, player_1_timer_label, player_1_timer_bar, _player_1_reconnect)
	if not _player_2_reconnect.is_empty():
		_render_reconnect(player_2_timer_state_label, player_2_timer_label, player_2_timer_bar, _player_2_reconnect)


func hide_decision_timers(clear_reconnect_state := false) -> void:
	if clear_reconnect_state:
		_player_1_reconnect.clear()
		_player_2_reconnect.clear()
	player_1_timer_panel.visible = false
	player_2_timer_panel.visible = false
	player_1_timer_label.visible = false
	player_2_timer_label.visible = false
	player_1_timer_state_label.visible = false
	player_2_timer_state_label.visible = false
	player_1_timer_bar.visible = false
	player_2_timer_bar.visible = false


func show_decision_timers(player_1_timer: Dictionary, player_2_timer: Dictionary) -> void:
	_player_1_timer = player_1_timer.duplicate(true)
	_player_2_timer = player_2_timer.duplicate(true)
	player_1_timer_panel.visible = true
	player_2_timer_panel.visible = true
	if _player_1_reconnect.is_empty():
		_set_timer(player_1_timer_state_label, player_1_timer_label, player_1_timer_bar, player_1_timer)
	if _player_2_reconnect.is_empty():
		_set_timer(player_2_timer_state_label, player_2_timer_label, player_2_timer_bar, player_2_timer)


func show_reconnect_timer(display_side: String, reconnect_deadline_at: String, grace_seconds: int, server_now: String = "") -> void:
	var deadline_unix := float(Time.get_unix_time_from_datetime_string(reconnect_deadline_at))
	if deadline_unix <= 0.0 or grace_seconds <= 0:
		return
	var anchor_unix := Time.get_unix_time_from_system()
	if server_now != "":
		var parsed_server_now := float(Time.get_unix_time_from_datetime_string(server_now))
		if parsed_server_now > 0.0:
			anchor_unix = parsed_server_now
	var remaining_ms := maxi(int(ceil((deadline_unix - anchor_unix) * 1000.0)), 0)
	var reconnect := {
		"expiresTicksMs": Time.get_ticks_msec() + remaining_ms,
		"graceSeconds": grace_seconds,
	}
	if display_side == "p1":
		_player_1_reconnect = reconnect
		player_1_timer_panel.visible = true
		_render_reconnect(player_1_timer_state_label, player_1_timer_label, player_1_timer_bar, reconnect)
	elif display_side == "p2":
		_player_2_reconnect = reconnect
		player_2_timer_panel.visible = true
		_render_reconnect(player_2_timer_state_label, player_2_timer_label, player_2_timer_bar, reconnect)


func clear_reconnect_timer(display_side: String) -> void:
	if display_side == "p1":
		_player_1_reconnect.clear()
		_set_timer(player_1_timer_state_label, player_1_timer_label, player_1_timer_bar, _player_1_timer)
	elif display_side == "p2":
		_player_2_reconnect.clear()
		_set_timer(player_2_timer_state_label, player_2_timer_label, player_2_timer_bar, _player_2_timer)


func has_active_reconnect_timer() -> bool:
	return not _player_1_reconnect.is_empty() or not _player_2_reconnect.is_empty()


func _render_reconnect(state_label: Label, time_label: Label, bar: ProgressBar, reconnect: Dictionary) -> void:
	var remaining_ms := maxi(int(reconnect.get("expiresTicksMs", 0)) - Time.get_ticks_msec(), 0)
	var remaining_seconds := int(ceil(float(remaining_ms) / 1000.0))
	var grace_seconds := maxi(int(reconnect.get("graceSeconds", 0)), 1)
	state_label.visible = true
	time_label.visible = true
	bar.visible = true
	state_label.text = _t("battle.timer.disconnected")
	time_label.text = _t("battle.timer.reconnect", {
		"time": "%02d:%02d" % [remaining_seconds / 60, remaining_seconds % 60],
	})
	bar.value = clampf(100.0 * float(remaining_seconds) / float(grace_seconds), 0.0, 100.0)
	var urgent := remaining_seconds <= 10
	state_label.modulate = Color(1.0, 0.35, 0.25) if urgent else Color.WHITE
	time_label.modulate = Color(1.0, 0.35, 0.25) if urgent else Color.WHITE


func _set_timer(state_label: Label, time_label: Label, bar: ProgressBar, timer: Dictionary) -> void:
	var state := str(timer.get("state", "WAITING"))
	var has_countdown := state in ["SCHEDULED", "DECIDING", "EXPIRED"] or _has_frozen_countdown(timer)
	state_label.visible = true
	time_label.visible = has_countdown
	bar.visible = has_countdown
	state_label.text = _timer_state_text(timer)
	time_label.text = _timer_time_text(timer)
	bar.value = _timer_progress(timer)
	var urgent := (
		str(timer.get("state", "")) == "DECIDING"
		and int(timer.get("effectiveDecisionRemainingMs", 999999)) <= 5000
	)
	state_label.modulate = Color(1.0, 0.35, 0.25) if urgent else Color.WHITE
	time_label.modulate = Color(1.0, 0.35, 0.25) if urgent else Color.WHITE


func _timer_state_text(timer: Dictionary) -> String:
	var state := str(timer.get("state", "WAITING"))
	if state in ["SCHEDULED", "DECIDING", "EXPIRED"]:
		return "%s · %s" % [_decision_text(str(timer.get("decisionKind", ""))), _state_text(state)]
	return _state_text(state)


func _timer_time_text(timer: Dictionary) -> String:
	var state := str(timer.get("state", "WAITING"))
	if state == "SCHEDULED":
		return _t("battle.timer.starts", {
			"time": _format_ms(int(timer.get("scheduledRemainingMs", 0))),
		})
	elif state in ["DECIDING", "EXPIRED", "WAITING"] and int(timer.get("decisionMaximumMs", 0)) > 0:
		return _t("battle.timer.time", {
			"time": _format_ms(int(timer.get("effectiveDecisionRemainingMs", 0))),
		})
	return ""


func _timer_progress(timer: Dictionary) -> float:
	var state := str(timer.get("state", "WAITING"))
	if state == "EXPIRED":
		return 0.0
	if state == "SCHEDULED":
		return 100.0
	if state == "DECIDING":
		var maximum := int(timer.get("decisionMaximumMs", 0))
		if maximum > 0:
			return clampf(100.0 * float(timer.get("effectiveDecisionRemainingMs", 0)) / float(maximum), 0.0, 100.0)
	if state == "WAITING" and _has_frozen_countdown(timer):
		var frozen_maximum := int(timer.get("decisionMaximumMs", 0))
		return clampf(100.0 * float(timer.get("effectiveDecisionRemainingMs", 0)) / float(frozen_maximum), 0.0, 100.0)
	return 0.0


func _has_frozen_countdown(timer: Dictionary) -> bool:
	return (
		str(timer.get("state", "WAITING")) == "WAITING"
		and timer.has("effectiveDecisionRemainingMs")
		and int(timer.get("decisionMaximumMs", 0)) > 0
	)


func _format_ms(value: int) -> String:
	var seconds: int = maxi(value, 0) / 1000
	return "%02d:%02d" % [seconds / 60, seconds % 60]


func _state_text(value: String) -> String:
	match value:
		"DECIDING": return _t("battle.timer.choosing")
		"SCHEDULED": return _t("battle.timer.scheduled")
		"PAUSED": return _t("battle.timer.paused")
		"EXPIRED": return _t("battle.timer.expired")
		_: return _t("common.waiting")


func _decision_text(value: String) -> String:
	match value:
		"TEAM_PREVIEW": return _t("battle.timer.team_preview")
		"FORCED_SWITCH": return _t("battle.timer.forced_switch")
		_: return _t("battle.timer.move")


func _t(key: String, replacements: Dictionary = {}) -> String:
	if _localization_manager != null:
		return str(_localization_manager.call("text", key, replacements))
	return key


func _on_locale_changed(_locale: String) -> void:
	if _player_1_reconnect.is_empty():
		_set_timer(player_1_timer_state_label, player_1_timer_label, player_1_timer_bar, _player_1_timer)
	if _player_2_reconnect.is_empty():
		_set_timer(player_2_timer_state_label, player_2_timer_label, player_2_timer_bar, _player_2_timer)
