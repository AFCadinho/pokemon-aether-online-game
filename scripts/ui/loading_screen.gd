extends Control

const WORLD_SCENE_PATH := "res://scenes/world.tscn"
const LOGIN_SCENE_PATH := "res://scenes/interface/login_screen.tscn"
const CharacterAppearanceService := preload("res://scripts/services/character_appearance_service.gd")
const LOGO_TEXTURE := preload("res://assets/ui/pokeaether_text_logo.png")
const BACKGROUND_TEXTURE := preload("res://assets/background/battle/pokemon_x_and_y_battle_background_11_by_phoenixoflight92_d843okx-414w-2x.jpg")

var status_label: Label


func _ready() -> void:
	_build_layout()
	_prepare_world.call_deferred()


func _build_layout() -> void:
	var background := TextureRect.new()
	background.texture = BACKGROUND_TEXTURE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var overlay := ColorRect.new()
	overlay.color = Color(0.005, 0.011, 0.024, 0.76)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 300)
	panel.add_theme_stylebox_override("panel", _create_panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_bottom", 36)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 22)
	margin.add_child(layout)

	var logo := TextureRect.new()
	logo.texture = LOGO_TEXTURE
	logo.custom_minimum_size = Vector2(340, 110)
	logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layout.add_child(logo)

	var title := Label.new()
	title.text = "Entering PokeAether"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.96, 0.96, 1.0))
	layout.add_child(title)

	status_label = Label.new()
	status_label.text = "Loading your trainer..."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(0.76, 0.78, 0.86))
	layout.add_child(status_label)


func _prepare_world() -> void:
	if not AuthService.is_authenticated():
		_return_to_login("Your session expired. Please sign in again.")
		return

	status_label.text = "Loading your trainer profile..."
	var profile_response: Dictionary = await PlayerGameStateService.load_player_profile()
	var saved_state: Dictionary = {}
	if bool(profile_response.get("success", false)):
		_apply_profile_response(profile_response)
		var position_response: Dictionary = _dictionary_from_value(profile_response.get("position", {}))
		if bool(position_response.get("hasState", false)):
			saved_state = _dictionary_from_value(position_response.get("state", {}))
			_apply_saved_appearance_state(saved_state)
	else:
		push_warning("LoadingScreen: player profile load failed: %s" % str(profile_response.get("error", "Unknown error")))
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

	status_label.text = "Entering the world..."
	var error: Error = get_tree().change_scene_to_file(WORLD_SCENE_PATH)
	if error != OK:
		push_error("LoadingScreen: failed to load world scene: %s" % error_string(error))
		_return_to_login("Could not enter the world. Please contact staff.")


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


func _apply_profile_response(profile_response: Dictionary) -> void:
	var user: Dictionary = _dictionary_from_value(profile_response.get("user", {}))
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

	var stats_response: Dictionary = _dictionary_from_value(profile_response.get("stats", {}))
	var stats: Dictionary = _dictionary_from_value(stats_response.get("stats", {}))
	PlayerSave.playtime_seconds = max(int(stats.get("playtimeSeconds", PlayerSave.playtime_seconds)), 0)


func _load_legacy_world_state() -> void:
	status_label.text = "Loading your party..."
	var party_response: Dictionary = await PlayerPartyStateService.load_party()
	if not bool(party_response.get("success", false)):
		push_warning("LoadingScreen: player party load failed: %s" % str(party_response.get("error", "Unknown error")))
	elif bool(party_response.get("hasParty", false)):
		var party_value: Variant = party_response.get("party", [])
		if party_value is Array:
			PlayerSave.replace_party_from_state(party_value as Array)
	else:
		PlayerSave.replace_party_from_state([])

	status_label.text = "Loading your location..."


func _apply_saved_appearance_state(state: Dictionary) -> void:
	var appearance: Dictionary = _dictionary_from_value(state.get("appearance", {}))
	PlayerSave.apply_appearance_state(appearance)

	var body_id: String = str(appearance.get("body", "")).strip_edges()
	if body_id == "":
		return


func _create_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.008, 0.012, 0.023, 0.94)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.784, 0.608, 0.353, 0.86)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.shadow_color = Color(0, 0, 0, 0.46)
	style.shadow_size = 22
	style.shadow_offset = Vector2(0, 10)
	return style
