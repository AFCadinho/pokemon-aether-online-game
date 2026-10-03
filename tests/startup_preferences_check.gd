extends SceneTree

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var auth_service := root.get_node("AuthService")
	var original_token: String = auth_service.session_token
	var original_user: Dictionary = auth_service.current_user
	auth_service.session_token = "startup-preferences-fixture"
	auth_service.current_user = {"id": 1}
	var service: Node = load("res://tests/fixtures/startup_preferences_probe.gd").new()
	root.add_child(service)

	var profile: Dictionary = await service.load_player_profile()
	var startup: Dictionary = service.consume_profile_preferences()
	_check(bool(profile.get("success", false)) and startup.get("preferences") == service.preferences,
		"startup receives the complete preferences from the loaded profile")
	_check(service.request_count == 1, "startup preferences do not send a second HTTP request")
	_check(service.consume_profile_preferences().is_empty(), "profile handoff is consumed only once")

	await service.load_player_profile()
	auth_service.session_token = "different-session-fixture"
	_check(service.consume_profile_preferences().is_empty(), "a different session cannot reuse profile preferences")
	auth_service.session_token = "startup-preferences-fixture"
	await service.load_player_profile()
	auth_service.current_user = {"id": 2}
	_check(service.consume_profile_preferences().is_empty(), "changed account identity cannot consume the old handoff")
	auth_service.current_user = {"id": 1}
	service.profile_user_id = 2
	await service.load_player_profile()
	_check(service.consume_profile_preferences().is_empty(), "a mismatched account profile is never reused")
	service.profile_user_id = 1

	await service.load_player_profile()
	await service.save_player_preferences({"showFollower": true})
	_check(service.consume_profile_preferences().is_empty(), "saving preferences invalidates the older profile handoff")

	await service.load_player_profile()
	service.fail_profile = true
	await service.load_player_profile()
	_check(service.consume_profile_preferences().is_empty(), "failed profile reload cannot reuse an older snapshot")
	service.fail_profile = false
	service.save_during_profile = true
	await service.load_player_profile()
	_check(service.consume_profile_preferences().is_empty(), "a save during profile loading prevents stale settings from being handed off")
	service.save_during_profile = false

	var complete: Dictionary = await service.load_player_preferences()
	_check((complete.get("favoritePokemonOptions", []) as Array).size() == 1,
		"explicit trainer-card preference requests still fetch companion options")

	var overlay := load("res://scripts/ui/ui_overlay.gd") as Script
	_check(overlay != null and overlay.can_instantiate(), "startup preference UI script compiles")
	auth_service.session_token = original_token
	auth_service.current_user = original_user
	service.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failed = true
		push_error("FAIL: %s" % label)
