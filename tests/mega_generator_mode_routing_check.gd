extends SceneTree

var failed := false


func _init() -> void:
	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	var client_source := FileAccess.get_file_as_string(
		"res://scripts/battle/battle_api/pokemon_data_api_client.gd"
	)

	_check(
		overlay_source.contains(
			"PokemonDataApiClient.create_pokemon_from_text(parse_pokemon_request, pokemon_text, true)"
		),
		"developer single-Pokemon and encounter generators preserve direct Mega forms"
	)
	_check(
		overlay_source.contains(
			"PokemonDataApiClient.create_team_from_text(parse_pokemon_request, team_text, true)"
		),
		"developer team generator preserves direct Mega forms"
	)
	_check(
		overlay_source.contains(
			"PokemonDataApiClient.create_team_from_text(parse_pokemon_request, pokemon_text)"
		),
		"Alpha generator uses the safe normalized Mega-form path"
	)
	_check(
		client_source.contains(
			'"preserveDirectStandardMegaForm": preserve_direct_standard_mega_form'
		),
		"Pokemon-data client sends the legacy standard-Mega compatibility option"
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
