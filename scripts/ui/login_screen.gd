extends Control

const NewsLocalizationService := preload("res://scripts/services/news_localization_service.gd")
const LanguageSelectorStyle := preload("res://scripts/ui/language_selector_style.gd")
const AETHER_CONFIRMATION_DIALOG_SCENE: PackedScene = preload("res://scenes/interface/aether_confirmation_dialog.tscn")

signal login_submitted(username: String, password: String)

const REGISTER_URL := "https://pokeaether.com/register"
const FORGOT_PASSWORD_URL := "https://pokeaether.com/forgot-password"
const NEWS_URL := "https://updates.pokeaether.com/data/news.json"
const LOADING_SCENE_PATH := "res://scenes/interface/loading_screen.tscn"
const USER_AGENT_HEADER := "User-Agent: PokeAether/1.0"
const ONLINE_COLOR := Color(0.16, 0.94, 0.66)
const OFFLINE_COLOR := Color(1.0, 0.42, 0.42)
const CHECKING_COLOR := Color(0.847, 0.706, 0.416)
const NEWS_LINK_COLOR := "#bd8cff"
const PLAYER_PREVIEW_SCENE: PackedScene = preload("res://scenes/player.tscn")
const CharacterAppearanceService := preload("res://scripts/services/character_appearance_service.gd")
const PLAYER_PREVIEW_VIEWPORT_SIZE := Vector2i(190, 154)
const PLAYER_PREVIEW_POSITION := Vector2(95, 92)
const PLAYER_PREVIEW_SCALE := Vector2(2.0, 2.0)

@onready var username_input: LineEdit = $Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/FormFields/UsernameInput
@onready var password_input: LineEdit = $Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/FormFields/PasswordInput
@onready var remember_me_checkbox: CheckBox = $Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/FormFields/RememberMeCheckbox
@onready var login_button: Button = $Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/LoginButton
@onready var status_label: Label = $Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/StatusLabel
@onready var register_link_button: LinkButton = $Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/RegisterLinkButton
@onready var forgot_password_link_button: LinkButton = $Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/ForgotPasswordLinkButton
@onready var login_card: PanelContainer = $Background/Shell/MainSplit/LoginColumn/LoginCard
@onready var saved_session_card: PanelContainer = $Background/Shell/MainSplit/LoginColumn/SavedSessionCard
@onready var saved_display_name_label: Label = $Background/Shell/MainSplit/LoginColumn/SavedSessionCard/SavedSessionMargin/SavedSessionLayout/TrainerCard/TrainerMargin/TrainerLayout/TrainerInfoLayout/SavedDisplayNameLabel
@onready var saved_username_label: Label = $Background/Shell/MainSplit/LoginColumn/SavedSessionCard/SavedSessionMargin/SavedSessionLayout/TrainerCard/TrainerMargin/TrainerLayout/TrainerInfoLayout/SavedUsernameLabel
@onready var saved_status_label: Label = $Background/Shell/MainSplit/LoginColumn/SavedSessionCard/SavedSessionMargin/SavedSessionLayout/SavedStatusLabel
@onready var continue_button: Button = $Background/Shell/MainSplit/LoginColumn/SavedSessionCard/SavedSessionMargin/SavedSessionLayout/ContinueButton
@onready var logout_button: Button = $Background/Shell/MainSplit/LoginColumn/SavedSessionCard/SavedSessionMargin/SavedSessionLayout/LogoutButton
@onready var player_preview_viewport: SubViewport = $Background/Shell/MainSplit/LoginColumn/SavedSessionCard/SavedSessionMargin/SavedSessionLayout/TrainerCard/TrainerMargin/TrainerLayout/PlayerPreviewViewportContainer/PlayerPreviewViewport
@onready var server_status_value: Label = $Background/Shell/MainSplit/BrandPanel/BrandMargin/BrandLayout/StatusCard/StatusMargin/StatusLayout/StatusValue
@onready var online_players_value: Label = $Background/Shell/MainSplit/BrandPanel/BrandMargin/BrandLayout/StatusCard/StatusMargin/StatusLayout/OnlinePlayersValue
@onready var login_news_label: RichTextLabel = $Background/Shell/MainSplit/BrandPanel/BrandMargin/BrandLayout/NewsCard/NewsMargin/NewsLayout/LoginNewsLabel
@onready var hero_background: TextureRect = $Background/HeroBackground
@onready var background_video_player: VideoStreamPlayer = $Background/VideoBackground
@onready var news_request: HTTPRequest = $NewsRequest
@onready var language_options_button: OptionButton = $Background/ScreenActions/LanguageOptionsButton
@onready var options_button: Button = $Background/ScreenActions/OptionsButton
@onready var quit_button: Button = $Background/ScreenActions/QuitButton
@onready var settings_menu: PanelContainer = $Background/LoginSettingsMenu

var server_online := false
var server_in_maintenance := false
var server_access_notice_active := false
var server_access_notice_message := ""
var server_access_notice_key := ""
var is_loading := false
var player_preview_instance: Node2D
var news_items: Array[Dictionary] = []
var raw_news_data: Dictionary = {}
var status_translation_key := ""
var status_translation_values: Dictionary = {}
var status_is_error := false
var saved_status_translation_key := ""
var saved_status_translation_values: Dictionary = {}
var saved_status_is_error := false
var server_status_translation_key := "ui.login.checking_server"
var online_players_translation_key := "ui.login.checking_players"
var online_players_translation_values: Dictionary = {}
var loading_language_options := false
var web_demo_notice_acknowledged := false

func _ready() -> void:
	MusicManager.play_login_music()
	_apply_remember_me_style()
	LanguageSelectorStyle.configure_login_compact(language_options_button)
	language_options_button.item_selected.connect(_on_language_selected)
	login_button.pressed.connect(_on_login_button_pressed)
	register_link_button.pressed.connect(_on_register_link_pressed)
	forgot_password_link_button.pressed.connect(_on_forgot_password_link_pressed)
	continue_button.pressed.connect(_on_continue_button_pressed)
	logout_button.pressed.connect(_on_logout_button_pressed)
	options_button.pressed.connect(_on_options_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	if OS.has_feature("web"):
		quit_button.hide()
		# Registration stays on this origin; no automatic production requests.
		forgot_password_link_button.hide()
	news_request.request_completed.connect(_on_news_request_completed)
	login_news_label.meta_clicked.connect(_on_news_meta_clicked)
	if settings_menu.has_signal("closed"):
		settings_menu.closed.connect(_on_settings_menu_closed)
	background_video_player.finished.connect(_on_background_video_finished)
	username_input.text_submitted.connect(_on_username_submitted)
	password_input.text_submitted.connect(_on_password_submitted)
	if not LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.connect(_on_locale_changed)
	LocalizationManager.localize_tree(self)
	_apply_language_options_to_control()
	_set_server_status_checking()
	_setup_background_video()
	_render_news_items([])
	_show_login_form()
	var pending_notice := AuthService.take_pending_login_notice()
	if pending_notice != "":
		show_status(pending_notice, true)
	_setup_player_preview()
	username_input.grab_focus()
	_center_settings_menu.call_deferred()
	_refresh_server_health.call_deferred()
	_fetch_news.call_deferred()
	_restore_saved_session.call_deferred()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.pokeaetherPreview.loginReady = true", true)


func _apply_remember_me_style() -> void:
	remember_me_checkbox.add_theme_icon_override("unchecked", _checkbox_icon(false, false))
	remember_me_checkbox.add_theme_icon_override("unchecked_hover", _checkbox_icon(false, true))
	remember_me_checkbox.add_theme_icon_override("unchecked_pressed", _checkbox_icon(false, true))
	remember_me_checkbox.add_theme_icon_override("checked", _checkbox_icon(true, false))
	remember_me_checkbox.add_theme_icon_override("checked_hover", _checkbox_icon(true, true))
	remember_me_checkbox.add_theme_icon_override("checked_pressed", _checkbox_icon(true, true))


func _checkbox_icon(checked: bool, highlighted: bool) -> ImageTexture:
	var image := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	var border := Color("#7aa7f4") if highlighted or checked else Color("#426384")
	var fill := Color("#315ca8") if checked else Color("#0d1c30")
	for y: int in range(20):
		for x: int in range(20):
			var is_border := x < 2 or x > 17 or y < 2 or y > 17
			image.set_pixel(x, y, border if is_border else fill)
	if checked:
		var check_pixels := [
			Vector2i(5, 10), Vector2i(6, 11), Vector2i(7, 12), Vector2i(8, 13),
			Vector2i(9, 12), Vector2i(10, 11), Vector2i(11, 10), Vector2i(12, 9),
			Vector2i(13, 8), Vector2i(14, 7),
		]
		for point: Vector2i in check_pixels:
			image.set_pixelv(point, Color.WHITE)
			if point.y + 1 < 18:
				image.set_pixel(point.x, point.y + 1, Color.WHITE)
	return ImageTexture.create_from_image(image)


func set_loading(is_loading: bool) -> void:
	self.is_loading = is_loading
	username_input.editable = not is_loading
	password_input.editable = not is_loading
	remember_me_checkbox.disabled = is_loading
	login_button.disabled = is_loading or not server_online
	continue_button.disabled = is_loading or not server_online
	logout_button.disabled = is_loading
	language_options_button.disabled = is_loading
	login_button.text = (
		LocalizationManager.text("ui.login.signing_in")
		if is_loading
		else _get_idle_login_button_text()
	)
	continue_button.text = LocalizationManager.text(
		"ui.login.entering" if is_loading else _get_saved_session_button_key()
	)

	if is_loading:
		show_status_key("ui.login.connecting")


func show_status(message: String, is_error: bool = false) -> void:
	status_translation_key = ""
	status_translation_values = {}
	status_is_error = is_error
	status_label.text = message
	status_label.visible = not message.strip_edges().is_empty()
	if is_error:
		status_label.add_theme_color_override("font_color", OFFLINE_COLOR)
	else:
		status_label.add_theme_color_override("font_color", ONLINE_COLOR)


func show_status_key(key: String, values: Dictionary = {}, is_error: bool = false) -> void:
	show_status(LocalizationManager.text(key, values), is_error)
	status_translation_key = key
	status_translation_values = values.duplicate()
	status_is_error = is_error


func show_saved_status(message: String, is_error: bool = false) -> void:
	saved_status_translation_key = ""
	saved_status_translation_values = {}
	saved_status_is_error = is_error
	saved_status_label.text = message
	saved_status_label.visible = not message.strip_edges().is_empty()
	if is_error:
		saved_status_label.add_theme_color_override("font_color", OFFLINE_COLOR)
	else:
		saved_status_label.add_theme_color_override("font_color", ONLINE_COLOR)


func show_saved_status_key(key: String, values: Dictionary = {}, is_error: bool = false) -> void:
	show_saved_status(LocalizationManager.text(key, values), is_error)
	saved_status_translation_key = key
	saved_status_translation_values = values.duplicate()
	saved_status_is_error = is_error


func _on_locale_changed(_locale: String) -> void:
	LocalizationManager.localize_tree(self)
	_apply_language_options_to_control()
	login_button.text = (
		LocalizationManager.text("ui.login.signing_in")
		if is_loading
		else _get_idle_login_button_text()
	)
	continue_button.text = LocalizationManager.text(
		"ui.login.entering" if is_loading else _get_saved_session_button_key()
	)
	if not status_translation_key.is_empty():
		show_status_key(status_translation_key, status_translation_values, status_is_error)
	if not saved_status_translation_key.is_empty():
		show_saved_status_key(
			saved_status_translation_key,
			saved_status_translation_values,
			saved_status_is_error
		)
	server_status_value.text = LocalizationManager.text(server_status_translation_key)
	online_players_value.text = LocalizationManager.text(
		online_players_translation_key,
		online_players_translation_values
	)
	if raw_news_data.is_empty():
		_render_news_items([])
	else:
		_render_localized_news()


func _on_language_selected(index: int) -> void:
	if loading_language_options or index < 0 or index >= language_options_button.item_count:
		return
	SettingsManager.set_locale(str(language_options_button.get_item_metadata(index)))


func _apply_language_options_to_control() -> void:
	if language_options_button == null:
		return
	var was_loading_options := loading_language_options
	loading_language_options = true
	language_options_button.clear()
	var selected_index := 0
	var supported_locales: Array[String] = LocalizationManager.get_supported_locales()
	for index: int in range(supported_locales.size()):
		var supported_locale := supported_locales[index]
		LanguageSelectorStyle.add_locale_item(
			language_options_button,
			supported_locale,
			LocalizationManager.get_language_name(supported_locale),
			index
		)
		if supported_locale == SettingsManager.locale:
			selected_index = index
	if language_options_button.item_count > 0:
		language_options_button.select(selected_index)
		LanguageSelectorStyle.apply_compact_label(
			language_options_button,
			str(language_options_button.get_item_metadata(selected_index))
		)
	loading_language_options = was_loading_options


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
	if OS.has_feature("web") and not web_demo_notice_acknowledged:
		_show_web_demo_notice()
		return
	_enter_world()


func _show_web_demo_notice() -> void:
	var dialog := AETHER_CONFIRMATION_DIALOG_SCENE.instantiate() as AetherConfirmationDialog
	dialog.configure(
		"Welcome to the PokeAether browser demo",
		"This browser version is a small, limited part of PokeAether. Explore the opening world, chat and practise battles here. Download the client for the full MMO experience. Your account and progress are shared.",
		"Continue in browser",
		"Download client"
	)
	dialog.confirmed.connect(func():
		web_demo_notice_acknowledged = true
		dialog.queue_free()
		_enter_world()
	)
	dialog.cancel_button.pressed.connect(func():
		OS.shell_open("https://pokeaether.com/download")
	)
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(560, 260))


func _on_logout_button_pressed() -> void:
	if is_loading:
		return

	set_loading(true)
	show_saved_status_key("ui.login.signing_out")
	await AuthService.logout()
	set_loading(false)

	clear_form()
	_show_login_form()


func _on_register_link_pressed() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.pokeaetherOpenRegistration()", true)
		return
	OS.shell_open(REGISTER_URL)


func _on_forgot_password_link_pressed() -> void:
	OS.shell_open(FORGOT_PASSWORD_URL)


func _on_options_button_pressed() -> void:
	_center_settings_menu()
	if settings_menu.has_method("open"):
		settings_menu.call("open", "login")
	else:
		settings_menu.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if (
		not event.is_action_pressed("ui_cancel")
		or is_loading
		or settings_menu == null
		or settings_menu.visible
	):
		return

	_on_options_button_pressed()
	get_viewport().set_input_as_handled()


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_settings_menu_closed() -> void:
	options_button.grab_focus()


func _setup_background_video() -> void:
	var has_video := background_video_player.stream != null
	background_video_player.visible = has_video
	hero_background.visible = not has_video
	if has_video:
		background_video_player.play()


func _on_background_video_finished() -> void:
	if background_video_player.stream == null:
		return

	background_video_player.play()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_center_settings_menu()


func _center_settings_menu() -> void:
	if settings_menu == null:
		return

	var menu_size: Vector2 = settings_menu.size
	if menu_size.x <= 0.0 or menu_size.y <= 0.0:
		menu_size = settings_menu.custom_minimum_size
	if menu_size.x <= 0.0 or menu_size.y <= 0.0:
		menu_size = Vector2(440, 540)

	var viewport_size: Vector2 = get_viewport_rect().size
	settings_menu.position = (viewport_size - menu_size) * 0.5


func _fetch_news() -> void:
	if NEWS_URL.is_empty():
		_render_news_items([])
		return

	var request_url := NEWS_URL
	if OS.has_feature("web"):
		request_url = str(JavaScriptBridge.eval("window.location.origin", true)) + "/news.json"
	var error_code: Error = news_request.request(
		request_url,
		[
			USER_AGENT_HEADER,
			"Accept-Language: %s, en;q=0.8" % LocalizationManager.get_http_locale(),
		]
	)
	if error_code != OK:
		_render_news_items([])


func _on_news_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_render_news_items([])
		return

	var news_text: String = body.get_string_from_utf8()
	var parsed_json: Variant = JSON.parse_string(news_text)
	if typeof(parsed_json) != TYPE_DICTIONARY:
		_render_news_items([])
		return

	raw_news_data = parsed_json as Dictionary
	_render_localized_news()


func _render_localized_news() -> void:
	_render_news_items(NewsLocalizationService.resolve_items(
		raw_news_data,
		LocalizationManager.get_http_locale()
	))


func _render_news_items(items: Array[Dictionary]) -> void:
	news_items = items
	login_news_label.clear()
	if news_items.is_empty():
		login_news_label.append_text(
			"[color=#cfd2df]%s[/color]" % LocalizationManager.text("ui.login.latest_empty")
		)
		return

	for index: int in range(mini(news_items.size(), 3)):
		var item: Dictionary = news_items[index]
		var title: String = _escape_bbcode(str(item.get("title", "")))
		var description: String = _escape_bbcode(str(item.get("description", "")))
		var url: String = str(item.get("url", ""))
		if not url.is_empty():
			login_news_label.append_text("[url=%d][color=%s]%s[/color][/url]\n" % [index, NEWS_LINK_COLOR, title])
		else:
			login_news_label.append_text("[color=%s]%s[/color]\n" % [NEWS_LINK_COLOR, title])

		if not description.is_empty():
			login_news_label.append_text("[color=#cfd2df]%s[/color]\n" % description)

		if index < mini(news_items.size(), 3) - 1:
			login_news_label.append_text("\n")


func _on_news_meta_clicked(meta: Variant) -> void:
	var index: int = int(meta)
	if index < 0 or index >= news_items.size():
		return

	var url: String = str(news_items[index].get("url", "")).strip_edges()
	if url.is_empty():
		return

	OS.shell_open(url)


func _escape_bbcode(text: String) -> String:
	return text.replace("[", "\\[").replace("]", "\\]")


func _submit_login() -> void:
	if is_loading:
		return

	var username := username_input.text.strip_edges()
	var password := password_input.text

	if username.is_empty():
		show_status_key("ui.login.error.enter_username", {}, true)
		username_input.grab_focus()
		return

	if AuthService.is_authenticated() and password.is_empty():
		var current_username: String = str(AuthService.current_user.get("username", ""))
		if username == current_username:
			_enter_world()
			return

	if password.is_empty():
		show_status_key("ui.login.error.enter_password", {}, true)
		password_input.grab_focus()
		return

	if not server_online:
		if server_access_notice_active:
			_apply_server_access_notice()
		else:
			show_status_key("ui.login.error.offline", {}, true)
		_refresh_server_health.call_deferred()
		return

	show_status("")
	set_loading(true)
	var result: Dictionary = await AuthService.login(username, password, remember_me_checkbox.button_pressed)
	set_loading(false)

	if not bool(result.get("success", false)):
		var login_error_code := BackendErrorLocalizationService.error_code(result)
		if int(result.get("status", 0)) == 503 or login_error_code == "server_maintenance":
			await _refresh_server_health()
			if server_in_maintenance:
				password_input.select_all()
				password_input.grab_focus()
				return
		show_status(_get_login_error_message(result), true)
		password_input.select_all()
		password_input.grab_focus()
		return

	_apply_authenticated_player_profile()

	login_submitted.emit(username, password)
	if OS.has_feature("web"):
		_show_web_demo_notice()
	else:
		_enter_world()


func _refresh_server_health() -> void:
	var result: Dictionary = await ServerHealthService.check_async(self)
	server_online = bool(result.get("online", false))
	server_in_maintenance = bool(result.get("maintenance", false))
	if server_online:
		_set_server_status("ui.login.server_online", ONLINE_COLOR)
		_clear_server_access_notice()
		await _refresh_online_players()
	elif server_in_maintenance:
		_set_server_status("ui.login.server_maintenance", CHECKING_COLOR)
		_set_online_players_status("ui.login.players_unavailable", {}, CHECKING_COLOR)
		var maintenance_message := str(result.get("message", "")).strip_edges()
		if maintenance_message.is_empty():
			_set_server_access_notice("", "ui.login.error.maintenance")
		else:
			_set_server_access_notice(maintenance_message)
	else:
		_set_server_status("ui.login.server_offline", OFFLINE_COLOR)
		_set_online_players_status("ui.login.players_unavailable", {}, CHECKING_COLOR)
		_set_server_access_notice("", "ui.login.error.offline")
	_apply_server_access_controls()


func _set_server_access_notice(message: String = "", key: String = "") -> void:
	server_access_notice_active = true
	server_access_notice_message = message
	server_access_notice_key = key
	_apply_server_access_notice()


func _apply_server_access_notice() -> void:
	if not server_access_notice_active:
		return
	if not server_access_notice_key.is_empty():
		show_status_key(server_access_notice_key, {}, true)
		show_saved_status_key(server_access_notice_key, {}, true)
	else:
		show_status(server_access_notice_message, true)
		show_saved_status(server_access_notice_message, true)


func _clear_server_access_notice() -> void:
	if not server_access_notice_active:
		return
	server_access_notice_active = false
	server_access_notice_message = ""
	server_access_notice_key = ""
	show_status("")
	show_saved_status("")


func _apply_server_access_controls() -> void:
	login_button.disabled = is_loading or not server_online
	continue_button.disabled = is_loading or not server_online


func _set_server_status(key: String, color: Color) -> void:
	server_status_translation_key = key
	server_status_value.text = LocalizationManager.text(key)
	server_status_value.add_theme_color_override("font_color", color)


func _set_online_players_status(key: String, values: Dictionary, color: Color) -> void:
	online_players_translation_key = key
	online_players_translation_values = values.duplicate()
	online_players_value.text = LocalizationManager.text(key, values)
	online_players_value.add_theme_color_override("font_color", color)


func _set_server_status_checking() -> void:
	server_online = false
	server_in_maintenance = false
	_set_server_status("ui.login.checking_server", CHECKING_COLOR)
	_set_online_players_status("ui.login.checking_players", {}, CHECKING_COLOR)
	_apply_server_access_controls()


func _refresh_online_players() -> void:
	var result: Dictionary = await ServerHealthService.check_presence_async(self)
	if not bool(result.get("success", false)):
		_set_online_players_status("ui.login.players_unavailable", {}, CHECKING_COLOR)
		return

	var online_players: int = int(result.get("onlineUsers", 0))
	online_players_translation_key = (
		"ui.login.player_online" if online_players == 1 else "ui.login.players_online"
	)
	_set_online_players_status(
		online_players_translation_key,
		{"count": online_players},
		ONLINE_COLOR
	)


func _restore_saved_session() -> void:
	var result: Dictionary = await AuthService.restore_saved_session()
	if not bool(result.get("success", false)):
		var restore_error_code := BackendErrorLocalizationService.error_code(result)
		if int(result.get("status", 0)) == 503 or restore_error_code == "server_maintenance":
			await _refresh_server_health()
		return

	var username: String = str(AuthService.current_user.get("username", ""))
	var display_name: String = AuthService.get_display_name()
	if username != "":
		username_input.text = username
	_apply_authenticated_player_profile()
	await _apply_saved_session_preview_state()

	password_input.clear()
	remember_me_checkbox.button_pressed = true
	login_button.text = _get_idle_login_button_text()
	_show_saved_session_card()


func _apply_saved_session_preview_state() -> void:
	if OS.has_feature("web"):
		return
	var profile_response: Dictionary = await PlayerGameStateService.load_player_profile()
	if not bool(profile_response.get("success", false)):
		return

	var position_response: Dictionary = _dictionary_from_value(profile_response.get("position", {}))
	if not bool(position_response.get("hasState", false)):
		return

	var saved_state: Dictionary = _dictionary_from_value(position_response.get("state", {}))
	var appearance: Dictionary = _dictionary_from_value(saved_state.get("appearance", {}))
	if appearance.is_empty():
		return

	PlayerSave.apply_appearance_state(appearance)


func _enter_world() -> void:
	_apply_authenticated_player_profile()

	# The browser uses the same authenticated loading path as the desktop
	# client.  Apart from making the hand-off feel deliberate, this hydrates
	# the account, party, inventory and bounded-world position before the map
	# can accept input.
	var error: Error = get_tree().change_scene_to_file(LOADING_SCENE_PATH)
	if error != OK:
		show_status_key("ui.login.error.enter_world", {}, true)
		push_error("LoginScreen: failed to load loading scene: %s" % error_string(error))


func _apply_authenticated_player_profile() -> void:
	var display_name: String = AuthService.get_display_name()
	if display_name != "":
		PlayerSave.player_name = display_name
	var user_id_text: String = AuthService.get_user_id_text()
	if user_id_text != "":
		PlayerSave.player_id = user_id_text
	var join_date_text: String = AuthService.get_created_at_text()
	if join_date_text != "":
		PlayerSave.flags["join_date"] = join_date_text
	PlayerSave.gender = AuthService.get_gender()
	PlayerSave.ensure_body_matches_gender()


func _get_idle_login_button_text() -> String:
	return LocalizationManager.text(
		"ui.login.continue" if AuthService.is_authenticated() else "ui.login.sign_in"
	)


func _get_saved_session_button_key() -> String:
	# The browser notice explains the demo boundary after an explicit sign-in.
	# Keep the launch action consistent with the desktop login affordance rather
	# than labelling it as a separate browser-demo destination.
	return "ui.login.sign_in" if OS.has_feature("web") else "ui.login.continue"


func _show_login_form() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.pokeaetherPreview.authenticated = false", true)
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
	_refresh_player_preview()
	show_status("")
	show_saved_status("")
	_apply_server_access_notice()
	continue_button.grab_focus()
	if OS.has_feature("web"):
		continue_button.disabled = is_loading or not server_online
		continue_button.text = LocalizationManager.text(_get_saved_session_button_key())
		JavaScriptBridge.eval("window.pokeaetherPreview.authenticated = true", true)


func _setup_player_preview() -> void:
	var preview_container := player_preview_viewport.get_parent() as SubViewportContainer
	if preview_container != null:
		preview_container.stretch = false
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
	_apply_player_preview_body(player_preview_instance)


func _refresh_player_preview() -> void:
	if player_preview_viewport == null:
		return
	for child: Node in player_preview_viewport.get_children():
		child.queue_free()

	player_preview_instance = _create_player_preview_visual()
	if player_preview_instance == null:
		return

	player_preview_viewport.add_child(player_preview_instance)
	player_preview_instance.position = PLAYER_PREVIEW_POSITION
	player_preview_instance.scale = PLAYER_PREVIEW_SCALE
	_disable_preview_processing(player_preview_instance)
	_set_preview_idle_frame(player_preview_instance)
	_apply_player_preview_body(player_preview_instance)


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


func _apply_player_preview_body(node: Node) -> void:
	if node is AnimatedSprite2D:
		var sprite: AnimatedSprite2D = node as AnimatedSprite2D
		if sprite.name == "BodySprite":
			var body_frames: SpriteFrames = CharacterAppearanceService.get_skin_tinted_body_frames(
				PlayerSave.appearance_body_id,
				PlayerSave.gender,
				CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
				PlayerSave.appearance_skin_tone
			)
			if body_frames != null:
				sprite.sprite_frames = body_frames
				sprite.modulate = Color.WHITE
				_set_preview_sprite_idle_down(sprite)
		else:
			_apply_player_preview_part(sprite)

	for child_node: Node in node.get_children():
		_apply_player_preview_body(child_node)

func _apply_player_preview_part(sprite: AnimatedSprite2D) -> void:
	var category_id: String = _get_player_preview_category_for_sprite(sprite.name)
	if category_id == "":
		return
	if not CharacterAppearanceService.body_supports_layered_parts(PlayerSave.appearance_body_id, PlayerSave.gender):
		sprite.visible = false
		sprite.sprite_frames = null
		sprite.material = null
		return

	var part_id: String = _get_player_preview_part_id(category_id)
	if part_id == "":
		sprite.visible = false
		sprite.sprite_frames = null
		sprite.material = null
		return

	var part_frames: SpriteFrames = _get_player_preview_part_frames(category_id, part_id)
	if part_frames == null:
		sprite.visible = false
		sprite.sprite_frames = null
		sprite.material = null
		return

	sprite.sprite_frames = part_frames
	_apply_player_preview_part_visuals(sprite, category_id)
	sprite.visible = true
	_set_preview_sprite_idle_down(sprite)

func _set_preview_sprite_idle_down(sprite: AnimatedSprite2D) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(&"idle_down"):
		return
	sprite.animation = &"idle_down"
	sprite.frame = 0
	sprite.stop()

func _get_player_preview_category_for_sprite(sprite_name: String) -> String:
	match sprite_name:
		"HairSprite":
			return "hair"
		"HeadgearSprite":
			return "headgear"
		"FacialHairSprite":
			return "facial_hair"
		"FaceGearSprite":
			return "facegear"
		"TopSprite":
			return "top"
		"BottomSprite":
			return "bottom"
		"ShoesSprite":
			return "shoes"
		"EyesSprite":
			return "eyes"
		"EyebrowsSprite":
			return "eyebrows"
		_:
			return ""

func _get_player_preview_part_id(category_id: String) -> String:
	match CharacterAppearanceService.normalize_part_category(category_id):
		"hair":
			return CharacterAppearanceService.deserialize_part_id(
				PlayerSave.appearance_hair_id
			)
		"headgear":
			return PlayerSave.appearance_headgear_id
		"facial_hair":
			return PlayerSave.appearance_facial_hair_id
		"facegear":
			return PlayerSave.appearance_facegear_id
		"top":
			return PlayerSave.appearance_top_id
		"bottom":
			return PlayerSave.appearance_bottom_id
		"shoes":
			return PlayerSave.appearance_shoes_id
		"eyes":
			return CharacterAppearanceService.get_default_part_id("eyes", PlayerSave.gender)
		"eyebrows":
			return CharacterAppearanceService.get_eyebrows_for_hair(PlayerSave.appearance_hair_id, PlayerSave.gender)
		_:
			return ""

func _get_player_preview_body_modulate() -> Color:
	if CharacterAppearanceService.body_supports_layered_parts(PlayerSave.appearance_body_id, PlayerSave.gender):
		return _parse_player_preview_color(PlayerSave.appearance_skin_tone, Color.WHITE)
	return Color.WHITE

func _get_player_preview_part_modulate(category_id: String) -> Color:
	return Color.WHITE

func _apply_player_preview_part_visuals(sprite: AnimatedSprite2D, category_id: String) -> void:
	var normalized_category: String = CharacterAppearanceService.normalize_part_category(category_id)
	sprite.material = null
	sprite.modulate = _get_player_preview_part_modulate(normalized_category)

func _get_player_preview_part_frames(category_id: String, part_id: String) -> SpriteFrames:
	var normalized_category: String = CharacterAppearanceService.normalize_part_category(category_id)
	if normalized_category == "eyes":
		return CharacterAppearanceService.get_tinted_part_frames(
			category_id,
			part_id,
			PlayerSave.gender,
			CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
			_parse_player_preview_color(PlayerSave.appearance_eye_color, Color.WHITE)
		)
	if normalized_category == "eyebrows" or (
		normalized_category == "hair"
		and CharacterAppearanceService.is_tintable_part(category_id, part_id)
	):
		return CharacterAppearanceService.get_tinted_part_frames(
			category_id,
			part_id,
			PlayerSave.gender,
			CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
			_parse_player_preview_color(PlayerSave.appearance_hair_color, Color.WHITE),
			true
		)
	if normalized_category == "facial_hair" and CharacterAppearanceService.is_tintable_part(category_id, part_id):
		return CharacterAppearanceService.get_tinted_part_frames(
			category_id,
			part_id,
			PlayerSave.gender,
			CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
			_parse_player_preview_color(PlayerSave.appearance_facial_hair_color, Color.WHITE),
			true
		)
	if normalized_category == "facegear" and CharacterAppearanceService.is_tintable_part(category_id, part_id):
		return CharacterAppearanceService.get_tinted_part_frames(
			category_id,
			part_id,
			PlayerSave.gender,
			CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
			_parse_player_preview_color(PlayerSave.appearance_facegear_color, Color.WHITE),
			true
		)
	if normalized_category == "top" and CharacterAppearanceService.is_tintable_part(category_id, part_id):
		return CharacterAppearanceService.get_tinted_part_frames(
			category_id,
			part_id,
			PlayerSave.gender,
			CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
			_parse_player_preview_color(PlayerSave.appearance_top_color, Color.WHITE),
			true
		)
	if normalized_category == "bottom" and CharacterAppearanceService.is_tintable_part(category_id, part_id):
		return CharacterAppearanceService.get_tinted_part_frames(
			category_id,
			part_id,
			PlayerSave.gender,
			CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
			_parse_player_preview_color(PlayerSave.appearance_bottom_color, Color.WHITE),
			true
		)
	if normalized_category == "shoes" and CharacterAppearanceService.is_tintable_part(category_id, part_id):
		return CharacterAppearanceService.get_tinted_part_frames(
			category_id,
			part_id,
			PlayerSave.gender,
			CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
			_parse_player_preview_color(PlayerSave.appearance_shoes_color, Color.WHITE),
			true
		)
	return CharacterAppearanceService.get_part_frames(category_id, part_id, PlayerSave.gender)

func _parse_player_preview_color(color_text: String, fallback: Color) -> Color:
	var normalized_color: String = color_text.strip_edges()
	if normalized_color == "" or not normalized_color.begins_with("#"):
		return fallback
	return Color(normalized_color)


func _dictionary_from_value(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


func _get_login_error_message(result: Dictionary) -> String:
	var status: int = int(result.get("status", 0))
	var body: Dictionary = _dictionary_from_value(result.get("body", {}))
	var detail: Dictionary = _dictionary_from_value(body.get("detail", {}))
	var code := BackendErrorLocalizationService.error_code(result)
	if code in ["account_login_blocked", "server_maintenance"]:
		var public_message := str(detail.get("message", "")).strip_edges()
		if public_message != "":
			return public_message
	if code != "":
		return BackendErrorLocalizationService.message(result, "ui.login.error.sign_in")
	if status == 401:
		return LocalizationManager.text("ui.login.error.invalid_credentials")
	if status >= 500:
		return LocalizationManager.text("ui.login.error.unavailable")
	return LocalizationManager.text("ui.login.error.sign_in")
