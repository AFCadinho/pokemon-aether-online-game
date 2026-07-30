class_name ContentCreatorPhotoMode
extends CanvasLayer

const CAMERA_MOVE_SPEED := 360.0
const CAMERA_FAST_MOVE_MULTIPLIER := 2.25
const MIN_ZOOM := 0.75
const MAX_ZOOM := 3.0
const SCREENSHOT_DIRECTORY := "user://screenshots"
const LIGHTING_PRESET_HOURS: Array[float] = [-1.0, 6.5, 12.0, 18.5, 0.0]

@onready var controls_panel: PanelContainer = %ControlsPanel
@onready var title_label: Label = %TitleLabel
@onready var help_label: Label = %HelpLabel
@onready var hud_toggle: CheckButton = %HudToggle
@onready var controls_toggle: CheckButton = %ControlsToggle
@onready var zoom_label: Label = %ZoomLabel
@onready var zoom_slider: HSlider = %ZoomSlider
@onready var zoom_value_label: Label = %ZoomValueLabel
@onready var lighting_preset_label: Label = %LightingPresetLabel
@onready var lighting_preset_select: OptionButton = %LightingPresetSelect
@onready var exposure_label: Label = %ExposureLabel
@onready var exposure_slider: HSlider = %ExposureSlider
@onready var exposure_value_label: Label = %ExposureValueLabel
@onready var weather_effects_toggle: CheckButton = %WeatherEffectsToggle
@onready var camera_section_label: Label = %CameraSectionLabel
@onready var scene_section_label: Label = %SceneSectionLabel
@onready var capture_section_label: Label = %CaptureSectionLabel
@onready var reset_button: Button = %ResetButton
@onready var capture_button: Button = %CaptureButton
@onready var open_folder_button: Button = %OpenFolderButton
@onready var close_button: Button = %CloseButton
@onready var status_label: Label = %StatusLabel
@onready var hidden_controls_hint: Label = %HiddenControlsHint

var active := false
var camera: Camera2D
var day_night_controller: Node
var weather_controller: Node
var original_camera_position := Vector2.ZERO
var original_camera_zoom := Vector2.ONE
var hud_hidden := true
var controls_hidden := false
var screenshot_in_progress := false


func _ready() -> void:
	add_to_group("content_creator_photo_mode")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	zoom_slider.min_value = MIN_ZOOM
	zoom_slider.max_value = MAX_ZOOM
	zoom_slider.step = 0.05
	exposure_slider.min_value = 0.65
	exposure_slider.max_value = 1.4
	exposure_slider.step = 0.05
	hud_toggle.toggled.connect(_on_hud_toggled)
	controls_toggle.toggled.connect(_on_controls_toggled)
	zoom_slider.value_changed.connect(_on_zoom_changed)
	lighting_preset_select.item_selected.connect(_on_lighting_preset_selected)
	exposure_slider.value_changed.connect(_on_exposure_changed)
	weather_effects_toggle.toggled.connect(_on_weather_effects_toggled)
	reset_button.pressed.connect(reset_camera)
	capture_button.pressed.connect(capture_screenshot)
	open_folder_button.pressed.connect(open_screenshot_folder)
	close_button.pressed.connect(close_photo_mode)
	if not LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.connect(_on_locale_changed)
	_refresh_copy()


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


func _unhandled_input(event: InputEvent) -> void:
	if not active or screenshot_in_progress:
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
				zoom_slider.value = minf(zoom_slider.value + zoom_slider.step, MAX_ZOOM)
				get_viewport().set_input_as_handled()
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom_slider.value = maxf(zoom_slider.value - zoom_slider.step, MIN_ZOOM)
				get_viewport().set_input_as_handled()


func open_photo_mode() -> void:
	if active or GameState.is_overworld_input_locked():
		return
	var world := GameState.get_world()
	if world == null or bool(world.get("is_in_battle")) or bool(world.get("is_loading_map")):
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	camera = player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	day_night_controller = world.get_node_or_null("DayNightController")
	weather_controller = world.get_node_or_null("WeatherController")

	original_camera_position = camera.position
	original_camera_zoom = camera.zoom
	active = true
	visible = true
	hud_hidden = true
	controls_hidden = false
	hud_toggle.set_pressed_no_signal(true)
	controls_toggle.set_pressed_no_signal(false)
	zoom_slider.set_value_no_signal(camera.zoom.x)
	lighting_preset_select.select(0)
	exposure_slider.set_value_no_signal(1.0)
	weather_effects_toggle.set_pressed_no_signal(SettingsManager.weather_effects)
	GameState.lock_overworld_input()
	get_tree().call_group("ui_overlay", "set_content_creator_capture_hidden", true)
	_on_weather_effects_toggled(weather_effects_toggle.button_pressed)
	_apply_controls_visibility()
	_refresh_zoom_value()
	_refresh_exposure_value()
	status_label.text = LocalizationManager.text("ui.creator.photo.status_ready")


func close_photo_mode() -> void:
	if not active:
		return
	_restore_runtime_state()
	active = false
	visible = false


func reset_camera() -> void:
	if camera == null or not is_instance_valid(camera):
		return
	camera.position = original_camera_position
	camera.zoom = original_camera_zoom
	zoom_slider.set_value_no_signal(camera.zoom.x)
	_refresh_zoom_value()
	camera.reset_smoothing()
	camera.force_update_scroll()


func capture_screenshot() -> void:
	if not active or screenshot_in_progress:
		return
	screenshot_in_progress = true
	var controls_were_visible := controls_panel.visible
	var hint_was_visible := hidden_controls_hint.visible
	controls_panel.visible = false
	hidden_controls_hint.visible = false
	await RenderingServer.frame_post_draw

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
	if saved:
		status_label.text = LocalizationManager.text(
			"ui.creator.photo.status_saved",
			{"filename": screenshot_path.get_file()}
		)
	else:
		status_label.text = LocalizationManager.text("ui.creator.photo.status_failed")
	screenshot_in_progress = false


func open_screenshot_folder() -> void:
	var absolute_directory := ProjectSettings.globalize_path(SCREENSHOT_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		status_label.text = LocalizationManager.text("ui.creator.photo.folder_failed")
		return
	if OS.shell_open(absolute_directory) != OK:
		status_label.text = LocalizationManager.text("ui.creator.photo.folder_failed")


func _restore_runtime_state() -> void:
	if camera != null and is_instance_valid(camera):
		camera.position = original_camera_position
		camera.zoom = original_camera_zoom
		camera.reset_smoothing()
		camera.force_update_scroll()
	get_tree().call_group("ui_overlay", "set_content_creator_capture_hidden", false)
	if day_night_controller != null and is_instance_valid(day_night_controller):
		day_night_controller.call("clear_creator_lighting_override")
	if weather_controller != null and is_instance_valid(weather_controller):
		weather_controller.call("clear_creator_weather_effects_override")
	GameState.unlock_overworld_input()
	camera = null
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
	controls_panel.visible = not controls_hidden
	hidden_controls_hint.visible = active and controls_hidden


func _on_zoom_changed(value: float) -> void:
	if camera != null and is_instance_valid(camera):
		camera.zoom = Vector2(value, value)
		camera.force_update_scroll()
	_refresh_zoom_value()


func _on_lighting_preset_selected(_index: int) -> void:
	_apply_lighting_override()


func _on_exposure_changed(_value: float) -> void:
	_refresh_exposure_value()
	_apply_lighting_override()


func _on_weather_effects_toggled(visible: bool) -> void:
	if active and weather_controller != null and is_instance_valid(weather_controller):
		weather_controller.call("set_creator_weather_effects_visible", visible)


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
		zoom_value_label.text = "%.2fx" % zoom_slider.value


func _refresh_exposure_value() -> void:
	if exposure_value_label != null:
		exposure_value_label.text = "%d%%" % roundi(exposure_slider.value * 100.0)


func _on_locale_changed(_locale: String) -> void:
	_refresh_copy()


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
	lighting_preset_label.text = LocalizationManager.text("ui.creator.photo.lighting")
	exposure_label.text = LocalizationManager.text("ui.creator.photo.exposure")
	weather_effects_toggle.text = LocalizationManager.text("ui.creator.photo.weather_effects")
	_refresh_lighting_preset_options()
	reset_button.text = LocalizationManager.text("ui.creator.photo.reset")
	capture_button.text = LocalizationManager.text("ui.creator.photo.capture")
	open_folder_button.text = LocalizationManager.text("ui.creator.photo.open_folder")
	close_button.text = "×"
	close_button.tooltip_text = LocalizationManager.text("common.close")
	hidden_controls_hint.text = LocalizationManager.text("ui.creator.photo.hidden_hint")


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
