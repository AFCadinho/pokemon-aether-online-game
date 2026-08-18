extends SceneTree

const PLAYER_DATA := preload("res://scripts/data/player_data.gd")

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var auth := _source("res://scripts/services/auth_service.gd")
	var player_data := _source("res://scripts/data/player_data.gd")
	var loading := _source("res://scripts/ui/loading_screen.gd")
	var world := _source("res://scripts/world/world.gd")
	var overlay := _source("res://scripts/ui/ui_overlay.gd")
	var settings := _source("res://scripts/ui/settings_menu.gd")
	var chat := _source("res://scripts/services/chat_realtime_service.gd")

	_expect(
		auth.contains('session_type == "impersonation"')
		and auth.contains("impersonated_by_user_id > 0"),
		"auth service exposes authoritative impersonation session state"
	)
	_expect(
		auth.contains('base_url + "/auth/impersonate/consume"')
		and auth.contains("get_authorization_header()"),
		"impersonation exchange is bound to the active staff session"
	)
	_expect(
		auth.contains('base_url + "/auth/impersonate/stop"')
		and auth.contains("func stop_impersonating()"),
		"auth service can securely exchange back to the staff account"
	)
	_expect(
		auth.contains("func _reset_account_runtime_state()")
		and auth.contains("PlayerSave.reset_account_state()")
		and auth.contains("PokedexService.invalidate_owned_species_cache()"),
		"account exchange clears account-scoped runtime caches"
	)
	_expect(
		player_data.contains("func apply_account_identity(user: Dictionary)")
		and player_data.contains("func reset_account_state()"),
		"player identity has shared hydrate and reset operations"
	)
	_expect(
		loading.contains("PlayerSave.apply_account_identity(")
		and loading.contains('PlayerSave.flags["trainer_stats"] = stats.duplicate(true)'),
		"loading hydrates trainer-card identity and stats for every account"
	)
	_expect(
		auth.contains("func get_user_id_text_from(user: Dictionary)")
		and loading.contains("AuthService.get_user_id_text_from(user)"),
		"profile identity comparison normalizes both JSON user ids"
	)
	_expect(
		loading.contains("if AuthService.account_switch_pending:")
		and loading.contains("await AuthService.logout()"),
		"switched-account profile failure logs out instead of using stale fallback state"
	)
	_expect(
		world.contains("ChatRealtimeService.disconnect_chat()")
		and overlay.find('world.call("prepare_for_account_switch")')
		< overlay.find("await AuthService.impersonate_with_token(token)"),
		"old chat transport is disconnected before token exchange"
	)
	_expect(
		chat.contains("websocket = WebSocketPeer.new()"),
		"chat disconnect discards the socket authenticated as the old account"
	)
	_expect(
		world.contains("await save_current_player_state_now()")
		and world.contains("await _flush_playtime_if_needed(true)"),
		"account switch persists position and playtime before exchanging accounts"
	)
	_expect(
		overlay.contains("func get_account_switch_block_reason()")
		and overlay.contains("Leave the PvP queue before switching accounts."),
		"PvP queue and match state block account exchange"
	)
	_expect(
		settings.contains("AuthService.is_impersonating()")
		and settings.contains("await AuthService.stop_impersonating()")
		and settings.contains('"ui.staff.impersonate.return_account"'),
		"existing account-return control restores the linked staff account"
	)
	_expect(
		overlay.contains(
			"var can_return_from_impersonation := AuthService.is_impersonating()"
		)
		and overlay.contains(
			"staff_impersonate_button.visible = can_return_from_impersonation or can_impersonate"
		)
		and overlay.contains(
			"(can_show_staff_action_bar or can_return_from_impersonation)"
		),
		"return action stays visible when the target account has no staff permissions"
	)
	_expect(
		overlay.contains('settings_menu.call("show_impersonation_return_confirmation")')
		and settings.contains("func show_impersonation_return_confirmation()"),
		"visible impersonation action opens the shared secure return confirmation"
	)
	_expect(
		settings.contains(
			"logout_confirm_dialog.set_focus_behavior_recursive(Control.FOCUS_BEHAVIOR_ENABLED)"
		)
		and settings.contains("func _focus_logout_confirm_return_button()")
		and settings.contains("logout_confirm_dialog.is_visible_in_tree()"),
		"account-return confirmation only grabs focus from an enabled visible popup"
	)
	_expect(
		auth.contains("if session_token == \"\" or is_impersonating():"),
		"temporary impersonation credentials are never saved locally"
	)
	_expect(
		auth.contains('body.get("impersonatedByUserId", null)')
		and auth.contains("0 if impersonator_id == null else int(impersonator_id)"),
		"normal login accepts a null impersonator id"
	)
	var impersonate_section := auth.substr(
		auth.find("func impersonate_with_token"),
		auth.find("func stop_impersonating") - auth.find("func impersonate_with_token")
	)
	var stop_section := auth.substr(
		auth.find("func stop_impersonating"),
		auth.find("func restore_saved_session") - auth.find("func stop_impersonating")
	)
	_expect(
		impersonate_section.contains("_clear_session_file()")
		and not impersonate_section.contains("_save_session()"),
		"entering impersonation removes the old persisted staff credential"
	)
	_expect(
		stop_section.contains('body.get("rememberMe", false)')
		and stop_section.contains("_save_session()"),
		"returning preserves the staff remember-me choice"
	)
	var auth_service := get_root().get_node_or_null("AuthService")
	_expect(auth_service != null, "auth service is available for identity normalization")
	if auth_service != null:
		_expect(
			auth_service.call("get_user_id_text_from", {"id": 42}) == "42"
			and auth_service.call("get_user_id_text_from", {"id": 42.0}) == "42",
			"integer and decoded JSON float ids normalize identically"
		)
	_verify_player_identity_reset()

	quit(1 if failed else 0)


func _verify_player_identity_reset() -> void:
	var player := PLAYER_DATA.new() as PlayerData
	player.apply_account_identity({
		"id": 42,
		"username": "target",
		"displayName": "Target Trainer",
		"gender": "female",
		"createdAt": "2026-01-02T03:04:05Z",
		"roles": [],
	})
	_expect(
		player.player_id == "42"
		and player.player_name == "Target Trainer"
		and player.gender == "female"
		and not player.is_staff,
		"target account identity hydrates into trainer runtime state"
	)
	player.money = 999
	player.gems = 12
	player.aetherite = 7
	player.battle_points = 5
	player.playtime_seconds = 321
	player.flags["trainer_stats"] = {"wins": 10}
	player.earned_gym_badges.append("boulder")

	player.reset_account_state()
	_expect(
		player.player_id == ""
		and player.player_name == "Player"
		and player.money == 0
		and player.gems == 0
		and player.aetherite == 0
		and player.battle_points == 0
		and player.playtime_seconds == 0
		and player.flags.is_empty()
		and player.earned_gym_badges.is_empty(),
		"account reset removes trainer-card, wallet, stats, and badge state"
	)
	player.free()


func _source(path: String) -> String:
	var source := FileAccess.get_file_as_string(path)
	if source == "":
		_expect(false, "can read %s" % path)
	return source


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
