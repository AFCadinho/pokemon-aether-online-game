extends SceneTree

const REMOTE_PLAYER_AVATAR_PATH := "res://scripts/world/remote_player_avatar.gd"

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var remote_player_avatar_script := load(REMOTE_PLAYER_AVATAR_PATH) as Script
	_check(remote_player_avatar_script != null, "remote player avatar script loads")
	if remote_player_avatar_script == null:
		quit(failures)
		return
	var avatar: Node2D = remote_player_avatar_script.new() as Node2D
	root.add_child(avatar)
	avatar.apply_state({
		"userId": 7,
		"username": "admin",
		"displayName": "Admin",
		"roles": [{
			"id": "developer",
			"displayName": "Developer",
			"color": "#00d8b4",
			"priority": 100,
		}],
		"selectedRoleBadge": "developer",
		"mapId": "kanto_pallet_town",
		"position": {"x": 64.0, "y": 64.0},
		"facingDirection": "down",
		"appearance": {"body": "Red"},
	})
	await process_frame

	var badge_icon := avatar.get_node_or_null("Nameplate/RoleBadgeIcon") as TextureRect
	var badge_panel := avatar.get_node_or_null("Nameplate/RoleBadgePanel") as Panel
	var badge_label := avatar.get_node_or_null("Nameplate/RoleBadgePanel/RoleBadge") as Label
	_check(badge_icon != null, "remote nameplate has a role badge icon")
	_check(badge_icon != null and badge_icon.visible, "remote Developer badge icon is visible")
	_check(badge_icon != null and badge_icon.texture != null, "remote Developer badge icon has a texture")
	_check(badge_panel != null and not badge_panel.visible, "text badge panel stays hidden for an icon badge")
	_check(badge_label != null and badge_label.text == "DEV", "remote role selection resolves to DEV")

	avatar.queue_free()
	quit(failures)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAILED: %s" % label)
