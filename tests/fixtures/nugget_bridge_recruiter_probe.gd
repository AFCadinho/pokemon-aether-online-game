extends NuggetBridgeRecruiter

# Exercise the real reward failure path without scene sensors or progress HTTP calls.
func _ready() -> void:
	set_process(false)
	set_physics_process(false)


var last_dialogue_id := ""
var last_speaker := ""


func _show_catalogue_dialogue(dialogue_id: String, _fallback_lines: Array[String], fallback_speaker: String) -> void:
	last_dialogue_id = dialogue_id
	last_speaker = fallback_speaker
	await get_tree().process_frame
