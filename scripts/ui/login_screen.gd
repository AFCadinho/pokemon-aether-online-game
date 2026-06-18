extends Control

signal login_submitted(username: String, password: String)

const REGISTER_URL := "https://pokeaether.com/register"
const WORLD_SCENE_PATH := "res://scenes/world.tscn"
const ONLINE_COLOR := Color(0.16, 0.94, 0.66)
const OFFLINE_COLOR := Color(1.0, 0.42, 0.42)
const CHECKING_COLOR := Color(0.847, 0.706, 0.416)
const PLAYER_PREVIEW_SCENE: PackedScene = preload("res://scenes/player.tscn")
const PLAYER_PREVIEW_VIEWPORT_SIZE := Vector2i(170, 132)
const PLAYER_PREVIEW_POSITION := Vector2(85, 70)
const PLAYER_PREVIEW_SCALE := Vector2(1.8, 1.8)

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
	player_preview_viewport.size = PLAYER_PREVIEW_VIEWPORT_SIZE
	player_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	player_preview_instance = _create_player_preview_visual()
	if player_preview_instance == null:
		return

	player_preview_viewport.add_child(player_preview_instance)
	player_preview_instance.position = PLAYER_PREVIEW_POSITION
	player_preview_instance.scale = PLAYER_PREVIEW_SCALE
	_disable_preview_processing(player_preview_instance)
	_set_preview_idle_frame(player_preview_instance)


func _create_player_preview_visual() -> Node2D:
	var source_player: Node2D = PLAYER_PREVIEW_SCENE.instantiate() as Node2D
	if source_player == null:
		return null

	var visual_root := Node2D.new()
	var source_look: Node2D = source_player.get_node_or_null("Look") as Node2D
	if source_look != null:
		var visual_look: Node2D = source_look.duplicate() as Node2D
		if visual_look != null:
			visual_look.position = Vector2.ZERO
			visual_root.add_child(visual_look)

	source_player.free()
	if visual_root.get_child_count() == 0:
		visual_root.free()
		return null

	return visual_root


func _disable_preview_processing(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	node.set_process_unhandled_key_input(false)

	for child_node: Node in node.get_children():
		_disable_preview_processing(child_node)


func _set_preview_idle_frame(node: Node) -> void:
	if node is AnimatedSprite2D:
		var sprite: AnimatedSprite2D = node as AnimatedSprite2D
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"idle_down"):
			sprite.animation = &"idle_down"
		sprite.frame = 0
		sprite.stop()

	for child_node: Node in node.get_children():
		_set_preview_idle_frame(child_node)


func _get_login_error_message(result: Dictionary) -> String:
	var status: int = int(result.get("status", 0))
	if status == 401:
		return "Invalid username or password."
	if status >= 500:
		return "PokeAether is currently unavailable. Please try again later."
	return str(result.get("error", "Could not sign in. Please try again."))
