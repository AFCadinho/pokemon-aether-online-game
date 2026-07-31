extends Control

const WORLD_SCENE_PATH := "res://scenes/world.tscn"
const LOGIN_SCENE_PATH := "res://scenes/interface/login_screen.tscn"
const CharacterAppearanceService := preload("res://scripts/services/character_appearance_service.gd")
const LOGO_TEXTURE := preload("res://assets/ui/pokeaether_text_logo.png")
const BACKGROUND_TEXTURE := preload("res://assets/background/battle/pokemon_x_and_y_battle_background_11_by_phoenixoflight92_d843okx-414w-2x.jpg")
const UI_TEXT := Color("#eef4ff")
const UI_MUTED_TEXT := Color("#8fa3bf")
const UI_CYAN := Color("#63d7ff")
const UI_GOLD := Color("#d8b767")
const UI_SUCCESS := Color("#58dfa2")

var status_label: Label
var session_label: Label
var title_label: Label
var loading_spinner: Control
var spinner_tween: Tween
var stage_panels: Array[PanelContainer] = []
var stage_labels: Array[Label] = []
var status_translation_key := "ui.loading.loading_profile"
var active_stage_index := 0


func _ready() -> void:
	_build_layout()
	if not LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.connect(_on_locale_changed)
	_prepare_world.call_deferred()


func _build_layout() -> void:
	var background := TextureRect.new()
	background.texture = BACKGROUND_TEXTURE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var overlay := ColorRect.new()
	overlay.color = Color(0.004, 0.012, 0.027, 0.82)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var aura := TextureRect.new()
	aura.texture = _create_aura_texture()
	aura.custom_minimum_size = Vector2(760, 520)
	aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aura.set_anchors_preset(Control.PRESET_CENTER)
	aura.position = Vector2(-380, -260)
	add_child(aura)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(570, 350)
	panel.add_theme_stylebox_override("panel", _create_panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 38)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	session_label = Label.new()
	session_label.text = LocalizationManager.text("ui.loading.secure_session")
	session_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	session_label.add_theme_font_size_override("font_size", 10)
	session_label.add_theme_color_override("font_color", UI_SUCCESS)
	layout.add_child(session_label)

	var logo := TextureRect.new()
	logo.texture = LOGO_TEXTURE
	logo.custom_minimum_size = Vector2(300, 86)
	logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layout.add_child(logo)

	title_label = Label.new()
	title_label.text = LocalizationManager.text("ui.loading.preparing")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", UI_TEXT)
	layout.add_child(title_label)

	status_label = Label.new()
	status_label.text = LocalizationManager.text(status_translation_key)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	layout.add_child(status_label)

	var spinner_center := CenterContainer.new()
	spinner_center.custom_minimum_size = Vector2(0, 34)
	layout.add_child(spinner_center)
	loading_spinner = _create_loading_spinner()
	spinner_center.add_child(loading_spinner)

	var stages := HBoxContainer.new()
	stages.alignment = BoxContainer.ALIGNMENT_CENTER
	stages.add_theme_constant_override("separation", 8)
	layout.add_child(stages)
	for stage_key: String in [
		"ui.loading.stage.trainer",
		"ui.loading.stage.party",
		"ui.loading.stage.world",
	]:
		_add_stage_indicator(stages, stage_key)
	_refresh_stage_indicators(0)
	_start_spinner_animation.call_deferred()


func _on_locale_changed(_locale: String) -> void:
	session_label.text = LocalizationManager.text("ui.loading.secure_session")
	title_label.text = LocalizationManager.text("ui.loading.preparing")
	status_label.text = LocalizationManager.text(status_translation_key)
	_refresh_stage_indicators(active_stage_index)


func _prepare_world() -> void:
	if not AuthService.is_authenticated():
		_return_to_login("Your session expired. Please sign in again.")
		return

	StoryService.reset_story()
	_set_loading_status("ui.loading.loading_profile", 0)
	var story_bootstrap_response: Dictionary = await PlayerGameStateService.bootstrap_story()
	if not bool(story_bootstrap_response.get("success", false)):
		push_warning(
			"LoadingScreen: story bootstrap failed: %s"
			% str(story_bootstrap_response.get("error", "Unknown error"))
		)
		_return_to_login("Could not prepare your story progress. Please try again.")
		return
	var profile_response: Dictionary = await PlayerGameStateService.load_player_profile()
	var saved_state: Dictionary = {}
	if bool(profile_response.get("success", false)):
		if not _apply_profile_response(profile_response):
			await AuthService.logout()
			_return_to_login("The authenticated account did not match its profile.")
			return
		var position_response: Dictionary = _dictionary_from_value(profile_response.get("position", {}))
		if bool(position_response.get("hasState", false)):
			saved_state = _dictionary_from_value(position_response.get("state", {}))
			_apply_saved_appearance_state(saved_state)
	else:
		push_warning("LoadingScreen: player profile load failed: %s" % str(profile_response.get("error", "Unknown error")))
		if AuthService.account_switch_pending:
			await AuthService.logout()
			_return_to_login("The switched account profile could not be loaded safely.")
			return
		await _load_legacy_world_state()
		var position_response: Dictionary = await PlayerGameStateService.load_player_position()
		if bool(position_response.get("success", false)) and bool(position_response.get("hasState", false)):
			saved_state = _dictionary_from_value(position_response.get("state", {}))
			_apply_saved_appearance_state(saved_state)
		elif not bool(position_response.get("success", false)):
			push_warning("LoadingScreen: player position load failed: %s" % str(position_response.get("error", "Unknown error")))

	GameState.set_prepared_world_state({
		"savedState": saved_state,
		"hasSavedState": not saved_state.is_empty(),
	})

	_set_loading_status("ui.loading.opening_path", 2)
	var world_scene: PackedScene = await _load_world_scene_threaded()
	if world_scene == null:
		_return_to_login("Could not load the world. Please contact staff.")
		return

	var error: Error = get_tree().change_scene_to_packed(world_scene)
	if error != OK:
		push_error("LoadingScreen: failed to load world scene: %s" % error_string(error))
		_return_to_login("Could not enter the world. Please contact staff.")
	else:
		AuthService.finish_account_switch()


func _load_world_scene_threaded() -> PackedScene:
	var request_error: Error = ResourceLoader.load_threaded_request(WORLD_SCENE_PATH, "PackedScene")
	if request_error != OK and request_error != ERR_BUSY:
		push_error(
			"LoadingScreen: could not start threaded world load: %s"
			% error_string(request_error)
		)
		return null

	while true:
		var status: int = ResourceLoader.load_threaded_get_status(WORLD_SCENE_PATH)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				return ResourceLoader.load_threaded_get(WORLD_SCENE_PATH) as PackedScene
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				await get_tree().process_frame
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_error("LoadingScreen: threaded world load failed with status %d" % status)
				return null
			_:
				push_error("LoadingScreen: threaded world load returned unexpected status %d" % status)
				return null
	return null


func _return_to_login(message: String) -> void:
	push_warning("LoadingScreen: %s" % message)
	var error: Error = get_tree().change_scene_to_file(LOGIN_SCENE_PATH)
	if error != OK:
		push_error("LoadingScreen: failed to return to login: %s" % error_string(error))


func _dictionary_from_value(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var dictionary: Dictionary = value
	return dictionary


func _apply_profile_response(profile_response: Dictionary) -> bool:
	var user: Dictionary = _dictionary_from_value(profile_response.get("user", {}))
	var authenticated_user_id := AuthService.get_user_id_text()
	var profile_user_id := AuthService.get_user_id_text_from(user)
	if profile_user_id != "" and authenticated_user_id != "" and profile_user_id != authenticated_user_id:
		push_error("LoadingScreen: authenticated user does not match loaded profile")
		return false
	PlayerSave.apply_account_identity(
		user if not user.is_empty() else AuthService.current_user
	)
	var gender_text: String = CharacterAppearanceService.normalize_gender(str(user.get("gender", AuthService.get_gender())))
	PlayerSave.gender = "female" if gender_text == "female" else "male"
	PlayerSave.ensure_body_matches_gender()

	var party_response: Dictionary = _dictionary_from_value(profile_response.get("party", {}))
	if bool(party_response.get("hasParty", false)):
		var party_value: Variant = party_response.get("party", [])
		if party_value is Array:
			PlayerSave.replace_party_from_state(party_value as Array)
	else:
		PlayerSave.replace_party_from_state([])

	var preferences: Dictionary = _dictionary_from_value(profile_response.get("preferences", {}))
	GameState.show_follower = bool(preferences.get("showFollower", GameState.show_follower))
	GameState.repel_enabled = bool(preferences.get("showRepel", GameState.repel_enabled))
	GameState.running_shoes_enabled = bool(preferences.get("runningShoes", GameState.running_shoes_enabled))
	GameState.selected_role_badge = str(preferences.get("selectedRoleBadge", GameState.selected_role_badge)).strip_edges().to_lower()
	AuthService.current_user["selectedRoleBadge"] = GameState.selected_role_badge

	var wallet: Dictionary = _dictionary_from_value(profile_response.get("wallet", {}))
	PlayerSave.money = max(int(wallet.get("money", PlayerSave.money)), 0)
	PlayerSave.gems = max(int(wallet.get("gems", PlayerSave.gems)), 0)
	PlayerSave.aetherite = max(int(wallet.get("aetherite", PlayerSave.aetherite)), 0)
	PlayerSave.battle_points = max(int(wallet.get("battle_points", PlayerSave.battle_points)), 0)

	var stats_response: Dictionary = _dictionary_from_value(profile_response.get("stats", {}))
	var stats: Dictionary = _dictionary_from_value(stats_response.get("stats", {}))
	PlayerSave.playtime_seconds = max(int(stats.get("playtimeSeconds", PlayerSave.playtime_seconds)), 0)
	PlayerSave.flags["trainer_stats"] = stats.duplicate(true)
	PlayerSave.apply_gym_badge_state(_dictionary_from_value(profile_response.get("badges", {})))
	StoryService.apply_story(_dictionary_from_value(profile_response.get("story", {})))
	return true


func _load_legacy_world_state() -> void:
	_set_loading_status("ui.loading.restoring_party", 1)
	var party_response: Dictionary = await PlayerPartyStateService.load_party()
	if not bool(party_response.get("success", false)):
		push_warning("LoadingScreen: player party load failed: %s" % str(party_response.get("error", "Unknown error")))
	elif bool(party_response.get("hasParty", false)):
		var party_value: Variant = party_response.get("party", [])
		if party_value is Array:
			PlayerSave.replace_party_from_state(party_value as Array)
	else:
		PlayerSave.replace_party_from_state([])

	_set_loading_status("ui.loading.finding_location", 2)


func _apply_saved_appearance_state(state: Dictionary) -> void:
	var appearance: Dictionary = _dictionary_from_value(state.get("appearance", {}))
	PlayerSave.apply_appearance_state(appearance)

	var body_id: String = str(appearance.get("body", "")).strip_edges()
	if body_id == "":
		return


func _create_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.031, 0.057, 0.97)
	style.border_width_left = 1
	style.border_width_top = 2
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.31, 0.55, 0.82, 0.9)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_right = 18
	style.corner_radius_bottom_left = 18
	style.shadow_color = Color(0.18, 0.16, 0.58, 0.42)
	style.shadow_size = 36
	style.shadow_offset = Vector2(0, 12)
	return style


func _create_surface_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	return style


func _create_aura_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.34, 0.22, 0.85, 0.28),
		Color(0.08, 0.48, 0.72, 0.12),
		Color(0.02, 0.08, 0.16, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 760
	texture.height = 520
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func _add_stage_indicator(parent: HBoxContainer, translation_key: String) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(104, 30)
	parent.add_child(panel)
	stage_panels.append(panel)

	var label := Label.new()
	label.text = LocalizationManager.text(translation_key)
	label.set_meta("translation_key", translation_key)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	panel.add_child(label)
	stage_labels.append(label)


func _set_loading_status(translation_key: String, active_stage: int) -> void:
	status_translation_key = translation_key
	status_label.text = LocalizationManager.text(status_translation_key)
	_refresh_stage_indicators(active_stage)


func _refresh_stage_indicators(active_stage: int) -> void:
	active_stage_index = active_stage
	for index in range(stage_panels.size()):
		var panel := stage_panels[index]
		var label := stage_labels[index]
		var base_text := LocalizationManager.text(str(label.get_meta("translation_key", "")))
		if index < active_stage:
			label.text = "✓ %s" % base_text
			label.add_theme_color_override("font_color", UI_SUCCESS)
			panel.add_theme_stylebox_override(
				"panel",
				_create_surface_style(Color(0.04, 0.18, 0.16, 0.72), Color(0.21, 0.72, 0.56, 0.5), 8)
			)
		elif index == active_stage:
			label.text = "● %s" % base_text
			label.add_theme_color_override("font_color", UI_CYAN)
			panel.add_theme_stylebox_override(
				"panel",
				_create_surface_style(Color(0.04, 0.13, 0.23, 0.9), Color(0.39, 0.84, 1.0, 0.75), 8)
			)
		else:
			label.text = "○ %s" % base_text
			label.add_theme_color_override("font_color", UI_MUTED_TEXT)
			panel.add_theme_stylebox_override(
				"panel",
				_create_surface_style(Color(0.03, 0.06, 0.11, 0.68), Color(0.18, 0.28, 0.4, 0.62), 8)
			)


func _create_loading_spinner() -> Control:
	var spinner := Control.new()
	spinner.custom_minimum_size = Vector2(32, 32)
	spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := Vector2(16, 16)
	var segment_count := 10
	for index in range(segment_count):
		var angle := TAU * float(index) / float(segment_count)
		var segment := Line2D.new()
		segment.width = 3.0
		segment.begin_cap_mode = Line2D.LINE_CAP_ROUND
		segment.end_cap_mode = Line2D.LINE_CAP_ROUND
		segment.points = PackedVector2Array([
			center + Vector2(0, -9).rotated(angle),
			center + Vector2(0, -14).rotated(angle),
		])
		var emphasis := float(index + 1) / float(segment_count)
		segment.default_color = UI_CYAN.lerp(UI_GOLD, emphasis * 0.45)
		segment.default_color.a = lerp(0.16, 1.0, emphasis)
		spinner.add_child(segment)
	return spinner


func _start_spinner_animation() -> void:
	if loading_spinner == null:
		return
	if spinner_tween != null and spinner_tween.is_valid():
		spinner_tween.kill()
	loading_spinner.pivot_offset = loading_spinner.size * 0.5
	spinner_tween = create_tween()
	spinner_tween.set_loops()
	spinner_tween.tween_property(loading_spinner, "rotation", TAU, 0.85).from(0.0).set_trans(Tween.TRANS_LINEAR)
