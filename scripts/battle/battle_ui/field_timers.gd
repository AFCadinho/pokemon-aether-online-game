extends PanelContainer

class_name FieldTimersPanel

@onready var condition_icon: TextureRect = $MarginContainer/VBoxContainer/FieldConditionRow/ConditionIcon
@onready var condition_label: Label = $MarginContainer/VBoxContainer/FieldConditionRow/ConditionLabel

func reset_timers() -> void:
	visible = false
	condition_icon.texture = null
	condition_icon.visible = false
	visible = false
	
func set_condition(text: String, icon: Texture2D = null) -> void:
	condition_label.text = text
	condition_icon.texture = icon
	condition_icon.visible = icon != null
	visible = text != ""
