extends VBoxContainer

signal name_restored

const CONFIRMATION_SCENE = preload("res://scenes/interface/aether_confirmation_dialog.tscn")
var rows: VBoxContainer
var status: Label
var restore_options: Array = []
var loading := false
var busy := false
var generation := 0


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	add_child(rows)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 12)
	status.visible = false
	add_child(status)
	visibility_changed.connect(_on_visibility_changed)
	LocalizationManager.locale_changed.connect(func(_locale: String): _render())
	refresh.call_deferred()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh.call_deferred()
	else:
		generation += 1
		loading = false


func refresh() -> void:
	if not is_visible_in_tree() or loading or busy or not _is_authenticated():
		return
	generation += 1
	var run := generation
	var account := AuthService.get_user_id_text()
	loading = true
	var response: Dictionary = await _load_options()
	if run != generation:
		return
	if account != AuthService.get_user_id_text():
		loading = false
		restore_options = []
		_render()
		return
	loading = false
	if bool(response.get("success", false)):
		restore_options = response.get("body", {}).get("options", [])
		status.text = ""
		status.visible = false
		_render()
	else:
		restore_options = []
		_render()
		status.text = BackendErrorLocalizationService.message(response, "ui.settings.rename.error")
		status.visible = true


func _load_options() -> Dictionary:
	return await AuthService.load_name_restore_options()


func _render() -> void:
	if rows == null:
		return
	rows.visible = not restore_options.is_empty()
	for child: Node in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for value: Variant in restore_options:
		if not value is Dictionary:
			continue
		var option: Dictionary = value
		var explanation := Label.new()
		explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		explanation.add_theme_font_size_override("font_size", 12)
		explanation.text = LocalizationManager.text("ui.settings.rename.offer", {"name": str(option.get("displayName", ""))})
		rows.add_child(explanation)
		var button := Button.new()
		button.text = LocalizationManager.text("ui.settings.rename.restore", {"name": str(option.get("displayName", ""))})
		button.custom_minimum_size.y = 40
		button.disabled = busy or not bool(option.get("available", false))
		button.pressed.connect(_confirm_restore.bind(option.duplicate(true)))
		rows.add_child(button)
		if not bool(option.get("available", false)):
			var unavailable := Label.new()
			unavailable.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			unavailable.text = LocalizationManager.text("ui.settings.rename.unavailable")
			rows.add_child(unavailable)


func _confirm_restore(option: Dictionary) -> void:
	if busy:
		return
	var dialog = CONFIRMATION_SCENE.instantiate()
	add_child(dialog)
	dialog.configure(
		LocalizationManager.text("ui.settings.rename.title"),
		LocalizationManager.text("ui.settings.rename.confirm", {"name": str(option.get("displayName", ""))}),
		LocalizationManager.text("ui.settings.rename.restore", {"name": str(option.get("displayName", ""))}),
		LocalizationManager.text("common.cancel")
	)
	dialog.confirmed.connect(func():
		dialog.queue_free()
		_restore(str(option.get("decisionId", "")))
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(520, 260))


func _restore(decision_id: String) -> void:
	if busy:
		return
	busy = true
	_render()
	var account := AuthService.get_user_id_text()
	var response: Dictionary = await _submit_restore(decision_id)
	busy = false
	if account != AuthService.get_user_id_text():
		restore_options = []
		_render()
		return
	if bool(response.get("success", false)):
		PlayerSave.player_name = AuthService.get_display_name()
		var player := get_tree().get_first_node_in_group("player")
		if player != null and player.has_method("set_display_name"):
			player.call("set_display_name", PlayerSave.player_name, SettingsManager.display_own_name)
		name_restored.emit()
		await refresh()
		status.text = LocalizationManager.text("ui.settings.rename.success", {"name": AuthService.get_display_name()})
		status.visible = true
	else:
		await refresh()
		status.text = BackendErrorLocalizationService.message(response, "ui.settings.rename.error")
		status.visible = true


func _submit_restore(decision_id: String) -> Dictionary:
	return await AuthService.restore_previous_trainer_name(decision_id)


func _is_authenticated() -> bool:
	return AuthService.is_authenticated() and not AuthService.is_impersonating()
