extends Control
## Independent scroll regions keep results in place while editing assumptions.
var overview_scroll := ScrollContainer.new()
var inspector_scroll := ScrollContainer.new()
var navigation := HBoxContainer.new()
var results_button := Button.new()
var settings_button := Button.new()
var settings_selected := false
var compact := false
var saved_scroll := Vector2i.ZERO
var restore_frames := 3

func configure(overview: Control, inspector: Control) -> void:
	name = "CalcdexWorkspace"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true
	for scroll in [overview_scroll, inspector_scroll]:
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		add_child(scroll)
	overview_scroll.name = "ResultsScroll"
	inspector_scroll.name = "SettingsScroll"
	overview_scroll.add_child(overview)
	inspector_scroll.add_child(inspector)
	add_child(navigation)
	navigation.add_theme_constant_override("separation", 6)
	results_button.text = "Results"
	settings_button.text = "Settings"
	for button in [results_button, settings_button]:
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		navigation.add_child(button)
	results_button.pressed.connect(func(): settings_selected = false)
	settings_button.pressed.connect(func(): settings_selected = true)

func _process(_delta: float) -> void:
	var available_width := minf(size.x * get_screen_transform().x.length(), get_window().size.x)
	compact = available_width < 1500
	navigation.visible = compact
	navigation.position = Vector2.ZERO
	navigation.size = Vector2(size.x, 34)
	results_button.set_pressed_no_signal(not settings_selected)
	settings_button.set_pressed_no_signal(settings_selected)
	if compact:
		for scroll in [overview_scroll, inspector_scroll]:
			scroll.position = Vector2(0, 40)
			scroll.size = Vector2(size.x, maxf(0,size.y - 40))
		overview_scroll.visible = not settings_selected
		inspector_scroll.visible = settings_selected
	else:
		overview_scroll.show()
		inspector_scroll.show()
		var left_width := (size.x - 14) * 0.60
		overview_scroll.position = Vector2.ZERO
		overview_scroll.size = Vector2(left_width, size.y)
		inspector_scroll.position = Vector2(left_width + 14,0)
		inspector_scroll.size = Vector2(size.x - left_width - 14,size.y)
	if restore_frames > 0:
		restore_frames -= 1
		if restore_frames == 0:
			overview_scroll.scroll_vertical = saved_scroll.x
			inspector_scroll.scroll_vertical = saved_scroll.y
