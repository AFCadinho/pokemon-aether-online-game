extends SceneTree

const DamageCalcPanel := preload("res://scripts/battle/battle_ui/battle_damage_calc_panel.gd")

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var panel := DamageCalcPanel.new()
	var content := VBoxContainer.new()
	content.name = "VBoxContainer"
	panel.add_child(content)
	root.add_child(panel)
	await process_frame

	panel.set_knowledge_snapshot({
		"viewerPokemon": [{
			"pokemonRef": "viewer:public-slot-1",
			"active": true,
			"fainted": false,
			"identity": {"state": "known", "value": "Samurott-Hisui"},
			"hp": {"display": {"current": 75, "maximum": 100, "scale": "exact"}},
		}],
		"opponentPokemon": [{
			"pokemonRef": "opponent:public-slot-1",
			"active": true,
			"fainted": false,
			"identity": {"state": "known", "value": "Volcarona"},
		}],
	})

	var pokemon_selector: OptionButton = panel._make_pokemon_selector("viewer", true)
	content.add_child(pokemon_selector)
	_assert_dropdown_style(pokemon_selector, "Pokemon selector")
	var team_icon := panel._make_team_icon_button(panel.knowledge_snapshot["viewerPokemon"][0], "viewer", 0)
	content.add_child(team_icon)
	var team_icon_style := team_icon.get_theme_stylebox("normal") as StyleBoxFlat
	if team_icon_style == null or not team_icon_style.border_color.is_equal_approx(panel.CONDITION_OWN_ACCENT):
		_fail("The selected team icon lacks its relation-colored active outline")
	if str(team_icon.get_meta("pokemon_ref", "")) != "viewer:public-slot-1" or team_icon.mouse_default_cursor_shape != Control.CURSOR_POINTING_HAND:
		_fail("Team icons must expose their public Pokémon ref as a direct click target")
	var team_hp_bar := _find_progress_bar(team_icon)
	if team_hp_bar == null or not is_equal_approx(float(team_hp_bar.value), 75.0):
		_fail("Team icons must show their privacy-safe HP value")
	var field_selector: OptionButton = panel._make_field_scenario_selector("weather", ["", "Rain"])
	content.add_child(field_selector)
	_assert_dropdown_style(field_selector, "Field selector")
	var positive_stage_selector := OptionButton.new()
	content.add_child(positive_stage_selector)
	panel._apply_calcdex_dropdown_style(positive_stage_selector, 28.0, 10)
	panel._apply_boost_stage_style(positive_stage_selector, 1, true, false)
	if not positive_stage_selector.get_theme_color("font_color").is_equal_approx(panel.STAGE_POSITIVE):
		_fail("Positive public stat stages lack their semantic color")
	var negative_stage_selector := OptionButton.new()
	content.add_child(negative_stage_selector)
	panel._apply_calcdex_dropdown_style(negative_stage_selector, 28.0, 10)
	panel._apply_boost_stage_style(negative_stage_selector, -1, false, true)
	if not negative_stage_selector.get_theme_color("font_color").is_equal_approx(panel.STAGE_NEGATIVE):
		_fail("Negative edited stat stages lack their semantic color")
	if panel.ITEM_LABEL_ACCENT != panel.ABILITY_LABEL_ACCENT \
			or panel.ITEM_LABEL_ACCENT != panel.NATURE_LABEL_ACCENT:
		_fail("Default set-field labels must share one quiet neutral color")
	if panel.TEXT_ACCENT.is_equal_approx(panel.CONDITION_OWN_ACCENT) \
			or panel.TEXT_ACCENT.is_equal_approx(panel.CONDITION_OPPONENT_ACCENT):
		_fail("Interaction states must not reuse either team-identity color")
	if panel.SURFACE_CANVAS.get_luminance() >= panel.SURFACE_PANEL.get_luminance() \
			or panel.SURFACE_PANEL.get_luminance() >= panel.SURFACE_RAISED.get_luminance():
		_fail("Calcdex surfaces must retain a visible canvas-panel-raised hierarchy")

	var suggestions_panel := panel._make_selector_suggestions_panel()
	content.add_child(suggestions_panel)
	if not suggestions_panel.has_theme_stylebox_override("panel"):
		_fail("Autocomplete suggestions lack their own Calcdex dropdown panel")
	var suggestion_button := panel._make_selector_result_button("Flame Body", "Ability", func() -> void: pass, true)
	suggestions_panel.add_child(suggestion_button)
	for style_name: String in ["normal", "hover", "pressed", "focus"]:
		if not suggestion_button.has_theme_stylebox_override(style_name):
			_fail("Autocomplete suggestion lacks its %s state" % style_name)
	if suggestion_button.mouse_default_cursor_shape != Control.CURSOR_POINTING_HAND:
		_fail("Autocomplete suggestions lack an interactive cursor")
	if not _has_label_text(suggestion_button, "Flame Body") or not _has_label_text(suggestion_button, "Ability"):
		_fail("Autocomplete suggestions must visually separate their title and subtitle")

	panel.sample_set_options = [{
		"id": "fixture-set",
		"name": "Offensive",
		"item": "Heavy-Duty Boots",
		"ability": "Flame Body",
		"nature": "Timid",
		"evs": {"spa": 252, "spe": 252},
		"ivs": {},
		"moves": ["Fiery Dance"],
	}]
	var usage_host := VBoxContainer.new()
	content.add_child(usage_host)
	panel._add_sample_set_selector(usage_host)
	var usage_selector := _find_option_button(usage_host)
	if usage_selector == null:
		_fail("Usage/sample-set selector was not created")
	else:
		_assert_dropdown_style(usage_selector, "Set selector")
	if failed:
		quit(1)
		return

	print("PASS battle_calcdex_dropdown_style_check")
	panel.queue_free()
	await process_frame
	quit(0)


func _assert_dropdown_style(selector: OptionButton, label: String) -> void:
	if selector == null:
		_fail("%s is missing" % label)
		return
	for style_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		if not selector.has_theme_stylebox_override(style_name):
			_fail("%s lacks the %s style" % [label, style_name])
			return
	if not selector.has_theme_icon_override("arrow"):
		_fail("%s still uses the default Godot arrow" % label)
		return
	if selector.mouse_default_cursor_shape != Control.CURSOR_POINTING_HAND:
		_fail("%s lacks the interactive cursor" % label)
		return
	var popup := selector.get_popup()
	if popup == null or not popup.has_theme_stylebox_override("panel"):
		_fail("%s popup lacks its Calcdex panel style" % label)
		return
	if not popup.has_theme_stylebox_override("hover"):
		_fail("%s popup lacks its item hover style" % label)
		return
	if not popup.has_theme_icon_override("radio_checked") or not popup.has_theme_icon_override("radio_unchecked"):
		_fail("%s popup still uses default Godot selection icons" % label)


func _find_option_button(node: Node) -> OptionButton:
	if node is OptionButton:
		return node as OptionButton
	for child: Node in node.get_children():
		var result := _find_option_button(child)
		if result != null:
			return result
	return null


func _has_label_text(node: Node, expected: String) -> bool:
	if node is Label and (node as Label).text == expected:
		return true
	for child: Node in node.get_children():
		if _has_label_text(child, expected):
			return true
	return false


func _find_progress_bar(node: Node) -> ProgressBar:
	if node is ProgressBar:
		return node as ProgressBar
	for child: Node in node.get_children():
		var result := _find_progress_bar(child)
		if result != null:
			return result
	return null


func _fail(message: String) -> void:
	failed = true
	push_error(message)
