extends CanvasLayer

class_name AetherClashArenaHud

const MATCHMAKING_COLOR := Color("#7edff4")
const MATCHMAKING_WARNING_COLOR := Color("#ffb35c")
const MATCHMAKING_WAITING_COLOR := Color("#9fb7cc")

@onready var challenger_name_label: Label = $Root/Panel/Margin/Main/Matchup/Challenger/Name
@onready var challenger_side_label: Label = $Root/Panel/Margin/Main/Matchup/Challenger/Side
@onready var challenger_count_label: Label = $Root/Panel/Margin/Main/Matchup/Challenger/Count
@onready var challenged_name_label: Label = $Root/Panel/Margin/Main/Matchup/Challenged/Name
@onready var challenged_side_label: Label = $Root/Panel/Margin/Main/Matchup/Challenged/Side
@onready var challenged_count_label: Label = $Root/Panel/Margin/Main/Matchup/Challenged/Count
@onready var phase_label: Label = $Root/Panel/Margin/Main/Matchup/Center/Phase
@onready var countdown_label: Label = $Root/Panel/Margin/Main/Matchup/Center/Countdown
@onready var barrier_hint_label: Label = $Root/Panel/Margin/Main/BarrierHint
@onready var matchmaking_hint_label: Label = $Root/Panel/Margin/Main/MatchmakingHint

var arena_payload: Dictionary = {}
var server_clock_offset_seconds := 0.0
var battle_overlay_active := false
var arena_display_requested := false


func _ready() -> void:
	visible = false
	show_syncing()


func _process(_delta: float) -> void:
	if visible and str(_session().get("status", "")) in [
		"entry_open",
		"roster_locked",
		"active",
		"finishing",
	]:
		_render_phase()


func show_syncing() -> void:
	arena_display_requested = true
	visible = not battle_overlay_active
	challenger_side_label.text = _text("ui.aether_clash.arena.blue_side", "BLUE SIDE")
	challenged_side_label.text = _text("ui.aether_clash.arena.red_side", "RED SIDE")
	challenger_name_label.text = _text("ui.aether_clash.arena.guild_one", "Guild 1")
	challenged_name_label.text = _text("ui.aether_clash.arena.guild_two", "Guild 2")
	challenger_count_label.text = "0"
	challenged_count_label.text = "0"
	phase_label.text = _text("ui.aether_clash.arena.syncing", "Synchronizing arena")
	countdown_label.text = "--:--"
	barrier_hint_label.text = _text(
		"ui.aether_clash.arena.barrier_raised",
		"The Aether barrier separates both Guilds"
	)
	matchmaking_hint_label.visible = false


func apply_arena_state(payload: Dictionary) -> void:
	arena_payload = payload.duplicate(true)
	arena_display_requested = true
	server_clock_offset_seconds = _server_clock_offset(str(payload.get("serverNow", "")))
	visible = not battle_overlay_active
	_render()


func set_battle_overlay_active(is_active: bool) -> void:
	battle_overlay_active = is_active
	visible = not battle_overlay_active and arena_display_requested


func _render() -> void:
	var session := _session()
	var challenger := _dictionary(session.get("challengerGuild", {}))
	var challenged := _dictionary(session.get("challengedGuild", {}))
	challenger_name_label.text = str(challenger.get("name", "Guild 1"))
	challenged_name_label.text = str(challenged.get("name", "Guild 2"))
	var counts := _display_counts(session)
	challenger_count_label.text = str(int(counts.get("challenger", 0)))
	challenged_count_label.text = str(int(counts.get("challenged", 0)))
	_render_phase()


func _render_phase() -> void:
	var session := _session()
	var status := str(session.get("status", ""))
	match status:
		"entry_open":
			matchmaking_hint_label.visible = false
			var remaining := _entry_seconds_remaining(session)
			phase_label.text = _text(
				"ui.aether_clash.arena.entry_open"
				if remaining > 0
				else "ui.aether_clash.arena.starting",
				"PORTAL OPEN" if remaining > 0 else "STARTING"
			)
			countdown_label.text = _format_countdown(remaining)
			barrier_hint_label.text = _text(
				"ui.aether_clash.arena.barrier_raised",
				"The Aether barrier separates both Guilds"
			)
		"roster_locked", "active", "finishing":
			phase_label.text = _text("ui.aether_clash.arena.active", "CLASH ACTIVE")
			countdown_label.text = _text("ui.aether_clash.arena.fight", "FIGHT!")
			barrier_hint_label.text = _text(
				"ui.aether_clash.arena.duel_time",
				"Duel time: {time}"
			).replace("{time}", _format_duration(_duel_seconds_elapsed(session)))
			_render_matchmaking()
		"completed", "no_show", "cancelled":
			matchmaking_hint_label.visible = false
			phase_label.text = _text("ui.aether_clash.arena.finished", "CLASH FINISHED")
			countdown_label.text = "—"
			barrier_hint_label.text = ""
		_:
			matchmaking_hint_label.visible = false
			phase_label.text = _text("ui.aether_clash.arena.syncing", "Synchronizing arena")
			countdown_label.text = "--:--"


func _render_matchmaking() -> void:
	var matchmaking := _dictionary(arena_payload.get("matchmaking", {}))
	var status := str(matchmaking.get("status", "disabled"))
	matchmaking_hint_label.visible = status != "disabled"
	match status:
		"searching":
			var remaining := _matchmaking_seconds_remaining(matchmaking)
			var warning_seconds := maxi(1, int(matchmaking.get("warningSeconds", 15)))
			matchmaking_hint_label.text = _text(
				"ui.aether_clash.arena.matchmaking_available",
				"OPPONENT AVAILABLE — Find a battle within {time} or be matched automatically"
			).replace("{time}", _format_countdown(remaining))
			matchmaking_hint_label.add_theme_color_override(
				"font_color",
				MATCHMAKING_WARNING_COLOR if remaining <= warning_seconds else MATCHMAKING_COLOR
			)
		"waiting_for_opponent":
			matchmaking_hint_label.text = _text(
				"ui.aether_clash.arena.matchmaking_waiting",
				"WAITING FOR AN OPPONENT…"
			)
			matchmaking_hint_label.add_theme_color_override(
				"font_color",
				MATCHMAKING_WAITING_COLOR
			)
		"starting":
			matchmaking_hint_label.text = _text(
				"ui.aether_clash.arena.matchmaking_starting",
				"STARTING FORCED BATTLE…"
			)
			matchmaking_hint_label.add_theme_color_override(
				"font_color",
				MATCHMAKING_WARNING_COLOR
			)
		_:
			matchmaking_hint_label.visible = false


func _matchmaking_seconds_remaining(matchmaking: Dictionary) -> int:
	var deadline := _timestamp_to_unix(str(matchmaking.get("deadlineAt", "")))
	if deadline > 0.0:
		return maxi(
			0,
			int(ceil(deadline - (Time.get_unix_time_from_system() + server_clock_offset_seconds)))
		)
	return maxi(0, int(matchmaking.get("secondsRemaining", 0)))


func _display_counts(session: Dictionary) -> Dictionary:
	var status := str(session.get("status", ""))
	if status == "entry_open":
		return _dictionary(session.get("entryCounts", {}))
	if status in ["active", "finishing", "completed"]:
		return _dictionary(session.get("activeCounts", {}))
	return _dictionary(session.get("participantCounts", {}))


func _entry_seconds_remaining(session: Dictionary) -> int:
	var deadline := _timestamp_to_unix(str(session.get("entryClosesAt", "")))
	if deadline <= 0.0:
		return 0
	return maxi(
		0,
		int(ceil(deadline - (Time.get_unix_time_from_system() + server_clock_offset_seconds)))
	)


func _format_countdown(seconds_remaining: int) -> String:
	var minutes := int(seconds_remaining / 60)
	var seconds := seconds_remaining % 60
	return "%02d:%02d" % [minutes, seconds]


func _duel_seconds_elapsed(session: Dictionary) -> int:
	var started_at := _timestamp_to_unix(str(session.get("startedAt", "")))
	if started_at <= 0.0:
		return 0
	return maxi(
		0,
		int(floor(Time.get_unix_time_from_system() + server_clock_offset_seconds - started_at))
	)


func _format_duration(seconds_elapsed: int) -> String:
	var hours := int(seconds_elapsed / 3600)
	var minutes := int(seconds_elapsed / 60) % 60
	var seconds := seconds_elapsed % 60
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, seconds]
	return "%02d:%02d" % [minutes, seconds]


func _server_clock_offset(server_now: String) -> float:
	var server_unix := _timestamp_to_unix(server_now)
	return server_unix - Time.get_unix_time_from_system() if server_unix > 0.0 else 0.0


func _timestamp_to_unix(value: String) -> float:
	var normalized := value.strip_edges().replace("+00:00", "Z")
	if normalized.is_empty():
		return 0.0
	return Time.get_unix_time_from_datetime_string(normalized)


func _session() -> Dictionary:
	return _dictionary(arena_payload.get("session", {}))


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _text(key: String, fallback: String) -> String:
	var manager := get_node_or_null("/root/LocalizationManager")
	if manager != null and manager.has_method("text"):
		var translated := str(manager.call("text", key))
		if translated != key:
			return translated
	return fallback
