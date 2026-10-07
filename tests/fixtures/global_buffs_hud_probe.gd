extends "res://scripts/ui/ui_overlay.gd"

var applied: Dictionary = {}

func _ready() -> void:
	set_process(false)

func _apply_global_boost_state(state: Dictionary, boost_id: String, _show_activation_notification: bool = false) -> void:
	_mark_global_buff_state_changed(boost_id)
	applied[boost_id] = state.duplicate(true)

func _apply_global_heal_state(state: Dictionary, _show_activation_notification: bool = false) -> void:
	_mark_global_buff_state_changed("global_heal")
	applied["global_heal"] = state.duplicate(true)
