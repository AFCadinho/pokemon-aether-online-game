extends SceneTree
var failed := false
var restored := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var auth := root.get_node("AuthService")
	var original_token: String = auth.session_token
	var original_user: Dictionary = auth.current_user.duplicate(true)
	auth.session_token = ""
	auth.current_user = {"id": 42, "username": "current", "displayName": "Current"}
	var panel = VBoxContainer.new()
	panel.set_script(load("res://tests/fixtures/trainer_name_restore_panel_probe.gd"))
	root.add_child(panel)
	panel.name_restored.connect(func(): restored += 1)
	await process_frame
	await process_frame
	_check(panel.restore_options.size() == 1, "revoked names are available in account settings")
	var button: Button = panel.rows.get_child(1)
	button.pressed.emit()
	await process_frame
	_check(panel.submissions.is_empty(), "opening confirmation does not change the name")
	var dialog = panel.get_child(panel.get_child_count() - 1)
	dialog._cancel()
	await process_frame
	_check(panel.submissions.is_empty(), "keeping current name spends no free restoration")
	panel._restore("fixture")
	panel._restore("fixture")
	_check(panel.busy, "duplicate restoration is blocked during submit")
	await process_frame
	await process_frame
	await process_frame
	_check(panel.submissions.size() == 1 and restored == 0, "failed restoration leaves the player unchanged")
	_check(not panel.status.text.is_empty() and not panel.busy, "failed restoration can be retried")
	panel.next_response = {"success": true}
	panel.options_response = {"success": true, "body": {"options": []}}
	panel._restore("fixture")
	await process_frame
	await process_frame
	await process_frame
	_check(restored == 1 and panel.restore_options.is_empty(), "successful restoration refreshes account controls and removes the spent option")
	var required_scene := load("res://scenes/interface/aether_confirmation_dialog.tscn") as PackedScene
	var required = required_scene.instantiate()
	required.set_script(load("res://tests/fixtures/required_name_change_dialog_probe.gd"))
	root.add_child(required)
	var cancelled := [false]
	required.name_changed.connect(func(): cancelled[0] = true)
	required.popup_centered()
	required.next_status = {"success": true, "user": {"id": 42, "username": "current", "nameChangeRequired": false}}
	required._check_requirement()
	await process_frame
	await process_frame
	_check(cancelled[0] and required.submitted_names.is_empty(), "staff cancellation releases an open rename prompt without changing the player's name")
	required.queue_free()
	auth.session_token = original_token
	auth.current_user = original_user
	panel.queue_free()
	await process_frame
	await process_frame
	quit(1 if failed else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
