extends Control

signal login_submitted(username: String, password: String)

const REGISTER_URL := "https://pokeaether.com/register"
const WORLD_SCENE_PATH := "res://scenes/world.tscn"
const ONLINE_COLOR := Color(0.16, 0.94, 0.66)
const OFFLINE_COLOR := Color(1.0, 0.42, 0.42)
const CHECKING_COLOR := Color(0.847, 0.706, 0.416)
const PLAYER_PREVIEW_SCENE: PackedScene = preload("res://scenes/player.tscn")

@onready var username_input: LineEdit = $Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/FormFields/UsernameInput
@onready var password_input: LineEdit = $Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/FormFields/PasswordInput
@onready var remember_me_checkbox: CheckBox = $Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/FormFields/RememberMeCheckbox
@onready var login_button: Button = $Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/LoginButton
@onready var status_label: Label = $Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/StatusLabel
@onready var register_link_button: LinkButton = $Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/RegisterLinkButton
@onready var login_card: PanelContainer = $Background/Shell/MainSplit/LoginColumn/LoginCard
@onready var saved_session_card: PanelContainer = $Background/Shell/MainSplit/LoginColumn/SavedSessionCard
@onready var saved_display_name_label: Label = $Background/Shell/MainSplit/LoginColumn/SavedSessionCard/SavedSessionMargin/SavedSessionLayout/TrainerCard/TrainerMargin/TrainerLayout/TrainerInfoLayout/SavedDisplayNameLabel
@onready var saved_username_label: Label = $Background/Shell/MainSplit/LoginColumn/SavedSessionCard/SavedSessionMargin/SavedSessionLayout/TrainerCard/TrainerMargin/TrainerLayout/TrainerInfoLayout/SavedUsernameLabel
@onready var saved_status_label: Label = $Background/Shell/MainSplit/LoginColumn/SavedSessionCard/SavedSessionMargin/SavedSessionLayout/SavedStatusLabel
@onready var continue_button: Button = $Background/Shell/MainSplit/LoginColumn/SavedSessionCard/SavedSessionMargin/SavedSessionLayout/ContinueButton
@onready var logout_button: Button = $Background/Shell/MainSplit/LoginColumn/SavedSessionCard/SavedSessionMargin/SavedSessionLayout/LogoutButton
@onready var player_preview_viewport: SubViewport = $Background/Shell/MainSplit/LoginColumn/SavedSessionCard/SavedSessionMargin/SavedSessionLayout/TrainerCard/TrainerMargin/TrainerLayout/PlayerPreviewViewportContainer/PlayerPreviewViewport
@onready var server_status_value: Label = $Background/Shell/MainSplit/BrandPanel/BrandMargin/BrandLayout/StatusCard/StatusMargin/StatusLayout/StatusValue

var server_online := false
var is_loading := false
var player_preview_instance: Node2D

func _ready() -> void:
	login_button.pressed.connect(_on_login_button_pressed)
	register_link_button.pressed.connect(_on_register_link_pressed)
	continue_button.pressed.connect(_on_continue_button_pressed)
	logout_button.pressed.connect(_on_logout_button_pressed)
	username_input.text_submitted.connect(_on_username_submitted)
	password_input.text_submitted.connect(_on_password_submitted)
	_set_server_status_checking()
	_show_login_form()
	_setup_player_preview()
	username_input.grab_focus()
	_refresh_server_health.call_deferred()
	_restore_saved_session.call_deferred()


func set_loading(is_loading: bool) -> void:
	self.is_loading = is_loading
	username_input.editable = not is_loading
	password_input.editable = not is_loading
	remember_me_checkbox.disabled = is_loading
	login_button.disabled = is_loading
	continue_button.disabled = is_loading
	logout_button.disabled = is_loading
	login_button.text = "Signing In..." if is_loading else _get_idle_login_button_text()
	continue_button.text = "Entering..." if is_loading else "Continue"

	if is_loading:
		show_status("Connecting to Aether...", false)


func show_status(message: String, is_error: bool = false) -> void:
	status_label.text = message
	status_label.visible = not message.strip_edges().is_empty()
	if is_error:
		status_label.add_theme_color_override("font_color", OFFLINE_COLOR)
	else:
		status_label.add_theme_color_override("font_color", ONLINE_COLOR)


func show_saved_status(message: String, is_error: bool = false) -> void:
	saved_status_label.text = message
	saved_status_label.visible = not message.strip_edges().is_empty()
	if is_error:
		saved_status_label.add_theme_color_override("font_color", OFFLINE_COLOR)
	else:
		saved_status_label.add_theme_color_override("font_color", ONLINE_COLOR)


func clear_form() -> void:
	username_input.clear()
	password_input.clear()
	remember_me_checkbox.button_pressed = false
	show_status("")
	username_input.grab_focus()


func _on_username_submitted(_text: String) -> void:
	password_input.grab_focus()


func _on_password_submitted(_text: String) -> void:
	_submit_login()


func _on_login_button_pressed() -> void:
	_submit_login()


func _on_continue_button_pressed() -> void:
	if is_loading:
		return
	_enter_world()


func _on_logout_button_pressed() -> void:
	if is_loading:
		return

	set_loading(true)
	show_saved_status("Signing out...", false)
	await AuthService.logout()
	set_loading(false)

	clear_form()
	_show_login_form()


func _on_register_link_pressed() -> void:
	OS.shell_open(REGISTER_URL)


func _submit_login() -> void:
	if is_loading:
		return

	var username := username_input.text.strip_edges()
	var password := password_input.text

	if username.is_empty():
		show_status("Enter your username.", true)
		username_input.grab_focus()
		return

	if AuthService.is_authenticated() and password.is_empty():
		var current_username: String = str(AuthService.current_user.get("username", ""))
		if username == current_username:
			_enter_world()
			return

	if password.is_empty():
		show_status("Enter your password.", true)
		password_input.grab_focus()
		return

	if not server_online:
		show_status("PokeAether is currently offline. Please try again later.", true)
		_refresh_server_health.call_deferred()
		return

	show_status("")
	set_loading(true)
	var result: Dictionary = await AuthService.login(username, password, remember_me_checkbox.button_pressed)
	set_loading(false)

	if not bool(result.get("success", false)):
		show_status(_get_login_error_message(result), true)
		password_input.select_all()
		password_input.grab_focus()
		return

	var display_name: String = AuthService.get_display_name()
	if display_name != "":
		PlayerSave.player_name = display_name

	login_submitted.emit(username, password)
	_enter_world()


func _refresh_server_health() -> void:
	var result: Dictionary = await ServerHealthService.check_async(self)
	server_online = bool(result.get("online", false))
	if server_online:
		server_status_value.text = "PokeAether Online"
		server_status_value.add_theme_color_override("font_color", ONLINE_COLOR)
	else:
		server_status_value.text = "PokeAether Offline"
		server_status_value.add_theme_color_override("font_color", OFFLINE_COLOR)


func _set_server_status_checking() -> void:
	server_online = false
	server_status_value.text = "Checking server..."
	server_status_value.add_theme_color_override("font_color", CHECKING_COLOR)


func _restore_saved_session() -> void:
	var result: Dictionary = await AuthService.restore_saved_session()
	if not bool(result.get("success", false)):
		return

	var username: String = str(AuthService.current_user.get("username", ""))
	var display_name: String = AuthService.get_display_name()
	if username != "":
		username_input.text = username
	if display_name != "":
		PlayerSave.player_name = display_name

	password_input.clear()
	remember_me_checkbox.button_pressed = true
	login_button.text = _get_idle_login_button_text()
	_show_saved_session_card()


func _enter_world() -> void:
	var display_name: String = AuthService.get_display_name()
	if display_name != "":
		PlayerSave.player_name = display_name

	var error: Error = get_tree().change_scene_to_file(WORLD_SCENE_PATH)
	if error != OK:
		show_status("Could not enter the world. Please contact staff.", true)
		push_error("LoginScreen: failed to load world scene: %s" % error_string(error))


func _get_idle_login_button_text() -> String:
	return "Continue" if AuthService.is_authenticated() else "Sign In"


func _show_login_form() -> void:
	login_card.visible = true
	saved_session_card.visible = false
	show_saved_status("")
	username_input.grab_focus()


func _show_saved_session_card() -> void:
	var username: String = str(AuthService.current_user.get("username", ""))
	var display_name: String = AuthService.get_display_name()
	saved_display_name_label.text = display_name if display_name != "" else username
	saved_username_label.text = "@%s" % username if username != "" else ""
	login_card.visible = false
	saved_session_card.visible = true
	show_status("")
	show_saved_status("")
	continue_button.grab_focus()


func _setup_player_preview() -> void:
	player_preview_viewport.transparent_bg = true
	player_preview_viewport.size = Vector2i(170, 132)

	player_preview_instance = PLAYER_PREVIEW_SCENE.instantiate() as Node2D
	if player_preview_instance == null:
		return

	player_preview_viewport.add_child(player_preview_instance)
	player_preview_instance.position = Vector2(85, 100)
	player_preview_instance.scale = Vector2(2.3, 2.3)
	player_preview_instance.set_process(false)
	player_preview_instance.set_physics_process(false)
	player_preview_instance.set_process_input(false)
	player_preview_instance.set_process_unhandled_input(false)
	player_preview_instance.set_process_unhandled_key_input(false)

	if player_preview_instance.has_method("reset_movement_state"):
		player_preview_instance.call("reset_movement_state")
	player_preview_instance.set("last_direction", Vector2.DOWN)
	if player_preview_instance.has_method("set_idle_frame"):
		player_preview_instance.call("set_idle_frame")


func _get_login_error_message(result: Dictionary) -> String:
	var status: int = int(result.get("status", 0))
	if status == 401:
		return "Invalid username or password."
	if status >= 500:
		return "PokeAether is currently unavailable. Please try again later."
	return str(result.get("error", "Could not sign in. Please try again."))
