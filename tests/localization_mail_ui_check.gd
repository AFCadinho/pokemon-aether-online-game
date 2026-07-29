extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"

var failed := false
var localization_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	localization_manager = root.get_node_or_null("LocalizationManager")
	_check(localization_manager != null, "Mail localization check can access LocalizationManager")
	if localization_manager == null:
		quit(1)
		return

	var original_locale := str(localization_manager.get("current_locale"))
	localization_manager.call("set_locale", "nl")
	var packed := load(OVERLAY_SCENE_PATH) as PackedScene
	var overlay := packed.instantiate()
	root.add_child(overlay)
	await process_frame

	var mail_popup := overlay.get("mail_popup") as Control
	var compose_popup := overlay.get("mail_compose_popup") as Control
	var title := mail_popup.find_child("Title", true, false) as Label
	var compose_title := compose_popup.find_child("Title", true, false) as Label
	var inbox_button := overlay.get("mail_inbox_button") as Button
	var recipient_input := overlay.get("mail_compose_recipient_input") as LineEdit
	var body_input := overlay.get("mail_compose_body_input") as TextEdit
	var empty_label := overlay.get("mail_empty_inbox_label") as Label
	_check(title != null and title.text == "Postvak", "Mailbox title renders in Dutch")
	_check(inbox_button != null and inbox_button.text == "Inbox", "Mailbox tabs render in Dutch")
	_check(compose_title != null and compose_title.text == "Mail opstellen", "Mail composer renders in Dutch")
	_check(
		recipient_input != null and recipient_input.placeholder_text == "Gebruikersnaam ontvanger",
		"Mail recipient placeholder renders in Dutch"
	)
	_check(body_input != null and body_input.placeholder_text == "Bericht", "Mail body placeholder renders in Dutch")
	_check(
		empty_label != null and empty_label.text.begins_with("Je inbox is leeg."),
		"Mailbox empty state renders in Dutch"
	)

	localization_manager.call("set_locale", "pt_BR")
	await process_frame
	_check(title != null and title.text == "Caixa de correio", "Mailbox title updates to Portuguese")
	_check(inbox_button != null and inbox_button.text == "Entrada", "Mailbox tabs update to Portuguese")
	_check(compose_title != null and compose_title.text == "Escrever mensagem", "Mail composer updates to Portuguese")
	_check(
		recipient_input != null and recipient_input.placeholder_text == "Nome de usuário do destinatário",
		"Mail recipient placeholder updates to Portuguese"
	)
	_check(body_input != null and body_input.placeholder_text == "Mensagem", "Mail body placeholder updates to Portuguese")
	_check(
		empty_label != null and empty_label.text.begins_with("Sua caixa de entrada está vazia."),
		"Mailbox empty state updates to Portuguese"
	)

	for loader_property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader := overlay.get(loader_property) as Node
		if loader != null:
			loader.free()
	overlay.queue_free()
	await process_frame
	localization_manager.call("set_locale", original_locale)
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
