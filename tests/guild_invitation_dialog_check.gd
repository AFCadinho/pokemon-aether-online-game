extends SceneTree

const DialogScript := preload("res://scripts/ui/guild_invitation_dialog.gd")

var failed := false

class FakeSystemOverlay extends Node:
	var messages: Array[String] = []

	func add_system_message(text: String) -> void:
		messages.append(text)


func _init() -> void:
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
	_check(
		dialog.position_label.text.contains("1") and dialog.position_label.text.contains("2"),
		"dialog shows the localized invitation queue position"
	)
	_check(dialog.find_child("AcceptGuildInvitationDialogButton", true, false) != null, "dialog has an accept action")
	_check(dialog.find_child("DeclineGuildInvitationDialogButton", true, false) != null, "dialog has a decline action")
	_check(system_overlay.messages.size() == 1, "incoming invitation emits one system message")
	dialog.show_invitations([first_invitation, second_invitation])
	_check(system_overlay.messages.size() == 1, "replayed invitation does not duplicate its system message")
	var localization_manager := root.get_node_or_null("LocalizationManager")
	if localization_manager != null:
		localization_manager.set_locale("pt_BR")
		await process_frame
		_check(dialog.title == "Convite para Guilda", "dialog title refreshes in Brazilian Portuguese")
		_check(dialog.heading_label.text.contains("Entrar em"), "dialog copy refreshes without losing its invitation")
		localization_manager.set_locale("en")
		await process_frame
	dialog.show_invitations([])
	_check(not dialog.visible, "dialog closes when no invitations remain")

	var source := FileAccess.get_file_as_string("res://scripts/ui/guild_invitation_dialog.gd")
	_check(source.contains("accept_invitation"), "accept action uses the authoritative guild service")
	_check(source.contains("decline_invitation"), "decline action uses the authoritative guild service")
	_check(source.contains("close_requested.connect(_decline)"), "window close explicitly declines the invitation")

	dialog.queue_free()
	system_overlay.queue_free()
	quit(1 if failed else 0)


func _check(value: bool, label: String) -> void:
	if value:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
