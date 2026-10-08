extends SceneTree

const DIALOG_SCENE = preload("res://scenes/interface/aether_confirmation_dialog.tscn")
const PROBE_PATH := "res://tests/fixtures/required_name_change_dialog_probe.gd"
var failed := false
var changes := 0
var cancellations := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var dialog = DIALOG_SCENE.instantiate()
	dialog.set_script(load(PROBE_PATH))
	root.add_child(dialog)
	await process_frame
	dialog.name_changed.connect(func(): changes += 1)
	dialog.canceled.connect(func(): cancellations += 1)
	dialog.popup_centered()
	dialog.name_input.text = "ab"
	dialog._confirm()
	_check(dialog.submitted_names.is_empty(), "invalid format never reaches the API")
	_check(dialog.visible and not dialog.error_label.text.is_empty(), "format errors keep the dialog open")
	dialog.name_input.text = "NewTrainer"
	dialog._confirm()
	_check(dialog.submitting and dialog.confirm_button.disabled, "submit cannot be duplicated")
	dialog._confirm()
	dialog._cancel()
	_check(cancellations == 0, "cancel is blocked during submit")
	await process_frame
	await process_frame
	_check(dialog.submitted_names.size() == 1, "only one request is sent")
	_check(changes == 0 and dialog.visible, "unavailable name keeps player in rename flow")
	_check(not dialog.confirm_button.disabled and dialog.name_input.editable, "failed requests permit correction")
	dialog.next_response = {"success": true}
	dialog.name_input.text = "ValidTrainer"
	dialog._confirm()
	await process_frame
	await process_frame
	_check(changes == 1, "only successful API completion allows continuing")
	var code := BackendErrorLocalizationService.error_code({"body": {"detail": [{"type": "name_inappropriate", "msg": "choose a new name"}]}})
	_check(code == "name_inappropriate", "request validation profanity errors are localized")
	dialog.queue_free()
	await process_frame
	var auth := root.get_node("AuthService")
	var original_user: Dictionary = auth.current_user.duplicate(true)
	auth.current_user = {"username": "fixture", "nameChangeRequired": true}
	var login_scene := load("res://scenes/interface/login_screen.tscn") as PackedScene
	var login = login_scene.instantiate()
	login.set_script(load("res://tests/fixtures/login_startup_recovery_probe.gd"))
	root.add_child(login)
	login.restore_results = [{"success": true}]
	await login._restore_saved_session()
	_check(is_instance_valid(login.required_name_dialog) and login.required_name_dialog.visible, "restored sessions show the required rename prompt")
	var count: int = login.get_child_count()
	login._enter_world()
	_check(login.get_child_count() == count and current_scene == null, "continue cannot enter the world or duplicate the prompt")
	auth.current_user = original_user
	login.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
