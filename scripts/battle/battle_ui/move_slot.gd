extends Button

@onready var type_bannner: TextureRect = $MarginContainer/VBoxContainer/HBoxContainer/TypeBanner
@onready var pp_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/PPLabel
@onready var move_name_label: Label = $MarginContainer/VBoxContainer/MoveNameLabel
@onready var effectiveness_label: Label = $MarginContainer/VBoxContainer/EffectivenessLabel

func set_move(move_name: String) -> void:
	visible = true
	disabled = false
	move_name_label.text = move_name
	pp_label.text = "--/--"
	effectiveness_label.text = ""
	type_bannner.visible = false
	
func set_empty() -> void:
	visible = false
	disabled = true
	move_name_label.text = ""
	pp_label.text = "--/--"
	effectiveness_label.text = ""
	type_bannner.visible = false
	
