extends RefCounted

class_name BattleBanterPresenter

const SUPPORTED_TRIGGER_TYPES := [
	"battle_start",
	"turn_start",
	"pokemon_sent_out",
	"pokemon_fainted",
	"hp_below",
	"move_used",
	"super_effective_hit",
	"move_missed",
	"battle_end",
]

var cues: Array[Dictionary] = []
var consumed_cue_ids: Dictionary = {}


func configure(trainer_metadata: Dictionary) -> void:
	reset()
	var config_value: Variant = trainer_metadata.get(
		"battle_banter",
		trainer_metadata.get("battleBanter", {})
	)
	if not (config_value is Dictionary):
		return
	var config: Dictionary = config_value as Dictionary
	if int(config.get("version", 1)) != 1:
		return
	var cue_values: Variant = config.get("cues", [])
	if not (cue_values is Array):
		return

	for cue_value: Variant in cue_values:
		if not (cue_value is Dictionary):
			continue
		var cue: Dictionary = (cue_value as Dictionary).duplicate(true)
		var cue_id := str(cue.get("id", "")).strip_edges()
		var text_key := str(cue.get("text_key", cue.get("textKey", ""))).strip_edges()
		var trigger_value: Variant = cue.get("trigger", {})
		if cue_id == "" or text_key == "" or not (trigger_value is Dictionary):
			continue
		var trigger_type := str((trigger_value as Dictionary).get("type", "")).strip_edges().to_lower()
		if trigger_type not in SUPPORTED_TRIGGER_TYPES:
			continue
		cue["id"] = cue_id
		cue["text_key"] = text_key
		cue["trigger"] = (trigger_value as Dictionary).duplicate(true)
		cues.append(cue)


func reset() -> void:
	cues.clear()
	consumed_cue_ids.clear()


func take_battle_start_cues() -> Array[Dictionary]:
	return _take_matching_cues({
		"trigger_type": "battle_start",
		"side": "any",
	})


func take_cues_for_event(event_data: Dictionary) -> Array[Dictionary]:
	var context := _build_event_context(event_data)
	if context.is_empty():
		return []
	return _take_matching_cues(context)


func _take_matching_cues(context: Dictionary) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for cue: Dictionary in cues:
		var cue_id := str(cue.get("id", ""))
		if cue_id == "" or consumed_cue_ids.has(cue_id):
			continue
		var trigger_value: Variant = cue.get("trigger", {})
		if not (trigger_value is Dictionary):
			continue
		if not _trigger_matches(trigger_value as Dictionary, context):
			continue
		consumed_cue_ids[cue_id] = true
		var matched_cue := cue.duplicate(true)
		matched_cue["context"] = context.duplicate(true)
		matches.append(matched_cue)
	return matches


func _trigger_matches(trigger: Dictionary, context: Dictionary) -> bool:
	if str(trigger.get("type", "")).to_lower() != str(context.get("trigger_type", "")):
		return false

	var expected_side := str(trigger.get("side", "any")).to_lower()
	var actual_side := str(context.get("side", "any")).to_lower()
	if expected_side != "any" and expected_side != actual_side:
		return false
	if not _optional_name_filter_matches(trigger, context, "species"):
		return false
	if not _optional_name_filter_matches(trigger, context, "move"):
		return false
	if trigger.has("turn") and int(trigger.get("turn", -1)) != int(context.get("turn", -1)):
		return false
	if trigger.has("at_or_below_percent"):
		var hp_percent := int(context.get("hp_percent", -1))
		if hp_percent < 0 or hp_percent > int(trigger.get("at_or_below_percent", -1)):
			return false
	return true


func _optional_name_filter_matches(trigger: Dictionary, context: Dictionary, field: String) -> bool:
	var expected := str(trigger.get(field, "")).strip_edges().to_lower()
	if expected == "":
		return true
	return expected == str(context.get(field, "")).strip_edges().to_lower()


func _build_event_context(event_data: Dictionary) -> Dictionary:
	var event_type := str(event_data.get("type", ""))
	match event_type:
		"turn":
			return {
				"trigger_type": "turn_start",
				"side": "any",
				"turn": int(event_data.get("turn", 0)),
			}
		"switch", "drag":
			var switch_ident := str(event_data.get("toIdent", event_data.get("pokemon", "")))
			var switch_player_id := str(event_data.get("playerId", _get_player_id(switch_ident)))
			return _pokemon_context(
				"pokemon_sent_out",
				switch_player_id,
				_get_event_species(event_data, switch_ident, ["toRef", "targetRef"], ["to", "species"])
			)
		"faint":
			var faint_ident := str(event_data.get("target", ""))
			return _pokemon_context(
				"pokemon_fainted",
				_get_player_id(faint_ident),
				_get_event_species(event_data, faint_ident, ["targetRef"], ["species"])
			)
		"damage":
			var damage_ident := str(event_data.get("target", ""))
			var damage_context := _pokemon_context(
				"hp_below",
				_get_player_id(damage_ident),
				_get_event_species(event_data, damage_ident, ["targetRef"], ["species"])
			)
			damage_context["hp_percent"] = _get_hp_percent(event_data)
			return damage_context
		"move":
			var actor_ident := str(event_data.get("actor", ""))
			var move_context := _pokemon_context(
				"move_used",
				_get_player_id(actor_ident),
				_get_event_species(event_data, actor_ident, ["actorRef"], ["species"])
			)
			move_context["move"] = str(event_data.get("move", ""))
			return move_context
		"effectiveness":
			if str(event_data.get("effectiveness", "")) != "super":
				return {}
			var effective_target := str(event_data.get("target", ""))
			return _pokemon_context(
				"super_effective_hit",
				_get_player_id(effective_target),
				_get_event_species(event_data, effective_target, ["targetRef"], ["species"])
			)
		"miss":
			var miss_target := str(event_data.get("target", ""))
			return _pokemon_context(
				"move_missed",
				_get_player_id(miss_target),
				_get_event_species(event_data, miss_target, ["targetRef"], ["species"])
			)
		"win":
			return {
				"trigger_type": "battle_end",
				"side": "any",
				"winner": str(event_data.get("winner", "")),
			}
	return {}


func _pokemon_context(trigger_type: String, player_id: String, species: String) -> Dictionary:
	return {
		"trigger_type": trigger_type,
		"side": _get_relative_side(player_id),
		"player_id": player_id,
		"species": species,
	}


func _get_event_species(
	event_data: Dictionary,
	fallback_ident: String,
	ref_keys: Array,
	direct_keys: Array
) -> String:
	for ref_key_value: Variant in ref_keys:
		var ref_value: Variant = event_data.get(str(ref_key_value), {})
		if not (ref_value is Dictionary):
			continue
		for field: String in ["displaySpecies", "display_species", "species"]:
			var ref_species := str((ref_value as Dictionary).get(field, "")).strip_edges()
			if ref_species != "":
				return ref_species
	for direct_key_value: Variant in direct_keys:
		var direct_species := str(event_data.get(str(direct_key_value), "")).strip_edges()
		if direct_species != "":
			return direct_species
	return _get_name_from_ident(fallback_ident)


func _get_hp_percent(event_data: Dictionary) -> int:
	var hp := int(event_data.get("hp", event_data.get("currentHp", -1)))
	var max_hp := int(event_data.get("maxHp", event_data.get("max_hp", -1)))
	if hp >= 0 and max_hp > 0:
		return clampi(int(round(float(hp) * 100.0 / float(max_hp))), 0, 100)
	var condition := str(event_data.get("condition", "")).strip_edges().split(" ")[0]
	if condition.contains("/"):
		var parts := condition.split("/")
		if parts.size() == 2 and str(parts[0]).is_valid_int() and str(parts[1]).is_valid_int():
			var condition_max := int(parts[1])
			if condition_max > 0:
				return clampi(int(round(float(int(parts[0])) * 100.0 / float(condition_max))), 0, 100)
	return -1


func _get_relative_side(player_id: String) -> String:
	if player_id == "p1":
		return "player"
	if player_id == "p2":
		return "opponent"
	return "any"


func _get_player_id(ident: String) -> String:
	if ident.begins_with("p1"):
		return "p1"
	if ident.begins_with("p2"):
		return "p2"
	return ""


func _get_name_from_ident(ident: String) -> String:
	if ident.contains(": "):
		return str(ident.split(": ", false, 1)[1]).strip_edges()
	return ident.strip_edges()
