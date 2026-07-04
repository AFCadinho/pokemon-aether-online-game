extends Control

signal login_submitted(username: String, password: String)

const REGISTER_URL := "https://pokeaether.com/register"
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
@onready var options_button: Button = $Background/ScreenActions/OptionsButton
@onready var quit_button: Button = $Background/ScreenActions/QuitButton
@onready var settings_menu: PanelContainer = $Background/LoginSettingsMenu

var server_online := false
var is_loading := false
var player_preview_instance: Node2D
var news_items: Array[Dictionary] = []

func _ready() -> void:
	MusicManager.play_login_music()
	login_button.pressed.connect(_on_login_button_pressed)
	register_link_button.pressed.connect(_on_register_link_pressed)
	continue_button.pressed.connect(_on_continue_button_pressed)
	logout_button.pressed.connect(_on_logout_button_pressed)
	options_button.pressed.connect(_on_options_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	news_request.request_completed.connect(_on_news_request_completed)
	login_news_label.meta_clicked.connect(_on_news_meta_clicked)
	if settings_menu.has_signal("closed"):
		settings_menu.closed.connect(_on_settings_menu_closed)
	background_video_player.finished.connect(_on_background_video_finished)
	username_input.text_submitted.connect(_on_username_submitted)
	password_input.text_submitted.connect(_on_password_submitted)
	_set_server_status_checking()
	_setup_background_video()
	_render_news_items([])
	_show_login_form()
	_setup_player_preview()
	username_input.grab_focus()
	_center_settings_menu.call_deferred()
	_refresh_server_health.call_deferred()
	_fetch_news.call_deferred()
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


func _on_options_button_pressed() -> void:
	_center_settings_menu()
	if settings_menu.has_method("open"):
		settings_menu.call("open", "login")
	else:
		settings_menu.visible = true


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

	var error_code: Error = news_request.request(NEWS_URL, [USER_AGENT_HEADER])
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

	var news_data: Dictionary = parsed_json
	var parsed_items: Array[Dictionary] = []
	var item_variants: Variant = news_data.get("items", [])
	if typeof(item_variants) != TYPE_ARRAY:
		item_variants = news_data.get("articles", [])
	if typeof(item_variants) == TYPE_ARRAY:
		for item_variant: Variant in item_variants:
			if typeof(item_variant) != TYPE_DICTIONARY:
				continue

			var item: Dictionary = item_variant
			var title: String = str(item.get("title", "")).strip_edges()
			if title.is_empty():
				continue

			parsed_items.append({
				"title": title,
				"description": str(item.get("description", item.get("summary", ""))).strip_edges(),
				"url": str(item.get("url", item.get("externalLink", ""))).strip_edges(),
			})

	_render_news_items(parsed_items)


func _render_news_items(items: Array[Dictionary]) -> void:
	news_items = items
	login_news_label.clear()
	if news_items.is_empty():
		login_news_label.append_text("[color=#cfd2df]Latest updates will appear here.[/color]")
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

	_apply_authenticated_player_profile()

	login_submitted.emit(username, password)
	_enter_world()


func _refresh_server_health() -> void:
	var result: Dictionary = await ServerHealthService.check_async(self)
	server_online = bool(result.get("online", false))
	if server_online:
		server_status_value.text = "Server Online"
		server_status_value.add_theme_color_override("font_color", ONLINE_COLOR)
		await _refresh_online_players()
	else:
		server_status_value.text = "Server Offline"
		server_status_value.add_theme_color_override("font_color", OFFLINE_COLOR)
		online_players_value.text = "Players online unavailable"
		online_players_value.add_theme_color_override("font_color", CHECKING_COLOR)


func _set_server_status_checking() -> void:
	server_online = false
	server_status_value.text = "Checking server..."
	server_status_value.add_theme_color_override("font_color", CHECKING_COLOR)
	online_players_value.text = "Checking players online..."
	online_players_value.add_theme_color_override("font_color", CHECKING_COLOR)


func _refresh_online_players() -> void:
	var result: Dictionary = await ServerHealthService.check_presence_async(self)
	if not bool(result.get("success", false)):
		online_players_value.text = "Players online unavailable"
		online_players_value.add_theme_color_override("font_color", CHECKING_COLOR)
		return

	var online_players: int = int(result.get("onlineUsers", 0))
	online_players_value.text = "%s %s online" % [online_players, "player" if online_players == 1 else "players"]
	online_players_value.add_theme_color_override("font_color", ONLINE_COLOR)


func _restore_saved_session() -> void:
	var result: Dictionary = await AuthService.restore_saved_session()
	if not bool(result.get("success", false)):
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

	var error: Error = get_tree().change_scene_to_file(LOADING_SCENE_PATH)
	if error != OK:
		show_status("Could not enter the world. Please contact staff.", true)
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
	_refresh_player_preview()
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
			var body_frames: SpriteFrames = CharacterAppearanceService.get_body_frames(PlayerSave.appearance_body_id, PlayerSave.gender)
			if body_frames != null:
				sprite.sprite_frames = body_frames
				sprite.modulate = _get_player_preview_body_modulate()
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
			return PlayerSave.appearance_hair_id
		"headgear":
			return PlayerSave.appearance_headgear_id
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
			return CharacterAppearanceService.get_default_part_id("eyebrows", PlayerSave.gender)
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
	if normalized_category == "hair" or normalized_category == "eyebrows":
		return CharacterAppearanceService.get_tinted_part_frames(
			category_id,
			part_id,
			PlayerSave.gender,
			CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
			_parse_player_preview_color(PlayerSave.appearance_hair_color, Color.WHITE),
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
	if status == 401:
		return "Invalid username or password."
	if status >= 500:
		return "PokeAether is currently unavailable. Please try again later."
	return str(result.get("error", "Could not sign in. Please try again."))
