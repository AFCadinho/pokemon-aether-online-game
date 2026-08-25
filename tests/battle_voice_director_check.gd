extends SceneTree

const BattleVoiceDirectorScript := preload("res://scripts/battle/battle_voice_director.gd")
const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"
const EVENT_RENDERER_PATH := "res://scripts/battle/battle_event_renderer.gd"

var failed := false


func _init() -> void:
	_check_public_context_intents()
	_check_viewer_independent_selection()
	_check_profiles_and_intensity()
	_check_catalog_localization_contract()
	_check_battle_integration_contract()
	quit(1 if failed else 0)


func _check_public_context_intents() -> void:
	var director = BattleVoiceDirectorScript.new()
	director.configure("battle-voice-test", "pvp")
	_check_equal(_resolve_switch(director, {"forced": true}).get("intent"), "forced_by_effect", "public forced event selects force-switch intent")
	_check_equal(_resolve_switch(director, {"from_fainted": true}).get("intent"), "replacement_after_faint", "public faint state selects replacement intent")
	_check_equal(_resolve_switch(director, {"from_hp_percent": 25}).get("intent"), "save_wounded_pokemon", "low public HP selects protective switch intent")
	_check_equal(_resolve_switch(director, {"foe_hp_percent": 25}).get("intent"), "press_weak_opponent", "low foe public HP selects pressure intent")
	_check_equal(_resolve_switch(director, {}).get("intent"), "voluntary_switch", "ordinary switch keeps voluntary intent")
	var first_summon := director.resolve_command({
		"kind": "switch",
		"player_id": "p1",
		"from": "",
		"to": "Charmander",
		"pokemon": "Charmander",
	}, {"turn": 0})
	_check_equal(first_summon.get("intent"), "send_out", "first summons use the dedicated send-out voice variants")


func _check_viewer_independent_selection() -> void:
	var local_view = BattleVoiceDirectorScript.new()
	var remote_view = BattleVoiceDirectorScript.new()
	var spectator_view = BattleVoiceDirectorScript.new()
	for director in [local_view, remote_view, spectator_view]:
		director.configure("shared-battle-id", "pvp")
	var public_command := {
		"kind": "move",
		"pokemon": "Garchomp",
		"move": "Earthquake",
	}
	var local_command := public_command.duplicate(true)
	local_command["player_id"] = "p1"
	var remote_command := public_command.duplicate(true)
	remote_command["player_id"] = "p2"
	var local_result: Dictionary = local_view.resolve_command(local_command, {"turn": 7})
	var remote_result: Dictionary = remote_view.resolve_command(remote_command, {"turn": 7})
	var spectator_result: Dictionary = spectator_view.resolve_command(remote_command, {"turn": 7})
	_check_equal(local_result.get("variant_id"), remote_result.get("variant_id"), "relative participant side does not change the variant")
	_check_equal(local_result.get("variant_id"), spectator_result.get("variant_id"), "spectator receives the participant variant")
	_check_equal(local_result.get("text_key"), spectator_result.get("text_key"), "spectator receives the same localization key")


func _check_profiles_and_intensity() -> void:
	var director = BattleVoiceDirectorScript.new()
	director.configure("npc-battle", "trainer", {
		"battle_voice": {"version": 1, "profile": "confident", "intensity": "full"},
	})
	var result: Dictionary = director.resolve_command({
		"kind": "move",
		"player_id": "p2",
		"pokemon": "Onix",
		"move": "Rock Throw",
	}, {"turn": 2})
	_check_equal(result.get("profile"), "confident", "NPC metadata selects a supported voice profile")
	_check_equal(result.get("rule_id"), "move_command_confident", "profile selects its higher-priority rule pack")

	var reduced = BattleVoiceDirectorScript.new()
	reduced.configure("npc-reduced", "trainer", {
		"battle_voice": {"version": 1, "profile": "tactical", "intensity": "reduced"},
	})
	var reduced_result: Dictionary = reduced.resolve_command({
		"kind": "switch",
		"player_id": "p2",
		"from": "Onix",
		"to": "Geodude",
	}, {"forced": true, "turn": 3})
	_check_equal(reduced_result.get("intent"), "voluntary_switch", "reduced mode avoids contextual flourishes")

	var off = BattleVoiceDirectorScript.new()
	off.configure("npc-off", "trainer", {
		"battle_voice": {"version": 1, "profile": "classic", "intensity": "off"},
	})
	_check_equal(off.resolve_command({"kind": "move", "player_id": "p2", "pokemon": "Onix", "move": "Tackle"}), {}, "off mode suppresses configured NPC voice")

	var fallback = BattleVoiceDirectorScript.new()
	fallback.configure("fallback-battle", "pvp")
	fallback.rules.clear()
	var fallback_result: Dictionary = fallback.resolve_command({
		"kind": "move",
		"player_id": "p1",
		"pokemon": "Pikachu",
		"move": "Thunderbolt",
	})
	_check_equal(fallback_result.get("text_key"), "battle.command.move", "catalog failure safely falls back to the existing command")


func _check_catalog_localization_contract() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_voice_rules.json"))
	_check(parsed is Dictionary, "voice rule catalog is valid JSON")
	if not (parsed is Dictionary):
		return
	var catalogs: Array[Dictionary] = []
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var catalog_value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://localization/%s.json" % locale))
		_check(catalog_value is Dictionary, "%s localization catalog is valid JSON" % locale)
		catalogs.append(catalog_value as Dictionary if catalog_value is Dictionary else {})
	for rule_value: Variant in (parsed as Dictionary).get("rules", []):
		if not (rule_value is Dictionary):
			continue
		for variant_value: Variant in (rule_value as Dictionary).get("variants", []):
			if not (variant_value is Dictionary):
				continue
			var text_key := str((variant_value as Dictionary).get("text_key", ""))
			for catalog: Dictionary in catalogs:
				_check(catalog.has(text_key), "voice variant is localized: %s" % text_key)


func _check_battle_integration_contract() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var renderer_source := FileAccess.get_file_as_string(EVENT_RENDERER_PATH)
	_check(source.contains("battle_voice_director.resolve_command"), "battle command callouts use the voice director")
	_check(source.contains('battle_voice_director.configure('), "trainer and PvP setup configure the voice director")
	var command_start := source.find("func _show_trainer_command(command: Dictionary) -> Dictionary:")
	var command_end := source.find("\nfunc ", command_start + 1)
	var command_source := source.substr(command_start, command_end - command_start)
	_check(not command_source.contains("_is_spectator_battle"), "spectators are not excluded from public command callouts")
	_check(renderer_source.count('"event": event_data') == 2, "move and true-miss dodge callouts retain the same public source event")
	_check(source.contains("PvP public projections expose HP with the same ceiling rule"), "context HP follows the spectator-safe public projection rule")
	_check(source.contains("func _present_initial_summon_command"), "trainer and PvP lead summons receive command callouts")
	_check(source.contains("func _show_pvp_team_preview_greetings"), "PvP Team Preview exposes the shared sportsmanship greeting")


func _resolve_switch(director: RefCounted, context: Dictionary) -> Dictionary:
	var public_context := {
		"turn": 4,
		"forced": false,
		"from_fainted": false,
		"from_hp_percent": 80,
		"foe_hp_percent": 80,
	}
	public_context.merge(context, true)
	return director.call("resolve_command", {
		"kind": "switch",
		"player_id": "p1",
		"from": "Charmander",
		"to": "Pidgey",
	}, public_context)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	_check(actual == expected, "%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
