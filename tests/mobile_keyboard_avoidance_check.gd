extends SceneTree

const Avoidance := preload("res://scripts/ui/mobile_keyboard_avoidance.gd")
var failures := 0
var checks := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for scale_factor: float in [0.5, 1.0, 1.5]:
		await _check_layout(scale_factor)
	await _check_scene("res://scenes/interface/login_screen.tscn", "Background/Shell", [
		"MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/FormFields/UsernameInput",
		"MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/FormFields/PasswordInput",
	])
	await _check_scene("res://scenes/interface/ui_overlay.tscn", "Control/ChatPanel", [
		"MarginContainer/VBoxContainer/InputRow/ChatInput",
	])
	_check(Avoidance.required_shift(Rect2(10, 40, 100, 40), 200) == 0.0, "Visible fields stay still")
	_check(Avoidance.required_shift(Rect2(10, 100, 100, 40), 20) == 84.0, "Tiny available area keeps the field top visible")
	var login_source := FileAccess.get_file_as_string("res://scripts/ui/login_screen.gd")
	var chat_source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	_check(login_source.contains("keyboard_avoidance.inputs.assign([username_input, password_input])"), "Both login fields use avoidance")
	_check(chat_source.contains("keyboard_avoidance.inputs.assign([chat_input])"), "Chat uses the same avoidance")
	_check(load("res://scripts/ui/ui_overlay.gd") != null, "Chat script parses")
	print("mobile_keyboard_avoidance_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_scene(scene_path: String, surface_path: String, input_paths: Array) -> void:
	# Exercise the real Container layouts without starting authentication,
	# networking or the game overlay's unrelated services.
	var scene := (load(scene_path) as PackedScene).instantiate()
	var surface := scene.get_node(surface_path) as Control
	surface.get_parent().remove_child(surface)
	scene.free()
	root.add_child(surface)
	var helper := Avoidance.new()
	helper.surface = surface
	for path: String in input_paths:
		helper.inputs.append(surface.get_node(path) as LineEdit)
	surface.add_child(helper)
	helper.set_process(false)
	for frame in range(4):
		await process_frame
	var original := surface.position
	for input: LineEdit in helper.inputs:
		input.grab_focus()
		helper.update_layout(400.0, 700.0)
		_check_field_visible(input, 300.0, scene_path + ": " + input.name)
		helper.update_layout(0.0, 700.0)
		_check(surface.position.is_equal_approx(original), "Real layout restores after closing keyboard")
	surface.free()


func _check_layout(scale_factor: float) -> void:
	var parent := Control.new()
	parent.scale = Vector2.ONE * scale_factor
	root.add_child(parent)
	var surface := Control.new()
	surface.position = Vector2(50, 200)
	surface.size = Vector2(400, 600)
	parent.add_child(surface)
	var username := LineEdit.new()
	username.position = Vector2(20, 180)
	username.size = Vector2(200, 48)
	surface.add_child(username)
	var password := LineEdit.new()
	password.position = Vector2(20, 270)
	password.size = Vector2(200, 48)
	surface.add_child(password)
	var helper := Avoidance.new()
	helper.surface = surface
	helper.inputs.assign([username, password])
	surface.add_child(helper)
	helper.set_process(false)
	await process_frame
	var original_position := surface.position
	username.text = "trainer"
	username.grab_focus()
	username.caret_column = 3
	var keyboard_top := (username.get_screen_transform() * Vector2.ZERO).y + 20.0
	helper.update_layout(300.0, keyboard_top + 300.0)
	_check_field_visible(username, keyboard_top, "Username at scale %s" % scale_factor)
	var shifted_position := surface.position
	helper.update_layout(300.0, keyboard_top + 300.0)
	_check(surface.position.is_equal_approx(shifted_position), "Repeated frames do not drift")
	_check(username.text == "trainer" and username.caret_column == 3 and username.has_focus(), "Typing state stays intact")
	password.grab_focus()
	helper.update_layout(300.0, keyboard_top + 300.0)
	_check_field_visible(password, keyboard_top, "Password / chat input at scale %s" % scale_factor)
	helper.update_layout(0.0, keyboard_top + 300.0)
	_check(surface.position.is_equal_approx(original_position), "Keyboard close restores layout")
	parent.scale = Vector2.ONE * scale_factor * 0.8
	helper.update_layout(300.0, keyboard_top + 300.0)
	_check_field_visible(password, keyboard_top, "Changed screen scale remains visible")
	helper.update_layout(350.0, keyboard_top + 300.0)
	_check_field_visible(password, keyboard_top - 50.0, "Changed keyboard height remains visible")
	helper.update_layout(0.0, keyboard_top + 300.0)
	if not OS.has_feature("mobile"):
		helper._process(0.0)
		_check(surface.position.is_equal_approx(original_position), "Desktop processing preserves layout")
	helper.update_layout(300.0, keyboard_top + 300.0)
	password.release_focus()
	helper.update_layout(300.0, keyboard_top + 300.0)
	_check(surface.position.is_equal_approx(original_position), "Unrelated focused controls restore layout")
	password.grab_focus()
	helper.update_layout(300.0, keyboard_top + 300.0)
	surface.hide()
	helper.update_layout(300.0, keyboard_top + 300.0)
	_check(surface.position.is_equal_approx(original_position), "Hidden chat restores layout")
	parent.free()


func _check_field_visible(input: LineEdit, keyboard_top: float, message: String) -> void:
	var rect := input.get_screen_transform() * Rect2(Vector2.ZERO, input.size)
	_check(rect.end.y <= keyboard_top - Avoidance.MARGIN_PIXELS + 0.1 and rect.position.y >= 0.0, message)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
