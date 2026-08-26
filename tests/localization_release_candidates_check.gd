extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"
const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"
const PLAYER_STATUS_SCENE_PATH := "res://scenes/interface/player_status_card.tscn"
const LOGIN_SCENE_PATH := "res://scenes/interface/login_screen.tscn"
const VS_SCENE_PATH := "res://scenes/battle/vs_panel_container.tscn"
const SUPPORTED_LOCALES: Array[String] = ["en", "nl", "pt_BR", "zh_CN"]
const SUPPORTED_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

var failed := false
var localization_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	localization_manager = root.get_node_or_null("LocalizationManager")
	_check(localization_manager != null, "Release candidate check can access LocalizationManager")
	if localization_manager == null:
		quit(1)
		return

	var original_locale := str(localization_manager.get("current_locale"))
	_check_scene_source_contracts()
	await _check_runtime_locale_and_layout_matrix()
	localization_manager.call("set_locale", original_locale)
	quit(1 if failed else 0)


func _check_scene_source_contracts() -> void:
	var overlay_scene := FileAccess.get_file_as_string(OVERLAY_SCENE_PATH)
	var overlay_script := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)
	var player_status_scene := FileAccess.get_file_as_string(PLAYER_STATUS_SCENE_PATH)
	var login_scene := FileAccess.get_file_as_string(LOGIN_SCENE_PATH)
	var vs_scene := FileAccess.get_file_as_string(VS_SCENE_PATH)

	for key: String in [
		"ui.world.location.unknown",
		"ui.world.location.unknown_region",
		"ui.mail.title",
		"ui.mail.new",
		"ui.mail.empty.inbox",
		"ui.mail.detail.choose",
		"ui.mail.compose.recipient_placeholder",
		"ui.mail.compose.message_placeholder",
		"ui.mail.compose.send",
	]:
		_check(overlay_scene.contains('"%s"' % key), "Overlay scene uses semantic key %s" % key)
	_check(
		player_status_scene.count('text = "ui.trainer_card.trainer"') == 2,
		"Player status defaults use Trainer Card localization"
	)
	_check(
		login_scene.contains('[node name="SavedUsernameLabel"')
		and _node_block(login_scene, '[node name="SavedUsernameLabel"').contains('text = ""'),
		"Saved username preview starts empty until player data is available"
	)
	_check(vs_scene.contains('text = "VS"'), "Battle versus marker is classified as non-linguistic")
	_check(
		overlay_script.contains(
			'host.title = LocalizationManager.text("ui.pokemon_summary.title")'
		),
		"Detached Pokémon Summary window uses its semantic title"
	)


func _check_runtime_locale_and_layout_matrix() -> void:
	var packed := load(OVERLAY_SCENE_PATH) as PackedScene
	_check(packed != null, "Final localized overlay scene loads")
	if packed == null:
		return

	var overlay := packed.instantiate()
	root.add_child(overlay)
	await process_frame

	var root_control := overlay.get_node_or_null("Control") as Control
	var location_panel := overlay.get("location_panel") as Control
	var player_status_panel := overlay.get("player_status_panel") as Control
	var mail_popup := overlay.get("mail_popup") as Control
	var compose_popup := overlay.get("mail_compose_popup") as Control
	var mail_title := mail_popup.find_child("Title", true, false) as Label
	var compose_title := compose_popup.find_child("Title", true, false) as Label
	var compose_body := overlay.get("mail_compose_body_input") as TextEdit
	var compose_scroll := compose_popup.get_node_or_null("ComposeScroll") as ScrollContainer
	var compose_margin := compose_popup.find_child("MarginContainer", true, false) as MarginContainer
	var selected_attachments_list := overlay.get("mail_selected_attachments_list") as VBoxContainer
	var trainer_eyebrow := player_status_panel.find_child("EyebrowLabel", true, false) as Label
	_check(compose_scroll != null, "Mail composer installs its minimum-resolution scroll workspace")
	_check(
		compose_margin != null and compose_margin.get_parent() == compose_scroll,
		"Mail composer content remains reachable after workspace setup"
	)
	_check(
		selected_attachments_list != null
		and selected_attachments_list.get_parent() is ScrollContainer,
		"Mail attachment styling has a stable runtime scroll reference"
	)
	if root_control != null:
		root_control.set_anchors_preset(Control.PRESET_TOP_LEFT)
		root_control.position = Vector2.ZERO

	for locale: String in SUPPORTED_LOCALES:
		localization_manager.call("set_locale", locale)
		await process_frame
		_check(
			mail_title != null
			and mail_title.text == localization_manager.call("text", "ui.mail.title"),
			"Mailbox title renders for %s" % locale
		)
		_check(
			compose_title != null
			and compose_title.text == localization_manager.call("text", "ui.mail.compose.title"),
			"Mail composer title renders for %s" % locale
		)
		_check(
			compose_body != null
			and compose_body.placeholder_text
				== localization_manager.call("text", "ui.mail.compose.message_placeholder"),
			"Mail body placeholder renders for %s" % locale
		)
		_check(
			trainer_eyebrow != null
			and trainer_eyebrow.text
				== localization_manager.call("text", "ui.trainer_card.trainer"),
			"Player status heading renders for %s" % locale
		)

		for resolution: Vector2i in SUPPORTED_RESOLUTIONS:
			root_control.size = Vector2(resolution)
			await process_frame
			overlay.call(
				"_move_mail_to_global_position",
				Vector2(
					(float(resolution.x) - mail_popup.size.x) * 0.5,
					(float(resolution.y) - mail_popup.size.y) * 0.5
				)
			)
			await process_frame
			_check(
				root_control != null and root_control.size.is_equal_approx(Vector2(resolution)),
				"Overlay fills %s at %s" % [str(resolution), locale]
			)
			_check_control_fits(location_panel, resolution, "Location card", locale)
			_check_control_fits(player_status_panel, resolution, "Player status card", locale)
			_check_control_fits(mail_popup, resolution, "Mailbox", locale)
			_check_control_fits(compose_popup, resolution, "Mail composer", locale)

	for loader_property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader := overlay.get(loader_property) as Node
		if loader != null:
			loader.free()
	overlay.queue_free()
	await process_frame


func _check_control_fits(
	control: Control,
	resolution: Vector2i,
	label: String,
	locale: String
) -> void:
	_check(control != null, "%s exists for layout validation" % label)
	if control == null:
		return
	var rect := control.get_rect()
	_check(
		rect.position.x >= -1.0
		and rect.position.y >= -1.0
		and rect.end.x <= float(resolution.x) + 1.0
		and rect.end.y <= float(resolution.y) + 1.0,
		"%s fits %s at %s (rect %s)" % [label, str(resolution), locale, str(rect)]
	)


func _node_block(source: String, marker: String) -> String:
	var start := source.find(marker)
	if start < 0:
		return ""
	var next := source.find("\n[node ", start + marker.length())
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
