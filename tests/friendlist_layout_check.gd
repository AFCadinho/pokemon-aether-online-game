extends SceneTree

const FRIENDLIST_SCRIPT_PATH := "res://scripts/ui/friendlist_popup.gd"

var failures := 0


func _init() -> void:
	var source := FileAccess.get_file_as_string(FRIENDLIST_SCRIPT_PATH)

	_check(source.contains("const POPUP_SIZE := Vector2(880, 620)"), "Friend List uses a spacious social workspace")
	_check(source.contains('const FRIENDLIST_ICON: Texture2D = preload("res://assets/ui/friendlist.svg")'), "Friend List header uses its dedicated social icon")
	_check(source.contains('title.text = "Friends"'), "Friend List uses a concise player-facing title")
	_check(source.contains('subtitle.text = "Your trainer network and social activity"'), "Friend List header explains its scope")
	_check(source.contains('add_friend_button.text = "+  Add Friend"'), "Adding a friend remains a clear primary action")
	_check(source.contains('refresh_button.text = "↻"') and source.contains('close_button.text = "×"'), "Header utilities use compact controls")
	_check(source.contains("button.size_flags_horizontal = Control.SIZE_EXPAND_FILL"), "Social tabs share the available width")
	_check(source.contains("func _refresh_tab_counts("), "Friends, requests and blocked tabs report their counts")
	_check(source.contains("friends_summary_label.text ="), "Friends view reports total and online trainers")
	_check(source.contains("func _create_user_avatar("), "Trainer rows have a compact identity avatar")
	_check(source.contains("func _user_initials("), "Avatar placeholders remain readable without profile artwork")
	_check(source.contains('presence_label.text = _presence_label_text(user).to_upper()'), "Trainer cards retain online and last-seen state")
	_check(source.contains('username_label.text = "@%s"'), "Trainer cards separate display names from usernames")
	_check(source.contains('message_button.text = "Message"'), "Private messaging remains available")
	_check(source.contains('mail_button.text = "Mail"'), "Friend mail remains available")
	_check(source.contains('remove_button.text = "Remove"'), "Removing a friend remains explicit")
	_check(source.contains('incoming_title.text = "INCOMING  ·  %s"'), "Incoming requests have a clear counted section")
	_check(source.contains('outgoing_title.text = "SENT  ·  %s"'), "Sent requests have a clear counted section")
	_check(source.contains("func _create_request_identity("), "Request and blocked rows use structured trainer identity")
	_check(source.contains('"Messages and social invites are hidden"'), "Blocked rows explain their effect")
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
