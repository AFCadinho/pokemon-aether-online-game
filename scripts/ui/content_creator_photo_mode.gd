class_name ContentCreatorPhotoMode
extends CanvasLayer

const ArenaCameraPolicy := preload("res://scripts/services/aether_clash_camera_policy.gd")

const DROPDOWN_ARROW: Texture2D = preload("res://assets/ui/photo_mode_dropdown_arrow.svg")
const DROPDOWN_RADIO_CHECKED: Texture2D = preload("res://assets/ui/photo_mode_radio_checked.svg")
const DROPDOWN_RADIO_UNCHECKED: Texture2D = preload("res://assets/ui/photo_mode_radio_unchecked.svg")
const PhotoZoom := preload("res://scripts/ui/content_creator_photo_zoom.gd")
const CAMERA_MOVE_SPEED := 360.0
const CAMERA_FAST_MOVE_MULTIPLIER := 2.25
const MIN_ZOOM_FACTOR := PhotoZoom.MIN_FACTOR
const MAX_ZOOM_FACTOR := PhotoZoom.MAX_FACTOR
const DEFAULT_ZOOM_FACTOR := PhotoZoom.DEFAULT_FACTOR
const SCREENSHOT_DIRECTORY := "user://screenshots"
const LIGHTING_PRESET_HOURS: Array[float] = [-1.0, 6.5, 12.0, 18.5, 0.0]
const PLAYER_DIRECTIONS: Array[Vector2] = [
	Vector2.ZERO,
	Vector2.DOWN,
	Vector2.LEFT,
	Vector2.RIGHT,
	Vector2.UP,
]
const CAPTURE_TIMER_SECONDS: Array[int] = [0, 3, 5, 10]
const PANEL_VIEWPORT_MARGIN := 12.0
const MOUSE_WHEEL_ZOOM_STEP := 0.15

@onready var composition_grid: Control = %CompositionGrid
@onready var countdown_label: Label = %CountdownLabel
@onready var controls_panel: PanelContainer = %ControlsPanel
@onready var header_row: HBoxContainer = %HeaderRow
@onready var title_label: Label = %TitleLabel
@onready var help_label: Label = %HelpLabel
@onready var hud_toggle: CheckButton = %HudToggle
@onready var controls_toggle: CheckButton = %ControlsToggle
@onready var zoom_label: Label = %ZoomLabel
@onready var zoom_slider: HSlider = %ZoomSlider
@onready var zoom_value_label: Label = %ZoomValueLabel
@onready var direction_label: Label = %DirectionLabel
@onready var direction_select: OptionButton = %DirectionSelect
@onready var lighting_preset_label: Label = %LightingPresetLabel
@onready var lighting_preset_select: OptionButton = %LightingPresetSelect
@onready var exposure_label: Label = %ExposureLabel
@onready var exposure_slider: HSlider = %ExposureSlider
@onready var exposure_value_label: Label = %ExposureValueLabel
@onready var weather_effects_toggle: CheckButton = %WeatherEffectsToggle
@onready var other_players_toggle: CheckButton = %OtherPlayersToggle
@onready var nameplates_toggle: CheckButton = %NameplatesToggle
@onready var camera_section_label: Label = %CameraSectionLabel
@onready var scene_section_label: Label = %SceneSectionLabel
@onready var capture_section_label: Label = %CaptureSectionLabel
@onready var reset_button: Button = %ResetButton
@onready var composition_grid_toggle: CheckButton = %CompositionGridToggle
@onready var timer_label: Label = %TimerLabel
@onready var timer_select: OptionButton = %TimerSelect
@onready var capture_button: Button = %CaptureButton
@onready var open_folder_button: Button = %OpenFolderButton
@onready var close_button: Button = %CloseButton
@onready var status_label: Label = %StatusLabel
@onready var hidden_controls_hint: Label = %HiddenControlsHint

var active := false
var camera: Camera2D
var photo_player: Node2D
var day_night_controller: Node
var weather_controller: Node
var original_camera_position := Vector2.ZERO
var original_camera_zoom := Vector2.ONE
var current_zoom_factor := DEFAULT_ZOOM_FACTOR
var original_player_direction := Vector2.DOWN
var hud_hidden := true
var controls_hidden := false
var screenshot_in_progress := false
var controls_panel_dragging := false
var camera_mouse_panning := false
var capture_sequence := 0


func _ready() -> void:
	add_to_group("content_creator_photo_mode")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	zoom_slider.min_value = MIN_ZOOM_FACTOR
	zoom_slider.max_value = MAX_ZOOM_FACTOR
	zoom_slider.step = 0.05
	exposure_slider.min_value = 0.65
	exposure_slider.max_value = 1.4
	exposure_slider.step = 0.05
	for select: OptionButton in [direction_select, lighting_preset_select, timer_select]:
		_apply_dropdown_style(select)
	hud_toggle.toggled.connect(_on_hud_toggled)
	controls_toggle.toggled.connect(_on_controls_toggled)
	zoom_slider.value_changed.connect(_on_zoom_changed)
	direction_select.item_selected.connect(_on_direction_selected)
	lighting_preset_select.item_selected.connect(_on_lighting_preset_selected)
	exposure_slider.value_changed.connect(_on_exposure_changed)
	weather_effects_toggle.toggled.connect(_on_weather_effects_toggled)
	other_players_toggle.toggled.connect(_on_other_players_toggled)
	nameplates_toggle.toggled.connect(_on_nameplates_toggled)
	composition_grid_toggle.toggled.connect(_on_composition_grid_toggled)
	reset_button.pressed.connect(reset_camera)
	capture_button.pressed.connect(capture_screenshot)
	open_folder_button.pressed.connect(open_screenshot_folder)
	close_button.pressed.connect(close_photo_mode)
	header_row.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header_row.gui_input.connect(_on_drag_handle_gui_input)
	get_viewport().size_changed.connect(_clamp_controls_panel_to_viewport)
	if not LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.connect(_on_locale_changed)
	_refresh_copy()
	_fit_controls_panel_to_content.call_deferred()


func _exit_tree() -> void:
	if active:
		_restore_runtime_state()


func _process(delta: float) -> void:
	if not active or screenshot_in_progress or camera == null or not is_instance_valid(camera):
		return

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction == Vector2.ZERO:
		return
	var speed := CAMERA_MOVE_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= CAMERA_FAST_MOVE_MULTIPLIER
	camera.position += direction * speed * delta / maxf(camera.zoom.x, 0.01)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if (
			controls_panel_dragging
			and mouse_event.button_index == MOUSE_BUTTON_LEFT
			and not mouse_event.pressed
		):
			controls_panel_dragging = false
			get_viewport().set_input_as_handled()
			return
		if not active or screenshot_in_progress:
			return
		if mouse_event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if not mouse_event.pressed:
				if camera_mouse_panning:
					camera_mouse_panning = false
					get_viewport().set_input_as_handled()
				return
			if not _pointer_over_controls(mouse_event.position):
				camera_mouse_panning = true
				get_viewport().set_input_as_handled()
			return
		if mouse_event.pressed and not _pointer_over_controls(mouse_event.position):
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_set_zoom_from_pointer(zoom_slider.value + MOUSE_WHEEL_ZOOM_STEP)
				get_viewport().set_input_as_handled()
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_set_zoom_from_pointer(zoom_slider.value - MOUSE_WHEEL_ZOOM_STEP)
				get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if controls_panel_dragging:
			if mouse_motion.button_mask & MOUSE_BUTTON_MASK_LEFT == 0:
				controls_panel_dragging = false
				return
			controls_panel.position += mouse_motion.relative
			_clamp_controls_panel_to_viewport()
			get_viewport().set_input_as_handled()
		elif (
			camera_mouse_panning
			and active
			and not screenshot_in_progress
			and camera != null
			and is_instance_valid(camera)
		):
			var pan_button_mask := MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE
			if mouse_motion.button_mask & pan_button_mask == 0:
				camera_mouse_panning = false
				return
			camera.position -= mouse_motion.relative / maxf(camera.zoom.x, 0.01)
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if screenshot_in_progress:
		var countdown_key := event as InputEventKey
		if (
			countdown_label.visible
			and countdown_key != null
			and countdown_key.pressed
			and not countdown_key.echo
			and countdown_key.keycode == KEY_ESCAPE
		):
			close_photo_mode()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		match key_event.keycode:
			KEY_ESCAPE:
				close_photo_mode()
				get_viewport().set_input_as_handled()
			KEY_H:
				controls_toggle.set_pressed(not controls_hidden)
				get_viewport().set_input_as_handled()
			KEY_F12:
				capture_screenshot()
				get_viewport().set_input_as_handled()
			KEY_R:
				reset_camera()
				get_viewport().set_input_as_handled()
			KEY_EQUAL, KEY_KP_ADD:
				zoom_slider.value = minf(zoom_slider.value + zoom_slider.step, MAX_ZOOM_FACTOR)
				get_viewport().set_input_as_handled()
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom_slider.value = maxf(zoom_slider.value - zoom_slider.step, MIN_ZOOM_FACTOR)
				get_viewport().set_input_as_handled()


func open_photo_mode() -> void:
	if active or GameState.is_overworld_input_locked() or ArenaCameraPolicy.is_locked(get_tree()):
		return
	var world := GameState.get_world()
	if world == null or bool(world.get("is_in_battle")) or bool(world.get("is_loading_map")):
		return
	photo_player = get_tree().get_first_node_in_group("player") as Node2D
	if photo_player == null:
		return
	camera = photo_player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		photo_player = null
		return
	day_night_controller = world.get_node_or_null("DayNightController")
	weather_controller = world.get_node_or_null("WeatherController")

	original_camera_position = camera.position
	original_camera_zoom = camera.zoom
	var player_direction_value: Variant = photo_player.get("last_direction")
	original_player_direction = (
		player_direction_value as Vector2
		if player_direction_value is Vector2
		else Vector2.DOWN
	)
	active = true
	visible = true
	current_zoom_factor = DEFAULT_ZOOM_FACTOR
	hud_hidden = true
	controls_hidden = false
	hud_toggle.set_pressed_no_signal(true)
	controls_toggle.set_pressed_no_signal(false)
	zoom_slider.set_value_no_signal(current_zoom_factor)
	direction_select.select(0)
	lighting_preset_select.select(0)
	exposure_slider.set_value_no_signal(1.0)
	weather_effects_toggle.set_pressed_no_signal(SettingsManager.weather_effects)
	other_players_toggle.set_pressed_no_signal(false)
	nameplates_toggle.set_pressed_no_signal(false)
	composition_grid_toggle.set_pressed_no_signal(false)
	composition_grid.visible = false
	countdown_label.visible = false
	capture_button.disabled = false
	screenshot_in_progress = false
	GameState.lock_overworld_input()
	get_tree().call_group("ui_overlay", "set_content_creator_capture_hidden", true)
	_clamp_controls_panel_to_viewport()
	_on_weather_effects_toggled(weather_effects_toggle.button_pressed)
	_on_other_players_toggled(other_players_toggle.button_pressed)
	_on_nameplates_toggled(nameplates_toggle.button_pressed)
	_apply_controls_visibility()
	_refresh_zoom_value()
	_refresh_exposure_value()
	status_label.text = LocalizationManager.text("ui.creator.photo.status_ready")
	_fit_controls_panel_to_content.call_deferred()


func close_photo_mode() -> void:
	if not active:
		return
	capture_sequence += 1
	screenshot_in_progress = false
	capture_button.disabled = false
	countdown_label.visible = false
	composition_grid.visible = false
	controls_panel_dragging = false
	camera_mouse_panning = false
	_restore_runtime_state()
	active = false
	visible = false


func reset_camera() -> void:
	if camera == null or not is_instance_valid(camera):
		return
	camera.position = original_camera_position
	current_zoom_factor = DEFAULT_ZOOM_FACTOR
	camera.zoom = resolve_zoom_for_baseline(original_camera_zoom, current_zoom_factor)
	zoom_slider.set_value_no_signal(current_zoom_factor)
	_refresh_zoom_value()
	camera.reset_smoothing()
	camera.force_update_scroll()


func capture_screenshot() -> void:
	if not active or screenshot_in_progress:
		return
	screenshot_in_progress = true
	capture_button.disabled = true
	camera_mouse_panning = false
	capture_sequence += 1
	var current_capture_sequence := capture_sequence
	var timer_index := clampi(timer_select.selected, 0, CAPTURE_TIMER_SECONDS.size() - 1)
	var delay_seconds := CAPTURE_TIMER_SECONDS[timer_index]
	for remaining: int in range(delay_seconds, 0, -1):
		countdown_label.text = str(remaining)
		countdown_label.visible = true
		await get_tree().create_timer(1.0).timeout
		if not active or current_capture_sequence != capture_sequence:
			return
	countdown_label.visible = false

	var controls_were_visible := controls_panel.visible
	var hint_was_visible := hidden_controls_hint.visible
	var grid_was_visible := composition_grid.visible
	controls_panel.visible = false
	hidden_controls_hint.visible = false
	composition_grid.visible = false
	await RenderingServer.frame_post_draw
	if not active or current_capture_sequence != capture_sequence:
		return

	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(SCREENSHOT_DIRECTORY)
	)
	var saved := false
	var screenshot_path := ""
	if directory_error == OK or directory_error == ERR_ALREADY_EXISTS:
		var timestamp := Time.get_datetime_string_from_system(false, true)
		timestamp = "%s_%03d" % [
			timestamp.replace(":", "-").replace(" ", "_"),
			Time.get_ticks_msec() % 1000,
		]
		screenshot_path = "%s/pokeaether_%s.png" % [SCREENSHOT_DIRECTORY, timestamp]
		var image := get_viewport().get_texture().get_image()
		saved = image != null and image.save_png(screenshot_path) == OK

	controls_panel.visible = controls_were_visible
	hidden_controls_hint.visible = hint_was_visible
	composition_grid.visible = grid_was_visible
	if saved:
		status_label.text = LocalizationManager.text(
			"ui.creator.photo.status_saved",
			{"filename": screenshot_path.get_file()}
		)
	else:
		status_label.text = LocalizationManager.text("ui.creator.photo.status_failed")
	screenshot_in_progress = false
	capture_button.disabled = false
	_fit_controls_panel_to_content.call_deferred()


func open_screenshot_folder() -> void:
	var absolute_directory := ProjectSettings.globalize_path(SCREENSHOT_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		status_label.text = LocalizationManager.text("ui.creator.photo.folder_failed")
		_fit_controls_panel_to_content.call_deferred()
		return
	if OS.shell_open(absolute_directory) != OK:
		status_label.text = LocalizationManager.text("ui.creator.photo.folder_failed")
		_fit_controls_panel_to_content.call_deferred()


func _restore_runtime_state() -> void:
	if camera != null and is_instance_valid(camera):
		camera.position = original_camera_position
		camera.zoom = original_camera_zoom
		camera.reset_smoothing()
		camera.force_update_scroll()
	if photo_player != null and is_instance_valid(photo_player):
		_face_player_direction(original_player_direction)
	get_tree().call_group("ui_overlay", "set_content_creator_capture_hidden", false)
	if day_night_controller != null and is_instance_valid(day_night_controller):
		day_night_controller.call("clear_creator_lighting_override")
	if weather_controller != null and is_instance_valid(weather_controller):
		weather_controller.call("clear_creator_weather_effects_override")
	var world := GameState.get_world()
	if world != null:
		world.call("clear_creator_remote_players_visibility_override")
		world.call("clear_creator_nameplates_visibility_override")
	GameState.unlock_overworld_input()
	camera = null
	photo_player = null
	day_night_controller = null
	weather_controller = null


func _on_hud_toggled(pressed: bool) -> void:
	hud_hidden = pressed
	if active:
		get_tree().call_group("ui_overlay", "set_content_creator_capture_hidden", hud_hidden)


func _on_controls_toggled(pressed: bool) -> void:
	controls_hidden = pressed
	_apply_controls_visibility()


func _apply_controls_visibility() -> void:
	if controls_hidden:
		controls_panel_dragging = false
	controls_panel.visible = not controls_hidden
	hidden_controls_hint.visible = active and controls_hidden


func _on_drag_handle_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	controls_panel_dragging = mouse_event.pressed
	if controls_panel_dragging:
		camera_mouse_panning = false
	controls_panel.accept_event()


func _clamp_controls_panel_to_viewport() -> void:
	if controls_panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var max_position := Vector2(
		maxf(PANEL_VIEWPORT_MARGIN, viewport_size.x - controls_panel.size.x - PANEL_VIEWPORT_MARGIN),
		maxf(PANEL_VIEWPORT_MARGIN, viewport_size.y - controls_panel.size.y - PANEL_VIEWPORT_MARGIN)
	)
	controls_panel.position = Vector2(
		clampf(controls_panel.position.x, PANEL_VIEWPORT_MARGIN, max_position.x),
		clampf(controls_panel.position.y, PANEL_VIEWPORT_MARGIN, max_position.y)
	)


func _fit_controls_panel_to_content() -> void:
	if controls_panel == null:
		return
	controls_panel.size = controls_panel.get_combined_minimum_size()
	_clamp_controls_panel_to_viewport()


func _apply_dropdown_style(select: OptionButton) -> void:
	if select == null:
		return
	select.custom_minimum_size.y = maxf(select.custom_minimum_size.y, 32.0)
	select.focus_mode = Control.FOCUS_NONE
	select.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	select.alignment = HORIZONTAL_ALIGNMENT_LEFT
	select.add_theme_font_size_override("font_size", 13)
	select.add_theme_color_override("font_color", Color("#d8e9f4"))
	select.add_theme_color_override("font_hover_color", Color("#f4fbff"))
	select.add_theme_color_override("font_pressed_color", Color("#f4fbff"))
	select.add_theme_color_override("font_focus_color", Color("#f4fbff"))
	select.add_theme_color_override("font_disabled_color", Color("#718899"))
	select.add_theme_constant_override("arrow_margin", 11)
	select.add_theme_icon_override("arrow", DROPDOWN_ARROW)
	select.add_theme_stylebox_override(
		"normal",
		_dropdown_button_style(Color("#071725f2"), Color("#294b61cc"))
	)
	select.add_theme_stylebox_override(
		"hover",
		_dropdown_button_style(Color("#0b2438f7"), Color("#4e9bc2e6"))
	)
	select.add_theme_stylebox_override(
		"pressed",
		_dropdown_button_style(Color("#0d2c43fa"), Color("#8edfff"))
	)
	select.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	select.add_theme_stylebox_override(
		"disabled",
		_dropdown_button_style(Color("#07111bc4"), Color("#263b4999"))
	)

	var popup := select.get_popup()
	popup.transparent_bg = true
	popup.borderless = true
	popup.add_theme_font_size_override("font_size", 13)
	popup.add_theme_color_override("font_color", Color("#c8dce8"))
	popup.add_theme_color_override("font_hover_color", Color("#ffffff"))
	popup.add_theme_color_override("font_disabled_color", Color("#657b8b"))
	popup.add_theme_color_override("font_separator_color", Color("#70cdef"))
	popup.add_theme_color_override("font_outline_color", Color("#02070b"))
	popup.add_theme_constant_override("outline_size", 1)
	popup.add_theme_constant_override("item_start_padding", 10)
	popup.add_theme_constant_override("item_end_padding", 12)
	popup.add_theme_constant_override("v_separation", 6)
	popup.add_theme_stylebox_override("panel", _dropdown_popup_style())
	popup.add_theme_stylebox_override(
		"hover",
		_dropdown_popup_item_style(Color("#12344cf7"), Color("#63bfe6"))
	)
	popup.add_theme_stylebox_override(
		"separator",
		_dropdown_popup_item_style(Color("#00000000"), Color("#31566b88"), 0)
	)
	popup.add_theme_icon_override("radio_checked", DROPDOWN_RADIO_CHECKED)
	popup.add_theme_icon_override("radio_unchecked", DROPDOWN_RADIO_UNCHECKED)
	popup.add_theme_icon_override("radio_checked_disabled", DROPDOWN_RADIO_CHECKED)
	popup.add_theme_icon_override("radio_unchecked_disabled", DROPDOWN_RADIO_UNCHECKED)


func _dropdown_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 10
	style.content_margin_top = 5
	style.content_margin_right = 10
	style.content_margin_bottom = 5
	return style


func _dropdown_popup_style() -> StyleBoxFlat:
	var style := _dropdown_popup_item_style(Color("#050e18fc"), Color("#4e8caae6"), 9)
	style.content_margin_left = 5
	style.content_margin_top = 6
	style.content_margin_right = 5
	style.content_margin_bottom = 6
	style.shadow_color = Color("#00000099")
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 6)
	return style


func _dropdown_popup_item_style(
	background: Color,
	border: Color,
	radius: int = 6
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8
	style.content_margin_top = 5
	style.content_margin_right = 8
	style.content_margin_bottom = 5
	return style


func _on_zoom_changed(value: float) -> void:
	current_zoom_factor = clamp_zoom_factor(value)
	if camera != null and is_instance_valid(camera):
		camera.zoom = resolve_zoom_for_baseline(original_camera_zoom, current_zoom_factor)
		camera.force_update_scroll()
	_refresh_zoom_value()


func _set_zoom_from_pointer(value: float) -> void:
	zoom_slider.value = clamp_zoom_factor(value)


func apply_camera_baseline_zoom(target_camera: Camera2D, baseline_zoom: Vector2) -> bool:
	if (
		not active
		or camera == null
		or not is_instance_valid(camera)
		or camera != target_camera
		or baseline_zoom.x <= 0.0
		or baseline_zoom.y <= 0.0
	):
		return false
	original_camera_zoom = baseline_zoom
	camera.zoom = resolve_zoom_for_baseline(original_camera_zoom, current_zoom_factor)
	camera.reset_smoothing()
	camera.force_update_scroll()
	return true


static func clamp_zoom_factor(value: float) -> float:
	return PhotoZoom.clamp_factor(value)


static func resolve_zoom_for_baseline(baseline_zoom: Vector2, factor: float) -> Vector2:
	return PhotoZoom.resolve_zoom(baseline_zoom, factor)


func _pointer_over_controls(pointer_position: Vector2) -> bool:
	return controls_panel.visible and controls_panel.get_global_rect().has_point(pointer_position)


func _on_direction_selected(index: int) -> void:
	if index < 0 or index >= PLAYER_DIRECTIONS.size():
		return
	_face_player_direction(
		original_player_direction
		if index == 0
		else PLAYER_DIRECTIONS[index]
	)


func _face_player_direction(direction: Vector2) -> void:
	if photo_player == null or not is_instance_valid(photo_player) or direction == Vector2.ZERO:
		return
	photo_player.call("face_world_position", photo_player.global_position + direction * 32.0)


func _on_lighting_preset_selected(_index: int) -> void:
	_apply_lighting_override()


func _on_exposure_changed(_value: float) -> void:
	_refresh_exposure_value()
	_apply_lighting_override()


func _on_weather_effects_toggled(visible: bool) -> void:
	if active and weather_controller != null and is_instance_valid(weather_controller):
		weather_controller.call("set_creator_weather_effects_visible", visible)


func _on_other_players_toggled(visible: bool) -> void:
	if not active:
		return
	var world := GameState.get_world()
	if world != null:
		world.call("set_creator_remote_players_visible", visible)


func _on_nameplates_toggled(visible: bool) -> void:
	if not active:
		return
	var world := GameState.get_world()
	if world != null:
		world.call("set_creator_nameplates_visible", visible)


func _on_composition_grid_toggled(visible: bool) -> void:
	composition_grid.visible = active and visible


func _apply_lighting_override() -> void:
	if not active or day_night_controller == null or not is_instance_valid(day_night_controller):
		return
	var preset_index := clampi(lighting_preset_select.selected, 0, LIGHTING_PRESET_HOURS.size() - 1)
	var selected_hour := LIGHTING_PRESET_HOURS[preset_index]
	var exposure := float(exposure_slider.value)
	if selected_hour < 0.0 and is_equal_approx(exposure, 1.0):
		day_night_controller.call("clear_creator_lighting_override")
		return
	day_night_controller.call("set_creator_lighting_override", selected_hour, exposure)


func _refresh_zoom_value() -> void:
	if zoom_value_label != null:
		zoom_value_label.text = "%.2fx" % current_zoom_factor


func _refresh_exposure_value() -> void:
	if exposure_value_label != null:
		exposure_value_label.text = "%d%%" % roundi(exposure_slider.value * 100.0)


func _on_locale_changed(_locale: String) -> void:
	_refresh_copy()
	_fit_controls_panel_to_content.call_deferred()


func _refresh_copy() -> void:
	if title_label == null:
		return
	title_label.text = LocalizationManager.text("ui.creator.photo.title")
	help_label.text = LocalizationManager.text("ui.creator.photo.help")
	camera_section_label.text = LocalizationManager.text("ui.creator.photo.section.camera")
	scene_section_label.text = LocalizationManager.text("ui.creator.photo.section.scene")
	capture_section_label.text = LocalizationManager.text("ui.creator.photo.section.capture")
	hud_toggle.text = LocalizationManager.text("ui.creator.photo.hide_hud")
	controls_toggle.text = LocalizationManager.text("ui.creator.photo.hide_controls")
	zoom_label.text = LocalizationManager.text("ui.creator.photo.zoom")
	direction_label.text = LocalizationManager.text("ui.creator.photo.direction")
	lighting_preset_label.text = LocalizationManager.text("ui.creator.photo.lighting")
	exposure_label.text = LocalizationManager.text("ui.creator.photo.exposure")
	weather_effects_toggle.text = LocalizationManager.text("ui.creator.photo.weather_effects")
	other_players_toggle.text = LocalizationManager.text("ui.creator.photo.other_players")
	nameplates_toggle.text = LocalizationManager.text("ui.creator.photo.nameplates")
	composition_grid_toggle.text = LocalizationManager.text("ui.creator.photo.composition_grid")
	timer_label.text = LocalizationManager.text("ui.creator.photo.timer")
	_refresh_direction_options()
	_refresh_timer_options()
	_refresh_lighting_preset_options()
	reset_button.text = LocalizationManager.text("ui.creator.photo.reset")
	capture_button.text = LocalizationManager.text("ui.creator.photo.capture")
	open_folder_button.text = LocalizationManager.text("ui.creator.photo.open_folder")
	close_button.text = "×"
	close_button.tooltip_text = LocalizationManager.text("common.close")
	hidden_controls_hint.text = LocalizationManager.text("ui.creator.photo.hidden_hint")
	header_row.tooltip_text = LocalizationManager.text("ui.creator.photo.tooltip.drag_panel")
	zoom_slider.tooltip_text = LocalizationManager.text("ui.creator.photo.tooltip.zoom")
	direction_select.tooltip_text = LocalizationManager.text("ui.creator.photo.tooltip.direction")
	reset_button.tooltip_text = LocalizationManager.text("ui.creator.photo.tooltip.reset")
	lighting_preset_select.tooltip_text = LocalizationManager.text("ui.creator.photo.tooltip.lighting")
	exposure_slider.tooltip_text = LocalizationManager.text("ui.creator.photo.tooltip.exposure")
	weather_effects_toggle.tooltip_text = LocalizationManager.text("ui.creator.photo.tooltip.weather")
	other_players_toggle.tooltip_text = LocalizationManager.text("ui.creator.photo.tooltip.other_players")
	nameplates_toggle.tooltip_text = LocalizationManager.text("ui.creator.photo.tooltip.nameplates")
	hud_toggle.tooltip_text = LocalizationManager.text("ui.creator.photo.tooltip.hud")
	controls_toggle.tooltip_text = LocalizationManager.text("ui.creator.photo.tooltip.controls")
	composition_grid_toggle.tooltip_text = LocalizationManager.text("ui.creator.photo.tooltip.grid")
	timer_select.tooltip_text = LocalizationManager.text("ui.creator.photo.tooltip.timer")
	capture_button.tooltip_text = LocalizationManager.text("ui.creator.photo.tooltip.capture")
	open_folder_button.tooltip_text = LocalizationManager.text("ui.creator.photo.tooltip.folder")


func _refresh_direction_options() -> void:
	if direction_select == null:
		return
	var selected_index := maxi(direction_select.selected, 0)
	direction_select.clear()
	for key: String in [
		"ui.creator.photo.direction.current",
		"ui.creator.photo.direction.down",
		"ui.creator.photo.direction.left",
		"ui.creator.photo.direction.right",
		"ui.creator.photo.direction.up",
	]:
		direction_select.add_item(LocalizationManager.text(key))
	direction_select.select(clampi(selected_index, 0, direction_select.item_count - 1))


func _refresh_timer_options() -> void:
	if timer_select == null:
		return
	var selected_index := maxi(timer_select.selected, 0)
	timer_select.clear()
	timer_select.add_item(LocalizationManager.text("ui.creator.photo.timer.off"))
	for seconds: int in CAPTURE_TIMER_SECONDS.slice(1):
		timer_select.add_item(
			LocalizationManager.text(
				"ui.creator.photo.timer.seconds",
				{"seconds": seconds}
			)
		)
	timer_select.select(clampi(selected_index, 0, timer_select.item_count - 1))


func _refresh_lighting_preset_options() -> void:
	if lighting_preset_select == null:
		return
	var selected_index := maxi(lighting_preset_select.selected, 0)
	lighting_preset_select.clear()
	for key: String in [
		"ui.creator.photo.lighting.current",
		"ui.creator.photo.lighting.dawn",
		"ui.creator.photo.lighting.day",
		"ui.creator.photo.lighting.golden_hour",
		"ui.creator.photo.lighting.night",
	]:
		lighting_preset_select.add_item(LocalizationManager.text(key))
	lighting_preset_select.select(clampi(selected_index, 0, lighting_preset_select.item_count - 1))
