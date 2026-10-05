extends SceneTree

func _init() -> void:
	_raise_script_error()
	quit(0)

func _raise_script_error() -> void:
	var absent: Variant = null
	absent.missing_method()
