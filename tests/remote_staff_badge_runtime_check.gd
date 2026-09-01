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
	var emblem_pixels: Array = []
	emblem_pixels.resize(32 * 32)
	emblem_pixels.fill(-1)
	emblem_pixels[0] = 0
	avatar.apply_state({
		"userId": 7,
		"username": "admin",
		"displayName": "Admin",
		"roles": [{
			"id": "developer",
			"displayName": "Developer",
			"color": "#00d8b4",
			"priority": 100,
			"display": {},
		}],
		"selectedRoleBadge": "developer",
		"guildEmblem": {
			"palette": ["#60d3ff"],
			"pixels": emblem_pixels,
		},
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

	var nameplate := avatar.get_node_or_null("Nameplate") as Control
	var name_label := avatar.get_node_or_null("Nameplate/NameLabel") as Label
	var guild_emblem := avatar.get_node_or_null("Nameplate/GuildEmblem") as TextureRect
	avatar.call("set_gameplay_identity_masked", true, "???")
	_check(nameplate != null and nameplate.visible, "masked gameplay identity keeps the remote nameplate visible")
	_check(name_label != null and name_label.text == "???", "masked gameplay identity replaces the Trainer name")
	_check(guild_emblem != null and guild_emblem.visible, "masked gameplay identity keeps the Guild emblem visible")
	_check(badge_icon != null and not badge_icon.visible, "masked gameplay identity hides role information")
	avatar.call("clear_gameplay_identity_mask_override")
	_check(name_label != null and name_label.text == "Admin", "clearing identity masking restores the Trainer name")
	_check(badge_icon != null and badge_icon.visible, "clearing identity masking restores role information")
	avatar.call("set_gameplay_nameplate_visible", false)
	_check(nameplate != null and not nameplate.visible, "gameplay identity rules hide the complete remote nameplate")
	avatar.call("set_creator_nameplate_visible", true)
	_check(nameplate != null and not nameplate.visible, "creator visibility cannot bypass gameplay identity hiding")
	avatar.call("clear_gameplay_nameplate_visibility_override")
	_check(nameplate != null and nameplate.visible, "clearing gameplay identity rules restores normal nameplate visibility")

	avatar.queue_free()
	quit(failures)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAILED: %s" % label)
