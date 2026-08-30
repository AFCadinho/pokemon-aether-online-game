extends CanvasLayer

class_name AetherClashSpectatorCameraHud

signal return_requested

@onready var title_label: Label = $Root/Panel/Margin/Content/Copy/Title
@onready var hint_label: Label = $Root/Panel/Margin/Content/Copy/Hint
@onready var return_button: Button = $Root/Panel/Margin/Content/ReturnButton


func _ready() -> void:
	visible = false
	title_label.text = _text("ui.aether_clash.spectator.title", "AETHER VIEW")
	hint_label.text = _text(
		"ui.aether_clash.spectator.hint",
		"Move with WASD or the arrow keys · Mouse wheel zooms · Click a Master Ball to watch its battle"
	)
	return_button.text = _text("ui.aether_clash.spectator.return", "Return to Jail")
	return_button.pressed.connect(func() -> void: return_requested.emit())


func set_camera_active(active: bool) -> void:
	visible = active


func _text(key: String, fallback: String) -> String:
	var manager := get_node_or_null("/root/LocalizationManager")
	if manager != null and manager.has_method("text"):
		var translated := str(manager.call("text", key))
		if translated != key:
			return translated
	return fallback
