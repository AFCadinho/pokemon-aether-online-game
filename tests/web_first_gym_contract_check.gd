extends SceneTree

var failures := 0


func _init() -> void:
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	var core := _section(presets, "[preset.3]", "[preset.3.options]")
	var module := _section(presets, "[preset.4]", "[preset.4.options]")
	_check(not core.contains("generated/tiled_visuals/pewter_city/**"), "Pewter City is included in the web core")
	_check(not core.contains("generated/tiled_visuals/lobby/**"), "Aether Clash Lobby is included in the web core")
	_check(core.contains("generated/tiled_visuals/aether_clash_duel/**"), "Guild Duel remains outside the web core")
	_check(core.contains("generated/tiled_visuals/waiting_area/**"), "Waiting Area remains outside the web core")
	_check(module.contains("aether_clash_duel.tscn"), "the optional module selects Guild Duel")
	_check(module.contains("aether_clash_battle_royale.tscn"), "the optional module selects Battle Royale")
	_check(module.contains("waiting_area.tscn"), "the optional module selects Waiting Area")

	var loader := FileAccess.get_file_as_string("res://scripts/services/web_asset_module_service.gd")
	_check(loader.contains("FileAccess.get_sha256(pack_path)"), "the browser verifies the module hash")
	_check(loader.contains("ProjectSettings.load_resource_pack(pack_path, false)"), "the browser mounts the verified pack without replacing core assets")
	var guild_service := FileAccess.get_file_as_string("res://scripts/services/guild_service.gd")
	_check(guild_service.contains('path.replace("/game/aether-clash", "/auth/web/aether-clash")'), "Aether Clash uses its narrow web API")
	_check(guild_service.count("_ensure_web_aether_clash_maps()") >= 4, "creation and acceptance wait for the map module")
	var transit_service := FileAccess.get_file_as_string("res://scripts/services/transit_service.gd")
	_check(transit_service.contains('_transit_endpoint() + "/travel"'), "browser Aethernet uses the scoped travel endpoint")
	var login := FileAccess.get_file_as_string("res://scripts/ui/login_screen.gd")
	_check(login.contains("_offer_web_lobby_recovery"), "unsupported saved locations can offer Lobby recovery")
	_check(login.contains("changes your shared position on desktop too"), "Lobby recovery warns about shared position")

	print("web_first_gym_contract_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)


func _section(source: String, start_marker: String, end_marker: String) -> String:
	var start := source.find(start_marker)
	var end := source.find(end_marker, start + start_marker.length())
	return source.substr(start, end - start if end >= 0 else -1)


func _check(ok: bool, label: String) -> void:
	if ok:
		return
	failures += 1
	push_error(label)
