extends SceneTree

const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"

var failures := 0


func _init() -> void:
	var source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)

	_check(source.contains("const MAIL_POPUP_SIZE := Vector2(920, 600)"), "Mailbox uses a readable two-panel workspace")
	_check(source.contains("const MAIL_COMPOSE_POPUP_SIZE := Vector2(720, 650)"), "Mail composer has room for message and attachment controls")
	_check(source.contains("func _setup_mail_workspace_structure()"), "Mailbox builds a dedicated visual hierarchy")
	_check(source.contains('"ui.mail.title"'), "Mailbox has a clear localized player-facing title")
	_check(source.contains("icon.texture = SOCIALS_MAIL_ICON"), "Mailbox header reuses the dedicated mail icon")
	_check(source.contains('"ui.mail.subtitle"'), "Mailbox header explains its scope with localized copy")
	_check(source.contains('action_row.name = "ActionRow"'), "Message actions share a compact footer row")
	_check(source.contains('"●  " if is_unread else ""'), "Unread messages remain visually distinct")
	_check(source.contains('"ui.mail.list.sent" if active_mail_box == "sent" else "ui.mail.list.inbox"'), "Mailbox navigation reports the localized active folder count")
	_check(source.contains('"ui.mail.claim_all" if has_unclaimed_attachments else "ui.mail.all_claimed"'), "Attachment claim state is localized and explicit")
	_check(source.contains("_mail_currency_icon(currency_id)"), "Currency attachments render their wallet icon")
	_check(source.contains('"money":\n\t\t\treturn TRAINER_WALLET_MONEY_ICON'), "Pokédollar attachments use the pixel coin icon")
	_check(source.contains('"gems":\n\t\t\treturn TRAINER_WALLET_AETHER_GEM_ICON'), "Aether Gem attachments use the gem icon")
	_check(source.contains('"aetherite":\n\t\t\treturn TRAINER_WALLET_AETHERITE_ICON'), "Aetherite attachments use the Aetherite icon")
	_check(source.contains('"battle_points":\n\t\t\treturn TRAINER_WALLET_BATTLE_POINTS_ICON'), "Battle Point attachments use the Battle Point icon")
	_check(source.contains("func _setup_mail_compose_workspace_structure()"), "Composer uses the refreshed workspace language")
	_check(source.contains('"ui.mail.compose.title"'), "Composer has a clear localized task title")
	_check(source.contains('"ui.mail.compose.send"'), "Composer primary action is localized and unambiguous")
	_check(source.contains("func _create_mail_compose_attachment_row("), "Selected attachments render as structured rows")
	_check(source.contains("func _on_mail_remove_item_attachment_pressed("), "Item attachments can be removed before sending")
	_check(source.contains("func _on_mail_remove_money_attachment_pressed("), "Money attachments can be removed before sending")
	_check(source.contains("func _on_mail_remove_pokemon_attachment_pressed("), "Pokémon attachments can be removed before sending")
	_check(source.contains("mail_money_amount.value"), "Composer exposes a Pokédollar attachment amount")
	_check(source.contains('"ui.mail.compose.no_attachments"'), "Composer has a useful localized attachment empty state")
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
