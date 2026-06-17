extends Control

signal login_submitted(username: String, password: String)

const REGISTER_URL := "https://pokeaether.com/register"
const ONLINE_COLOR := Color(0.16, 0.94, 0.66)
const OFFLINE_COLOR := Color(1.0, 0.42, 0.42)
const CHECKING_COLOR := Color(0.847, 0.706, 0.416)

@onready var username_input: LineEdit = $Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/FormFields/UsernameInput
@onready var password_input: LineEdit = $Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/FormFields/PasswordInput
@onready var login_button: Button = $Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/LoginButton
@onready var status_label: Label = $Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/StatusLabel
@onready var register_link_button: LinkButton = $Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/RegisterLinkButton
@onready var server_status_value: Label = $Background/Shell/MainSplit/BrandPanel/BrandMargin/BrandLayout/StatusCard/StatusMargin/StatusLayout/StatusValue

var server_online := false

func _ready() -> void:
	login_button.pressed.connect(_on_login_button_pressed)
	register_link_button.pressed.connect(_on_register_link_pressed)
	username_input.text_submitted.connect(_on_username_submitted)
	password_input.text_submitted.connect(_on_password_submitted)
	_set_server_status_checking()
	username_input.grab_focus()
	_refresh_server_health.call_deferred()


func set_loading(is_loading: bool) -> void:
	username_input.editable = not is_loading
	password_input.editable = not is_loading
	login_button.disabled = is_loading
	login_button.text = "Signing In..." if is_loading else "Sign In"

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
	var username := username_input.text.strip_edges()
	var password := password_input.text

	if username.is_empty():
		show_status("Enter your username.", true)
		username_input.grab_focus()
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
	login_submitted.emit(username, password)


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
