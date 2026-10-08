extends AetherConfirmationDialog

class_name RequiredNameChangeDialog

signal name_changed

var name_input: LineEdit
var error_label: Label
var submitting := false


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


func _confirm() -> void:
	if submitting:
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
