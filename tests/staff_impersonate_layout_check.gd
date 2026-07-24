extends SceneTree

const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"

var failures := 0


func _init() -> void:
	var source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)

	_check(source.contains("staff_impersonate_popup.custom_minimum_size = Vector2(620, 350)"), "Impersonation popup uses a compact focused layout")
	_check(source.contains("var impersonate_shell_style := _make_glass_panel_style(14)") and not source.contains('staff_impersonate_popup.add_theme_stylebox_override("panel", _make_gold_panel_style'), "Impersonation popup uses the modern glass shell")
	_check(source.contains('impersonate_subtitle.text = "Start a temporary secure account session"'), "Header explains the temporary session")
	_check(source.contains('security_title.text = "SECURE STAFF ACTION"'), "Sensitive action has a prominent security notice")
	_check(source.contains("staff_impersonate_token_input.secret = true") and source.contains('staff_impersonate_token_input.secret_character = "•"'), "Impersonation token is masked")
	_check(source.contains("staff_impersonate_token_input.text_submitted.connect(_on_staff_impersonate_token_submitted)"), "Token can be submitted from the keyboard")
	_check(source.contains('staff_impersonate_confirm_button.text = "Start Secure Session"'), "Primary action clearly describes the secure session")
	_check(source.contains("var staff_impersonate_in_flight := false") and source.contains("if staff_impersonate_in_flight:"), "Duplicate submissions and closing during authentication are guarded")
	_check(source.contains('staff_impersonate_confirm_button.text = "Verifying..."') and source.contains('staff_impersonate_confirm_button.text = "Loading Profile..."'), "Authentication progress is visible")
	_check(source.contains("func _set_staff_impersonate_status") and source.contains("UI_DANGER if is_error else UI_MUTED_TEXT"), "Inline errors and neutral status messages have distinct styling")
	_check(source.contains("await AuthService.impersonate_with_token(token)"), "Existing authoritative token exchange remains intact")
	_check(source.contains("staff_impersonate_token_input.clear()"), "Sensitive token is cleared when the popup closes")

	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
