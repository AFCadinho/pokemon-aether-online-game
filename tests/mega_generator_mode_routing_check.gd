extends SceneTree

var failed := false


func _init() -> void:
	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	var client_source := FileAccess.get_file_as_string(
		"res://scripts/battle/battle_api/pokemon_data_api_client.gd"
	)

	_check(
		overlay_source.contains(
			"preserve_direct_battle_form"
		),
		"developer Pokemon generator routes the explicit direct-form choice"
	)
	_check(
		overlay_source.contains(
			"test_purpose.length() < 8"
		),
		"developer direct-form generation requires an explicit test purpose"
	)
	_check(
		overlay_source.contains(
			"PokemonDataApiClient.create_team_from_text(parse_pokemon_request, pokemon_text)"
		),
		"Alpha generator uses the safe normalized Mega-form path"
	)
	_check(
		client_source.contains(
			'"preserveDirectBattleForm": preserve_direct_battle_form'
		),
		"Pokemon-data client sends the testing-only direct-form option"
	)
	_check(
		overlay_source.contains("dev_preserve_direct_form.set_pressed_no_signal(false)"),
		"testing-only direct-form option resets instead of being remembered"
	)
	_check(
		overlay_source.contains("_can_generate_direct_battle_forms()"),
		"direct-form control has its own client permission boundary"
	)

	if failed:
		quit(1)
		return
	print("PASS mega_generator_mode_routing_check")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("FAIL: %s" % message)
