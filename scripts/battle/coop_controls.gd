extends Control

var battle_mode := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if battle_mode:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(load("res://scripts/battle/coop_battle_panel.gd").new())


func _target_label(target: int, _participant: String) -> String:
	var controller := "p2" if target == 1 else "p4" if target == 2 else "p1" if target == -1 else "p3"
	for position: Dictionary in CoopService.view.get("positions", []):
		if position.get("controller") == controller:
			return str(position.get("details", controller))
	return controller
