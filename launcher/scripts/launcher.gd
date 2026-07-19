extends Control

const LauncherServerHealthService := preload("res://scripts/server_health_service.gd")

const DEFAULT_MANIFEST_URL := "https://example.com/pokeaether/manifest.json"
const DEFAULT_NEWS_URL := "https://updates.pokeaether.com/data/news.json"
const DEFAULT_DISCORD_URL := "https://discord.com/invite/b6WexWT8HX"
const DEFAULT_PATCH_NOTES_URL := "https://pokeaether.com/patch-notes"
const DEFAULT_CREDITS_URL := "https://pokeaether.com/credits"
const DEFAULT_HEALTH_URL := "https://pokeaether.com/health"
const DEFAULT_PRESENCE_URL := "https://admin.pokeaether.com/presence/online-count"
const LAUNCHER_CONFIG_FILE := "res://config/launcher_config.json"
const DEFAULT_INSTALL_DIR := "user://game"
const GAME_INSTALL_SUBDIR := "game"
const LAUNCHER_SETTINGS_FILE := "user://launcher_settings.json"
const VERSION_FILE := "user://versions.json"
const ERROR_LOG_FILE := "user://launcher_error.log"
const TEMP_DIR := "user://downloads"
const EXTRACT_PROGRESS_BATCH_SIZE := 25
const USER_AGENT_HEADER := "User-Agent: PokeAetherLauncher/1.0"
const GEN5_OPTIONAL_ASSET_PACK_PREFIX := "pokemon-gen5"
const GEN5_SPRITES_FOLDER_PATH := "assets/sprites/pokemon/gen5"
const ASSET_PACK_REQUIRED_PATHS := {
	"music": "assets/music",
	"pokemon-home": "assets/sprites/pokemon/pokemon_home",
	"pokemon-front": "assets/sprites/pokemon/front",
	"pokemon-back": "assets/sprites/pokemon/back",
	"pokemon-shiny-front": "assets/sprites/pokemon/shiny_front",
	"pokemon-shiny-back": "assets/sprites/pokemon/shiny_back",
	"pokemon-gen5-front": "assets/sprites/pokemon/gen5/front",
	"pokemon-gen5-back": "assets/sprites/pokemon/gen5/back",
	"pokemon-gen5-shiny-front": "assets/sprites/pokemon/gen5/shiny_front",
	"pokemon-gen5-shiny-back": "assets/sprites/pokemon/gen5/shiny_back",
}
const LAUNCHER_UPDATE_TEMP_DIR := "user://launcher_update"
const LAUNCHER_UPDATE_STAGING_SUBDIR := "staging"
const LAUNCHER_UPDATE_WINDOWS_SCRIPT := "apply_launcher_update.bat"
const LAUNCHER_UPDATE_UNIX_SCRIPT := "apply_launcher_update.sh"
const LAUNCHER_UPDATE_ZIP_NAME_PREFIX := "pokeaether-launcher-update"
const WINDOWS_LAUNCHER_BINARY := "PokeAether Launcher.exe"
const LINUX_LAUNCHER_BINARY := "PokeAether Launcher.x86_64"
const MACOS_LAUNCHER_BINARY := "PokeAether Launcher.app/Contents/MacOS/PokeAether Launcher"
const WINDOWS_GAME_BINARY := "PokeAether.exe"
const LINUX_GAME_BINARY := "PokeAether.x86_64"
const MACOS_GAME_BINARY := "PokeAether.app/Contents/MacOS/PokeAether"
const MAX_VERSION_SEGMENTS := 4

const KNOWN_URL_SCHEMES: Array[String] = ["http://", "https://"]
const SERVER_ONLINE_COLOR := Color(0.16, 0.94, 0.66, 1.0)
const SERVER_OFFLINE_COLOR := Color(1.0, 0.38, 0.45, 1.0)
const SERVER_CHECKING_COLOR := Color(1.0, 0.72, 0.34, 1.0)

@onready var shell_panel: PanelContainer = $Shell
@onready var sidebar_panel: PanelContainer = $Shell/MainSplit/Sidebar
@onready var brand_mark: PanelContainer = $Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/BrandRow/BrandMark
@onready var server_card: PanelContainer = $Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/ServerCard
@onready var server_online_label: Label = $Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/ServerCard/ServerMargin/ServerLayout/StatusHeader/ServerOnline
@onready var online_players_label: Label = $Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/ServerCard/ServerMargin/ServerLayout/OnlinePlayers
@onready var meta_card: PanelContainer = $Shell/MainSplit/Content/ContentLayout/CenterColumn/MetaCard
@onready var progress_card: PanelContainer = $Shell/MainSplit/Content/ContentLayout/CenterColumn/ProgressCard
@onready var news_card: PanelContainer = $Shell/MainSplit/Content/ContentLayout/NewsCard
@onready var version_label: Label = $Shell/MainSplit/Content/ContentLayout/CenterColumn/MetaCard/MetaMargin/MetaGrid/VersionBlock/VersionLabel
@onready var status_value_label: Label = $Shell/MainSplit/Content/ContentLayout/CenterColumn/MetaCard/MetaMargin/MetaGrid/StatusBlock/StatusValueLabel
@onready var last_check_label: Label = $Shell/MainSplit/Content/ContentLayout/CenterColumn/MetaCard/MetaMargin/MetaGrid/LastCheckBlock/LastCheckLabel
@onready var launcher_version_label: Label = $Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/ServerCard/ServerMargin/ServerLayout/VersionRow/LauncherVersionValue
@onready var status_label: Label = $Shell/MainSplit/Content/ContentLayout/CenterColumn/ProgressCard/ProgressMargin/ProgressLayout/StatusLabel
@onready var progress_bar: ProgressBar = $Shell/MainSplit/Content/ContentLayout/CenterColumn/ProgressCard/ProgressMargin/ProgressLayout/ProgressBar
@onready var progress_percent_label: Label = $Shell/MainSplit/Content/ContentLayout/CenterColumn/ProgressCard/ProgressMargin/ProgressLayout/ProgressHeader/ProgressPercentLabel
@onready var log_label: RichTextLabel = $Shell/MainSplit/Content/ContentLayout/NewsCard/NewsMargin/NewsLayout/LogLabel
@onready var check_button: Button = $Shell/MainSplit/Content/ContentLayout/CenterColumn/ButtonRow/CheckButton
@onready var update_button: Button = $Shell/MainSplit/Content/ContentLayout/CenterColumn/ButtonRow/UpdateButton
@onready var gen5_sprites_button: Button = $Shell/MainSplit/Content/ContentLayout/CenterColumn/ButtonRow/Gen5SpritesButton
@onready var play_button: Button = $Shell/MainSplit/Content/ContentLayout/CenterColumn/ButtonRow/PlayButton
@onready var game_folder_button: Button = $Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/GameFolderButton
@onready var patch_notes_button: Button = $Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/PatchNotesButton
@onready var credits_button: Button = $Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/CreditsButton
@onready var uninstall_button: Button = $Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/UninstallButton
@onready var discord_button: Button = $Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/SocialSection/SocialRow/DiscordButton
@onready var install_folder_dialog: FileDialog = $InstallFolderDialog
@onready var uninstall_confirm_dialog: ConfirmationDialog = $UninstallConfirmDialog
@onready var launcher_update_confirm_dialog: ConfirmationDialog = $LauncherUpdateConfirmDialog
@onready var launcher_update_http_request: HTTPRequest = $LauncherUpdateHttpRequest
@onready var http_request: HTTPRequest = $HttpRequest
@onready var news_request: HTTPRequest = $NewsRequest

var manifest: Dictionary = {}
var local_versions: Dictionary = {}
var pending_downloads: Array[Dictionary] = []
var current_download: Dictionary = {}
var update_required := false
var manifest_url := DEFAULT_MANIFEST_URL
var news_url := DEFAULT_NEWS_URL
var health_url := DEFAULT_HEALTH_URL
var presence_url := DEFAULT_PRESENCE_URL
var discord_url := DEFAULT_DISCORD_URL
var patch_notes_url := DEFAULT_PATCH_NOTES_URL
var credits_url := DEFAULT_CREDITS_URL
var install_dir := DEFAULT_INSTALL_DIR
var launcher_update_info: Dictionary = {}
var launcher_update_busy := false
var launcher_update_in_progress := false
var launcher_update_pending := false
var launcher_update_shown := false
var news_items: Array[Dictionary] = []
var progress_is_indeterminate := false
var asset_pack_download_total := 0
var current_asset_pack_download_index := 0


func _draw() -> void:
	var viewport_size := size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.018, 0.019, 0.036))
	draw_rect(Rect2(Vector2(viewport_size.x * 0.23, 0.0), Vector2(viewport_size.x * 0.77, viewport_size.y * 0.45)), Color(0.055, 0.035, 0.12, 0.76))
	draw_rect(Rect2(Vector2(viewport_size.x * 0.62, 0.0), Vector2(viewport_size.x * 0.38, viewport_size.y * 0.38)), Color(0.23, 0.07, 0.48, 0.34))

	var star_points := [
		Vector2(0.41, 0.08), Vector2(0.58, 0.09), Vector2(0.72, 0.08), Vector2(0.83, 0.10),
		Vector2(0.47, 0.14), Vector2(0.64, 0.15), Vector2(0.78, 0.16), Vector2(0.91, 0.15),
		Vector2(0.37, 0.21), Vector2(0.52, 0.20), Vector2(0.69, 0.22), Vector2(0.87, 0.23),
	]
	for point: Vector2 in star_points:
		var star_position := Vector2(viewport_size.x * point.x, viewport_size.y * point.y)
		draw_circle(star_position, 1.6, Color(0.78, 0.45, 1.0, 0.9))
		draw_circle(star_position, 4.0, Color(0.78, 0.45, 1.0, 0.18))

	var moon_center := Vector2(viewport_size.x * 0.78, viewport_size.y * 0.14)
	draw_circle(moon_center, 31.0, Color(0.42, 0.13, 0.82, 0.44))
	draw_circle(moon_center + Vector2(-13, -3), 31.0, Color(0.055, 0.035, 0.12, 0.92))

	var mountain_y := viewport_size.y * 0.39
	draw_polygon(PackedVector2Array([
		Vector2(viewport_size.x * 0.24, mountain_y + 22),
		Vector2(viewport_size.x * 0.40, mountain_y - 52),
		Vector2(viewport_size.x * 0.55, mountain_y + 22),
	]), PackedColorArray([
		Color(0.04, 0.06, 0.14, 0.72),
		Color(0.04, 0.06, 0.14, 0.72),
		Color(0.04, 0.06, 0.14, 0.72),
	]))
	draw_polygon(PackedVector2Array([
		Vector2(viewport_size.x * 0.45, mountain_y + 24),
		Vector2(viewport_size.x * 0.61, mountain_y - 36),
		Vector2(viewport_size.x * 0.78, mountain_y + 24),
	]), PackedColorArray([
		Color(0.05, 0.07, 0.17, 0.78),
		Color(0.05, 0.07, 0.17, 0.78),
		Color(0.05, 0.07, 0.17, 0.78),
	]))
	draw_rect(Rect2(Vector2(viewport_size.x * 0.23, mountain_y + 8), Vector2(viewport_size.x * 0.77, viewport_size.y - mountain_y)), Color(0.018, 0.022, 0.046, 0.72))

	var mascot_center := Vector2(viewport_size.x * 0.89, viewport_size.y * 0.25)
	draw_circle(mascot_center, 58.0, Color(0.012, 0.016, 0.036, 0.96))
	draw_polygon(PackedVector2Array([
		mascot_center + Vector2(-46, -39),
		mascot_center + Vector2(-28, -96),
		mascot_center + Vector2(-8, -48),
	]), PackedColorArray([
		Color(0.012, 0.016, 0.036, 0.96),
		Color(0.012, 0.016, 0.036, 0.96),
		Color(0.012, 0.016, 0.036, 0.96),
	]))
	draw_polygon(PackedVector2Array([
		mascot_center + Vector2(33, -42),
		mascot_center + Vector2(63, -92),
		mascot_center + Vector2(48, -29),
	]), PackedColorArray([
		Color(0.012, 0.016, 0.036, 0.96),
		Color(0.012, 0.016, 0.036, 0.96),
		Color(0.012, 0.016, 0.036, 0.96),
	]))
	draw_arc(mascot_center + Vector2(0, 8), 30.0, 0.05, PI - 0.05, 24, Color(0.73, 0.42, 1.0, 0.92), 10.0)


func _ready() -> void:
	_apply_visual_style()
	_load_launcher_config()
	_load_launcher_settings()
	check_button.pressed.connect(check_for_updates)
	update_button.pressed.connect(start_update)
	gen5_sprites_button.pressed.connect(download_gen5_animated_sprites)
	play_button.pressed.connect(launch_game)
	game_folder_button.pressed.connect(open_install_folder_dialog)
	patch_notes_button.pressed.connect(open_patch_notes)
	credits_button.pressed.connect(open_credits)
	uninstall_button.pressed.connect(_on_uninstall_button_pressed)
	launcher_update_confirm_dialog.confirmed.connect(_start_launcher_update_download)
	launcher_update_http_request.request_completed.connect(_on_launcher_update_request_completed)
	discord_button.pressed.connect(open_discord)
	install_folder_dialog.dir_selected.connect(_on_install_folder_selected)
	uninstall_confirm_dialog.confirmed.connect(_uninstall_game_folder)
	http_request.request_completed.connect(_on_request_completed)
	if news_request != null:
		news_request.request_completed.connect(_on_news_request_completed)
	log_label.meta_clicked.connect(_on_news_meta_clicked)
	_load_local_versions()
	_refresh_launcher_version()
	_refresh_status()
	_set_server_health_checking()
	_sync_button_cursors()
	_refresh_server_health.call_deferred()
	check_for_updates.call_deferred()
	fetch_news.call_deferred()
	queue_redraw()


func _apply_visual_style() -> void:
	add_theme_font_size_override("font_size", 16)

	shell_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.027, 0.043, 0.078, 0.38), Color(0.192, 0.314, 0.439, 0.82), 14, 1))
	sidebar_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.022, 0.032, 0.061, 0.95), Color(0.192, 0.314, 0.439, 0.72), 12, 1))
	brand_mark.add_theme_stylebox_override("panel", _panel_style(Color(0.48, 0.22, 0.96, 1.0), Color(0.72, 0.48, 1.0, 0.55), 28, 0))
	server_card.add_theme_stylebox_override("panel", _panel_style(Color(0.051, 0.086, 0.145, 0.9), Color(0.192, 0.314, 0.439, 0.9), 12, 1))
	meta_card.add_theme_stylebox_override("panel", _panel_style(Color(0.051, 0.086, 0.145, 0.84), Color(0.192, 0.314, 0.439, 0.82), 14, 1))
	progress_card.add_theme_stylebox_override("panel", _panel_style(Color(0.051, 0.086, 0.145, 0.9), Color(0.192, 0.314, 0.439, 0.82), 14, 1))
	news_card.add_theme_stylebox_override("panel", _panel_style(Color(0.051, 0.086, 0.145, 0.9), Color(0.192, 0.314, 0.439, 0.88), 14, 1))

	var nav_buttons: Array[Button] = [
		$Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/HomeButton,
		$Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/PatchNotesButton,
		$Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/CreditsButton,
		$Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/GameFolderButton,
		$Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/UninstallButton,
	]
	for nav_button in nav_buttons:
		nav_button.add_theme_stylebox_override("normal", _sidebar_button_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
		nav_button.add_theme_stylebox_override("hover", _sidebar_button_style(Color(0.105, 0.085, 0.19, 0.82), Color(0.42, 0.22, 0.82, 0.68), 1))
		nav_button.add_theme_stylebox_override("pressed", _sidebar_button_style(Color(0.14, 0.10, 0.26, 0.92), Color(0.52, 0.30, 0.96, 0.82), 1))
		nav_button.add_theme_color_override("font_color", Color(0.76, 0.78, 0.88, 1.0))
		nav_button.add_theme_color_override("font_hover_color", Color(0.94, 0.94, 1.0, 1.0))
	var nav_active := _sidebar_button_style(Color(0.18, 0.13, 0.34, 0.92), Color(0.48, 0.25, 0.92, 0.9), 1)
	$Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/HomeButton.add_theme_stylebox_override("normal", nav_active)
	$Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/HomeButton.add_theme_stylebox_override("hover", nav_active)
	$Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/HomeButton.add_theme_color_override("font_color", Color(0.96, 0.96, 1.0))
	$Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/SocialSection/SocialRow/DiscordButton.add_theme_stylebox_override("normal", _sidebar_button_style(Color(0.08, 0.085, 0.14, 0.74), Color(0.24, 0.25, 0.36, 0.72), 1))
	$Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/SocialSection/SocialRow/DiscordButton.add_theme_stylebox_override("hover", _sidebar_button_style(Color(0.12, 0.095, 0.22, 0.86), Color(0.42, 0.22, 0.82, 0.76), 1))
	$Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/SocialSection/SocialRow/DiscordButton.add_theme_stylebox_override("pressed", _sidebar_button_style(Color(0.07, 0.055, 0.13, 0.9), Color(0.42, 0.22, 0.82, 0.76), 1))
	$Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/SocialSection/SocialRow/DiscordButton.add_theme_constant_override("icon_max_width", 20)

	for nav_button in [
		$Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/PatchNotesButton,
		$Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/CreditsButton,
	]:
		nav_button.add_theme_stylebox_override("disabled", _panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 8, 0))
		nav_button.add_theme_color_override("font_disabled_color", Color(0.68, 0.70, 0.80, 0.82))

	_apply_button_style(check_button, false)
	_apply_refresh_button_style(check_button)
	_apply_button_style(update_button, false)
	_apply_button_style(gen5_sprites_button, false)
	_apply_button_style(play_button, true)
	$Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/UninstallButton.add_theme_color_override("font_color", Color(1.0, 0.68, 0.68, 1.0))
	$Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/UninstallButton.add_theme_color_override("font_hover_color", Color(1.0, 0.74, 0.74, 1.0))
	$Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/UninstallButton.add_theme_color_override("font_pressed_color", Color(1.0, 0.56, 0.56, 1.0))

	progress_bar.add_theme_stylebox_override("background", _panel_style(Color(0.14, 0.16, 0.27, 0.86), Color(0, 0, 0, 0), 7, 0))
	progress_bar.add_theme_stylebox_override("fill", _panel_style(Color(0.55, 0.26, 0.96, 1.0), Color(0, 0, 0, 0), 7, 0))
	log_label.add_theme_color_override("default_color", Color(0.80, 0.81, 0.88))


func _panel_style(background_color: Color, border_color: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = background_color
	style_box.border_color = border_color
	style_box.border_width_left = border_width
	style_box.border_width_top = border_width
	style_box.border_width_right = border_width
	style_box.border_width_bottom = border_width
	style_box.corner_radius_top_left = radius
	style_box.corner_radius_top_right = radius
	style_box.corner_radius_bottom_right = radius
	style_box.corner_radius_bottom_left = radius
	style_box.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	style_box.shadow_size = 12
	style_box.shadow_offset = Vector2(0, 6)
	return style_box


func _sidebar_button_style(background_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style_box := _panel_style(background_color, border_color, 8, border_width)
	style_box.content_margin_left = 14.0
	style_box.content_margin_right = 12.0
	style_box.content_margin_top = 8.0
	style_box.content_margin_bottom = 8.0
	style_box.shadow_size = 0
	style_box.shadow_offset = Vector2.ZERO
	return style_box


func _apply_button_style(button: Button, is_primary: bool) -> void:
	var normal_color := Color(0.075, 0.08, 0.13, 0.92)
	var border_color := Color(0.52, 0.26, 0.96, 0.95)
	if is_primary:
		normal_color = Color(0.48, 0.22, 0.92, 1.0)
		border_color = Color(0.72, 0.47, 1.0, 0.8)

	button.add_theme_stylebox_override("normal", _panel_style(normal_color, border_color, 8, 1))
	button.add_theme_stylebox_override("hover", _panel_style(normal_color.lightened(0.08), border_color.lightened(0.08), 8, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(normal_color.darkened(0.08), border_color, 8, 1))
	button.add_theme_stylebox_override("disabled", _panel_style(Color(0.08, 0.085, 0.14, 0.72), Color(0.26, 0.27, 0.4, 0.9), 8, 1))
	button.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.91, 0.86, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.46, 0.56))
	button.add_theme_font_size_override("font_size", 17)


func _apply_refresh_button_style(button: Button) -> void:
	button.custom_minimum_size = Vector2(52, 56)
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.065, 0.08, 0.13, 0.65), Color(0.20, 0.24, 0.40, 0.45), 10, 0))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.09, 0.11, 0.17, 0.78), Color(0.35, 0.22, 0.70, 0.7), 10, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.12, 0.15, 0.2, 0.82), Color(0.5, 0.24, 1.0, 0.85), 10, 1))
	button.add_theme_stylebox_override("disabled", _panel_style(Color(0.06, 0.07, 0.11, 0.45), Color(0.13, 0.14, 0.2, 0.4), 10, 0))
	button.add_theme_constant_override("icon_max_width", 24)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _process(_delta: float) -> void:
	_update_progress_percent()
	_sync_button_cursors()
	if http_request.get_http_client_status() == HTTPClient.STATUS_BODY:
		var downloaded_bytes: int = http_request.get_downloaded_bytes()
		var expected_bytes: int = 0
		if not current_download.is_empty():
			expected_bytes = int(current_download.get("size_bytes", 0))

		var total_bytes: int = expected_bytes
		if total_bytes <= 0:
			total_bytes = http_request.get_body_size()

		if total_bytes > 0:
			var progress_is_reliable := downloaded_bytes >= 0 and downloaded_bytes <= total_bytes
			if not progress_is_reliable:
				progress_is_indeterminate = true
				progress_bar.value = fmod(float(Time.get_ticks_msec()) / 18.0, 100.0)
				if not current_download.is_empty():
					_set_status(
						"Downloading %s... Large download in progress (%s)" % [
							_get_current_download_display_label(),
							_format_bytes(total_bytes),
						]
					)
				return

			progress_is_indeterminate = false
			var percent: float = minf((float(downloaded_bytes) / float(total_bytes)) * 100.0, 99.0)
			progress_bar.value = percent
			if not current_download.is_empty():
				_set_status(
					"Downloading %s... %s / %s (%d%%)" % [
						_get_current_download_display_label(),
						_format_bytes(downloaded_bytes),
						_format_bytes(total_bytes),
						int(percent),
					]
				)
		elif not current_download.is_empty():
			if downloaded_bytes < 0:
				progress_is_indeterminate = true
				progress_bar.value = fmod(float(Time.get_ticks_msec()) / 18.0, 100.0)
				_set_status(
					"Downloading %s... Large download in progress" % [
						_get_current_download_display_label(),
					]
				)
				return

			progress_is_indeterminate = false
			progress_bar.value = 0.0
			_set_status(
				"Downloading %s... %s" % [
					_get_current_download_display_label(),
					_format_bytes(maxi(downloaded_bytes, 0)),
				]
			)


func check_for_updates() -> void:
	_set_busy(true)
	_set_status("Checking for updates...")
	_log("Checking for updates.")
	http_request.download_file = ""
	var error_code: Error = http_request.request(manifest_url, _request_headers())
	if error_code != OK:
		_set_busy(false)
		_set_status("Could not request manifest.")
		_log_error("Manifest request failed: %s" % error_string(error_code))


func fetch_news() -> void:
	if news_request == null or news_url.is_empty():
		_render_news_items([])
		return

	var error_code: Error = news_request.request(news_url, _request_headers())
	if error_code != OK:
		_render_news_items([])
		_log_error("News request failed: %s" % error_string(error_code))


func start_update() -> void:
	if manifest.is_empty():
		check_for_updates()
		return

	_build_download_queue()
	_reset_download_progress_counters()
	if pending_downloads.is_empty():
		update_required = false
		_set_status("Already up to date.")
		_refresh_status()
		return

	_set_busy(true)
	update_button.disabled = true
	play_button.disabled = true
	_start_next_download()


func download_gen5_animated_sprites() -> void:
	if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_set_status("Wait until the current launcher task is finished.")
		return

	if manifest.is_empty():
		_set_status("Check for updates first.")
		check_for_updates()
		return

	_build_optional_gen5_download_queue()
	_reset_download_progress_counters()
	if pending_downloads.is_empty():
		_set_status("Gen 5 Animated sprites are already installed or unavailable.")
		_refresh_status()
		return

	_set_busy(true)
	update_button.disabled = true
	play_button.disabled = true
	gen5_sprites_button.disabled = true
	_start_next_download()


func launch_game() -> void:
	var game_data: Dictionary = _get_dictionary(manifest, "game")
	var absolute_executable_path := _get_game_executable_path(game_data)
	if not FileAccess.file_exists(absolute_executable_path):
		_set_status("Game executable not found. Run update first.")
		_log_error("Missing executable: %s" % absolute_executable_path)
		return

	var permission_error: Error = _ensure_executable_permissions(absolute_executable_path)
	if permission_error != OK:
		_set_status("Could not prepare game executable.")
		_log_error("Could not set executable permissions: %s" % error_string(permission_error))
		return

	_log("Starting game.")
	var process_id: int = _create_game_process(absolute_executable_path)
	if process_id <= 0:
		_set_status("Could not start game.")
		_log_error("OS.create_process failed.")
		return

	print("Started game process id: %s" % process_id)
	get_tree().quit()


func open_install_folder_dialog() -> void:
	if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_set_status("Wait until the current launcher task is finished.")
		return

	install_folder_dialog.current_dir = _globalize_storage_path(install_dir)
	install_folder_dialog.popup_centered()


func open_discord() -> void:
	var normalized_discord_url := _normalize_url(discord_url)
	if normalized_discord_url.is_empty():
		_set_status("Discord link is not configured.")
		return

	var open_error: Error = OS.shell_open(normalized_discord_url)
	if open_error != OK:
		_set_status("Could not open Discord link.")
		_log_error("Could not open Discord link '%s': %s" % [normalized_discord_url, error_string(open_error)])


func open_patch_notes() -> void:
	var normalized_patch_notes_url := _normalize_url(patch_notes_url)
	if normalized_patch_notes_url.is_empty():
		_set_status("Patch notes link is not configured.")
		return

	var open_error: Error = OS.shell_open(normalized_patch_notes_url)
	if open_error != OK:
		_set_status("Could not open patch notes link.")
		_log_error("Could not open patch notes link '%s': %s" % [normalized_patch_notes_url, error_string(open_error)])


func open_credits() -> void:
	var normalized_credits_url := _normalize_url(credits_url)
	if normalized_credits_url.is_empty():
		_set_status("Credits link is not configured.")
		return

	var open_error: Error = OS.shell_open(normalized_credits_url)
	if open_error != OK:
		_set_status("Could not open credits link.")
		_log_error("Could not open credits link '%s': %s" % [normalized_credits_url, error_string(open_error)])


func _start_launcher_update_download() -> void:
	if launcher_update_busy or launcher_update_in_progress:
		_set_status("Launcher update already in progress.")
		return

	if launcher_update_http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_set_status("Wait until the current launcher task is finished.")
		return

	var launcher_data: Dictionary = launcher_update_info
	if not launcher_update_pending:
		_set_status("No launcher update is available.")
		return

	if launcher_data.is_empty() or str(launcher_data.get("url", "")).is_empty():
		_set_status("Launcher update information is unavailable.")
		return

	var temp_dir := _globalize_storage_path(LAUNCHER_UPDATE_TEMP_DIR)
	var create_dir_error: Error = DirAccess.make_dir_recursive_absolute(temp_dir)
	if create_dir_error != OK:
		_set_status("Could not prepare launcher update temp folder.")
		_log_error("Could not create launcher update temp folder: %s" % error_string(create_dir_error))
		return

	var now_suffix := str(Time.get_ticks_msec())
	var update_file_name := "%s-%s.zip" % [LAUNCHER_UPDATE_ZIP_NAME_PREFIX, now_suffix]
	var download_path := temp_dir.path_join(update_file_name)
	launcher_update_http_request.download_file = download_path
	launcher_update_busy = true
	launcher_update_in_progress = false
	_set_busy(true)
	_set_status("Downloading launcher update...")
	var error_code: Error = launcher_update_http_request.request(str(launcher_data.get("url", "")), _request_headers())
	if error_code != OK:
		launcher_update_busy = false
		_set_status("Could not start launcher update download.")
		_log_error("Launcher update request failed: %s" % error_string(error_code))
		_set_busy(false)


func _on_uninstall_button_pressed() -> void:
	if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_set_status("Wait until the current launcher task is finished.")
		return

	var game_install_dir := _get_game_install_dir()
	var absolute_game_install_dir := _globalize_storage_path(game_install_dir)
	if not DirAccess.dir_exists_absolute(absolute_game_install_dir):
		_set_status("No installed game folder found.")
		_refresh_uninstall_button()
		return

	uninstall_confirm_dialog.dialog_text = "This will permanently remove the game folder:\n%s\n\nContinue?" % absolute_game_install_dir
	uninstall_confirm_dialog.popup_centered()


func _uninstall_game_folder() -> void:
	var game_install_dir := _get_game_install_dir()
	var absolute_game_install_dir := _globalize_storage_path(game_install_dir)
	if not DirAccess.dir_exists_absolute(absolute_game_install_dir):
		_set_status("No installed game folder found.")
		_refresh_uninstall_button()
		_refresh_status()
		return

	_set_busy(true)
	_set_status("Uninstalling game folder...")

	var remove_error: Error = _remove_directory_contents(absolute_game_install_dir)
	if remove_error == OK:
		remove_error = DirAccess.remove_absolute(absolute_game_install_dir)

	if remove_error != OK:
		_set_busy(false)
		_set_status("Could not uninstall game.")
		_log_error("Could not remove game folder %s: %s" % [absolute_game_install_dir, error_string(remove_error)])
		_build_download_queue()
		update_required = not pending_downloads.is_empty()
		_refresh_uninstall_button()
		_refresh_status()
		return

	_reset_local_versions()
	_save_local_versions()
	_build_download_queue()
	update_required = not pending_downloads.is_empty()
	_set_status("Game folder removed.")
	_set_busy(false)
	_refresh_uninstall_button()
	_refresh_status()
	_log("Game folder removed: %s" % absolute_game_install_dir)


func _on_install_folder_selected(selected_path: String) -> void:
	var selected_install_dir := selected_path.strip_edges()
	if selected_install_dir.is_empty():
		return

	var write_error := _ensure_install_dir_is_writable(selected_install_dir)
	if write_error != OK:
		_set_status("Selected install folder is not writable.")
		_log_error("Install folder is not writable: %s (%s)" % [selected_install_dir, error_string(write_error)])
		return

	if selected_install_dir == install_dir:
		_set_status("Install folder unchanged.")
		return

	install_dir = selected_install_dir
	_reset_local_versions()
	_save_launcher_settings()
	_save_local_versions()
	_build_download_queue()
	update_required = not pending_downloads.is_empty()
	_refresh_status()
	_set_status("Install folder changed. Run update to install there.")
	_log("Install folder changed: %s" % selected_install_dir)


func _create_game_process(absolute_executable_path: String) -> int:
	var game_dir: String = absolute_executable_path.get_base_dir()
	var executable_name: String = absolute_executable_path.get_file()
	var os_name: String = OS.get_name()
	if os_name == "Windows":
		var command: String = "cd /D %s && %s" % [
			_quote_windows_shell(game_dir),
			_quote_windows_shell(executable_name),
		]
		return OS.create_process("cmd.exe", PackedStringArray(["/C", command]))

	if os_name == "Linux" or os_name == "macOS" or os_name == "FreeBSD" or os_name == "NetBSD" or os_name == "OpenBSD" or os_name == "BSD":
		var command: String = "cd \"$1\" && exec \"./$2\""
		return OS.create_process("/bin/sh", PackedStringArray(["-c", command, "pokeaether-launcher", game_dir, executable_name]))

	return OS.create_process(absolute_executable_path, PackedStringArray())


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	progress_is_indeterminate = false
	progress_bar.value = 100.0
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_set_busy(false)
		var request_failure_message: String = _format_request_failure(result, response_code)
		_set_status(request_failure_message)
		_log_error("%s url=%s" % [request_failure_message, _get_active_request_url()])
		return

	if current_download.is_empty():
		_handle_manifest_response(body)
	else:
		_handle_download_response()


func _on_news_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_render_news_items([])
		_log_error("Could not load news. result=%s status=%s" % [result, response_code])
		return

	var news_text := body.get_string_from_utf8()
	var parsed_json: Variant = JSON.parse_string(news_text)
	if typeof(parsed_json) != TYPE_DICTIONARY:
		_render_news_items([])
		_log_error("News JSON must be an object.")
		return

	var news_data: Dictionary = parsed_json
	var parsed_items: Array[Dictionary] = []
	var item_variants: Variant = news_data.get("items") if news_data.has("items") else news_data.get("articles", [])
	if typeof(item_variants) == TYPE_ARRAY:
		for item_variant: Variant in item_variants:
			if typeof(item_variant) != TYPE_DICTIONARY:
				continue

			var item: Dictionary = item_variant
			var title := str(item.get("title", "")).strip_edges()
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
	log_label.clear()
	if news_items.is_empty():
		log_label.text = "No news available."
		return

	for index in range(mini(news_items.size(), 5)):
		var item := news_items[index]
		var title := _escape_bbcode(str(item.get("title", "")))
		var description := _escape_bbcode(str(item.get("description", "")))
		var url := str(item.get("url", ""))
		if not url.is_empty():
			log_label.append_text("[url=%d][color=#b779ff]%s[/color][/url]\n" % [index, title])
		else:
			log_label.append_text("[color=#b779ff]%s[/color]\n" % title)

		if not description.is_empty():
			log_label.append_text("[color=#cfd2df]%s[/color]\n" % description)

		if index < mini(news_items.size(), 5) - 1:
			log_label.append_text("\n")


func _on_news_meta_clicked(meta: Variant) -> void:
	var index := int(meta)
	if index < 0 or index >= news_items.size():
		return

	var url := _normalize_url(str(news_items[index].get("url", "")))
	if url.is_empty():
		return

	var open_error: Error = OS.shell_open(url)
	if open_error != OK:
		_log_error("Could not open news link '%s': %s" % [url, error_string(open_error)])


func _normalize_url(value: String) -> String:
	var normalized := value.strip_edges()
	if normalized.is_empty():
		return ""

	for scheme in KNOWN_URL_SCHEMES:
		if normalized.begins_with(scheme):
			return normalized

	if normalized.find("://") != -1:
		return normalized

	if normalized.begins_with("www."):
		return "https://%s" % normalized

	return ""


func _handle_manifest_response(body: PackedByteArray) -> void:
	var manifest_text := body.get_string_from_utf8()
	var parsed_json: Variant = JSON.parse_string(manifest_text)
	if typeof(parsed_json) != TYPE_DICTIONARY:
		_set_busy(false)
		_set_status("Manifest is invalid.")
		_log_error("Manifest JSON must be an object.")
		return

	manifest = parsed_json
	last_check_label.text = _format_last_check_time()
	launcher_update_info = _get_launcher_update_info()
	_build_download_queue()
	update_required = not pending_downloads.is_empty()
	_set_busy(false)
	_refresh_status()
	_refresh_launcher_update_status()
	if launcher_update_pending and not launcher_update_shown:
		launcher_update_shown = true
		launcher_update_confirm_dialog.dialog_text = "A new launcher version (%s) is available. Install it now?" % str(
			launcher_update_info.get("version", "unknown")
		)
		launcher_update_confirm_dialog.popup_centered()
	elif not launcher_update_pending:
		launcher_update_shown = false

	if update_required:
		_log("Update available.")
	else:
		_log("Everything is up to date.")


func _on_launcher_update_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if not launcher_update_busy:
		return

	launcher_update_busy = false
	_set_busy(false)
	var url := str(launcher_update_info.get("url", ""))
	var expected_sha256 := str(launcher_update_info.get("sha256", "")).to_lower()
	var downloaded_path := str(launcher_update_http_request.download_file)
	if downloaded_path.is_empty():
		_set_status("Launcher update failed: missing downloaded file path.")
		_log_error("Launcher update path missing for url=%s" % url)
		launch_restart_check_failed("Launcher update file path is missing.")
		return

	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_set_status("Launcher update download failed.")
		_log_error("Launcher update download failed. result=%s status=%s url=%s" % [result, response_code, url])
		launch_restart_check_failed("Could not download launcher update.")
		return

	var downloaded_file := FileAccess.open(downloaded_path, FileAccess.READ)
	if downloaded_file == null:
		_set_status("Launcher update failed: could not open downloaded file.")
		_log_error("Launcher update downloaded file could not be opened: %s" % downloaded_path)
		launch_restart_check_failed("Downloaded launcher file could not be opened.")
		return

	var downloaded_size: int = downloaded_file.get_length()
	downloaded_file.close()
	downloaded_file = null
	var expected_size: int = int(
		launcher_update_info.get("sizeBytes", launcher_update_info.get("size_bytes", 0))
	)
	if expected_size > 0 and downloaded_size != expected_size:
		_set_status("Launcher update download incomplete.")
		_log_error("Launcher update size mismatch for %s. expected=%s actual=%s" % [downloaded_path, expected_size, downloaded_size])
		launch_restart_check_failed("Launcher update download incomplete.")
		return

	if not expected_sha256.is_empty() and expected_sha256 != FileAccess.get_sha256(downloaded_path).to_lower():
		_set_status("Launcher update checksum failed.")
		_log_error("Launcher update checksum mismatch.")
		launch_restart_check_failed("Launcher update checksum failed.")
		return

	launcher_update_in_progress = true
	_set_status("Applying launcher update...")
	var updater_process_id: int = _write_and_run_launcher_update_script(downloaded_path)
	if updater_process_id <= 0:
		launcher_update_in_progress = false
		_set_status("Could not start launcher updater.")
		launch_restart_check_failed("Could not start launcher updater script.")
		return

	# The Windows updater must remain alive while this process still owns the
	# launcher files. Merely receiving a PID is insufficient: a malformed cmd
	# command can start and exit before the launcher closes, leaving users with
	# no update and no restarted launcher.
	await get_tree().create_timer(0.35).timeout
	if not OS.is_process_running(updater_process_id):
		launcher_update_in_progress = false
		_set_status("Could not keep launcher updater running.")
		_log_error("Launcher updater exited before launcher shutdown. process_id=%s" % updater_process_id)
		launch_restart_check_failed("Launcher updater stopped before applying the update.")
		return

	_set_status("Launcher update downloaded. Restarting launcher...")
	if OS.get_name() == "Windows":
		# A graceful tree quit can leave the Windows Godot process alive after
		# its window has disappeared. The external updater is already verified
		# above and is waiting on this exact PID, so terminate this process
		# explicitly to release the executable and PCK file locks.
		var terminate_error := OS.kill(OS.get_process_id())
		if terminate_error != OK:
			launcher_update_in_progress = false
			_log_error("Could not terminate Windows launcher for update: %s" % error_string(terminate_error))
			launch_restart_check_failed("Could not close the launcher for updating.")
		return
	get_tree().quit()


func _refresh_launcher_update_status() -> void:
	var local_launcher_version := _get_local_launcher_version()
	var remote_version := str(launcher_update_info.get("version", ""))
	var remote_url := str(launcher_update_info.get("url", ""))

	launcher_update_pending = false
	if remote_version.is_empty() or remote_url.is_empty():
		launcher_update_shown = false
		return

	launcher_update_pending = _is_newer_version(remote_version, local_launcher_version)
	if launcher_update_pending:
		_log("Launcher update available: %s -> %s" % [local_launcher_version, remote_version])
	else:
		launcher_update_shown = false


func _get_launcher_update_info() -> Dictionary:
	var update_data := _get_dictionary(manifest, "launcher")
	if update_data.is_empty():
		update_data = _get_dictionary(manifest, "launcherUpdate")
	if update_data.is_empty():
		update_data = _get_dictionary(manifest, "launcher_update")

	if update_data.is_empty():
		update_data = {}

	var fallback_version := str(manifest.get("launcherVersion", manifest.get("launcher_version", "")))
	var fallback_url := str(manifest.get("launcherUrl", manifest.get("launcher_url", "")))
	var fallback_sha := str(manifest.get("launcherSha256", manifest.get("launcherHash", "")))
	var fallback_size := int(manifest.get("launcherSizeBytes", manifest.get("launcherSize", 0)))
	var fallback_manifest_value: Variant = manifest.get("launcher", "")
	if typeof(fallback_manifest_value) == TYPE_STRING:
		var fallback_url_candidate := str(fallback_manifest_value).strip_edges()
		if not fallback_url_candidate.is_empty():
			fallback_url = fallback_url_candidate

	var package_data := _get_dictionary(manifest, "package")
	if update_data.is_empty() and not package_data.is_empty():
		update_data = package_data

	var update_version := _read_first_string(update_data, ["version", "launcherVersion", "launcher_version"])
	if update_version.is_empty():
		update_version = fallback_version.strip_edges()

	var update_url := _read_first_string(update_data, ["url", "downloadUrl", "download_url", "uri", "path"])
	var platform_urls := _get_dictionary(update_data, "urls")
	if update_url.is_empty():
		update_url = _get_platform_manifest_url(platform_urls)
	if update_url.is_empty():
		update_url = _get_platform_manifest_url(_get_dictionary(update_data, "platformUrls"))
	if update_url.is_empty():
		update_url = _read_first_string(update_data, ["urlWindows", "urlLinux", "urlMacOS"])
	if update_url.is_empty():
		update_url = fallback_url.strip_edges()

	var update_binary := _read_first_string(
		update_data,
		["binary", "executable", "launcherBinary", "binaryName", "file", "filename"]
	)
	if update_binary.is_empty():
		update_binary = _read_first_string(package_data, ["binary", "executable", "launcherBinary"])

	var update_size := _read_first_int(update_data, ["sizeBytes", "size_bytes", "size"])
	if update_size <= 0:
		update_size = _read_first_int(package_data, ["sizeBytes", "size_bytes", "size"])
	if update_size <= 0:
		update_size = fallback_size

	var update_sha := _read_first_string(update_data, ["sha256", "sha", "checksum", "hash", "digest"])
	if update_sha.is_empty():
		update_sha = _read_first_string(package_data, ["sha256", "sha", "checksum", "hash", "digest"])
	if update_sha.is_empty():
		update_sha = fallback_sha

	return {
		"version": update_version.strip_edges(),
		"url": _normalize_url(update_url),
		"sha256": update_sha.to_lower(),
		"sizeBytes": update_size,
		"binary": update_binary.strip_edges(),
	}


func _read_first_string(value_map: Dictionary, keys: Array) -> String:
	for key_index: int in range(keys.size()):
		var key: Variant = keys[key_index]
		var candidate: Variant = value_map.get(key, "")
		var candidate_text := str(candidate).strip_edges()
		if not candidate_text.is_empty():
			return candidate_text
	return ""


func _read_first_int(value_map: Dictionary, keys: Array) -> int:
	for key_index: int in range(keys.size()):
		var key: Variant = keys[key_index]
		var candidate: Variant = value_map.get(key, 0)
		if typeof(candidate) == TYPE_INT:
			return int(candidate)
		if typeof(candidate) == TYPE_FLOAT:
			return int(candidate)

		var candidate_text := str(candidate).strip_edges()
		if candidate_text.is_empty():
			continue

		var matcher := RegEx.create_from_string("\\d+")
		var search := matcher.search(candidate_text)
		if search != null:
			return int(search.get_string())
		if candidate_text.is_valid_int():
			return candidate_text.to_int()
	return 0


func _is_newer_version(remote_version: String, local_version: String) -> bool:
	var compare_result := _compare_version_parts(_parse_version(remote_version), _parse_version(local_version))
	return compare_result > 0


func _parse_version(version: String) -> PackedInt32Array:
	var parsed: PackedInt32Array = PackedInt32Array()
	var raw_parts := version.strip_edges().split(".")
	for raw_part in raw_parts:
		if parsed.size() >= MAX_VERSION_SEGMENTS:
			break

		var normalized_part := str(raw_part).strip_edges()
		var matcher := RegEx.create_from_string("\\d+")
		var match := matcher.search(normalized_part)
		if match == null:
			parsed.append(0)
			continue

		parsed.append(int(match.get_string()))

	while parsed.size() < MAX_VERSION_SEGMENTS:
		parsed.append(0)

	return parsed


func _compare_version_parts(left: PackedInt32Array, right: PackedInt32Array) -> int:
	var index_count := maxi(left.size(), right.size())
	for index in range(index_count):
		var left_value := left[index] if index < left.size() else 0
		var right_value := right[index] if index < right.size() else 0
		if left_value > right_value:
			return 1
		if left_value < right_value:
			return -1

	return 0


func _get_local_launcher_version() -> String:
	var local_version := str(ProjectSettings.get_setting("application/config/version", "0.0.0")).strip_edges()
	if local_version.is_empty():
		return "0.0.0"

	return local_version


func launch_restart_check_failed(reason: String) -> void:
	launcher_update_busy = false
	launcher_update_in_progress = false
	_set_status("%s You can retry from launcher update prompt." % reason)
	_cleanup_launcher_update_files()
	_set_busy(false)


func _cleanup_launcher_update_files() -> void:
	_delete_existing_download(str(launcher_update_http_request.download_file))
	launcher_update_shown = false
	var temp_dir := _globalize_storage_path(LAUNCHER_UPDATE_TEMP_DIR)
	if DirAccess.dir_exists_absolute(temp_dir):
		_remove_directory_contents(temp_dir)


func _write_and_run_launcher_update_script(downloaded_path: String) -> int:
	if not FileAccess.file_exists(downloaded_path):
		_log_error("Launcher update package missing before launch: %s" % downloaded_path)
		return -1

	var launcher_binary_path := _globalize_storage_path(OS.get_executable_path())
	if launcher_binary_path.is_empty():
		_log_error("Could not resolve running launcher executable path.")
		return -1

	var target_dir := launcher_binary_path.get_base_dir()
	var temp_dir := _globalize_storage_path(LAUNCHER_UPDATE_TEMP_DIR)
	var staging_dir := temp_dir.path_join(LAUNCHER_UPDATE_STAGING_SUBDIR)

	var make_dir_error: Error = _clear_directory(staging_dir)
	if make_dir_error != OK:
		_log_error("Could not prepare launcher staging dir: %s" % error_string(make_dir_error))
		return -1

	var extract_error: Error = _extract_launcher_update_zip(downloaded_path, staging_dir)
	if extract_error != OK:
		_log_error("Could not extract launcher update package: %s" % error_string(extract_error))
		_cleanup_launcher_update_files()
		return -1

	var launcher_binary_name := _read_first_string(launcher_update_info, ["binary"])
	if launcher_binary_name.is_empty():
		launcher_binary_name = _derive_launcher_binary_name()
	var packaged_binary_path := ""
	if launcher_binary_name.find("/") != -1 or launcher_binary_name.find("\\") != -1:
		packaged_binary_path = staging_dir.path_join(launcher_binary_name)
	else:
		packaged_binary_path = _find_file_case_insensitive(staging_dir, launcher_binary_name)
	if packaged_binary_path.is_empty():
		_log_error("Could not find launcher binary in update package.")
		_cleanup_launcher_update_files()
		return -1

	var packaged_binary_relative_path := _get_relative_path(packaged_binary_path, staging_dir)
	var updated_launcher_path := target_dir.path_join(packaged_binary_relative_path)

	var os_name := OS.get_name()
	var script_path := temp_dir.path_join(LAUNCHER_UPDATE_UNIX_SCRIPT)
	if os_name == "Windows":
		script_path = temp_dir.path_join(LAUNCHER_UPDATE_WINDOWS_SCRIPT)

	var script_text := ""
	if os_name == "Windows":
		var launcher_process_id := OS.get_process_id()
		var launcher_exe_backup := "%s.bak" % launcher_binary_path
		var launcher_pck_path := launcher_binary_path.get_basename() + ".pck"
		var launcher_pck_backup := "%s.bak" % launcher_pck_path
		script_text = """@echo off
setlocal
set "LAUNCHER_EXE=%s"
set "LAUNCHER_EXE_BAK=%s"
set "LAUNCHER_PCK=%s"
set "LAUNCHER_PCK_BAK=%s"
set "UPDATED_LAUNCHER_EXE=%s"
set "LAUNCHER_DIR=%s"
set "UPDATE_DIR=%s"
set "LAUNCHER_PID=%s"
set "UPDATE_LOG=%%~dp0launcher_update_windows.log"

echo [launcher] updater started > "%%UPDATE_LOG%%"
echo [launcher] launcher exe: %%LAUNCHER_EXE%% >> "%%UPDATE_LOG%%"
echo [launcher] update dir: %%UPDATE_DIR%% >> "%%UPDATE_LOG%%"
set /A WAIT_ATTEMPTS=0

:WAIT
tasklist /FI "PID eq %%LAUNCHER_PID%%" /NH | find "%%LAUNCHER_PID%%" >nul
if not errorlevel 1 (
	set /A WAIT_ATTEMPTS+=1
	if %%WAIT_ATTEMPTS%% GEQ 60 (
		echo [launcher] launcher process did not exit within 60 seconds. >> "%%UPDATE_LOG%%"
		exit /b 1
	)
	echo [launcher] waiting for launcher process to exit... >> "%%UPDATE_LOG%%"
	timeout /t 1 /nobreak >nul
	goto WAIT
)

if not exist "%%UPDATE_DIR%%" (
	echo [launcher] update directory not found: %%UPDATE_DIR%% >> "%%UPDATE_LOG%%"
	exit /b 1
)

if not exist "%%LAUNCHER_EXE%%" (
	echo [launcher] launcher executable not found: %%LAUNCHER_EXE%% >> "%%UPDATE_LOG%%"
	exit /b 1
)

echo [launcher] copying update files... >> "%%UPDATE_LOG%%"
copy /Y "%%LAUNCHER_EXE%%" "%%LAUNCHER_EXE_BAK%%" >> "%%UPDATE_LOG%%" 2>&1
if errorlevel 1 (
	echo [launcher] could not back up launcher executable. >> "%%UPDATE_LOG%%"
	exit /b 1
)
if exist "%%LAUNCHER_PCK%%" (
	copy /Y "%%LAUNCHER_PCK%%" "%%LAUNCHER_PCK_BAK%%" >> "%%UPDATE_LOG%%" 2>&1
	if errorlevel 1 (
		del /F /Q "%%LAUNCHER_EXE_BAK%%" >nul 2>nul
		echo [launcher] could not back up launcher package. >> "%%UPDATE_LOG%%"
		exit /b 1
	)
)
robocopy "%%UPDATE_DIR%%" "%%LAUNCHER_DIR%%" /E /R:30 /W:1 /NFL /NDL /NJH /NJS /NP >> "%%UPDATE_LOG%%" 2>&1
set "COPY_EXIT=%%ERRORLEVEL%%"
echo [launcher] robocopy exit code: %%COPY_EXIT%% >> "%%UPDATE_LOG%%"
if %%COPY_EXIT%% GEQ 8 (
	copy /Y "%%LAUNCHER_EXE_BAK%%" "%%LAUNCHER_EXE%%" >> "%%UPDATE_LOG%%" 2>&1
	if exist "%%LAUNCHER_PCK_BAK%%" copy /Y "%%LAUNCHER_PCK_BAK%%" "%%LAUNCHER_PCK%%" >> "%%UPDATE_LOG%%" 2>&1
	del /F /Q "%%LAUNCHER_EXE_BAK%%" >nul 2>nul
	del /F /Q "%%LAUNCHER_PCK_BAK%%" >nul 2>nul
	echo [launcher] copy failed, restoring launcher executable. >> "%%UPDATE_LOG%%"
	start "" "%%LAUNCHER_EXE%%"
	rmdir /S /Q "%%UPDATE_DIR%%" >nul 2>nul
	exit /b 1
)
del /F /Q "%%LAUNCHER_EXE_BAK%%" >nul 2>nul
del /F /Q "%%LAUNCHER_PCK_BAK%%" >nul 2>nul
echo [launcher] starting updated launcher... >> "%%UPDATE_LOG%%"
if exist "%%UPDATED_LAUNCHER_EXE%%" (
	if /I not "%%LAUNCHER_EXE%%"=="%%UPDATED_LAUNCHER_EXE%%" (
		del /F /Q "%%LAUNCHER_EXE%%" >nul 2>nul
		del /F /Q "%%LAUNCHER_PCK%%" >nul 2>nul
	)
	start "" "%%UPDATED_LAUNCHER_EXE%%"
) else (
	echo [launcher] updated launcher path missing, starting original path. >> "%%UPDATE_LOG%%"
	start "" "%%LAUNCHER_EXE%%"
)
rmdir /S /Q "%%UPDATE_DIR%%" >nul 2>nul
echo [launcher] updater finished. >> "%%UPDATE_LOG%%"
exit /b 0
""" % [launcher_binary_path, launcher_exe_backup, launcher_pck_path, launcher_pck_backup, updated_launcher_path, target_dir, staging_dir, launcher_process_id]
	else:
		var launcher_exe_backup := "%s.bak" % launcher_binary_path
		var launcher_pck_path := launcher_binary_path.get_basename() + ".pck"
		script_text = """#!/bin/sh
LAUNCHER_EXE=\"%s\"
LAUNCHER_EXE_BAK=\"%s\"
LAUNCHER_PCK=\"%s\"
UPDATED_LAUNCHER_EXE=\"%s\"
LAUNCHER_DIR=\"%s\"
UPDATE_DIR=\"%s\"

sleep 1
if [ ! -d \"$UPDATE_DIR\" ]; then
  echo \"[launcher] update directory not found: $UPDATE_DIR\"
  exit 1
fi

cp -f \"$LAUNCHER_EXE\" \"$LAUNCHER_EXE_BAK\"
if ! cp -a \"$UPDATE_DIR\"/. \"$LAUNCHER_DIR\"/; then
  if [ -f \"$LAUNCHER_EXE_BAK\" ]; then
    cp -a \"$LAUNCHER_EXE_BAK\" \"$LAUNCHER_EXE\"
    rm -f \"$LAUNCHER_EXE_BAK\"
  fi
  echo \"[launcher] copy failed, restoring executable.\"
  exec \"$LAUNCHER_EXE\"
fi

rm -f \"$LAUNCHER_EXE_BAK\"
if [ -f \"$UPDATED_LAUNCHER_EXE\" ]; then
  chmod +x \"$UPDATED_LAUNCHER_EXE\"
  if [ \"$LAUNCHER_EXE\" != \"$UPDATED_LAUNCHER_EXE\" ]; then
    rm -f \"$LAUNCHER_EXE\" \"$LAUNCHER_PCK\"
  fi
  \"$UPDATED_LAUNCHER_EXE\" &
else
  chmod +x \"$LAUNCHER_EXE\"
  \"$LAUNCHER_EXE\" &
fi
rm -rf \"$UPDATE_DIR\"
""" % [launcher_binary_path, launcher_exe_backup, launcher_pck_path, updated_launcher_path, target_dir, staging_dir]

	var script_file := FileAccess.open(script_path, FileAccess.WRITE)
	if script_file == null:
		_log_error("Could not write launcher update script.")
		return -1

	script_file.store_string(script_text)
	script_file = null

	var exec_args := PackedStringArray()
	var launcher_command := ""
	if os_name == "Windows":
		exec_args = PackedStringArray(["/D", "/C", script_path])
		launcher_command = "cmd.exe"
	else:
		_exec_make_executable(script_path)
		exec_args = PackedStringArray(["-c", "\"%s\"" % script_path])
		launcher_command = "/bin/sh"

	var process_id: int = OS.create_process(launcher_command, exec_args)
	if process_id <= 0:
		_log_error("Could not start launcher update process.")
		_cleanup_launcher_update_files()
		return -1

	_log("Launcher updater started with process_id=%s." % process_id)
	return process_id


func _get_relative_path(path: String, base_path: String) -> String:
	var normalized_path := path.replace("\\", "/")
	var normalized_base := base_path.replace("\\", "/")
	while normalized_base.ends_with("/"):
		normalized_base = normalized_base.substr(0, normalized_base.length() - 1)
	var prefix := normalized_base + "/"
	if normalized_path.begins_with(prefix):
		return normalized_path.substr(prefix.length())

	return path.get_file()


func _derive_launcher_binary_name() -> String:
	if OS.get_name() == "Windows":
		return WINDOWS_LAUNCHER_BINARY
	if OS.get_name() == "macOS":
		return MACOS_LAUNCHER_BINARY
	return LINUX_LAUNCHER_BINARY


func _find_file_case_insensitive(root_path: String, file_name: String) -> String:
	var queue: Array[String] = [root_path]
	while not queue.is_empty():
		var current_dir: String = queue.pop_front()
		var directory := DirAccess.open(current_dir)
		if directory == null:
			continue

		directory.list_dir_begin()
		var entry_name: String = directory.get_next()
		while not entry_name.is_empty():
			if entry_name == "." or entry_name == "..":
				entry_name = directory.get_next()
				continue

			var entry_path: String = current_dir.path_join(entry_name)
			if directory.current_is_dir():
				queue.append(entry_path)
			elif entry_name.to_lower() == file_name.to_lower():
				return entry_path

			entry_name = directory.get_next()
		directory.list_dir_end()

	return ""


func _extract_launcher_update_zip(zip_path: String, target_dir: String) -> Error:
	var reader := ZIPReader.new()
	var open_error: Error = reader.open(zip_path)
	if open_error != OK:
		return open_error

	var packed_file_paths: PackedStringArray = reader.get_files()
	for packed_file_path: String in packed_file_paths:
		if packed_file_path.ends_with("/"):
			continue

		var output_path := target_dir.path_join(packed_file_path)
		var absolute_output_path := _globalize_storage_path(output_path)
		DirAccess.make_dir_recursive_absolute(absolute_output_path.get_base_dir())

		if FileAccess.file_exists(absolute_output_path):
			var remove_error: Error = DirAccess.remove_absolute(absolute_output_path)
			if remove_error != OK:
				reader.close()
				return remove_error

		var output_file := FileAccess.open(absolute_output_path, FileAccess.WRITE)
		if output_file == null:
			reader.close()
			return ERR_CANT_CREATE

		output_file.store_buffer(reader.read_file(packed_file_path))
		output_file.close()
	reader.close()
	return OK


func _exec_make_executable(path: String) -> void:
	if OS.get_name() == "Windows":
		return
	OS.execute("chmod", PackedStringArray(["+x", path]), [])


func _handle_download_response() -> void:
	progress_is_indeterminate = false
	var file_path := str(current_download.get("file_path", ""))
	var sha256 := str(current_download.get("sha256", ""))
	if not FileAccess.file_exists(file_path):
		_set_busy(false)
		_set_status("Downloaded file is missing.")
		_log_error("Downloaded file is missing.")
		current_download.clear()
		return

	if not sha256.is_empty() and FileAccess.get_sha256(file_path) != sha256:
		_set_busy(false)
		_set_status("Downloaded file checksum failed.")
		_log_error("Downloaded file checksum failed.")
		current_download.clear()
		return

	var download_label: String = _get_current_download_display_label()
	_set_status("Extracting %s..." % download_label)
	_log("Extracting %s." % download_label)
	await get_tree().process_frame

	var extract_target_dir: String = _get_download_extract_dir(current_download)
	if str(current_download.get("type", "")) == "game":
		var clear_error: Error = _clear_directory(extract_target_dir)
		if clear_error != OK:
			_set_busy(false)
			_set_status("Could not prepare game folder.")
			_log_error("Could not clear game folder: %s" % error_string(clear_error))
			current_download.clear()
			return

	var extract_error: Error = await _extract_zip(file_path, extract_target_dir, download_label)
	if extract_error != OK:
		_set_busy(false)
		_set_status("Could not extract update.")
		_log_error("Extract failed: %s" % error_string(extract_error))
		current_download.clear()
		return

	_delete_existing_download(file_path)
	_mark_download_installed(current_download)
	current_download.clear()
	_start_next_download()


func _start_next_download() -> void:
	if pending_downloads.is_empty():
		progress_is_indeterminate = false
		_reset_download_progress_counters()
		_save_local_versions()
		update_required = false
		_set_busy(false)
		_refresh_status()
		_set_status("Update complete.")
		_log("Update complete.")
		return

	current_download = pending_downloads.pop_front()
	_prepare_current_download_progress()
	var url := str(current_download.get("url", ""))
	var file_name := str(current_download.get("file_name", "download.zip"))
	var unique_file_name := "%s-%s.zip" % [file_name.get_basename(), Time.get_ticks_msec()]
	var target_path := TEMP_DIR.path_join(unique_file_name)
	current_download["file_path"] = target_path
	progress_is_indeterminate = false
	progress_bar.value = 0.0

	DirAccess.make_dir_recursive_absolute(_globalize_storage_path(TEMP_DIR))
	var download_label: String = _get_current_download_display_label()
	_set_status("Downloading %s..." % download_label)
	_log("Downloading %s." % download_label)
	http_request.download_file = target_path
	var error_code: Error = http_request.request(url, _request_headers())
	if error_code != OK:
		_set_busy(false)
		_set_status("Could not start download.")
		_log_error("Download request failed: %s" % error_string(error_code))
		current_download.clear()


func _request_headers() -> PackedStringArray:
	return PackedStringArray([USER_AGENT_HEADER])


func _build_download_queue() -> void:
	pending_downloads.clear()
	if manifest.is_empty():
		return

	var game_data: Dictionary = _get_dictionary(manifest, "game")
	var remote_game_version := str(game_data.get("version", manifest.get("gameVersion", "")))
	var local_game_missing := not _has_installed_game_for_manifest(game_data)
	if remote_game_version != "" and (str(local_versions.get("gameVersion", "")) != remote_game_version or local_game_missing):
		pending_downloads.append({
			"type": "game",
			"id": "game",
			"version": remote_game_version,
			"url": str(game_data.get("url", "")),
			"sha256": str(game_data.get("sha256", "")),
			"size_bytes": int(game_data.get("sizeBytes", 0)),
			"file_name": "game-%s.zip" % remote_game_version,
			"label": "game %s" % remote_game_version,
		})

	var asset_packs_variant: Variant = manifest.get("assetPacks", [])
	var asset_packs: Array = []
	if typeof(asset_packs_variant) == TYPE_ARRAY:
		asset_packs = asset_packs_variant

	var local_asset_packs: Dictionary = _get_dictionary(local_versions, "assetPacks")
	for asset_pack_variant: Variant in asset_packs:
		if typeof(asset_pack_variant) != TYPE_DICTIONARY:
			continue

		var asset_pack: Dictionary = asset_pack_variant
		if _is_optional_asset_pack(asset_pack) and not _should_auto_update_optional_asset_pack(asset_pack):
			continue

		var pack_id := str(asset_pack.get("id", ""))
		var pack_version := str(asset_pack.get("version", ""))
		if pack_id.is_empty() or pack_version.is_empty():
			continue

		if _is_asset_pack_installed(asset_pack, local_asset_packs):
			continue

		pending_downloads.append({
			"type": "asset_pack",
			"id": pack_id,
			"version": pack_version,
			"url": str(asset_pack.get("url", "")),
			"sha256": str(asset_pack.get("sha256", "")),
			"size_bytes": int(asset_pack.get("sizeBytes", 0)),
			"file_name": "%s-%s.zip" % [pack_id, pack_version],
			"label": pack_id,
		})

	var filtered_downloads: Array[Dictionary] = []
	for download: Dictionary in pending_downloads:
		if not str(download.get("url", "")).is_empty():
			filtered_downloads.append(download)

	pending_downloads = filtered_downloads


func _build_optional_gen5_download_queue() -> void:
	pending_downloads.clear()
	if manifest.is_empty():
		return

	var local_asset_packs: Dictionary = _get_dictionary(local_versions, "assetPacks")
	for asset_pack: Dictionary in _get_gen5_asset_packs():
		var pack_id := str(asset_pack.get("id", ""))
		var pack_version := str(asset_pack.get("version", ""))
		if pack_id.is_empty() or pack_version.is_empty():
			continue

		if str(local_asset_packs.get(pack_id, "")) == pack_version:
			continue

		var pack_url := str(asset_pack.get("url", ""))
		if pack_url.is_empty():
			continue

		pending_downloads.append({
			"type": "asset_pack",
			"id": pack_id,
			"version": pack_version,
			"url": pack_url,
			"sha256": str(asset_pack.get("sha256", "")),
			"size_bytes": int(asset_pack.get("sizeBytes", 0)),
			"file_name": "%s-%s.zip" % [pack_id, pack_version],
			"label": str(asset_pack.get("label", "Gen 5 Animated Sprites")),
		})


func _get_gen5_asset_packs() -> Array[Dictionary]:
	var packs: Array[Dictionary] = []
	var asset_packs_variant: Variant = manifest.get("assetPacks", [])
	if typeof(asset_packs_variant) != TYPE_ARRAY:
		return packs

	for asset_pack_variant: Variant in asset_packs_variant:
		if typeof(asset_pack_variant) != TYPE_DICTIONARY:
			continue

		var asset_pack: Dictionary = asset_pack_variant
		if _is_gen5_asset_pack(asset_pack):
			packs.append(asset_pack)

	return packs


func _is_optional_asset_pack(asset_pack: Dictionary) -> bool:
	return bool(asset_pack.get("optional", false)) or _is_gen5_asset_pack(asset_pack)


func _is_gen5_asset_pack(asset_pack: Dictionary) -> bool:
	return str(asset_pack.get("id", "")).begins_with(GEN5_OPTIONAL_ASSET_PACK_PREFIX)


func _is_asset_pack_installed(asset_pack: Dictionary, local_asset_packs: Dictionary) -> bool:
	var pack_id := str(asset_pack.get("id", ""))
	var pack_version := str(asset_pack.get("version", ""))
	if pack_id.is_empty() or pack_version.is_empty():
		return false

	if str(local_asset_packs.get(pack_id, "")) != pack_version:
		return false

	return _has_asset_pack_required_path(pack_id)


func _has_asset_pack_required_path(pack_id: String) -> bool:
	var required_path := str(ASSET_PACK_REQUIRED_PATHS.get(pack_id, ""))
	if required_path.is_empty():
		return true

	return DirAccess.dir_exists_absolute(_globalize_storage_path(install_dir.path_join(required_path)))


func _reset_download_progress_counters() -> void:
	asset_pack_download_total = 0
	current_asset_pack_download_index = 0
	for download: Dictionary in pending_downloads:
		if str(download.get("type", "")) == "asset_pack":
			asset_pack_download_total += 1


func _prepare_current_download_progress() -> void:
	if str(current_download.get("type", "")) != "asset_pack":
		return

	current_asset_pack_download_index += 1
	current_download["asset_pack_index"] = current_asset_pack_download_index
	current_download["asset_pack_total"] = asset_pack_download_total


func _get_current_download_display_label() -> String:
	var label: String = str(current_download.get("label", current_download.get("file_name", "download")))
	if str(current_download.get("type", "")) != "asset_pack":
		return label

	var asset_pack_index: int = int(current_download.get("asset_pack_index", current_asset_pack_download_index))
	var asset_pack_total: int = int(current_download.get("asset_pack_total", asset_pack_download_total))
	if asset_pack_total <= 0:
		return "asset pack: %s" % label

	return "asset pack %d/%d: %s" % [asset_pack_index, asset_pack_total, label]


func _get_download_extract_dir(download: Dictionary) -> String:
	var download_type := str(download.get("type", ""))
	if download_type == "game":
		return _get_game_install_dir()

	return install_dir


func _mark_download_installed(download: Dictionary) -> void:
	var download_type := str(download.get("type", ""))
	if download_type == "game":
		local_versions["gameVersion"] = str(download.get("version", ""))
		var game_data: Dictionary = _get_dictionary(manifest, "game")
		local_versions["gameExecutable"] = str(game_data.get("executable", ""))
	elif download_type == "asset_pack":
		var local_asset_packs: Dictionary = _get_dictionary(local_versions, "assetPacks")
		local_asset_packs[str(download.get("id", ""))] = str(download.get("version", ""))
		local_versions["assetPacks"] = local_asset_packs


func _extract_zip(zip_path: String, target_dir: String, label: String) -> Error:
	progress_is_indeterminate = false
	var reader := ZIPReader.new()
	var open_error: Error = reader.open(zip_path)
	if open_error != OK:
		return open_error

	var packed_file_paths: PackedStringArray = reader.get_files()
	var file_count: int = packed_file_paths.size()
	var extracted_file_count: int = 0
	progress_bar.value = 0.0

	for packed_file_path: String in packed_file_paths:
		if packed_file_path.ends_with("/"):
			continue

		extracted_file_count += 1
		if extracted_file_count == 1 or extracted_file_count % EXTRACT_PROGRESS_BATCH_SIZE == 0:
			var percent: float = 0.0
			if file_count > 0:
				percent = minf((float(extracted_file_count) / float(file_count)) * 100.0, 99.0)
			progress_bar.value = percent
			_set_status(
				"Extracting %s... %d / %d files (%d%%)" % [
					label,
					extracted_file_count,
					file_count,
					int(percent),
				]
			)
			await get_tree().process_frame

		var output_path := target_dir.path_join(packed_file_path)
		var absolute_output_path := _globalize_storage_path(output_path)
		DirAccess.make_dir_recursive_absolute(absolute_output_path.get_base_dir())

		if FileAccess.file_exists(absolute_output_path):
			var remove_error: Error = DirAccess.remove_absolute(absolute_output_path)
			if remove_error != OK:
				reader.close()
				_log_error("Could not replace existing file: %s (%s)" % [absolute_output_path, error_string(remove_error)])
				return remove_error

		var output_file := FileAccess.open(absolute_output_path, FileAccess.WRITE)
		if output_file == null:
			reader.close()
			_log_error("Could not create extracted file: %s" % absolute_output_path)
			return ERR_CANT_CREATE

		output_file.store_buffer(reader.read_file(packed_file_path))

	reader.close()
	progress_bar.value = 100.0
	return OK


func _clear_directory(target_dir: String) -> Error:
	var absolute_target_dir: String = _globalize_storage_path(target_dir)
	if not DirAccess.dir_exists_absolute(absolute_target_dir):
		return DirAccess.make_dir_recursive_absolute(absolute_target_dir)

	var clear_error: Error = _remove_directory_contents(absolute_target_dir)
	if clear_error != OK:
		return clear_error

	return DirAccess.make_dir_recursive_absolute(absolute_target_dir)


func _remove_directory_contents(absolute_dir: String) -> Error:
	var directory: DirAccess = DirAccess.open(absolute_dir)
	if directory == null:
		return ERR_CANT_OPEN

	directory.list_dir_begin()
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		if entry_name == "." or entry_name == "..":
			entry_name = directory.get_next()
			continue

		var entry_path: String = absolute_dir.path_join(entry_name)
		var remove_error: Error = OK
		if directory.current_is_dir():
			remove_error = _remove_directory_contents(entry_path)
			if remove_error == OK:
				remove_error = DirAccess.remove_absolute(entry_path)
		else:
			remove_error = DirAccess.remove_absolute(entry_path)

		if remove_error != OK:
			directory.list_dir_end()
			return remove_error

		entry_name = directory.get_next()

	directory.list_dir_end()
	return OK


func _delete_existing_download(download_path: String) -> void:
	if not FileAccess.file_exists(download_path):
		return

	var absolute_download_path := _globalize_storage_path(download_path)
	var remove_error: Error = DirAccess.remove_absolute(absolute_download_path)
	if remove_error != OK:
		_log_error("Could not remove old download: %s" % error_string(remove_error))


func _ensure_executable_permissions(absolute_executable_path: String) -> Error:
	var os_name := OS.get_name()
	if os_name != "Linux" and os_name != "macOS" and os_name != "FreeBSD" and os_name != "NetBSD" and os_name != "OpenBSD" and os_name != "BSD":
		return OK

	var chmod_args := PackedStringArray(["755", absolute_executable_path])
	var exit_code: int = OS.execute("chmod", chmod_args)
	if exit_code != 0:
		return FAILED

	return OK


func _quote_windows_shell(value: String) -> String:
	return "\"%s\"" % value.replace("\"", "\"\"")


func _load_local_versions() -> void:
	if not FileAccess.file_exists(VERSION_FILE):
		local_versions = {
			"gameVersion": "",
			"assetPacks": {},
		}
		return

	var file := FileAccess.open(VERSION_FILE, FileAccess.READ)
	if file == null:
		local_versions = {}
		return

	var parsed_json: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed_json) == TYPE_DICTIONARY:
		local_versions = parsed_json
	else:
		local_versions = {}

	if not local_versions.has("assetPacks"):
		local_versions["assetPacks"] = {}


func _load_launcher_config() -> void:
	if not FileAccess.file_exists(LAUNCHER_CONFIG_FILE):
		return

	var file := FileAccess.open(LAUNCHER_CONFIG_FILE, FileAccess.READ)
	if file == null:
		return

	var parsed_json: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed_json) != TYPE_DICTIONARY:
		return

	var config: Dictionary = parsed_json
	var configured_manifest_urls: Dictionary = _get_dictionary(config, "manifestUrls")
	var platform_manifest_url := _get_platform_manifest_url(configured_manifest_urls)
	if not platform_manifest_url.is_empty():
		manifest_url = platform_manifest_url
	else:
		var configured_manifest_url := str(config.get("manifestUrl", ""))
		if not configured_manifest_url.is_empty():
			manifest_url = configured_manifest_url

	var configured_news_url := str(config.get("newsUrl", ""))
	if not configured_news_url.is_empty():
		news_url = configured_news_url
	var configured_health_url := str(config.get("healthUrl", ""))
	if not configured_health_url.is_empty():
		health_url = configured_health_url
	var configured_presence_url := str(config.get("presenceUrl", ""))
	if not configured_presence_url.is_empty():
		presence_url = configured_presence_url
	manifest_url = _normalize_url(manifest_url)
	news_url = _normalize_url(news_url)
	health_url = _normalize_url(health_url)
	presence_url = _normalize_url(presence_url)
	if manifest_url.is_empty():
		manifest_url = DEFAULT_MANIFEST_URL
	if health_url.is_empty():
		health_url = DEFAULT_HEALTH_URL
	if presence_url.is_empty():
		presence_url = DEFAULT_PRESENCE_URL

	var configured_discord_url := str(config.get("discordUrl", ""))
	if not configured_discord_url.is_empty():
		discord_url = configured_discord_url

	var configured_patch_notes_url := str(config.get("patchNotesUrl", ""))
	if not configured_patch_notes_url.is_empty():
		patch_notes_url = configured_patch_notes_url
	var configured_credits_url := str(config.get("creditsUrl", ""))
	if not configured_credits_url.is_empty():
		credits_url = configured_credits_url
	discord_url = _normalize_url(discord_url)
	patch_notes_url = _normalize_url(patch_notes_url)
	credits_url = _normalize_url(credits_url)
	if discord_url.is_empty():
		discord_url = DEFAULT_DISCORD_URL
	if patch_notes_url.is_empty():
		patch_notes_url = DEFAULT_PATCH_NOTES_URL
	if credits_url.is_empty():
		credits_url = DEFAULT_CREDITS_URL


func _load_launcher_settings() -> void:
	if not FileAccess.file_exists(LAUNCHER_SETTINGS_FILE):
		return

	var file := FileAccess.open(LAUNCHER_SETTINGS_FILE, FileAccess.READ)
	if file == null:
		return

	var parsed_json: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed_json) != TYPE_DICTIONARY:
		return

	var settings: Dictionary = parsed_json
	var configured_install_dir := str(settings.get("installDir", ""))
	if not configured_install_dir.is_empty():
		install_dir = configured_install_dir.strip_edges()


func _save_launcher_settings() -> void:
	var file := FileAccess.open(LAUNCHER_SETTINGS_FILE, FileAccess.WRITE)
	if file == null:
		_log_error("Could not write launcher settings.")
		return

	file.store_string(JSON.stringify({
		"installDir": install_dir,
	}, "\t"))


func _ensure_install_dir_is_writable(target_dir: String) -> Error:
	var absolute_target_dir := _globalize_storage_path(target_dir)
	var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(absolute_target_dir)
	if make_dir_error != OK:
		return make_dir_error

	var test_file_path := absolute_target_dir.path_join(".aether_write_test")
	var test_file := FileAccess.open(test_file_path, FileAccess.WRITE)
	if test_file == null:
		return ERR_CANT_CREATE

	test_file.store_string("ok")
	test_file = null
	var remove_error: Error = DirAccess.remove_absolute(test_file_path)
	if remove_error != OK:
		return remove_error

	return OK


func _reset_local_versions() -> void:
	local_versions = {
		"gameVersion": "",
		"gameExecutable": "",
		"assetPacks": {},
	}


func _globalize_storage_path(path: String) -> String:
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)

	return path


func _get_platform_manifest_url(manifest_urls: Dictionary) -> String:
	if manifest_urls.is_empty():
		return ""

	var os_name := OS.get_name()
	var candidates := PackedStringArray([
		os_name,
		os_name.to_lower(),
	])
	if os_name == "macOS":
		candidates.append("MacOS")
		candidates.append("macos")
	elif os_name == "Linux" or os_name == "FreeBSD" or os_name == "NetBSD" or os_name == "OpenBSD" or os_name == "BSD":
		candidates.append("linux")

	for candidate: String in candidates:
		var manifest_url_variant: Variant = manifest_urls.get(candidate, "")
		var platform_manifest_url := str(manifest_url_variant)
		if not platform_manifest_url.is_empty():
			return _normalize_url(platform_manifest_url)

	return ""


func _format_last_check_time() -> String:
	var datetime := Time.get_datetime_dict_from_system()
	return "%02d-%02d-%04d %02d:%02d" % [
		int(datetime.get("day", 0)),
		int(datetime.get("month", 0)),
		int(datetime.get("year", 0)),
		int(datetime.get("hour", 0)),
		int(datetime.get("minute", 0)),
	]


func _format_request_failure(result: int, response_code: int) -> String:
	var task_label: String = "manifest"
	if not current_download.is_empty():
		task_label = str(current_download.get("label", current_download.get("file_name", "download")))

	var reason: String = _get_request_failure_reason(result, response_code)
	return "Download failed: %s (%s). See launcher_error.log." % [task_label, reason]


func _get_request_failure_reason(result: int, response_code: int) -> String:
	if response_code > 0:
		return "HTTP %d" % response_code

	match result:
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
			return "size mismatch"
		HTTPRequest.RESULT_CANT_CONNECT:
			return "cannot connect"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "cannot resolve host"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "connection error"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS error"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "size limit exceeded"
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED:
			return "decompress failed"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
			return "cannot open download file"
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "download write error"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "redirect limit reached"
		HTTPRequest.RESULT_TIMEOUT:
			return "timeout"
		_:
			return "result %d" % result


func _get_active_request_url() -> String:
	if not current_download.is_empty():
		return str(current_download.get("url", ""))

	return manifest_url


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if typeof(value) == TYPE_DICTIONARY:
		return value

	return {}


func _save_local_versions() -> void:
	var file := FileAccess.open(VERSION_FILE, FileAccess.WRITE)
	if file == null:
		_log_error("Could not write versions file.")
		return

	file.store_string(JSON.stringify(local_versions, "\t"))


func _refresh_status() -> void:
	var local_game_version := str(local_versions.get("gameVersion", ""))
	if local_game_version.is_empty():
		local_game_version = "not installed"
	version_label.text = local_game_version
	play_button.disabled = update_required or not _has_installed_game()
	update_button.disabled = not update_required
	check_button.disabled = false
	_refresh_gen5_sprites_button()
	_refresh_uninstall_button()
	if update_required:
		_set_status("Update available.")
	elif local_game_version == "" or local_game_version == "not installed":
		_set_status("Game is not installed.")
	else:
		_set_status("Ready to play.")
	_sync_button_cursors()


func _refresh_launcher_version() -> void:
	var launcher_version: String = str(ProjectSettings.get_setting("application/config/version", "dev")).strip_edges()
	if launcher_version.is_empty():
		launcher_version = "dev"

	launcher_version_label.text = launcher_version


func _refresh_server_health() -> void:
	var result: Dictionary = await LauncherServerHealthService.check_async(self, health_url)
	if bool(result.get("online", false)):
		server_online_label.text = "Online"
		server_online_label.add_theme_color_override("font_color", SERVER_ONLINE_COLOR)
		await _refresh_online_players()
	else:
		server_online_label.text = "Offline"
		server_online_label.add_theme_color_override("font_color", SERVER_OFFLINE_COLOR)
		online_players_label.text = "Players online unavailable"
		online_players_label.add_theme_color_override("font_color", SERVER_CHECKING_COLOR)


func _set_server_health_checking() -> void:
	server_online_label.text = "Checking..."
	server_online_label.add_theme_color_override("font_color", SERVER_CHECKING_COLOR)
	online_players_label.text = "Checking players online..."
	online_players_label.add_theme_color_override("font_color", SERVER_CHECKING_COLOR)


func _refresh_online_players() -> void:
	var result: Dictionary = await LauncherServerHealthService.request_presence_async(self, presence_url)
	if not bool(result.get("success", false)):
		online_players_label.text = "Players online unavailable"
		online_players_label.add_theme_color_override("font_color", SERVER_CHECKING_COLOR)
		return

	var online_players: int = int(result.get("onlineUsers", 0))
	online_players_label.text = "%s %s online" % [online_players, "player" if online_players == 1 else "players"]
	online_players_label.add_theme_color_override("font_color", SERVER_ONLINE_COLOR)


func _set_busy(is_busy: bool) -> void:
	var locked := is_busy or launcher_update_busy or launcher_update_in_progress
	check_button.disabled = locked
	update_button.disabled = locked or not update_required
	gen5_sprites_button.disabled = locked or not _can_download_gen5_sprites()
	play_button.disabled = locked or update_required or not _has_installed_game()
	uninstall_button.disabled = locked or not _has_game_install_folder()
	_sync_button_cursors()


func _sync_button_cursors() -> void:
	for button: Button in [check_button, update_button, gen5_sprites_button, play_button, patch_notes_button, credits_button, uninstall_button]:
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND
	game_folder_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	discord_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	patch_notes_button.tooltip_text = "Open patch notes"
	credits_button.tooltip_text = "View credits"
	uninstall_button.tooltip_text = "Remove installed game folder"


func _refresh_gen5_sprites_button() -> void:
	if _has_gen5_sprites_folder():
		gen5_sprites_button.visible = false
		gen5_sprites_button.disabled = true
		gen5_sprites_button.tooltip_text = "Gen 5 Animated Sprites are already installed."
		return

	gen5_sprites_button.visible = true
	if manifest.is_empty():
		gen5_sprites_button.text = "Gen 5 Sprites"
		gen5_sprites_button.disabled = true
		gen5_sprites_button.tooltip_text = "Download Gen 5 Animated sprites after launcher manifest is available."
		return

	if _are_gen5_sprites_installed():
		gen5_sprites_button.text = "Gen 5 Installed"
		gen5_sprites_button.disabled = true
		gen5_sprites_button.tooltip_text = "Gen 5 Animated Sprites are already installed."
		return

	gen5_sprites_button.text = "Download Gen 5"
	gen5_sprites_button.disabled = not _can_download_gen5_sprites()
	gen5_sprites_button.tooltip_text = "Download Gen 5 Animated Sprites."


func _has_gen5_sprites_folder() -> bool:
	if _are_gen5_sprites_installed():
		return true

	var gen5_root := _globalize_storage_path(install_dir.path_join(GEN5_SPRITES_FOLDER_PATH))
	return _directory_has_contents(gen5_root)


func _directory_has_contents(path: String) -> bool:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return false

	directory.list_dir_begin()
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		if entry_name != "." and entry_name != "..":
			directory.list_dir_end()
			return true
		entry_name = directory.get_next()

	directory.list_dir_end()
	return false


func _should_auto_update_optional_asset_pack(asset_pack: Dictionary) -> bool:
	if not _is_optional_asset_pack(asset_pack):
		return true

	if bool(asset_pack.get("autoUpdateIfInstalled", false)):
		return _is_gen5_asset_pack(asset_pack) and _has_gen5_sprites_folder()

	return false


func _can_download_gen5_sprites() -> bool:
	return not manifest.is_empty() and not _are_gen5_sprites_installed() and not _get_gen5_asset_packs().is_empty()


func _refresh_uninstall_button() -> void:
	var has_game_install_folder := _has_game_install_folder()
	uninstall_button.visible = has_game_install_folder
	uninstall_button.disabled = not has_game_install_folder
	if has_game_install_folder:
		uninstall_button.tooltip_text = "Remove installed game folder"
	else:
		uninstall_button.tooltip_text = "No game folder to remove"


func _are_gen5_sprites_installed() -> bool:
	var gen5_asset_packs: Array[Dictionary] = _get_gen5_asset_packs()
	if gen5_asset_packs.is_empty():
		return false

	var local_asset_packs: Dictionary = _get_dictionary(local_versions, "assetPacks")
	for asset_pack: Dictionary in gen5_asset_packs:
		if not _is_asset_pack_installed(asset_pack, local_asset_packs):
			return false

	return true


func _has_game_install_folder() -> bool:
	return DirAccess.dir_exists_absolute(_globalize_storage_path(_get_game_install_dir()))


func _has_installed_game() -> bool:
	if str(local_versions.get("gameVersion", "")).is_empty():
		return false

	var game_data: Dictionary = _get_dictionary(manifest, "game")
	return _has_installed_game_for_manifest(game_data)


func _has_installed_game_for_manifest(game_data: Dictionary) -> bool:
	var executable_path := str(game_data.get("executable", local_versions.get("gameExecutable", "")))
	if executable_path.is_empty():
		executable_path = _get_default_game_executable_name()

	var absolute_executable_path := _globalize_storage_path(_get_game_install_dir().path_join(executable_path))
	return FileAccess.file_exists(absolute_executable_path)


func _get_game_executable_path(game_data: Dictionary) -> String:
	var executable_path := str(game_data.get("executable", local_versions.get("gameExecutable", "")))
	if executable_path.is_empty():
		executable_path = _get_default_game_executable_name()

	return _globalize_storage_path(_get_game_install_dir().path_join(executable_path))


func _get_default_game_executable_name() -> String:
	match OS.get_name():
		"Windows":
			return WINDOWS_GAME_BINARY
		"macOS":
			return MACOS_GAME_BINARY
	return LINUX_GAME_BINARY


func _get_game_install_dir() -> String:
	return install_dir.path_join(GAME_INSTALL_SUBDIR)


func _set_status(message: String) -> void:
	status_label.text = message
	var lowered_message := message.to_lower()
	if lowered_message.contains("failed") or lowered_message.contains("could not") or lowered_message.contains("missing") or lowered_message.contains("invalid"):
		status_value_label.text = "Error"
		status_value_label.add_theme_color_override("font_color", Color(1.0, 0.38, 0.45))
	elif lowered_message.contains("not installed"):
		status_value_label.text = "Not installed"
		status_value_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.34))
	elif lowered_message.contains("update available"):
		status_value_label.text = "Update needed"
		status_value_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.34))
	elif lowered_message.contains("download") or lowered_message.contains("extract") or lowered_message.contains("checking"):
		status_value_label.text = "Updating"
		status_value_label.add_theme_color_override("font_color", Color(0.70, 0.45, 1.0))
	else:
		status_value_label.text = "Ready."
		status_value_label.add_theme_color_override("font_color", Color(0.16, 0.94, 0.66))


func _update_progress_percent() -> void:
	if progress_is_indeterminate:
		progress_percent_label.text = ""
		return

	progress_percent_label.text = "%d%%" % int(round(progress_bar.value))


func _format_bytes(byte_count: int) -> String:
	var byte_count_float := float(byte_count)
	if byte_count_float >= 1024.0 * 1024.0 * 1024.0:
		return "%.2f GB" % (byte_count_float / 1024.0 / 1024.0 / 1024.0)
	if byte_count_float >= 1024.0 * 1024.0:
		return "%.1f MB" % (byte_count_float / 1024.0 / 1024.0)
	if byte_count_float >= 1024.0:
		return "%.1f KB" % (byte_count_float / 1024.0)

	return "%d B" % byte_count


func _escape_bbcode(value: String) -> String:
	return value.replace("[", "[lb]").replace("]", "[rb]")


func _log(message: String) -> void:
	print(message)


func _log_error(message: String) -> void:
	print("ERROR: %s" % message)
	var file: FileAccess = FileAccess.open(ERROR_LOG_FILE, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(ERROR_LOG_FILE, FileAccess.WRITE)
	if file == null:
		return

	file.seek_end()
	file.store_line("%s ERROR: %s" % [_format_last_check_time(), message])
