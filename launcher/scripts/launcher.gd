extends Control

const LauncherServerHealthService := preload("res://scripts/server_health_service.gd")
const LauncherNewsLocalizationService := preload("res://scripts/news_localization_service.gd")
const LauncherLanguageSelectorStyle := preload("res://scripts/language_selector_style.gd")
const LauncherResumableDownloadService := preload("res://scripts/resumable_download_service.gd")

const DEFAULT_MANIFEST_URL := "https://example.com/pokeaether/manifest.json"
const DEFAULT_NEWS_URL := "https://updates.pokeaether.com/data/news.json"
const DEFAULT_DISCORD_URL := "https://discord.com/invite/b6WexWT8HX"
const DEFAULT_PATCH_NOTES_URL := "https://pokeaether.com/patch-notes"
const DEFAULT_CREDITS_URL := "https://pokeaether.com/credits"
const DEFAULT_PRESENCE_URL := "https://admin.pokeaether.com/presence/online-count"
const LAUNCHER_CONFIG_FILE := "res://config/launcher_config.json"
const DEFAULT_INSTALL_DIR := "user://game"
const GAME_INSTALL_SUBDIR := "game"
const LAUNCHER_SETTINGS_FILE := "user://launcher_settings.json"
const VERSION_FILE := "user://versions.json"
const ERROR_LOG_FILE := "user://launcher_error.log"
const PREVIOUS_ERROR_LOG_FILE := "user://launcher_error.previous.log"
const MAX_ERROR_LOG_BYTES := 1024 * 1024
const MAX_CHECKSUM_RETRIES := 1
const MAX_MANIFEST_RETRIES := 3
const MANIFEST_RETRY_DELAYS_SECONDS: Array[float] = [1.0, 3.0, 8.0]
const SERVER_HEALTH_REFRESH_SECONDS := 30.0
const TEMP_DIR := "user://downloads"
const INSTALL_STAGING_DIR_NAME := ".launcher-staging"
const EXTRACT_PROGRESS_BATCH_SIZE := 25
const USER_AGENT_HEADER := "User-Agent: PokeAetherLauncher/1.0"
const GEN5_OPTIONAL_ASSET_PACK_PREFIX := "pokemon-gen5"
const GEN5_SPRITES_FOLDER_PATH := "assets/sprites/pokemon/gen5"
const ASSET_PACK_REQUIRED_PATHS := {
	"music": "assets/music",
	"pokemon-home": "assets/sprites/pokemon/pokemon_home",
	"pokemon-home-shiny": "assets/sprites/pokemon/pokemon_home_shiny",
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
const SERVER_MAINTENANCE_COLOR := Color(1.0, 0.72, 0.34, 1.0)

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
@onready var content_layout: HBoxContainer = $Shell/MainSplit/Content/ContentLayout
@onready var diagnostics_card: PanelContainer = $Shell/MainSplit/Content/DiagnosticsCard
@onready var diagnostics_log_view: RichTextLabel = $Shell/MainSplit/Content/DiagnosticsCard/DiagnosticsMargin/DiagnosticsLayout/LogView
@onready var diagnostics_back_button: Button = $Shell/MainSplit/Content/DiagnosticsCard/DiagnosticsMargin/DiagnosticsLayout/HeaderRow/BackButton
@onready var diagnostics_copy_button: Button = $Shell/MainSplit/Content/DiagnosticsCard/DiagnosticsMargin/DiagnosticsLayout/ButtonRow/CopyButton
@onready var diagnostics_open_folder_button: Button = $Shell/MainSplit/Content/DiagnosticsCard/DiagnosticsMargin/DiagnosticsLayout/ButtonRow/OpenFolderButton
@onready var diagnostics_clear_button: Button = $Shell/MainSplit/Content/DiagnosticsCard/DiagnosticsMargin/DiagnosticsLayout/ButtonRow/ClearButton
@onready var check_button: Button = $Shell/MainSplit/Content/ContentLayout/CenterColumn/ButtonRow/CheckButton
@onready var update_button: Button = $Shell/MainSplit/Content/ContentLayout/CenterColumn/ButtonRow/UpdateButton
@onready var gen5_sprites_button: Button = $Shell/MainSplit/Content/ContentLayout/CenterColumn/ButtonRow/Gen5SpritesButton
@onready var play_button: Button = $Shell/MainSplit/Content/ContentLayout/CenterColumn/ButtonRow/PlayButton
@onready var game_folder_button: Button = $Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/GameFolderButton
@onready var patch_notes_button: Button = $Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/PatchNotesButton
@onready var credits_button: Button = $Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/CreditsButton
@onready var home_button: Button = $Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/HomeButton
@onready var diagnostics_button: Button = $Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/DiagnosticsButton
@onready var uninstall_button: Button = $Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/UninstallButton
@onready var language_options_button: OptionButton = $Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/LanguageSection/LanguageOptionsButton
@onready var discord_button: Button = $Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/SocialSection/SocialRow/DiscordButton
@onready var install_folder_dialog: FileDialog = $InstallFolderDialog
@onready var uninstall_confirm_dialog: ConfirmationDialog = $UninstallConfirmDialog
@onready var launcher_update_overlay: Control = $LauncherUpdateOverlay
@onready var launcher_update_card: PanelContainer = $LauncherUpdateOverlay/UpdateCard
@onready var launcher_update_version_badge: PanelContainer = $LauncherUpdateOverlay/UpdateCard/Margin/Layout/EyebrowRow/VersionBadge
@onready var launcher_update_version_label: Label = $LauncherUpdateOverlay/UpdateCard/Margin/Layout/EyebrowRow/VersionBadge/Label
@onready var launcher_update_later_button: Button = $LauncherUpdateOverlay/UpdateCard/Margin/Layout/ButtonRow/LaterButton
@onready var launcher_update_now_button: Button = $LauncherUpdateOverlay/UpdateCard/Margin/Layout/ButtonRow/UpdateNowButton
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
var server_status_url := LauncherServerHealthService.DEFAULT_STATUS_URL
var presence_url := DEFAULT_PRESENCE_URL
var discord_url := DEFAULT_DISCORD_URL
var patch_notes_url := DEFAULT_PATCH_NOTES_URL
var credits_url := DEFAULT_CREDITS_URL
var install_dir := DEFAULT_INSTALL_DIR
var locale := "en"
var launcher_update_info: Dictionary = {}
var launcher_update_busy := false
var launcher_update_in_progress := false
var launcher_update_pending := false
var launcher_update_shown := false
var news_items: Array[Dictionary] = []
var raw_news_data: Dictionary = {}
var progress_is_indeterminate := false
var asset_pack_download_total := 0
var current_asset_pack_download_index := 0
var has_unseen_diagnostics_error := false
var last_check_datetime: Dictionary = {}
var download_service: ResumableDownloadService
var download_progress_snapshot: Dictionary = {}
var active_resumable_download_kind := ""
var manifest_retry_count := 0
var manifest_request_generation := 0
var server_access_blocked := false
var server_access_message := ""
var server_health_check_in_progress := false
var server_health_failure_logged := false
var server_health_refresh_timer: Timer


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
	_load_launcher_config()
	_load_launcher_settings()
	LauncherLocalization.set_locale(locale)
	_initialize_diagnostics_log()
	_apply_visual_style()
	_apply_locale()
	_populate_language_options()
	home_button.pressed.connect(_show_home)
	diagnostics_button.pressed.connect(_show_diagnostics)
	diagnostics_back_button.pressed.connect(_show_home)
	diagnostics_copy_button.pressed.connect(_copy_diagnostics)
	diagnostics_open_folder_button.pressed.connect(_open_diagnostics_folder)
	diagnostics_clear_button.pressed.connect(_clear_diagnostics)
	check_button.pressed.connect(check_for_updates)
	update_button.pressed.connect(start_update)
	gen5_sprites_button.pressed.connect(download_gen5_animated_sprites)
	play_button.pressed.connect(launch_game)
	game_folder_button.pressed.connect(open_install_folder_dialog)
	patch_notes_button.pressed.connect(open_patch_notes)
	credits_button.pressed.connect(open_credits)
	uninstall_button.pressed.connect(_on_uninstall_button_pressed)
	language_options_button.item_selected.connect(_on_language_selected)
	launcher_update_later_button.pressed.connect(_hide_launcher_update_prompt)
	launcher_update_now_button.pressed.connect(_on_launcher_update_now_pressed)
	launcher_update_http_request.request_completed.connect(_on_launcher_update_request_completed)
	discord_button.pressed.connect(open_discord)
	install_folder_dialog.dir_selected.connect(_on_install_folder_selected)
	uninstall_confirm_dialog.confirmed.connect(_uninstall_game_folder)
	http_request.request_completed.connect(_on_request_completed)
	http_request.timeout = 30.0
	download_service = LauncherResumableDownloadService.new()
	add_child(download_service)
	server_health_refresh_timer = Timer.new()
	server_health_refresh_timer.wait_time = SERVER_HEALTH_REFRESH_SECONDS
	server_health_refresh_timer.autostart = true
	server_health_refresh_timer.timeout.connect(_refresh_server_health)
	add_child(server_health_refresh_timer)
	download_service.progress_changed.connect(_on_download_progress_changed)
	download_service.diagnostic_event.connect(_on_download_diagnostic_event)
	download_service.download_completed.connect(_on_resumable_download_completed)
	download_service.download_failed.connect(_on_resumable_download_failed)
	if news_request != null:
		news_request.timeout = 15.0
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
	_log(
		"Launcher session started. launcher_version=%s os=%s locale=%s" % [
			str(ProjectSettings.get_setting("application/config/version", "dev")),
			OS.get_name(),
			locale,
		]
	)
	queue_redraw()


func _apply_locale() -> void:
	LauncherLocalization.localize_tree(self)
	_refresh_last_check_label()
	install_folder_dialog.title = _t("Open a Directory")
	uninstall_confirm_dialog.title = _t("Uninstall Game")
	uninstall_confirm_dialog.ok_button_text = _t("Uninstall")
	uninstall_confirm_dialog.dialog_text = _t(
		"This will permanently remove the selected game folder and all downloaded files.\n\nContinue?"
	)
	_refresh_diagnostics_button()


func _populate_language_options() -> void:
	language_options_button.clear()
	var selected_index := 0
	var supported_locales: Array[String] = LauncherLocalization.get_supported_locales()
	for index: int in range(supported_locales.size()):
		var supported_locale := supported_locales[index]
		LauncherLanguageSelectorStyle.add_locale_item(
			language_options_button,
			supported_locale,
			LauncherLocalization.get_language_name(supported_locale),
			index
		)
		if supported_locale == locale:
			selected_index = index
	language_options_button.select(selected_index)


func _on_language_selected(index: int) -> void:
	var selected_locale := str(language_options_button.get_item_metadata(index))
	if selected_locale.is_empty() or selected_locale == locale:
		return
	locale = LauncherLocalization.set_locale(selected_locale)
	_save_launcher_settings()
	_apply_locale()
	_populate_language_options()
	_refresh_status()
	_set_server_health_checking()
	_refresh_server_health.call_deferred()
	if raw_news_data.is_empty():
		fetch_news()
	else:
		_render_localized_news()


func _t(key: String, values: Dictionary = {}) -> String:
	return LauncherLocalization.text(key, values)


func _show_home() -> void:
	content_layout.show()
	diagnostics_card.hide()
	_apply_active_nav_style(home_button)


func _show_diagnostics() -> void:
	content_layout.hide()
	diagnostics_card.show()
	has_unseen_diagnostics_error = false
	_refresh_diagnostics_button()
	_refresh_diagnostics_view()
	_apply_active_nav_style(diagnostics_button)


func _apply_active_nav_style(active_button: Button) -> void:
	var inactive_style := _sidebar_button_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0)
	var active_style := _sidebar_button_style(
		Color(0.18, 0.13, 0.34, 0.92),
		Color(0.48, 0.25, 0.92, 0.9),
		1
	)
	for button: Button in [home_button, diagnostics_button]:
		var style := active_style if button == active_button else inactive_style
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style if button == active_button else _sidebar_button_style(Color(0.105, 0.085, 0.19, 0.82), Color(0.42, 0.22, 0.82, 0.68), 1))
		button.add_theme_color_override(
			"font_color",
			Color(0.96, 0.96, 1.0) if button == active_button else Color(0.76, 0.78, 0.88, 1.0)
		)


func _apply_visual_style() -> void:
	add_theme_font_size_override("font_size", 16)

	shell_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.027, 0.043, 0.078, 0.38), Color(0.192, 0.314, 0.439, 0.82), 14, 1))
	sidebar_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.022, 0.032, 0.061, 0.95), Color(0.192, 0.314, 0.439, 0.72), 12, 1))
	brand_mark.add_theme_stylebox_override("panel", _panel_style(Color(0.48, 0.22, 0.96, 1.0), Color(0.72, 0.48, 1.0, 0.55), 28, 0))
	server_card.add_theme_stylebox_override("panel", _panel_style(Color(0.051, 0.086, 0.145, 0.9), Color(0.192, 0.314, 0.439, 0.9), 12, 1))
	meta_card.add_theme_stylebox_override("panel", _panel_style(Color(0.051, 0.086, 0.145, 0.84), Color(0.192, 0.314, 0.439, 0.82), 14, 1))
	progress_card.add_theme_stylebox_override("panel", _panel_style(Color(0.051, 0.086, 0.145, 0.9), Color(0.192, 0.314, 0.439, 0.82), 14, 1))
	news_card.add_theme_stylebox_override("panel", _panel_style(Color(0.051, 0.086, 0.145, 0.9), Color(0.192, 0.314, 0.439, 0.88), 14, 1))
	diagnostics_card.add_theme_stylebox_override("panel", _panel_style(Color(0.037, 0.058, 0.105, 0.96), Color(0.30, 0.39, 0.58, 0.9), 14, 1))

	var nav_buttons: Array[Button] = [
		$Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/HomeButton,
		$Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/PatchNotesButton,
		$Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/CreditsButton,
		$Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/DiagnosticsButton,
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
	for diagnostics_action_button: Button in [
		diagnostics_back_button,
		diagnostics_copy_button,
		diagnostics_open_folder_button,
		diagnostics_clear_button,
	]:
		_apply_button_style(diagnostics_action_button, false)
	_apply_active_nav_style(home_button)
	$Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/UninstallButton.add_theme_color_override("font_color", Color(1.0, 0.68, 0.68, 1.0))
	$Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/UninstallButton.add_theme_color_override("font_hover_color", Color(1.0, 0.74, 0.74, 1.0))
	$Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/Nav/UninstallButton.add_theme_color_override("font_pressed_color", Color(1.0, 0.56, 0.56, 1.0))

	progress_bar.add_theme_stylebox_override("background", _panel_style(Color(0.14, 0.16, 0.27, 0.86), Color(0, 0, 0, 0), 7, 0))
	progress_bar.add_theme_stylebox_override("fill", _panel_style(Color(0.55, 0.26, 0.96, 1.0), Color(0, 0, 0, 0), 7, 0))
	log_label.add_theme_color_override("default_color", Color(0.80, 0.81, 0.88))
	diagnostics_log_view.add_theme_color_override("default_color", Color(0.80, 0.83, 0.91))
	diagnostics_log_view.add_theme_color_override("font_selected_color", Color(1.0, 1.0, 1.0))
	diagnostics_log_view.add_theme_color_override("selection_color", Color(0.38, 0.20, 0.72, 0.85))

	launcher_update_card.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.055, 0.105, 0.99), Color(0.48, 0.29, 0.92, 0.95), 18, 1))
	launcher_update_version_badge.add_theme_stylebox_override("panel", _panel_style(Color(0.27, 0.14, 0.54, 0.9), Color(0.66, 0.42, 1.0, 0.7), 12, 1))
	launcher_update_version_label.add_theme_color_override("font_color", Color(0.94, 0.89, 1.0, 1.0))
	launcher_update_version_label.add_theme_font_size_override("font_size", 13)
	$LauncherUpdateOverlay/UpdateCard/Margin/Layout/EyebrowRow/Eyebrow.add_theme_color_override("font_color", Color(0.70, 0.48, 1.0, 1.0))
	$LauncherUpdateOverlay/UpdateCard/Margin/Layout/Title.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0, 1.0))
	$LauncherUpdateOverlay/UpdateCard/Margin/Layout/Description.add_theme_color_override("font_color", Color(0.76, 0.79, 0.90, 1.0))
	$LauncherUpdateOverlay/UpdateCard/Margin/Layout/RestartNote.add_theme_color_override("font_color", Color(0.57, 0.68, 0.87, 1.0))
	$LauncherUpdateOverlay/UpdateCard/Margin/Layout/Divider.add_theme_stylebox_override("separator", _panel_style(Color(0.20, 0.27, 0.43, 0.8), Color(0, 0, 0, 0), 1, 0))
	_apply_button_style(launcher_update_later_button, false)
	_apply_button_style(launcher_update_now_button, true)
	launcher_update_later_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	launcher_update_now_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	LauncherLanguageSelectorStyle.configure(language_options_button)


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
	if download_progress_snapshot.is_empty():
		return
	var downloaded_bytes := int(download_progress_snapshot.get("downloaded_bytes", 0))
	var total_bytes := int(download_progress_snapshot.get("total_bytes", 0))
	var recent_speed := float(download_progress_snapshot.get("recent_bytes_per_second", 0.0))
	var stalled_seconds := float(download_progress_snapshot.get("seconds_without_bytes", 0.0))
	if total_bytes <= 0:
		progress_is_indeterminate = true
		progress_bar.value = fmod(float(Time.get_ticks_msec()) / 18.0, 100.0)
		return
	progress_is_indeterminate = false
	progress_bar.value = minf((float(downloaded_bytes) / float(total_bytes)) * 100.0, 99.9)
	var speed_text := _format_transfer_speed(recent_speed)
	var active_label := _get_current_download_display_label() if not current_download.is_empty() else _t("launcher update")
	var message := _t("Downloading {label}... {downloaded} / {total} — {speed}", {
		"label": active_label,
		"downloaded": _format_bytes(downloaded_bytes),
		"total": _format_bytes(total_bytes),
		"speed": speed_text,
	})
	if stalled_seconds >= LauncherResumableDownloadService.STALL_WARNING_SECONDS:
		message = _t("Connection stalled for {seconds}s — reconnecting automatically", {
			"seconds": int(stalled_seconds),
		})
	_set_status(message, "updating")


func check_for_updates() -> void:
	_set_busy(true)
	_set_status("Checking for updates...")
	_log("Checking for updates.")
	manifest_retry_count = 0
	manifest_request_generation += 1
	_request_manifest(manifest_request_generation)


func _request_manifest(request_generation: int) -> void:
	if request_generation != manifest_request_generation:
		return
	http_request.download_file = ""
	var error_code: Error = http_request.request(manifest_url, _request_headers())
	if error_code != OK:
		_handle_manifest_request_failure(HTTPRequest.RESULT_CANT_CONNECT, 0, error_string(error_code))


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
	if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED or download_service.is_active():
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
	if server_access_blocked:
		_set_status(
			server_access_message if not server_access_message.is_empty() else "Server maintenance.",
			"maintenance"
		)
		return

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

	if launcher_update_http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED or download_service.is_active():
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

	launcher_update_busy = true
	launcher_update_in_progress = false
	_set_busy(true)
	_set_status("Downloading launcher update...")
	active_resumable_download_kind = "launcher_update"
	var error_code: Error = download_service.start_download({
		"type": "launcher_update",
		"id": "launcher",
		"version": str(launcher_data.get("version", "")),
		"url": str(launcher_data.get("url", "")),
		"sha256": str(launcher_data.get("sha256", "")),
		"size_bytes": int(launcher_data.get("sizeBytes", launcher_data.get("size_bytes", 0))),
		"download_dir": LAUNCHER_UPDATE_TEMP_DIR,
	})
	if error_code != OK:
		active_resumable_download_kind = ""
		launcher_update_busy = false
		_set_status("Could not start launcher update download.")
		_log_error("Launcher update request failed: %s" % error_string(error_code))
		_set_busy(false)


func _on_uninstall_button_pressed() -> void:
	if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED or download_service.is_active():
		_set_status("Wait until the current launcher task is finished.")
		return

	var game_install_dir := _get_game_install_dir()
	var absolute_game_install_dir := _globalize_storage_path(game_install_dir)
	if not DirAccess.dir_exists_absolute(absolute_game_install_dir):
		_set_status("No installed game folder found.")
		_refresh_uninstall_button()
		return

	uninstall_confirm_dialog.dialog_text = _t(
		"This will permanently remove the game folder:\n{path}\n\nContinue?",
		{"path": absolute_game_install_dir}
	)
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
		var command: String = "cd /D %s && %s -- --locale=%s" % [
			_quote_windows_shell(game_dir),
			_quote_windows_shell(executable_name),
			locale,
		]
		return OS.create_process("cmd.exe", PackedStringArray(["/C", command]))

	if os_name == "Linux" or os_name == "macOS" or os_name == "FreeBSD" or os_name == "NetBSD" or os_name == "OpenBSD" or os_name == "BSD":
		var command: String = "cd \"$1\" && exec \"./$2\" -- \"--locale=$3\""
		return OS.create_process(
			"/bin/sh",
			PackedStringArray(["-c", command, "pokeaether-launcher", game_dir, executable_name, locale])
		)

	return OS.create_process(absolute_executable_path, PackedStringArray(["--", "--locale=%s" % locale]))


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	progress_is_indeterminate = false
	progress_bar.value = 100.0
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		var request_failure_message: String = _format_request_failure(result, response_code)
		_handle_manifest_request_failure(result, response_code, request_failure_message)
		return

	_handle_manifest_response(body)


func _handle_manifest_request_failure(result: int, response_code: int, reason: String) -> void:
	var retriable := response_code in [0, 408, 425, 429, 500, 502, 503, 504]
	if result in [HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CONNECTION_ERROR, HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR, HTTPRequest.RESULT_TIMEOUT]:
		retriable = true
	if retriable and manifest_retry_count < MAX_MANIFEST_RETRIES:
		manifest_retry_count += 1
		var delay := MANIFEST_RETRY_DELAYS_SECONDS[manifest_retry_count - 1]
		_set_status(_t("Could not reach the update manifest — retrying ({retry}/{max})", {
			"retry": manifest_retry_count,
			"max": MAX_MANIFEST_RETRIES,
		}), "updating")
		_log_warning("Manifest request retry=%s/%s delay_seconds=%s result=%s status=%s reason=%s" % [
			manifest_retry_count,
			MAX_MANIFEST_RETRIES,
			delay,
			result,
			response_code,
			reason,
		])
		_retry_manifest_after(delay, manifest_request_generation)
		return
	_set_busy(false)
	_set_status(_format_request_failure(result, response_code), "error")
	_log_error("Manifest request failed after retries. result=%s status=%s reason=%s url=%s" % [
		result,
		response_code,
		reason,
		manifest_url,
	])


func _retry_manifest_after(delay_seconds: float, request_generation: int) -> void:
	await get_tree().create_timer(delay_seconds).timeout
	_request_manifest(request_generation)


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

	raw_news_data = parsed_json as Dictionary
	_render_localized_news()


func _render_localized_news() -> void:
	_render_news_items(LauncherNewsLocalizationService.resolve_items(
		raw_news_data,
		LauncherLocalization.get_http_locale()
	))


func _render_news_items(items: Array[Dictionary]) -> void:
	news_items = items
	log_label.clear()
	if news_items.is_empty():
		log_label.text = _t("No news available.")
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
	var manifest_validation_error := _validate_download_manifest(parsed_json)
	if not manifest_validation_error.is_empty():
		_set_busy(false)
		_set_status("Manifest is invalid.")
		_log_error("Manifest validation failed: %s" % manifest_validation_error)
		return

	manifest = parsed_json
	last_check_datetime = Time.get_datetime_dict_from_system()
	_refresh_last_check_label()
	launcher_update_info = _get_launcher_update_info()
	_build_download_queue()
	update_required = not pending_downloads.is_empty()
	_set_busy(false)
	_refresh_status()
	_refresh_launcher_update_status()
	if launcher_update_pending and not launcher_update_shown:
		launcher_update_shown = true
		_show_launcher_update_prompt()
	elif not launcher_update_pending:
		launcher_update_shown = false

	if update_required:
		_log("Update available.")
	else:
		_log("Everything is up to date.")


func _validate_download_manifest(candidate: Dictionary) -> String:
	var entries: Array[Dictionary] = []
	var game_entry: Variant = candidate.get("game", {})
	if typeof(game_entry) != TYPE_DICTIONARY:
		return "game entry is missing"
	entries.append({"label": "game", "value": game_entry})
	var packs: Variant = candidate.get("assetPacks", [])
	if typeof(packs) != TYPE_ARRAY:
		return "assetPacks must be an array"
	for pack: Variant in packs:
		if typeof(pack) != TYPE_DICTIONARY:
			return "assetPacks contains a non-object entry"
		entries.append({"label": "asset pack %s" % str(pack.get("id", "unknown")), "value": pack})
	var launcher_entry: Variant = candidate.get("launcher", {})
	if typeof(launcher_entry) == TYPE_DICTIONARY and not launcher_entry.is_empty():
		entries.append({"label": "launcher update", "value": launcher_entry})

	for entry: Dictionary in entries:
		var value: Dictionary = entry["value"]
		var label := str(entry["label"])
		if not bool(LauncherResumableDownloadService.parse_http_url(str(value.get("url", ""))).get("valid", false)):
			return "%s has no valid HTTP URL" % label
		if int(value.get("sizeBytes", 0)) <= 0:
			return "%s has no positive size" % label
		var sha256 := str(value.get("sha256", "")).strip_edges().to_lower()
		if sha256.length() != 64 or not sha256.is_valid_hex_number():
			return "%s has no valid SHA-256" % label
	return ""


func _show_launcher_update_prompt() -> void:
	launcher_update_version_label.text = "v%s" % str(launcher_update_info.get("version", "unknown"))
	launcher_update_overlay.show()
	launcher_update_now_button.grab_focus()


func _hide_launcher_update_prompt() -> void:
	launcher_update_overlay.hide()


func _on_launcher_update_now_pressed() -> void:
	_hide_launcher_update_prompt()
	_start_launcher_update_download()


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

	var actual_sha256 := FileAccess.get_sha256(downloaded_path).to_lower()
	if not expected_sha256.is_empty() and expected_sha256 != actual_sha256:
		_set_status("Launcher update checksum failed.")
		_log_error(
			"LCH-001 launcher update checksum mismatch. version=%s expected_size=%s actual_size=%s expected_sha256=%s actual_sha256=%s url=%s" % [
				str(launcher_update_info.get("version", "")),
				expected_size,
				downloaded_size,
				expected_sha256,
				actual_sha256,
				url,
			]
		)
		_delete_existing_download(downloaded_path)
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
	_set_status(_t(
		"{reason} You can retry from launcher update prompt.",
		{"reason": _t(reason)}
	), "error")
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
		if not _is_safe_archive_path(packed_file_path):
			reader.close()
			_log_error("Launcher update archive contains unsafe path: %s" % packed_file_path)
			return ERR_INVALID_DATA

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
	var expected_sha256 := str(current_download.get("sha256", "")).to_lower()
	if not FileAccess.file_exists(file_path):
		_set_busy(false)
		_set_status("Downloaded file is missing.")
		_log_error(
			"DL-001 downloaded file is missing. type=%s id=%s version=%s build_id=%s" % [
				str(current_download.get("type", "")),
				str(current_download.get("id", "")),
				str(current_download.get("version", "")),
				str(current_download.get("build_id", "")),
			]
		)
		current_download.clear()
		return

	var actual_sha256 := FileAccess.get_sha256(file_path).to_lower()
	if not expected_sha256.is_empty() and actual_sha256 != expected_sha256:
		var actual_size := _get_file_size(file_path)
		var retry_count := int(current_download.get("checksum_retry_count", 0))
		_log_error(
			"CHK-001 downloaded file checksum mismatch. type=%s id=%s version=%s build_id=%s expected_size=%s actual_size=%s expected_sha256=%s actual_sha256=%s retry=%s url=%s" % [
				str(current_download.get("type", "")),
				str(current_download.get("id", "")),
				str(current_download.get("version", "")),
				str(current_download.get("build_id", "")),
				int(current_download.get("size_bytes", 0)),
				actual_size,
				expected_sha256,
				actual_sha256,
				retry_count,
				str(current_download.get("url", "")),
			]
		)
		_delete_existing_download(file_path)
		if retry_count < MAX_CHECKSUM_RETRIES:
			current_download["checksum_retry_count"] = retry_count + 1
			_set_status("Downloaded file integrity check failed. Retrying once...", "updating")
			_log_warning(
				"CHK-001 retrying download once with cache revalidation. id=%s version=%s" % [
					str(current_download.get("id", "")),
					str(current_download.get("version", "")),
				]
			)
			await get_tree().process_frame
			_start_current_download()
			return

		_set_busy(false)
		_set_status(
			"Download verification failed (CHK-001). Open Diagnostics for details.",
			"error"
		)
		current_download.clear()
		return

	var download_label: String = _get_current_download_display_label()
	if int(current_download.get("checksum_retry_count", 0)) > 0:
		_log("CHK-001 retry passed integrity verification. id=%s" % str(current_download.get("id", "")))
	_set_status(_t("Extracting {label}...", {"label": download_label}), "updating")
	_log("Extracting %s." % download_label)
	await get_tree().process_frame

	var staging_key := "%s-%s" % [
		str(current_download.get("id", "download")),
		str(current_download.get("version", "")).sha256_text().substr(0, 12),
	]
	var staging_root := install_dir.path_join(INSTALL_STAGING_DIR_NAME).path_join(staging_key)
	var clear_error: Error = _clear_directory(staging_root)
	if clear_error != OK:
		_set_busy(false)
		_set_status("Could not prepare update staging folder.")
		_log_error("Could not prepare staging folder: %s" % error_string(clear_error))
		current_download.clear()
		return

	var extract_error: Error = await _extract_zip(file_path, staging_root, download_label)
	if extract_error != OK:
		_set_busy(false)
		_set_status("Could not extract update.")
		_log_error("Extract failed: %s" % error_string(extract_error))
		_remove_directory_tree(staging_root)
		current_download.clear()
		return

	var install_error := _commit_staged_download(current_download, staging_root)
	if install_error != OK:
		_set_busy(false)
		_set_status("Could not install extracted update.")
		_log_error(
			"Staged install failed: %s (code=%s). See the preceding STG diagnostic for the failed phase." % [
				error_string(install_error),
				int(install_error),
			]
		)
		_remove_directory_tree(staging_root)
		current_download.clear()
		return

	_delete_existing_download(file_path)
	_mark_download_installed(current_download)
	current_download.clear()
	_start_next_download()


func _start_next_download() -> void:
	if pending_downloads.is_empty():
		progress_is_indeterminate = false
		download_progress_snapshot.clear()
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
	current_download["checksum_retry_count"] = 0
	_start_current_download()


func _start_current_download() -> void:
	progress_is_indeterminate = false
	progress_bar.value = 0.0
	download_progress_snapshot.clear()

	var download_label: String = _get_current_download_display_label()
	_set_status(_t("Downloading {label}...", {"label": download_label}), "updating")
	_log(
		"Downloading %s. type=%s id=%s version=%s build_id=%s expected_size=%s resumable=true" % [
			download_label,
			str(current_download.get("type", "")),
			str(current_download.get("id", "")),
			str(current_download.get("version", "")),
			str(current_download.get("build_id", "")),
			int(current_download.get("size_bytes", 0)),
		]
	)
	current_download["download_dir"] = TEMP_DIR
	active_resumable_download_kind = "content"
	var error_code: Error = download_service.start_download(current_download)
	if error_code != OK:
		active_resumable_download_kind = ""
		_set_busy(false)
		_set_status("Could not start download.")
		_log_error("Download request failed: %s" % error_string(error_code))
		current_download.clear()


func _on_download_progress_changed(snapshot: Dictionary) -> void:
	download_progress_snapshot = snapshot.duplicate(true)


func _on_download_diagnostic_event(event: Dictionary) -> void:
	var event_name := str(event.get("event", "download_event"))
	if event_name == "download_verifying":
		var verifying_label := _get_current_download_display_label() if not current_download.is_empty() else _t("launcher update")
		_set_status(_t("Verifying {label}...", {"label": verifying_label}), "updating")
	var fields := PackedStringArray()
	var field_names := [
		"id", "version", "status", "attempt", "retry", "retries", "max_retries", "offset",
		"resume_offset", "downloaded_bytes", "total_bytes", "recent_bytes_per_second",
		"average_bytes_per_second", "seconds_without_bytes", "delay_seconds", "reason",
		"content_range", "accept_ranges", "edge", "duration_seconds", "stalls",
		"resumed", "resumed_bytes", "expected_size", "actual_size",
		"time_to_first_byte_seconds", "last_failure", "parallel", "parallel_used",
		"parallel_fallback", "connections", "segment", "segments",
		"fresh_file", "corrupt_file_removed",
	]
	for field_name: String in field_names:
		if event.has(field_name) and str(event[field_name]) != "":
			fields.append("%s=%s" % [field_name, str(event[field_name])])
	var message := "%s %s" % [event_name, " ".join(fields)]
	if event_name == "download_failed":
		_log_error(message)
	elif event_name in ["download_retry", "download_stall", "partial_reset", "parallel_download_fallback"]:
		_log_warning(message)
	else:
		_log(message)


func _on_resumable_download_completed(file_path: String, summary: Dictionary) -> void:
	download_progress_snapshot.clear()
	var completed_kind := active_resumable_download_kind
	active_resumable_download_kind = ""
	if completed_kind == "launcher_update":
		launcher_update_http_request.download_file = file_path
		_on_launcher_update_request_completed(
			HTTPRequest.RESULT_SUCCESS,
			200,
			PackedStringArray(),
			PackedByteArray()
		)
		return
	if current_download.is_empty():
		_delete_existing_download(file_path)
		return
	current_download["file_path"] = file_path
	current_download["download_summary"] = summary
	progress_is_indeterminate = false
	progress_bar.value = 100.0
	_handle_download_response()


func _on_resumable_download_failed(message: String, summary: Dictionary) -> void:
	download_progress_snapshot.clear()
	progress_is_indeterminate = false
	var failed_kind := active_resumable_download_kind
	active_resumable_download_kind = ""
	_set_busy(false)
	if failed_kind == "launcher_update":
		launcher_update_busy = false
		launcher_update_in_progress = false
		launcher_update_shown = false
		_set_status(_t("Download failed: {task} ({reason}). Partial progress was kept.", {
			"task": _t("launcher update"),
			"reason": message,
		}), "error")
		_log_error("Launcher update download stopped after bounded retries. reason=%s" % message)
		return
	var label := _get_current_download_display_label() if not current_download.is_empty() else "download"
	_set_status(_t("Download failed: {task} ({reason}). Partial progress was kept.", {
		"task": label,
		"reason": message,
	}), "error")
	_log_error(
		"Download stopped after bounded retries. id=%s downloaded_bytes=%s retries=%s stalls=%s reason=%s" % [
			str(summary.get("id", "download")),
			int(summary.get("downloaded_bytes", 0)),
			int(summary.get("retries", 0)),
			int(summary.get("stalls", 0)),
			message,
		]
	)
	current_download.clear()


func _request_headers(force_revalidate: bool = false) -> PackedStringArray:
	var headers := PackedStringArray([
		USER_AGENT_HEADER,
		"Accept-Language: %s, en;q=0.8" % LauncherLocalization.get_http_locale(),
	])
	if force_revalidate:
		headers.append("Cache-Control: no-cache")
		headers.append("Pragma: no-cache")
	return headers


func _build_download_queue() -> void:
	pending_downloads.clear()
	if manifest.is_empty():
		return

	var game_data: Dictionary = _get_dictionary(manifest, "game")
	var remote_game_version := str(game_data.get("version", manifest.get("gameVersion", "")))
	var remote_game_build_id := str(game_data.get(
		"buildId",
		manifest.get("gameBuildId", remote_game_version)
	))
	var local_game_build_id := str(local_versions.get(
		"gameBuildId",
		local_versions.get("gameVersion", "")
	))
	var local_game_missing := not _has_installed_game_for_manifest(game_data)
	if remote_game_build_id != "" and (local_game_build_id != remote_game_build_id or local_game_missing):
		pending_downloads.append({
			"type": "game",
			"id": "game",
			"version": remote_game_version,
			"build_id": remote_game_build_id,
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
		local_versions["gameBuildId"] = str(download.get("build_id", download.get("version", "")))
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
		if not _is_safe_archive_path(packed_file_path):
			reader.close()
			_log_error("Archive contains unsafe path: %s" % packed_file_path)
			return ERR_INVALID_DATA

		extracted_file_count += 1
		if extracted_file_count == 1 or extracted_file_count % EXTRACT_PROGRESS_BATCH_SIZE == 0:
			var percent: float = 0.0
			if file_count > 0:
				percent = minf((float(extracted_file_count) / float(file_count)) * 100.0, 99.0)
			progress_bar.value = percent
			_set_status(
				_t("Extracting {label}... {current} / {total} files ({percent}%)", {
					"label": label,
					"current": extracted_file_count,
					"total": file_count,
					"percent": int(percent),
				}),
				"updating"
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


func _commit_staged_download(download: Dictionary, staging_root: String) -> Error:
	var download_type := str(download.get("type", ""))
	var staged_source := staging_root
	var target := _get_game_install_dir()
	if download_type == "game":
		var game_data := _get_dictionary(manifest, "game")
		var executable := str(game_data.get("executable", ""))
		if executable.is_empty():
			executable = _get_default_game_executable_name()
		var staged_executable := _globalize_storage_path(staged_source.path_join(executable))
		if not FileAccess.file_exists(staged_executable):
			return _report_staged_install_failure(
				download,
				"validate_game_executable",
				ERR_FILE_MISSING_DEPENDENCIES,
				staged_executable,
				_globalize_storage_path(target)
			)
	else:
		var required_path := str(ASSET_PACK_REQUIRED_PATHS.get(str(download.get("id", "")), ""))
		if required_path.is_empty():
			return _report_staged_install_failure(
				download,
				"validate_asset_pack_mapping",
				ERR_INVALID_DATA,
				_globalize_storage_path(staged_source),
				_globalize_storage_path(target)
			)
		staged_source = staging_root.path_join(required_path)
		target = install_dir.path_join(required_path)
		if not DirAccess.dir_exists_absolute(_globalize_storage_path(staged_source)):
			return _report_staged_install_failure(
				download,
				"validate_asset_pack_contents",
				ERR_FILE_MISSING_DEPENDENCIES,
				_globalize_storage_path(staged_source),
				_globalize_storage_path(target)
			)

	var absolute_source := _globalize_storage_path(staged_source)
	var absolute_target := _globalize_storage_path(target)
	var absolute_backup := "%s.launcher-backup" % absolute_target
	var parent_error := DirAccess.make_dir_recursive_absolute(absolute_target.get_base_dir())
	if parent_error != OK:
		return _report_staged_install_failure(
			download,
			"create_target_parent",
			parent_error,
			absolute_source,
			absolute_target.get_base_dir()
		)
	if not DirAccess.dir_exists_absolute(absolute_target) and DirAccess.dir_exists_absolute(absolute_backup):
		var recovery_error := DirAccess.rename_absolute(absolute_backup, absolute_target)
		if recovery_error != OK:
			return _report_staged_install_failure(
				download,
				"restore_interrupted_backup",
				recovery_error,
				absolute_backup,
				absolute_target
			)
	var cleanup_error := _remove_directory_tree(absolute_backup)
	if cleanup_error != OK:
		return _report_staged_install_failure(
			download,
			"remove_stale_backup",
			cleanup_error,
			absolute_backup,
			absolute_target
		)

	var had_existing_target := DirAccess.dir_exists_absolute(absolute_target)
	if had_existing_target:
		var backup_error := DirAccess.rename_absolute(absolute_target, absolute_backup)
		if backup_error != OK:
			return _report_staged_install_failure(
				download,
				"backup_existing_install",
				backup_error,
				absolute_target,
				absolute_backup
			)

	var promote_error := DirAccess.rename_absolute(absolute_source, absolute_target)
	if promote_error != OK:
		_report_staged_install_failure(
			download,
			"promote_staging",
			promote_error,
			absolute_source,
			absolute_target
		)
		if had_existing_target and DirAccess.dir_exists_absolute(absolute_backup):
			var rollback_error := DirAccess.rename_absolute(absolute_backup, absolute_target)
			if rollback_error != OK:
				_report_staged_install_failure(
					download,
					"rollback_after_promotion_failure",
					rollback_error,
					absolute_backup,
					absolute_target,
					"STG-002"
				)
		return promote_error

	if had_existing_target:
		cleanup_error = _remove_directory_tree(absolute_backup)
		if cleanup_error != OK:
			_log_warning(
				"STG-003 staged_install_cleanup_failed phase=remove_committed_backup error=%s error_code=%s path=%s path_exists=%s" % [
					error_string(cleanup_error),
					int(cleanup_error),
					absolute_backup,
					_staged_install_path_exists(absolute_backup),
				]
			)
	_remove_directory_tree(staging_root)
	return OK


func _report_staged_install_failure(
	download: Dictionary,
	phase: String,
	failure: Error,
	source: String,
	target: String,
	diagnostic_code: String = "STG-001"
) -> Error:
	_log_error(_format_staged_install_failure(
		download,
		phase,
		failure,
		source,
		target,
		diagnostic_code
	))
	return failure


func _format_staged_install_failure(
	download: Dictionary,
	phase: String,
	failure: Error,
	source: String,
	target: String,
	diagnostic_code: String = "STG-001"
) -> String:
	return "%s staged_install_failed phase=%s type=%s id=%s version=%s build_id=%s error=%s error_code=%s os=%s source=%s source_exists=%s target=%s target_exists=%s" % [
		diagnostic_code,
		phase,
		str(download.get("type", "")),
		str(download.get("id", "")),
		str(download.get("version", "")),
		str(download.get("build_id", "")),
		error_string(failure),
		int(failure),
		OS.get_name(),
		source,
		_staged_install_path_exists(source),
		target,
		_staged_install_path_exists(target),
	]


func _staged_install_path_exists(path: String) -> bool:
	if path.is_empty():
		return false
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)


func _is_safe_archive_path(path: String) -> bool:
	var normalized := path.replace("\\", "/")
	if normalized.is_empty() or normalized.begins_with("/") or normalized.contains(":"):
		return false
	for segment: String in normalized.split("/", false):
		if segment in [".", ".."]:
			return false
	return true


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


func _remove_directory_tree(path: String) -> Error:
	var absolute_path := _globalize_storage_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return OK
	var remove_contents_error := _remove_directory_contents(absolute_path)
	if remove_contents_error != OK:
		return remove_contents_error
	return DirAccess.remove_absolute(absolute_path)


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
			"gameBuildId": "",
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
	var configured_status_url := str(config.get("statusUrl", config.get("healthUrl", "")))
	if not configured_status_url.is_empty():
		server_status_url = configured_status_url
	var configured_presence_url := str(config.get("presenceUrl", ""))
	if not configured_presence_url.is_empty():
		presence_url = configured_presence_url
	manifest_url = _normalize_url(manifest_url)
	news_url = _normalize_url(news_url)
	server_status_url = _normalize_url(server_status_url)
	presence_url = _normalize_url(presence_url)
	if manifest_url.is_empty():
		manifest_url = DEFAULT_MANIFEST_URL
	if server_status_url.is_empty():
		server_status_url = LauncherServerHealthService.DEFAULT_STATUS_URL
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
		locale = LauncherLocalization.get_preferred_system_locale()
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
	locale = LauncherLocalization.normalize_locale(
		str(settings.get("locale", LauncherLocalization.get_preferred_system_locale()))
	)


func _save_launcher_settings() -> void:
	var file := FileAccess.open(LAUNCHER_SETTINGS_FILE, FileAccess.WRITE)
	if file == null:
		_log_error("Could not write launcher settings.")
		return

	file.store_string(JSON.stringify({
		"installDir": install_dir,
		"locale": locale,
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
		"gameBuildId": "",
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


func _refresh_last_check_label() -> void:
	if last_check_label == null:
		return
	last_check_label.text = _get_last_check_display_text()


func _get_last_check_display_text() -> String:
	if last_check_datetime.is_empty():
		return _t("Never")
	return _format_last_check_time(last_check_datetime)


func _format_last_check_time(datetime: Dictionary) -> String:
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
	return _t("Download failed: {task} ({reason}). See launcher_error.log.", {
		"task": task_label,
		"reason": reason,
	})


func _get_request_failure_reason(result: int, response_code: int) -> String:
	if response_code > 0:
		return "HTTP %d" % response_code

	match result:
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
			return _t("size mismatch")
		HTTPRequest.RESULT_CANT_CONNECT:
			return _t("cannot connect")
		HTTPRequest.RESULT_CANT_RESOLVE:
			return _t("cannot resolve host")
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return _t("connection error")
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return _t("TLS error")
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return _t("size limit exceeded")
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED:
			return _t("decompress failed")
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
			return _t("cannot open download file")
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return _t("download write error")
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return _t("redirect limit reached")
		HTTPRequest.RESULT_TIMEOUT:
			return _t("timeout")
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
	version_label.text = _t(local_game_version)
	play_button.disabled = server_access_blocked or update_required or not _has_installed_game()
	update_button.disabled = not update_required
	check_button.disabled = false
	_refresh_gen5_sprites_button()
	_refresh_uninstall_button()
	if server_access_blocked:
		_set_status(
			server_access_message if not server_access_message.is_empty() else "Server maintenance.",
			"maintenance"
		)
	elif update_required:
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
	if server_health_check_in_progress:
		return
	server_health_check_in_progress = true
	var result: Dictionary = await LauncherServerHealthService.check_async(self, server_status_url)
	server_health_check_in_progress = false
	if bool(result.get("online", false)):
		_log_server_health_recovery_if_needed(result)
		server_access_blocked = false
		server_access_message = ""
		server_online_label.text = _t("Online")
		server_online_label.add_theme_color_override("font_color", SERVER_ONLINE_COLOR)
		await _refresh_online_players()
	elif bool(result.get("maintenance", false)):
		_log_server_health_recovery_if_needed(result)
		server_access_blocked = true
		server_access_message = str(result.get("message", "")).strip_edges()
		server_online_label.text = _t("Maintenance")
		server_online_label.add_theme_color_override("font_color", SERVER_MAINTENANCE_COLOR)
		online_players_label.text = _t("Players online unavailable")
		online_players_label.add_theme_color_override("font_color", SERVER_CHECKING_COLOR)
	else:
		if not server_health_failure_logged:
			_log_error(
				"Server status check failed after %d attempt(s): %s" % [
					int(result.get("attempts", 1)),
					str(result.get("error", "unknown error")),
				]
			)
			server_health_failure_logged = true
		server_access_blocked = false
		server_access_message = ""
		server_online_label.text = _t("Offline")
		server_online_label.add_theme_color_override("font_color", SERVER_OFFLINE_COLOR)
		online_players_label.text = _t("Players online unavailable")
		online_players_label.add_theme_color_override("font_color", SERVER_CHECKING_COLOR)
	_apply_server_access_status()


func _log_server_health_recovery_if_needed(result: Dictionary) -> void:
	if not server_health_failure_logged:
		return
	_log("Server status check recovered after %d attempt(s)." % int(result.get("attempts", 1)))
	server_health_failure_logged = false


func _apply_server_access_status() -> void:
	var launcher_task_active := (
		http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED
		or (download_service != null and download_service.is_active())
		or launcher_update_busy
		or launcher_update_in_progress
	)
	play_button.disabled = (
		launcher_task_active
		or server_access_blocked
		or update_required
		or not _has_installed_game()
	)
	if not launcher_task_active:
		_refresh_status()
	else:
		_sync_button_cursors()


func _set_server_health_checking() -> void:
	server_online_label.text = _t("Checking...")
	server_online_label.add_theme_color_override("font_color", SERVER_CHECKING_COLOR)
	online_players_label.text = _t("Checking players online...")
	online_players_label.add_theme_color_override("font_color", SERVER_CHECKING_COLOR)


func _refresh_online_players() -> void:
	var result: Dictionary = await LauncherServerHealthService.request_presence_async(self, presence_url)
	if not bool(result.get("success", false)):
		online_players_label.text = _t("Players online unavailable")
		online_players_label.add_theme_color_override("font_color", SERVER_CHECKING_COLOR)
		return

	var online_players: int = int(result.get("onlineUsers", 0))
	online_players_label.text = _t(
		"{count} player online" if online_players == 1 else "{count} players online",
		{"count": online_players}
	)
	online_players_label.add_theme_color_override("font_color", SERVER_ONLINE_COLOR)


func _set_busy(is_busy: bool) -> void:
	var locked := is_busy or launcher_update_busy or launcher_update_in_progress
	check_button.disabled = locked
	update_button.disabled = locked or not update_required
	gen5_sprites_button.disabled = locked or not _can_download_gen5_sprites()
	play_button.disabled = locked or server_access_blocked or update_required or not _has_installed_game()
	uninstall_button.disabled = locked or not _has_game_install_folder()
	_sync_button_cursors()


func _sync_button_cursors() -> void:
	for button: Button in [check_button, update_button, gen5_sprites_button, play_button, patch_notes_button, credits_button, uninstall_button]:
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND
	for button: Button in [
		home_button,
		diagnostics_button,
		diagnostics_back_button,
		diagnostics_copy_button,
		diagnostics_open_folder_button,
		diagnostics_clear_button,
	]:
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND
	game_folder_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	discord_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	patch_notes_button.tooltip_text = _t("Open patch notes")
	credits_button.tooltip_text = _t("View credits")
	uninstall_button.tooltip_text = _t("Remove installed game folder")


func _refresh_gen5_sprites_button() -> void:
	if _has_gen5_sprites_folder():
		gen5_sprites_button.visible = false
		gen5_sprites_button.disabled = true
		gen5_sprites_button.tooltip_text = _t("Gen 5 Animated Sprites are already installed.")
		return

	gen5_sprites_button.visible = true
	if manifest.is_empty():
		gen5_sprites_button.text = _t("Gen 5 Sprites")
		gen5_sprites_button.disabled = true
		gen5_sprites_button.tooltip_text = _t("Download Gen 5 Animated sprites after launcher manifest is available.")
		return

	if _are_gen5_sprites_installed():
		gen5_sprites_button.text = _t("Gen 5 Installed")
		gen5_sprites_button.disabled = true
		gen5_sprites_button.tooltip_text = _t("Gen 5 Animated Sprites are already installed.")
		return

	gen5_sprites_button.text = _t("Download Gen 5")
	gen5_sprites_button.disabled = not _can_download_gen5_sprites()
	gen5_sprites_button.tooltip_text = _t("Download Gen 5 Animated Sprites.")


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
		uninstall_button.tooltip_text = _t("Remove installed game folder")
	else:
		uninstall_button.tooltip_text = _t("No game folder to remove")


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


func _set_status(message: String, state: String = "") -> void:
	status_label.text = _t(message)
	var lowered_message := message.to_lower()
	if state == "maintenance":
		status_value_label.text = _t("Maintenance")
		status_value_label.add_theme_color_override("font_color", SERVER_MAINTENANCE_COLOR)
	elif state == "error" or lowered_message.contains("failed") or lowered_message.contains("could not") or lowered_message.contains("missing") or lowered_message.contains("invalid"):
		status_value_label.text = _t("Error")
		status_value_label.add_theme_color_override("font_color", Color(1.0, 0.38, 0.45))
	elif state == "not_installed" or lowered_message.contains("not installed"):
		status_value_label.text = _t("Not installed")
		status_value_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.34))
	elif state == "update_needed" or lowered_message.contains("update available"):
		status_value_label.text = _t("Update needed")
		status_value_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.34))
	elif state == "updating" or lowered_message.contains("download") or lowered_message.contains("extract") or lowered_message.contains("checking"):
		status_value_label.text = _t("Updating")
		status_value_label.add_theme_color_override("font_color", Color(0.70, 0.45, 1.0))
	else:
		status_value_label.text = _t("Ready.")
		status_value_label.add_theme_color_override("font_color", Color(0.16, 0.94, 0.66))


func _update_progress_percent() -> void:
	if progress_is_indeterminate:
		progress_percent_label.text = ""
		return

	progress_percent_label.text = "%.1f%%" % progress_bar.value


func _format_bytes(byte_count: int) -> String:
	var byte_count_float := float(byte_count)
	if byte_count_float >= 1024.0 * 1024.0 * 1024.0:
		return "%.2f GB" % (byte_count_float / 1024.0 / 1024.0 / 1024.0)
	if byte_count_float >= 1024.0 * 1024.0:
		return "%.1f MB" % (byte_count_float / 1024.0 / 1024.0)
	if byte_count_float >= 1024.0:
		return "%.1f KB" % (byte_count_float / 1024.0)

	return "%d B" % byte_count


func _format_transfer_speed(bytes_per_second: float) -> String:
	if bytes_per_second <= 0.0:
		return _t("waiting for data")
	return "%s/s" % _format_bytes(int(bytes_per_second))


func _get_file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var file_size := file.get_length()
	file.close()
	return file_size


func _escape_bbcode(value: String) -> String:
	return value.replace("[", "[lb]").replace("]", "[rb]")


func _log(message: String) -> void:
	print(message)
	_append_diagnostic("INFO", message)


func _log_error(message: String) -> void:
	print("ERROR: %s" % message)
	if diagnostics_card != null:
		has_unseen_diagnostics_error = not diagnostics_card.visible
		_refresh_diagnostics_button()
	_append_diagnostic("ERROR", message)


func _log_warning(message: String) -> void:
	print("WARNING: %s" % message)
	_append_diagnostic("WARN", message)


func _initialize_diagnostics_log() -> void:
	_rotate_diagnostics_log_if_needed()
	_sanitize_diagnostics_file(ERROR_LOG_FILE)
	_sanitize_diagnostics_file(PREVIOUS_ERROR_LOG_FILE)


func _rotate_diagnostics_log_if_needed() -> void:
	if not FileAccess.file_exists(ERROR_LOG_FILE):
		return

	var file: FileAccess = FileAccess.open(ERROR_LOG_FILE, FileAccess.READ_WRITE)
	if file == null:
		return
	var file_size := file.get_length()
	file.close()
	if file_size < MAX_ERROR_LOG_BYTES:
		return

	var absolute_log_path := _globalize_storage_path(ERROR_LOG_FILE)
	var absolute_previous_log_path := _globalize_storage_path(PREVIOUS_ERROR_LOG_FILE)
	if FileAccess.file_exists(absolute_previous_log_path):
		DirAccess.remove_absolute(absolute_previous_log_path)
	DirAccess.rename_absolute(absolute_log_path, absolute_previous_log_path)


func _append_diagnostic(level: String, message: String) -> void:
	_rotate_diagnostics_log_if_needed()
	var sanitized_message := _sanitize_diagnostic_message(message)
	var file: FileAccess = FileAccess.open(ERROR_LOG_FILE, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(ERROR_LOG_FILE, FileAccess.WRITE)
	if file == null:
		return

	file.seek_end()
	file.store_line("%s %s: %s" % [_format_diagnostic_timestamp(), level, sanitized_message])
	file.close()
	if diagnostics_card != null and diagnostics_card.visible:
		_refresh_diagnostics_view()


func _sanitize_diagnostic_message(message: String) -> String:
	var sanitized := message.replace("\r", " ").replace("\n", " ")
	for private_path: String in _private_diagnostic_paths():
		sanitized = sanitized.replace(private_path, "<private_path>")

	var parts := sanitized.split(" ")
	for index: int in range(parts.size()):
		var part := parts[index]
		var url_start := part.find("https://")
		if url_start < 0:
			url_start = part.find("http://")
		var query_start := -1
		if url_start >= 0:
			query_start = part.find("?", url_start)
		if query_start >= 0:
			parts[index] = "%s?<redacted>" % part.substr(0, query_start)
	return " ".join(parts)


func _private_diagnostic_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	var candidates := [
		_globalize_storage_path("user://").trim_suffix("/").trim_suffix("\\"),
		_globalize_storage_path(install_dir).trim_suffix("/").trim_suffix("\\"),
		OS.get_environment("HOME").trim_suffix("/"),
		OS.get_environment("USERPROFILE").trim_suffix("\\"),
	]
	for candidate: String in candidates:
		if candidate.length() >= 4 and candidate not in paths:
			paths.append(candidate)
	return paths


func _format_diagnostic_timestamp() -> String:
	var datetime := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		int(datetime.get("year", 0)),
		int(datetime.get("month", 0)),
		int(datetime.get("day", 0)),
		int(datetime.get("hour", 0)),
		int(datetime.get("minute", 0)),
		int(datetime.get("second", 0)),
	]


func _sanitize_diagnostic_contents(contents: String) -> String:
	var sanitized_lines := PackedStringArray()
	for line: String in contents.split("\n", true):
		sanitized_lines.append(_sanitize_diagnostic_message(line))
	return "\n".join(sanitized_lines)


func _sanitize_diagnostics_file(path: String) -> void:
	var contents := _read_diagnostics_file(path)
	if contents.is_empty():
		return
	var sanitized_contents := _sanitize_diagnostic_contents(contents)
	if sanitized_contents == contents:
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(sanitized_contents)
	file.close()


func _read_diagnostics_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var contents := file.get_as_text()
	file.close()
	return contents


func _read_diagnostics() -> String:
	return _sanitize_diagnostic_contents(_read_diagnostics_file(ERROR_LOG_FILE))


func _refresh_diagnostics_view() -> void:
	var contents := _read_diagnostics()
	if contents.is_empty():
		diagnostics_log_view.text = _t("No diagnostics recorded yet.")
		return
	diagnostics_log_view.text = _escape_bbcode(contents)
	diagnostics_log_view.scroll_to_line(maxi(diagnostics_log_view.get_line_count() - 1, 0))


func _copy_diagnostics() -> void:
	var contents := _read_diagnostics()
	if contents.is_empty():
		contents = _t("No diagnostics recorded yet.")
	DisplayServer.clipboard_set(contents)
	_log("Diagnostics copied to clipboard.")


func _open_diagnostics_folder() -> void:
	var diagnostics_folder := _globalize_storage_path("user://")
	var open_error := OS.shell_open(diagnostics_folder)
	if open_error != OK:
		_log_error("Could not open diagnostics folder: %s" % error_string(open_error))


func _clear_diagnostics() -> void:
	var file := FileAccess.open(ERROR_LOG_FILE, FileAccess.WRITE)
	if file != null:
		file.close()
	_append_diagnostic("INFO", "Diagnostics log cleared by user.")


func _refresh_diagnostics_button() -> void:
	if diagnostics_button == null:
		return
	diagnostics_button.text = "%s%s" % [
		_t("Diagnostics"),
		" •" if has_unseen_diagnostics_error else "",
	]
