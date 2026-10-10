extends TrainerNPC

var battle_dialogues := 0
var sleeping_dialogues := 0
var post_battle_dialogues := 0


func _ready() -> void:
	set_process(false)
	_setup_rematch_marker()


func _show_battle_dialogue(_is_rematch: bool) -> void:
	battle_dialogues += 1


func show_dialogue(_lines: Array[String] = [], _speaker_name := "") -> bool:
	sleeping_dialogues += 1
	return true


func _show_post_battle_dialogue() -> void:
	post_battle_dialogues += 1


func _is_player_facing_npc(_body: Node2D) -> bool:
	return true


func _is_ui_typing() -> bool:
	return false


func _get_dialogue_box() -> Node:
	return null
