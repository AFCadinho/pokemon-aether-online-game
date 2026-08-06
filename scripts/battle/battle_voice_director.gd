extends RefCounted

class_name BattleVoiceDirector

const RULES_PATH := "res://data/battle_voice_rules.json"
const SUPPORTED_PROFILES := [
	"classic",
	"respectful",
	"confident",
	"playful",
	"dramatic",
	"tactical",
	"silent",
]
const SUPPORTED_INTENSITIES := ["full", "reduced", "off"]
const LOW_HP_THRESHOLD := 25

var battle_id := ""
var battle_mode := "trainer"
var rules: Array[Dictionary] = []
var profiles_by_player := {"p1": "classic", "p2": "classic"}
var intensity_by_player := {"p1": "full", "p2": "full"}


func configure(
	battle_identifier: String,
	mode: String,
	trainer_metadata: Dictionary = {}
) -> void:
	reset()
	battle_id = battle_identifier.strip_edges()
	battle_mode = "pvp" if mode.strip_edges().to_lower() == "pvp" else "trainer"
	_load_rules()
	if battle_mode == "trainer":
		_apply_opponent_configuration(trainer_metadata)


func reset() -> void:
	battle_id = ""
	battle_mode = "trainer"
	rules.clear()
	profiles_by_player = {"p1": "classic", "p2": "classic"}
	intensity_by_player = {"p1": "full", "p2": "full"}


func resolve_command(command: Dictionary, public_context: Dictionary = {}) -> Dictionary:
	var player_id := str(command.get("player_id", "")).strip_edges().to_lower()
	if player_id not in ["p1", "p2"]:
		return {}
	var intensity := str(intensity_by_player.get(player_id, "full"))
	if intensity == "off":
		return {}

	var context := public_context.duplicate(true)
	context.merge(command.duplicate(true), true)
	context["mode"] = battle_mode
	context["profile"] = str(profiles_by_player.get(player_id, "classic"))
	context["intent"] = _resolve_intent(command, context, intensity)
	var rule := _select_rule(context)
	if rule.is_empty():
		return _build_fallback_selection(player_id, context)
	var variant := _select_variant(rule, context)
	if variant.is_empty():
		return _build_fallback_selection(player_id, context)

	return {
		"intent": str(context.get("intent", "")),
		"player_id": player_id,
		"profile": str(context.get("profile", "classic")),
		"rule_id": str(rule.get("id", "")),
		"variant_id": str(variant.get("id", "")),
		"text_key": str(variant.get("text_key", variant.get("textKey", ""))),
		"values": _build_public_values(context),
	}


func _build_fallback_selection(player_id: String, context: Dictionary) -> Dictionary:
	var kind := str(context.get("kind", ""))
	var text_key := ""
	match kind:
		"move":
			text_key = "battle.command.move"
		"dodge":
			text_key = "battle.command.dodge"
		"switch":
			text_key = (
				"battle.command.switch"
				if str(context.get("from", "")) != ""
				else "battle.command.go"
			)
	if text_key == "":
		return {}
	return {
		"intent": str(context.get("intent", "")),
		"player_id": player_id,
		"profile": str(context.get("profile", "classic")),
		"rule_id": "safe_fallback",
		"variant_id": "legacy_command",
		"text_key": text_key,
		"values": _build_public_values(context),
	}


func _apply_opponent_configuration(trainer_metadata: Dictionary) -> void:
	var config_value: Variant = trainer_metadata.get(
		"battle_voice",
		trainer_metadata.get("battleVoice", {})
	)
	if not (config_value is Dictionary):
		return
	var config: Dictionary = config_value as Dictionary
	if int(config.get("version", 1)) != 1:
		return
	var profile := str(config.get("profile", "classic")).strip_edges().to_lower()
	if profile in SUPPORTED_PROFILES:
		profiles_by_player["p2"] = profile
	var intensity := str(config.get("intensity", "full")).strip_edges().to_lower()
	if intensity in SUPPORTED_INTENSITIES:
		intensity_by_player["p2"] = intensity


func _load_rules() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	if not (parsed is Dictionary) or int((parsed as Dictionary).get("version", 0)) != 1:
		push_warning("BattleVoiceDirector: invalid battle voice rule catalog.")
		return
	var values: Variant = (parsed as Dictionary).get("rules", [])
	if not (values is Array):
		return
	for value: Variant in values:
		if value is Dictionary:
			rules.append((value as Dictionary).duplicate(true))


func _resolve_intent(command: Dictionary, context: Dictionary, intensity: String) -> String:
	match str(command.get("kind", "")).strip_edges().to_lower():
		"move":
			return "move_command"
		"dodge":
			return "miss_dodge"
		"switch":
			if intensity == "reduced":
				return "voluntary_switch" if str(context.get("from", "")) != "" else "send_out"
			if bool(context.get("forced", false)) and not bool(context.get("from_fainted", false)):
				return "forced_by_effect"
			if bool(context.get("from_fainted", false)):
				return "replacement_after_faint"
			if str(context.get("from", "")) == "":
				return "send_out"
			var from_hp_percent := int(context.get("from_hp_percent", -1))
			if from_hp_percent >= 0 and from_hp_percent <= LOW_HP_THRESHOLD:
				return "save_wounded_pokemon"
			var foe_hp_percent := int(context.get("foe_hp_percent", -1))
			if foe_hp_percent >= 0 and foe_hp_percent <= LOW_HP_THRESHOLD:
				return "press_weak_opponent"
			return "voluntary_switch"
	return ""


func _select_rule(context: Dictionary) -> Dictionary:
	var best_rule: Dictionary = {}
	var best_priority := -1
	for rule: Dictionary in rules:
		if str(rule.get("intent", "")) != str(context.get("intent", "")):
			continue
		if not _list_allows(rule.get("modes", []), str(context.get("mode", ""))):
			continue
		if not _list_allows(rule.get("profiles", []), str(context.get("profile", "")), true):
			continue
		var priority := int(rule.get("priority", 0))
		if priority > best_priority:
			best_rule = rule
			best_priority = priority
	return best_rule


func _list_allows(value: Variant, expected: String, allow_any := false) -> bool:
	if not (value is Array):
		return false
	for entry: Variant in value as Array:
		var normalized := str(entry).strip_edges().to_lower()
		if normalized == expected or (allow_any and normalized == "any"):
			return true
	return false


func _select_variant(rule: Dictionary, context: Dictionary) -> Dictionary:
	var variants_value: Variant = rule.get("variants", [])
	if not (variants_value is Array):
		return {}
	var variants: Array = variants_value as Array
	var total_weight := 0
	for value: Variant in variants:
		if value is Dictionary:
			total_weight += maxi(int((value as Dictionary).get("weight", 1)), 1)
	if total_weight <= 0:
		return {}

	var roll := _stable_hash(_build_seed(rule, context)) % total_weight
	for value: Variant in variants:
		if not (value is Dictionary):
			continue
		var variant: Dictionary = value as Dictionary
		roll -= maxi(int(variant.get("weight", 1)), 1)
		if roll < 0:
			return variant
	return {}


func _build_seed(rule: Dictionary, context: Dictionary) -> String:
	# Deliberately excludes the relative p1/p2 side. Participant projections map
	# each local user to p1, while spectators keep a canonical perspective. All
	# viewers still choose the same variant from the same public event facts.
	return "|".join(PackedStringArray([
		battle_id if battle_id != "" else "local-battle",
		str(context.get("turn", 0)),
		str(context.get("intent", "")),
		str(rule.get("id", "")),
		str(context.get("pokemon", "")),
		str(context.get("move", "")),
		str(context.get("from", "")),
		str(context.get("to", "")),
		str(context.get("source", context.get("reason", ""))),
	]))


func _stable_hash(value: String) -> int:
	var result := 216613626
	for byte: int in value.to_utf8_buffer():
		result = ((result ^ byte) * 16777619) % 2147483647
	return absi(result)


func _build_public_values(context: Dictionary) -> Dictionary:
	return {
		"pokemon": str(context.get("pokemon", context.get("to", ""))),
		"move": str(context.get("move", "")),
		"from": str(context.get("from", "")),
		"to": str(context.get("to", context.get("pokemon", ""))),
	}
