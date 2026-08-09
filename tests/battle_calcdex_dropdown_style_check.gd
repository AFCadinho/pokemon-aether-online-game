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
	var field_selector: OptionButton = panel._make_field_scenario_selector("weather", ["", "Rain"])
	content.add_child(field_selector)
	_assert_dropdown_style(field_selector, "Field selector")
	var positive_stage_selector := OptionButton.new()
	content.add_child(positive_stage_selector)
	panel._apply_calcdex_dropdown_style(positive_stage_selector, 28.0, 10)
	panel._apply_boost_stage_style(positive_stage_selector, 1, true, false)
	if not positive_stage_selector.get_theme_color("font_color").is_equal_approx(Color(0.36, 0.86, 0.53, 1.0)):
		_fail("Positive public stat stages lack their semantic color")
	var negative_stage_selector := OptionButton.new()
	content.add_child(negative_stage_selector)
	panel._apply_calcdex_dropdown_style(negative_stage_selector, 28.0, 10)
	panel._apply_boost_stage_style(negative_stage_selector, -1, false, true)
	if not negative_stage_selector.get_theme_color("font_color").is_equal_approx(Color(0.96, 0.39, 0.39, 1.0)):
		_fail("Negative edited stat stages lack their semantic color")

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


func _fail(message: String) -> void:
	failed = true
	push_error(message)
