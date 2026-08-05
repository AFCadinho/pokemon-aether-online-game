extends CanvasLayer

var panel: PanelContainer
var label: Label
var current_state: Dictionary = {}
var jail_deadline := 0.0


func _ready() -> void:
	layer = 90
	_build_hud()
	ThievingService.state_changed.connect(_on_state_changed)
	LocalizationManager.locale_changed.connect(_on_locale_changed)
	set_process(true)


func _process(_delta: float) -> void:
	if panel == null or not bool(current_state.get("jailed", false)):
		return
	var seconds := maxi(ceili(jail_deadline - Time.get_unix_time_from_system()), 0)
	label.text = LocalizationManager.text("ui.thieving.jailed", {"seconds": seconds})


func _build_hud() -> void:
	panel = PanelContainer.new()
	panel.name = "ThievingStatusPanel"
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-210.0, 18.0)
	panel.custom_minimum_size = Vector2(420.0, 38.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#071522e8")
	style.border_color = Color("#d0a83b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("#f6e5a8"))
	panel.add_child(label)


func _on_state_changed(state: Dictionary) -> void:
	current_state = state.duplicate(true)
	if bool(current_state.get("jailed", false)):
		jail_deadline = Time.get_unix_time_from_system() + float(current_state.get("jailRemainingSeconds", 0))
	_refresh()


func _on_locale_changed(_locale: String) -> void:
	_refresh()


func _refresh() -> void:
	if panel == null:
		return
	var currency := maxi(int(current_state.get("currency", 0)), 0)
	var wanted := clampi(int(current_state.get("wanted", 0)), 0, 100)
	var jailed := bool(current_state.get("jailed", false))
	panel.visible = jailed or currency > 0 or wanted > 0
	if jailed:
		return
	if wanted >= 100:
		label.text = LocalizationManager.text("ui.thieving.most_wanted", {"currency": currency})
		label.add_theme_color_override("font_color", Color("#ff7878"))
		return
	label.add_theme_color_override("font_color", Color("#f6e5a8"))
	label.text = LocalizationManager.text("ui.thieving.status", {
		"level": maxi(int(current_state.get("level", 1)), 1),
		"currency": currency,
		"wanted": wanted,
	})
