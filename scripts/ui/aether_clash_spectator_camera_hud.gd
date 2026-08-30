extends CanvasLayer

class_name AetherClashSpectatorCameraHud

signal return_requested
signal region_requested(region_id: String)
signal zoom_requested(value: float)

@onready var title_label: Label = $Root/Panel/Margin/Content/Copy/Title
@onready var hint_label: Label = $Root/Panel/Margin/Content/Copy/Hint
@onready var navigation_label: Label = $Root/Panel/Margin/Content/Navigation/Label
@onready var zoom_label: Label = $Root/Panel/Margin/Content/Copy/ZoomRow/Label
@onready var zoom_slider: HSlider = $Root/Panel/Margin/Content/Copy/ZoomRow/Slider
@onready var zoom_value_label: Label = $Root/Panel/Margin/Content/Copy/ZoomRow/Value
@onready var return_button: Button = $Root/Panel/Margin/Content/ReturnButton

const REGION_BUTTONS := {
	"north_west": "Root/Panel/Margin/Content/Navigation/Grid/NorthWest",
	"north": "Root/Panel/Margin/Content/Navigation/Grid/North",
	"north_east": "Root/Panel/Margin/Content/Navigation/Grid/NorthEast",
	"west": "Root/Panel/Margin/Content/Navigation/Grid/West",
	"center": "Root/Panel/Margin/Content/Navigation/Grid/Center",
	"east": "Root/Panel/Margin/Content/Navigation/Grid/East",
	"south_west": "Root/Panel/Margin/Content/Navigation/Grid/SouthWest",
	"south": "Root/Panel/Margin/Content/Navigation/Grid/South",
	"south_east": "Root/Panel/Margin/Content/Navigation/Grid/SouthEast",
}

const REGION_LABELS := {
	"north_west": ["ui.aether_clash.spectator.north_west", "North West"],
	"north": ["ui.aether_clash.spectator.north", "North"],
	"north_east": ["ui.aether_clash.spectator.north_east", "North East"],
	"west": ["ui.aether_clash.spectator.west", "West"],
	"center": ["ui.aether_clash.spectator.center", "Center"],
	"east": ["ui.aether_clash.spectator.east", "East"],
	"south_west": ["ui.aether_clash.spectator.south_west", "South West"],
	"south": ["ui.aether_clash.spectator.south", "South"],
	"south_east": ["ui.aether_clash.spectator.south_east", "South East"],
}


func _ready() -> void:
	visible = false
	title_label.text = _text("ui.aether_clash.spectator.title", "AETHER VIEW")
	hint_label.text = _text(
		"ui.aether_clash.spectator.hint",
		"Hold and drag to look around · Click a Master Ball to watch its battle"
	)
	navigation_label.text = _text("ui.aether_clash.spectator.jump_to", "Jump to")
	zoom_label.text = _text("ui.aether_clash.spectator.zoom", "Zoom")
	return_button.text = _text("ui.aether_clash.spectator.return", "Return to Jail")
	return_button.pressed.connect(func() -> void: return_requested.emit())
	return_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	zoom_slider.value_changed.connect(_on_zoom_value_changed)
	for region_id: String in REGION_BUTTONS:
		var button := get_node_or_null(str(REGION_BUTTONS[region_id])) as Button
		if button == null:
			continue
		var label_parts: Array = REGION_LABELS[region_id]
		button.text = _text(str(label_parts[0]), str(label_parts[1]))
		button.tooltip_text = button.text
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_on_region_button_pressed.bind(region_id))
	set_zoom_value(float(zoom_slider.value))


func set_camera_active(active: bool) -> void:
	visible = active


func set_zoom_value(value: float) -> void:
	if zoom_slider == null:
		return
	zoom_slider.set_value_no_signal(value)
	zoom_value_label.text = "%.2fx" % value


func _on_zoom_value_changed(value: float) -> void:
	zoom_value_label.text = "%.2fx" % value
	zoom_requested.emit(value)


func _on_region_button_pressed(region_id: String) -> void:
	region_requested.emit(region_id)


func _text(key: String, fallback: String) -> String:
	var manager := get_node_or_null("/root/LocalizationManager")
	if manager != null and manager.has_method("text"):
		var translated := str(manager.call("text", key))
		if translated != key:
			return translated
	return fallback
