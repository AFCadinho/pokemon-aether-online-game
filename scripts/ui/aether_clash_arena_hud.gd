extends CanvasLayer

class_name AetherClashArenaHud

const MATCHMAKING_COLOR := Color("#7edff4")
const MATCHMAKING_WARNING_COLOR := Color("#ffb35c")
const MATCHMAKING_WAITING_COLOR := Color("#9fb7cc")
const ROSTER_ACTIVE_COLOR := Color("#73d98b")
const ROSTER_BATTLE_COLOR := Color("#bd8cff")
const ROSTER_ELIMINATED_COLOR := Color("#ff6b74")
const ROSTER_LEFT_COLOR := Color("#78889a")
const BLUE_SIDE_COLOR := Color("#58b8ff")
const RED_SIDE_COLOR := Color("#ff6678")
const ELIMINATION_TOAST_SECONDS := 5.0
const INITIAL_ELIMINATION_FRESHNESS_SECONDS := 10.0
const CONTEXT_PANEL_TOP := 166.0
const CONTEXT_PANEL_BOTTOM_MARGIN := 16.0
const CONTEXT_PANEL_COLLAPSED_HEIGHT := 128.0
const CONTEXT_PANEL_EXPANDED_HEIGHT := 480.0

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
@onready var clash_panel: PanelContainer = $Root/ClashPanel
@onready var context_title_label: Label = $Root/ClashPanel/Margin/Layout/Header/Title
@onready var viewer_status_label: Label = $Root/ClashPanel/Margin/Layout/Header/ViewerStatus
@onready var roster_header: HBoxContainer = $Root/ClashPanel/Margin/Layout/RosterHeader
@onready var roster_guild_name_label: Label = $Root/ClashPanel/Margin/Layout/RosterHeader/GuildName
@onready var roster_remaining_label: Label = $Root/ClashPanel/Margin/Layout/RosterHeader/Remaining
@onready var roster_toggle_button: Button = $Root/ClashPanel/Margin/Layout/RosterToggle
@onready var roster_scroll: ScrollContainer = $Root/ClashPanel/Margin/Layout/RosterScroll
@onready var roster_list: VBoxContainer = $Root/ClashPanel/Margin/Layout/RosterScroll/RosterList
@onready var battle_summary_label: Label = $Root/ClashPanel/Margin/Layout/BattleSummary
@onready var context_hint_label: Label = $Root/ClashPanel/Margin/Layout/ContextHint
@onready var elimination_feed: VBoxContainer = $Root/EliminationFeed

var arena_payload: Dictionary = {}
var server_clock_offset_seconds := 0.0
var battle_overlay_active := false
var arena_display_requested := false
var elimination_snapshot_received := false
var seen_elimination_ids: Dictionary = {}
var queued_elimination_events: Array[Dictionary] = []
var roster_expanded := false
var roster_player_count := 0


func _ready() -> void:
	visible = false
	roster_toggle_button.pressed.connect(_toggle_roster)
	var viewport := get_viewport()
	if viewport != null:
		viewport.size_changed.connect(_apply_context_panel_size)
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
	clash_panel.visible = false
	roster_player_count = 0
	_set_roster_expanded(false)
	_clear_roster()
	elimination_snapshot_received = false
	seen_elimination_ids.clear()
	queued_elimination_events.clear()
	_clear_elimination_feed()
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
	_render_context_panel()
	_consume_eliminations()


func set_battle_overlay_active(is_active: bool) -> void:
	var was_active := battle_overlay_active
	battle_overlay_active = is_active
	visible = not battle_overlay_active and arena_display_requested
	if was_active and not battle_overlay_active:
		_flush_queued_eliminations()


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


func _render_context_panel() -> void:
	var session := _session()
	var status := str(session.get("status", ""))
	clash_panel.visible = status in ["entry_open", "roster_locked", "active", "finishing"]
	if not clash_panel.visible:
		return
	context_title_label.text = _text("ui.aether_clash.arena.context.title", "CLASH STATUS")
	var viewer_role := str(arena_payload.get("viewerRole", "spectator"))
	var viewer_side := str(arena_payload.get("viewerSide", ""))
	var roster := _array(arena_payload.get("viewerRoster", []))
	var has_guild_roster := viewer_side in ["blue", "red"] and not roster.is_empty()
	roster_header.visible = has_guild_roster
	roster_player_count = roster.size() if has_guild_roster else 0
	if has_guild_roster:
		var own_guild := (
			_dictionary(session.get("challengerGuild", {}))
			if viewer_side == "blue"
			else _dictionary(session.get("challengedGuild", {}))
		)
		roster_guild_name_label.text = str(own_guild.get("name", "Your Guild"))
		var active_count := 0
		for player_value: Variant in roster:
			if player_value is Dictionary and str((player_value as Dictionary).get("status", "")) in ["active", "in_battle"]:
				active_count += 1
		roster_remaining_label.text = _text(
			"ui.aether_clash.arena.context.active_count",
			"{count} ACTIVE"
		).replace("{count}", str(active_count))
	_render_roster(roster if has_guild_roster else [])

	if viewer_role == "participant":
		viewer_status_label.text = (
			_text("ui.aether_clash.arena.context.staging", "STAGING PLAYER")
			if status == "entry_open"
			else _local_player_status(roster)
		)
		context_hint_label.text = (
			_text(
				"ui.aether_clash.arena.context.staging_hint",
				"Prepare your team. The barrier drops when the portal closes."
			)
			if status == "entry_open"
			else _text(
				"ui.aether_clash.arena.context.participant_hint",
				"Contact an opponent to start a battle."
			)
		)
	else:
		viewer_status_label.text = _text("ui.aether_clash.arena.context.spectator", "SPECTATOR")
		context_hint_label.text = _text(
			"ui.aether_clash.arena.context.spectator_hint",
			"Use an Aether View orb to explore. Click a Master Ball to watch its battle."
		)

	var live_engagements: Dictionary = {}
	for player_value: Variant in _array(arena_payload.get("arenaPlayers", [])):
		if not player_value is Dictionary:
			continue
		var engagement_id := str((player_value as Dictionary).get("engagementId", "")).strip_edges()
		if not engagement_id.is_empty():
			live_engagements[engagement_id] = true
	var live_battle_count := live_engagements.size()
	battle_summary_label.text = _text(
		"ui.aether_clash.arena.context.battles.one"
		if live_battle_count == 1
		else "ui.aether_clash.arena.context.battles.many",
		"1 battle in progress"
		if live_battle_count == 1
		else "{count} battles in progress"
	).replace("{count}", str(live_battle_count))
	_set_roster_expanded(roster_expanded if has_guild_roster else false)


func _toggle_roster() -> void:
	_set_roster_expanded(not roster_expanded)


func _set_roster_expanded(expanded: bool) -> void:
	var has_roster := roster_player_count > 0
	roster_expanded = expanded and has_roster
	roster_scroll.visible = roster_expanded
	context_hint_label.visible = roster_expanded
	roster_toggle_button.visible = has_roster
	roster_toggle_button.text = (
		_text("ui.aether_clash.arena.context.hide_players", "Hide players  ▴")
		if roster_expanded
		else _text(
			"ui.aether_clash.arena.context.show_players",
			"Players ({count})  ▾"
		).replace("{count}", str(roster_player_count))
	)
	roster_toggle_button.tooltip_text = context_hint_label.text
	_apply_context_panel_size()


func _apply_context_panel_size() -> void:
	if clash_panel == null:
		return
	var viewport := get_viewport()
	var viewport_height := (
		viewport.get_visible_rect().size.y
		if viewport != null
		else CONTEXT_PANEL_TOP + CONTEXT_PANEL_EXPANDED_HEIGHT + CONTEXT_PANEL_BOTTOM_MARGIN
	)
	var available_height := maxf(
		CONTEXT_PANEL_COLLAPSED_HEIGHT,
		viewport_height - CONTEXT_PANEL_TOP - CONTEXT_PANEL_BOTTOM_MARGIN
	)
	var requested_height := (
		CONTEXT_PANEL_EXPANDED_HEIGHT
		if roster_expanded
		else CONTEXT_PANEL_COLLAPSED_HEIGHT
	)
	var panel_height := minf(requested_height, available_height)
	clash_panel.offset_top = CONTEXT_PANEL_TOP
	clash_panel.offset_bottom = CONTEXT_PANEL_TOP + panel_height


func _render_roster(roster: Array) -> void:
	_clear_roster()
	var auth_service := get_node_or_null("/root/AuthService")
	var current_user: Dictionary = auth_service.get("current_user") as Dictionary if auth_service != null else {}
	var local_user_id := int(current_user.get("id", 0))
	for player_value: Variant in roster:
		if not player_value is Dictionary:
			continue
		var player := player_value as Dictionary
		var row := PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_stylebox_override("panel", _roster_row_style(str(player.get("status", "left"))))
		roster_list.add_child(row)
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_top", 5)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_bottom", 5)
		row.add_child(margin)
		var content := HBoxContainer.new()
		content.add_theme_constant_override("separation", 7)
		margin.add_child(content)
		var status := str(player.get("status", "left"))
		var dot := Label.new()
		dot.text = "●"
		dot.add_theme_color_override("font_color", _roster_status_color(status))
		dot.add_theme_font_size_override("font_size", 10)
		content.add_child(dot)
		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.add_theme_color_override("font_color", Color("#f4f0de"))
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.text = str(player.get("displayName", "Guildmate"))
		if int(player.get("userId", 0)) == local_user_id:
			name_label.text += _text("ui.aether_clash.arena.context.you", " (YOU)")
		content.add_child(name_label)
		var status_label := Label.new()
		status_label.add_theme_color_override("font_color", _roster_status_color(status))
		status_label.add_theme_font_size_override("font_size", 9)
		status_label.text = _roster_status_text(status)
		content.add_child(status_label)


func _clear_roster() -> void:
	if roster_list == null:
		return
	for child: Node in roster_list.get_children():
		roster_list.remove_child(child)
		child.queue_free()


func _local_player_status(roster: Array) -> String:
	var auth_service := get_node_or_null("/root/AuthService")
	var current_user: Dictionary = auth_service.get("current_user") as Dictionary if auth_service != null else {}
	var local_user_id := int(current_user.get("id", 0))
	for player_value: Variant in roster:
		if not player_value is Dictionary:
			continue
		var player := player_value as Dictionary
		if int(player.get("userId", 0)) == local_user_id:
			return _roster_status_text(str(player.get("status", "active")))
	return _text("ui.aether_clash.arena.context.participant", "ACTIVE PLAYER")


func _roster_status_text(status: String) -> String:
	match status:
		"in_battle":
			return _text("ui.aether_clash.arena.context.status.in_battle", "IN BATTLE")
		"eliminated":
			return _text("ui.aether_clash.arena.context.status.eliminated", "ELIMINATED")
		"left":
			return _text("ui.aether_clash.arena.context.status.left", "LEFT")
		_:
			return _text("ui.aether_clash.arena.context.status.active", "ACTIVE")


func _roster_status_color(status: String) -> Color:
	match status:
		"in_battle":
			return ROSTER_BATTLE_COLOR
		"eliminated":
			return ROSTER_ELIMINATED_COLOR
		"left":
			return ROSTER_LEFT_COLOR
		_:
			return ROSTER_ACTIVE_COLOR


func _roster_row_style(status: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#081522e8")
	style.border_width_left = 2
	style.border_color = _roster_status_color(status)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	return style


func _consume_eliminations() -> void:
	var eliminations := _array(arena_payload.get("recentEliminations", []))
	if not elimination_snapshot_received:
		elimination_snapshot_received = true
		for event_value: Variant in eliminations:
			if event_value is Dictionary:
				var event := event_value as Dictionary
				var event_id := str(event.get("engagementId", "")).strip_edges()
				if not event_id.is_empty():
					seen_elimination_ids[event_id] = true
		if not eliminations.is_empty():
			var latest_value: Variant = eliminations.back()
			if latest_value is Dictionary and _is_recent_elimination(latest_value as Dictionary):
				_present_elimination(latest_value as Dictionary)
		return
	for event_value: Variant in eliminations:
		if not event_value is Dictionary:
			continue
		var event := event_value as Dictionary
		var event_id := str(event.get("engagementId", "")).strip_edges()
		if event_id.is_empty() or seen_elimination_ids.has(event_id):
			continue
		seen_elimination_ids[event_id] = true
		_present_elimination(event)


func _is_recent_elimination(event: Dictionary) -> bool:
	var completed_at := _timestamp_to_unix(str(event.get("completedAt", "")))
	var server_now := _timestamp_to_unix(str(arena_payload.get("serverNow", "")))
	if completed_at <= 0.0 or server_now <= 0.0:
		return false
	var age := server_now - completed_at
	return age >= -1.0 and age <= INITIAL_ELIMINATION_FRESHNESS_SECONDS


func _present_elimination(event: Dictionary) -> void:
	if battle_overlay_active:
		queued_elimination_events.append(event.duplicate(true))
		return
	_show_elimination_toast(event)


func _flush_queued_eliminations() -> void:
	var queued := queued_elimination_events.duplicate(true)
	queued_elimination_events.clear()
	for event_value: Variant in queued:
		if event_value is Dictionary:
			_show_elimination_toast(event_value as Dictionary)


func _show_elimination_toast(event: Dictionary) -> void:
	var winner_side := str(event.get("winnerSide", ""))
	var loser_side := str(event.get("loserSide", ""))
	var viewer_side := str(arena_payload.get("viewerSide", ""))
	var message := ""
	if viewer_side == winner_side:
		var winner_name := str(event.get("winnerDisplayName", "")).strip_edges()
		message = _text(
			"ui.aether_clash.arena.elimination.own_winner",
			"{player} eliminated an enemy player."
		).replace(
			"{player}",
			winner_name if not winner_name.is_empty() else _text(
				"ui.aether_clash.arena.elimination.guildmate",
				"A guildmate"
			)
		)
	elif viewer_side == loser_side:
		var loser_name := str(event.get("loserDisplayName", "")).strip_edges()
		message = _text(
			"ui.aether_clash.arena.elimination.own_loser",
			"{player} was eliminated by an enemy player."
		).replace(
			"{player}",
			loser_name if not loser_name.is_empty() else _text(
				"ui.aether_clash.arena.elimination.guildmate",
				"A guildmate"
			)
		)
	else:
		message = _text(
			"ui.aether_clash.arena.elimination.spectator",
			"{winner} eliminated a {loser} player."
		).replace("{winner}", _side_text(winner_side)).replace("{loser}", _side_text(loser_side))

	var toast := PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#050b14f2")
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = BLUE_SIDE_COLOR if winner_side == "blue" else RED_SIDE_COLOR
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	toast.add_theme_stylebox_override("panel", style)
	elimination_feed.add_child(toast)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 9)
	toast.add_child(margin)
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("#f4f0de"))
	label.add_theme_font_size_override("font_size", 13)
	label.text = message
	margin.add_child(label)
	while elimination_feed.get_child_count() > 4:
		var oldest := elimination_feed.get_child(0)
		elimination_feed.remove_child(oldest)
		oldest.queue_free()
	var tween := toast.create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.16)
	tween.tween_interval(ELIMINATION_TOAST_SECONDS)
	tween.tween_property(toast, "modulate:a", 0.0, 0.32)
	tween.tween_callback(toast.queue_free)


func _clear_elimination_feed() -> void:
	if elimination_feed == null:
		return
	for child: Node in elimination_feed.get_children():
		elimination_feed.remove_child(child)
		child.queue_free()


func _side_text(side: String) -> String:
	return (
		_text("ui.aether_clash.arena.blue_side", "Blue Side")
		if side == "blue"
		else _text("ui.aether_clash.arena.red_side", "Red Side")
	)


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
		"opponent_searching":
			var remaining := _matchmaking_seconds_remaining(matchmaking)
			var warning_seconds := maxi(1, int(matchmaking.get("warningSeconds", 15)))
			matchmaking_hint_label.text = _text(
				"ui.aether_clash.arena.matchmaking_opponent_searching",
				"POTENTIAL OPPONENT FOUND — Automatic matchmaking in {time}"
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


func _array(value: Variant) -> Array:
	return value as Array if value is Array else []


func _text(key: String, fallback: String) -> String:
	var manager := get_node_or_null("/root/LocalizationManager")
	if manager != null and manager.has_method("text"):
		var translated := str(manager.call("text", key))
		if translated != key:
			return translated
	return fallback
