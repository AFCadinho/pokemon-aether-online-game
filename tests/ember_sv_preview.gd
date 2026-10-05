extends "res://tests/source_moves_preview.gd"
## Compatibility entry point for the approved Ember pilot. Local --sv-source is no longer needed.
func _start() -> void:
	if "--smoke-sv-ember" in OS.get_cmdline_user_args():
		create_timer(90.0).timeout.connect(func(): quit(1))
	await super._start()
	if is_instance_valid(move_picker): move_picker.select(3)
	if "--smoke-sv-ember" in OS.get_cmdline_user_args(): await _check_source_moves()
