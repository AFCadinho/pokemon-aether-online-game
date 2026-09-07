extends SceneTree

var failed := false


func _init() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/jail_bail_dialog.gd")
	_check(
		"func _apply_close_button_style" in source
		and 'add_theme_stylebox_override("hover", _button_style(Color("#3a1b2a"), Color("#ef7188"), 7, 2))' in source
		and 'add_theme_stylebox_override("pressed", _button_style(Color("#1c0d16"), Color("#ff9aac"), 7, 2))' in source,
		"The jail dialog close button has dedicated danger-hover styling"
	)
	_check(
		"func _apply_pay_button_style" in source
		and 'add_theme_stylebox_override("normal", _button_style(Color("#0d5f92"), Color("#4bc5ff"), 7, 1))' in source
		and 'add_theme_stylebox_override("disabled", _button_style(Color("#0a1722"), Color("#294457"), 7, 1))' in source,
		"The jail dialog bail action has styled primary and disabled states"
	)
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
