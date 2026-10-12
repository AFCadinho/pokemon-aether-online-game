extends SceneTree

const DialogScript := preload("res://scripts/ui/guild_invitation_dialog.gd")

var failed := false

class FakeSystemOverlay extends Node:
	var messages: Array[String] = []

	func add_system_message(text: String) -> void:
		messages.append(text)


func _init() -> void:
	root.gui_embed_subwindows = true
	var system_overlay := FakeSystemOverlay.new()
	system_overlay.add_to_group("ui_overlay")
	root.add_child(system_overlay)

	var dialog := DialogScript.new()
	root.add_child(dialog)
	await process_frame
	dialog.setup()
	_check(not dialog.visible and dialog.invitation.is_empty(), "guild invitation dialog starts hidden")

	var first_invitation := {
		"id": 7,
		"guildName": "Aether Vanguard",
		"invitedBy": "Nova",
		"status": "pending",
	}
	var pixels: Array = []
	pixels.resize(1024)
	pixels.fill(-1)
	pixels[0] = 0
	pixels[1023] = 1
	first_invitation["guildEmblem"] = {"palette": ["#60d3ff", "#e3bd68"], "pixels": pixels}
	var second_invitation := {
		"id": 8,
		"guildName": "Kanto Explorers",
		"invitedBy": "Maple",
		"status": "pending",
	}
	dialog.show_invitations([first_invitation, second_invitation])
	_check(dialog.visible, "incoming guild invitation opens the dialog")
	_check(dialog.invitations.size() == 2, "multiple invitations are queued")
	_check(dialog.heading_label.text.contains("Aether Vanguard"), "dialog identifies the guild")
	_check(dialog.status_label.text.contains("Nova"), "dialog identifies the inviter")
	_check(dialog.emblem_icon.texture != null and dialog.emblem_icon.texture != DialogScript.GUILD_ICON, "invitation displays the inviting Guild's own emblem")
	_check(dialog.emblem_icon.texture.get_image().get_pixel(0, 0).is_equal_approx(Color("#60d3ff")), "invitation keeps the emblem's authored colours")
	_check(dialog.find_child("GuildInvitationEmblemFrame", true, false) != null and dialog.find_child("GuildInvitationBenefits", true, false) != null, "invitation presents its crest and Guild benefits on a dedicated card")
	_check(
		dialog.position_label.text.contains("1") and dialog.position_label.text.contains("2"),
		"dialog shows the localized invitation queue position"
	)
	_check(dialog.find_child("AcceptGuildInvitationDialogButton", true, false) != null, "dialog has an accept action")
	_check(dialog.find_child("DeclineGuildInvitationDialogButton", true, false) != null, "dialog has a decline action")
	_check(system_overlay.messages.size() == 1, "incoming invitation emits one system message")
	dialog.show_invitations([first_invitation, second_invitation])
	_check(system_overlay.messages.size() == 1, "replayed invitation does not duplicate its system message")
	dialog._set_action_in_flight(true)
	dialog.show_invitations([second_invitation])
	_check(dialog.invitation["id"] == 7 and dialog.accept_button.disabled and dialog.decline_button.disabled, "a pending response keeps the original invitation and disables duplicate actions")
	dialog._set_action_in_flight(false)
	var localization_manager := root.get_node_or_null("LocalizationManager")
	if localization_manager != null:
		localization_manager.set_locale("pt_BR")
		await process_frame
		_check(dialog.title == "Convite para Guilda", "dialog title refreshes in Brazilian Portuguese")
		_check(dialog.heading_label.text.contains("Entrar em"), "dialog copy refreshes without losing its invitation")
		localization_manager.set_locale("en")
		await process_frame
	dialog.show_invitations([second_invitation])
	_check(dialog.emblem_icon.texture == DialogScript.GUILD_ICON and dialog.heading_label.text.contains("Kanto Explorers"), "an invitation without emblem data clears the previous crest and shows a fallback")
	dialog.show_invitations([])
	_check(not dialog.visible, "dialog closes when no invitations remain")

	var source := FileAccess.get_file_as_string("res://scripts/ui/guild_invitation_dialog.gd")
	_check(source.contains("accept_invitation"), "accept action uses the authoritative guild service")
	_check(source.contains("decline_invitation"), "decline action uses the authoritative guild service")
	_check(source.contains("close_requested.connect(_decline)"), "window close explicitly declines the invitation")
	if localization_manager != null:
		localization_manager.set_locale("nl")
	for viewport_size: Vector2i in [Vector2i(480, 360), Vector2i(360, 640)]:
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		viewport.gui_embed_subwindows = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		await process_frame
		var compact := DialogScript.new()
		viewport.add_child(compact)
		compact.setup()
		var long_invitation := first_invitation.duplicate(true)
		long_invitation["guildName"] = "Guild Met Een Bijzonder Lange Naam"
		compact.show_invitations([long_invitation])
		# Headless popup placement clamps to the dummy display rather than this viewport.
		if DisplayServer.get_name() == "headless":
			compact.size = compact.max_size
		for frame: int in range(8):
			await process_frame
		_check(compact.size.x <= viewport_size.x and compact.size.y <= viewport_size.y, "invitation fits %s in Dutch" % viewport_size)
		_check(compact.accept_button.get_global_rect().end.y <= compact.size.y and compact.decline_button.get_global_rect().end.y <= compact.size.y, "invitation actions remain visible at %s" % viewport_size)
		_check(compact.accept_button.text == "Lid worden", "Dutch invitation has a clear Join Guild action")
		var card_scroll := compact.find_child("GuildInvitationCardScroll", true, false) as ScrollContainer
		_check(card_scroll.get_global_rect().end.y <= compact.accept_button.get_global_rect().position.y, "only the invitation card scrolls above the fixed action buttons")
		if viewport_size.y < 420:
			_check(compact.heading_label.get_global_rect().position.y >= card_scroll.get_global_rect().position.y and compact.status_label.get_global_rect().end.y <= card_scroll.get_global_rect().end.y, "short screens show the Guild name and inviter without scrolling: heading %s, inviter %s, card %s" % [compact.heading_label.get_global_rect(), compact.status_label.get_global_rect(), card_scroll.get_global_rect()])
		viewport.free()
	if localization_manager != null:
		localization_manager.set_locale("en")

	dialog.queue_free()
	system_overlay.queue_free()
	quit(1 if failed else 0)


func _check(value: bool, label: String) -> void:
	if value:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
