extends Control

signal login_submitted(username: String, password: String)

const REGISTER_URL := "https://pokeaether.com/register"
const WORLD_SCENE_PATH := "res://scenes/world.tscn"
const ONLINE_COLOR := Color(0.16, 0.94, 0.66)
const OFFLINE_COLOR := Color(1.0, 0.42, 0.42)
const CHECKING_COLOR := Color(0.847, 0.706, 0.416)

@onready var username_input: LineEdit = $Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/FormFields/UsernameInput
@onready var password_input: LineEdit = $Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/FormFields/PasswordInput
@onready var remember_me_checkbox: CheckBox = $Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/FormFields/RememberMeCheckbox
@onready var login_button: Button = $Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/LoginButton
@onready var status_label: Label = $Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/StatusLabel
@onready var register_link_button: LinkButton = $Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/RegisterLinkButton
@onready var server_status_value: Label = $Background/Shell/MainSplit/BrandPanel/BrandMargin/BrandLayout/StatusCard/StatusMargin/StatusLayout/StatusValue

var server_online := false
var is_loading := false

func _ready() -> void:
	login_button.pressed.connect(_on_login_button_pressed)
	register_link_button.pressed.connect(_on_register_link_pressed)
	username_input.text_submitted.connect(_on_username_submitted)
	password_input.text_submitted.connect(_on_password_submitted)
	_set_server_status_checking()
	username_input.grab_focus()
	_refresh_server_health.call_deferred()
	_restore_saved_session.call_deferred()


func set_loading(is_loading: bool) -> void:
	self.is_loading = is_loading
	username_input.editable = not is_loading
	password_input.editable = not is_loading
	remember_me_checkbox.disabled = is_loading
	login_button.disabled = is_loading
	login_button.text = "Signing In..." if is_loading else _get_idle_login_button_text()

	if is_loading:
		show_status("Connecting to Aether...", false)


func show_status(message: String, is_error: bool = false) -> void:
	status_label.text = message
	status_label.visible = not message.strip_edges().is_empty()
	if is_error:
		status_label.add_theme_color_override("font_color", OFFLINE_COLOR)
	else:
		status_label.add_theme_color_override("font_color", ONLINE_COLOR)


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
		show_status("Signed in as %s." % display_name, false)

	password_input.clear()
	remember_me_checkbox.button_pressed = true
	login_button.text = _get_idle_login_button_text()


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


func _get_login_error_message(result: Dictionary) -> String:
	var status: int = int(result.get("status", 0))
	if status == 401:
		return "Invalid username or password."
	if status >= 500:
		return "PokeAether is currently unavailable. Please try again later."
	return str(result.get("error", "Could not sign in. Please try again."))
