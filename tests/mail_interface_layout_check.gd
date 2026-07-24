extends SceneTree

const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"

var failures := 0


func _init() -> void:
	var source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)

	_check(source.contains("const MAIL_POPUP_SIZE := Vector2(920, 600)"), "Mailbox uses a readable two-panel workspace")
	_check(source.contains("const MAIL_COMPOSE_POPUP_SIZE := Vector2(720, 650)"), "Mail composer has room for message and attachment controls")
	_check(source.contains("func _setup_mail_workspace_structure()"), "Mailbox builds a dedicated visual hierarchy")
	_check(source.contains('title_label.text = "Mailbox"'), "Mailbox has a clear player-facing title")
	_check(source.contains("icon.texture = SOCIALS_MAIL_ICON"), "Mailbox header reuses the dedicated mail icon")
	_check(source.contains('subtitle.text = "Messages, deliveries and trainer gifts"'), "Mailbox header explains its scope")
	_check(source.contains('action_row.name = "ActionRow"'), "Message actions share a compact footer row")
	_check(source.contains('"●  " if is_unread else ""'), "Unread messages remain visually distinct")
	_check(source.contains('list_title.text = "%s  ·  %s"'), "Mailbox navigation reports the active folder count")
	_check(source.contains('mail_claim_button.text = "Claim All" if has_unclaimed_attachments else "All Claimed"'), "Attachment claim state is explicit")
	_check(source.contains("func _setup_mail_compose_workspace_structure()"), "Composer uses the refreshed workspace language")
	_check(source.contains('title_label.text = "Compose Mail"'), "Composer has a clear task title")
	_check(source.contains('mail_compose_send_button.text = "Send Mail"'), "Composer primary action is unambiguous")
	_check(source.contains("func _create_mail_compose_attachment_row("), "Selected attachments render as structured rows")
	_check(source.contains("func _on_mail_remove_item_attachment_pressed("), "Item attachments can be removed before sending")
	_check(source.contains("func _on_mail_remove_pokemon_attachment_pressed("), "Pokémon attachments can be removed before sending")
	_check(source.contains('empty_label.text = "No attachments selected\\nYou can also send mail without an attachment."'), "Composer has a useful attachment empty state")
	_check(source.contains("MailService.claim_mail(selected_mail_id)"), "Mailbox revamp preserves claim-all behavior")
	_check(source.contains("MailService.claim_mail_attachment(selected_mail_id, attachment_id)"), "Mailbox revamp preserves individual claims")
	_check(source.contains("MailService.send_mail("), "Mailbox revamp preserves sending")
	_check(source.contains("_open_mail_compose_popup(recipient, subject)"), "Mailbox revamp preserves replies")

	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
