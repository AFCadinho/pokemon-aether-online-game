extends SceneTree

const MENU := "res://scenes/interface/settings/settings_menu.tscn"
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings := root.get_node("SettingsManager")
	var sfx := root.get_node("SfxManager")
	var original := FileAccess.get_file_as_string(settings.SETTINGS_PATH)
	var original_data: Dictionary = JSON.parse_string(original)
	var legacy := original_data.duplicate(true)
	legacy.erase("battle_sfx_volume")
	legacy.erase("overworld_sfx_volume")
	legacy["sfx_volume"] = 23.0
	_write(legacy)
	settings.load_settings()
	_check(settings.battle_sfx_volume == 23.0 and settings.overworld_sfx_volume == 23.0, "Real legacy file preserves both volumes")
	legacy["sfx_volume"] = 0.0
	_write(legacy)
	settings.load_settings()
	_check(settings.battle_sfx_volume == 0.0 and settings.overworld_sfx_volume == 0.0, "Legacy mute remains muted")
	legacy["battle_sfx_volume"] = 47.0
	_write(legacy)
	settings.load_settings()
	_check(settings.battle_sfx_volume == 47.0 and settings.overworld_sfx_volume == 0.0, "Partial migration preserves explicit new choice")
	settings.call("_load_sfx_volumes", {})
	_check(settings.battle_sfx_volume == 75.0 and settings.overworld_sfx_volume == 75.0, "Fresh defaults remain 75 percent")
	settings.set_master_volume(50.0)
	settings.set_battle_sfx_volume(25.0)
	settings.set_overworld_sfx_volume(80.0)
	settings.set_notification_volume(60.0)
	var stored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(settings.SETTINGS_PATH))
	_check(stored.battle_sfx_volume == 25.0 and stored.overworld_sfx_volume == 80.0, "Independent volumes persist")
	settings.load_settings()
	_check(settings.battle_sfx_volume == 25.0 and settings.overworld_sfx_volume == 80.0, "Independent volumes survive reload")
	_check(is_equal_approx(sfx.call("_web_sfx_volume", 0.0, settings.BATTLE_SFX_BUS), 0.125), "Browser battle gain includes only master and battle")
	_check(is_equal_approx(sfx.call("_web_sfx_volume", 0.0, settings.OVERWORLD_SFX_BUS), 0.4), "Browser world gain includes only master and world")
	_check(is_equal_approx(sfx.call("_web_sfx_volume", 0.0, settings.NOTIFICATION_BUS), 0.3), "Browser alerts use Notifications gain")

	var menu := load(MENU).instantiate() as Control
	root.add_child(menu)
	await process_frame
	var battle := menu.find_child("BattleSfxVolumeSlider", true, false) as HSlider
	var world := menu.find_child("OverworldSfxVolumeSlider", true, false) as HSlider
	_check(battle != null and world != null and battle.value == 25.0 and world.value == 80.0, "Menu loads both saved volumes")
	var other_volumes := [settings.music_volume, settings.pokemon_cry_volume, settings.ui_volume, settings.notification_volume]
	battle.value = 0.0
	_check(settings.battle_sfx_volume == 0.0 and settings.overworld_sfx_volume == 80.0, "Battle slider mutes only battles")
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(settings.BATTLE_SFX_BUS)) and not AudioServer.is_bus_mute(AudioServer.get_bus_index(settings.OVERWORLD_SFX_BUS)), "Native battle mute leaves world bus active")
	world.value = 0.0
	battle.value = 70.0
	_check(settings.battle_sfx_volume == 70.0 and settings.overworld_sfx_volume == 0.0, "World slider mutes only overworld")
	_check([settings.music_volume, settings.pokemon_cry_volume, settings.ui_volume, settings.notification_volume] == other_volumes, "Music, cries, interface and alerts stay independent")
	_check(sfx.call("_web_sfx_volume", 0.0, settings.OVERWORLD_SFX_BUS) == 0.0 and sfx.call("_web_sfx_volume", 0.0, settings.BATTLE_SFX_BUS) > 0.0, "Browser world mute leaves battle gain active")
	for pair: Array in [["sliding_door", settings.OVERWORLD_SFX_BUS], ["field_move_cut", settings.OVERWORLD_SFX_BUS], ["capture_throw", settings.BATTLE_SFX_BUS], ["battle_item_use", settings.BATTLE_SFX_BUS], ["ranked_match_found", settings.NOTIFICATION_BUS]]:
		var before := sfx.get_child_count()
		sfx.play(pair[0])
		var sound := sfx.get_child(sfx.get_child_count()-1) as AudioStreamPlayer
		_check(sfx.get_child_count() == before+1 and sound != null and sound.bus == pair[1], "Actual playback routes %s correctly" % pair[0])
		if sound != null:
			sound.stop(); sound.queue_free()
	var mega = load("res://scripts/battle/battle_ui/mega_evolution_effect_3d.gd").new()
	root.add_child(mega)
	mega.start(1.0)
	_check(mega.charge_audio.bus == settings.BATTLE_SFX_BUS and mega.reveal_audio.bus == settings.BATTLE_SFX_BUS, "Both native Mega Evolution phases use Battle effects")
	mega.cancel()
	var title_keys: Array[String] = []
	var all_nodes: Array[Node] = []
	_collect(menu, all_nodes)
	for node in all_nodes:
		if node is Label and bool(node.get_meta("settings_section_title", false)):
			title_keys.append(str(node.get_meta("i18n_text_key", "")))
	for key: String in ["sound_general", "sound_game", "sound_interface"]:
		_check(title_keys.has("ui.settings.section." + key), "Sound group %s exists" % key)
	menu.free()
	# Restore this slot's settings exactly; no other checkout's userdata is used.
	FileAccess.open(settings.SETTINGS_PATH, FileAccess.WRITE).store_string(original)
	settings.load_settings()
	FileAccess.open(settings.SETTINGS_PATH, FileAccess.WRITE).store_string(original)
	print("Split sound settings: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _write(data: Dictionary) -> void:
	FileAccess.open("user://settings.json", FileAccess.WRITE).store_string(JSON.stringify(data))

func _collect(node: Node, result: Array[Node]) -> void:
	result.append(node)
	for child in node.get_children(): _collect(child, result)

func _check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	failed = failed or not ok
