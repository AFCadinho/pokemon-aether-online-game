extends AetherConfirmationDialog

class_name RequiredNameChangeDialog

signal name_changed

var name_input: LineEdit
var error_label: Label
var submitting := false
var checking_requirement := false


func _ready() -> void:
	super._ready()
	configure(
		LocalizationManager.text("ui.login.rename.title"),
		LocalizationManager.text("ui.login.rename.message"),
		LocalizationManager.text("ui.login.rename.submit"),
		LocalizationManager.text("ui.login.rename.logout")
	)
	name_input = LineEdit.new()
	name_input.max_length = 32
	name_input.placeholder_text = LocalizationManager.text("ui.login.rename.placeholder")
	name_input.custom_minimum_size = Vector2(0, 40)
	add_custom_control(name_input)
	error_label = Label.new()
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.add_theme_color_override("font_color", Color("ff8a8a"))
	add_custom_control(error_label)
	name_input.text_submitted.connect(func(_text: String): _confirm())
	name_input.grab_focus.call_deferred()
	var timer := Timer.new()
	timer.wait_time = 5.0
	timer.timeout.connect(_check_requirement)
	add_child(timer)
	timer.start()



func _confirm() -> void:
	if submitting or checking_requirement:
		return
	var new_name := name_input.text.strip_edges()
	var format := RegEx.new()
	format.compile("^[A-Za-z0-9_]{3,32}$")
	if format.search(new_name) == null:
		error_label.text = LocalizationManager.text("ui.login.rename.format")
		return
	submitting = true
	confirm_button.disabled = true
	cancel_button.disabled = true
	close_button.disabled = true
	name_input.editable = false
	error_label.text = ""
	var response: Dictionary = await _submit_name(new_name)
	submitting = false
	confirm_button.disabled = false
	cancel_button.disabled = false
	close_button.disabled = false
	name_input.editable = true
	if bool(response.get("success", false)):
		name_changed.emit()
	else:
		error_label.text = BackendErrorLocalizationService.message(response, "ui.login.rename.error")


func _submit_name(new_name: String) -> Dictionary:
	return await AuthService.complete_required_name_change(new_name)


func _cancel() -> void:
	if not submitting:
		super._cancel()


func _check_requirement() -> void:
	if submitting or checking_requirement or not visible or not _is_authenticated():
		return
	checking_requirement = true
	var account := AuthService.get_user_id_text()
	var result: Dictionary = await _refresh_requirement()
	checking_requirement = false
	if not is_inside_tree() or account != AuthService.get_user_id_text():
		return
	if bool(result.get("success", false)) and not bool(result.get("user", {}).get("nameChangeRequired", true)):
		visible = false
		name_changed.emit()


func _refresh_requirement() -> Dictionary:
	return await AuthService.refresh_name_change_requirement()


func _is_authenticated() -> bool:
	return AuthService.is_authenticated()
