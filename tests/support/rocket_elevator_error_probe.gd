extends Node
var shown := 0
func show_message(_lines: Array) -> void:
	shown += 1
	await get_tree().process_frame
func show_response(_response: Dictionary, _fallback := "") -> void:
	shown += 1
	await get_tree().process_frame
func show_report_to_staff_message() -> void:
	shown += 1
	await get_tree().process_frame
