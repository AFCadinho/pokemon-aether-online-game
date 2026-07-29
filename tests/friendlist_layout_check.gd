extends SceneTree

const FRIENDLIST_SCRIPT_PATH := "res://scripts/ui/friendlist_popup.gd"

var failures := 0


func _init() -> void:
	var source := FileAccess.get_file_as_string(FRIENDLIST_SCRIPT_PATH)

	_check(source.contains("const POPUP_SIZE := Vector2(880, 620)"), "Friend List uses a spacious social workspace")
	_check(source.contains('const FRIENDLIST_ICON: Texture2D = preload("res://assets/ui/friendlist.svg")'), "Friend List header uses its dedicated social icon")
	_check(source.contains('"ui.friends.title"'), "Friend List uses a concise localized title")
	_check(source.contains('"ui.friends.subtitle"'), "Friend List header explains its scope with localized copy")
	_check(source.contains('"ui.friends.add"'), "Adding a friend remains a clear localized primary action")
	_check(source.contains('refresh_button.text = "↻"') and source.contains('close_button.text = "×"'), "Header utilities use compact controls")
	_check(source.contains("button.size_flags_horizontal = Control.SIZE_EXPAND_FILL"), "Social tabs share the available width")
	_check(source.contains("func _refresh_tab_counts("), "Friends, requests and blocked tabs report their counts")
	_check(source.contains("friends_summary_label.text ="), "Friends view reports total and online trainers")
	_check(source.contains("func _create_user_avatar("), "Trainer rows have a compact identity avatar")
	_check(source.contains("func _user_initials("), "Avatar placeholders remain readable without profile artwork")
	_check(source.contains('presence_label.text = _presence_label_text(user).to_upper()'), "Trainer cards retain online and last-seen state")
	_check(source.contains('username_label.text = "@%s"'), "Trainer cards separate display names from usernames")
	_check(source.contains('"ui.friends.message"'), "Localized private messaging remains available")
	_check(source.contains('"ui.friends.mail"'), "Localized friend mail remains available")
	_check(source.contains('"common.remove"'), "Removing a friend remains explicit and localized")
	_check(source.contains('"ui.friends.requests.incoming"'), "Incoming requests have a localized counted section")
	_check(source.contains('"ui.friends.requests.sent"'), "Sent requests have a localized counted section")
	_check(source.contains("func _create_request_identity("), "Request and blocked rows use structured trainer identity")
	_check(source.contains('"ui.friends.blocked.detail"'), "Blocked rows explain their effect with localized copy")
	_check(source.contains('status_character_label.text = "%s / 100"'), "Status editor exposes its character limit")
	_check(not source.contains('label": "Trades"') and not source.contains("func _load_trade_history"), "Trade history stays outside friend management")
	_check(source.contains("button.focus_mode = Control.FOCUS_NONE"), "Friend List buttons cannot become stale Spacebar targets")
	_check(source.contains("SocialService.send_friend_request(username)"), "Friend List revamp preserves friend requests")
	_check(source.contains("SocialService.remove_friend(username)"), "Friend List revamp preserves removal")
	_check(source.contains("SocialService.block_user(username)"), "Friend List revamp preserves blocking")

	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
