extends Button

@onready var type_bannner: TextureRect = $MarginContainer/VBoxContainer/HBoxContainer/TypeBanner
@onready var pp_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/PPLabel
@onready var move_name_label: Label = $MarginContainer/VBoxContainer/MoveNameLabel
@onready var effectiveness_label: Label = $MarginContainer/VBoxContainer/EffectivenessLabel

func set_move_data(move_data: Dictionary) -> void:
	visible = true
	disabled = move_data.get("disabled", false) == true
	
	move_name_label.text = str(move_data.get("name", ""))
	
	var current_pp := int(move_data.get("pp", 0))
	var max_pp := int(move_data.get("maxpp", current_pp))
	
	pp_label.text = "%s/%s" %[
		current_pp,
		max_pp
	]
	effectiveness_label.text = ""
	type_bannner.visible = true
	

func set_empty() -> void:
	visible = true
	disabled = true
	move_name_label.text = "Empty"
	pp_label.text = "--/--"
	effectiveness_label.text = ""
	type_bannner.visible = false
	
