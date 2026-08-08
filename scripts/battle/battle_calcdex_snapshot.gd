extends RefCounted

class_name BattleCalcdexSnapshot

const SCHEMA_VERSION := 1
const ROUTE_REVISION := "calc1.3-2026-08-08"
const VISIBILITY_CONTRACT_VERSION := 3
const REVISION_FIELDS := [
	"visibilityContractVersion",
	"snapshotFingerprint",
	"eventSeq",
	"batchSeq",
	"mechanicalRevision",
	"aggregateRevision",
	"battleEventSeq",
]
const SNAPSHOT_FIELDS := [
	"schemaVersion",
	"battleId",
	"viewerSide",
	"format",
	"turn",
	"projectionRevision",
	"mechanicsManifest",
	"field",
	"viewerPokemon",
	"opponentPokemon",
	"publicEvidence",
	"safeInputFingerprint",
]
const POKEMON_FIELDS := [
	"pokemonRef",
	"relation",
	"active",
	"fainted",
	"identity",
	"level",
	"gender",
	"hp",
	"status",
	"moves",
	"item",
	"ability",
	"nature",
	"evs",
	"ivs",
	"boosts",
	"tera",
	"abilityStatModifier",
	"volatiles",
]
const KNOWLEDGE_FIELDS := [
	"identity", "level", "gender", "status", "item", "ability", "nature",
	"evs", "ivs", "boosts", "tera", "abilityStatModifier",
]
const PROVENANCE_SOURCES := [
	"owned_exact",
	"public_reveal",
	"public_derived",
	"user_scenario",
	"curated_prior",
	"aggregate_prior",
	"observation_inference",
	"unknown",
]


static func normalize_response(response: Dictionary, expected_revision: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response.duplicate(true)
	if int(response.get("schemaVersion", 0)) != SCHEMA_VERSION:
		return _malformed("Unsupported Calcdex response schema.")
	if str(response.get("routeRevision", "")) != ROUTE_REVISION:
		return _malformed("Unsupported Calcdex route revision.")
	var snapshot_value: Variant = response.get("snapshot")
	if not (snapshot_value is Dictionary):
		return _malformed("Calcdex snapshot is missing.")
	var snapshot: Dictionary = snapshot_value as Dictionary
	var validation_error := _validate_snapshot(snapshot, expected_revision)
	if validation_error != "":
		return _malformed(validation_error)
	return {
		"success": true,
		"status": int(response.get("status", 200)),
		"schemaVersion": SCHEMA_VERSION,
		"routeRevision": ROUTE_REVISION,
		"snapshot": snapshot.duplicate(true),
	}


static func get_active_pokemon(snapshot: Dictionary, relation: String) -> Dictionary:
	var collection_name := "viewerPokemon" if relation == "viewer" else "opponentPokemon"
	var pokemon_value: Variant = snapshot.get(collection_name, [])
	if not (pokemon_value is Array):
		return {}
	for entry_value: Variant in pokemon_value:
		if entry_value is Dictionary and bool((entry_value as Dictionary).get("active", false)):
			return (entry_value as Dictionary).duplicate(true)
	return {}


static func get_knowledge_value(pokemon: Dictionary, field_name: String) -> Dictionary:
	var value: Variant = pokemon.get(field_name)
	if value is Dictionary and _validate_knowledge_value(value as Dictionary) == "":
		return (value as Dictionary).duplicate(true)
	return {}


static func _validate_snapshot(snapshot: Dictionary, expected_revision: Dictionary) -> String:
	if not _has_exact_fields(snapshot, SNAPSHOT_FIELDS):
		return "Calcdex snapshot fields do not match the frozen contract."
	if int(snapshot.get("schemaVersion", 0)) != SCHEMA_VERSION:
		return "Unsupported Calcdex snapshot schema."
	if str(snapshot.get("battleId", "")).strip_edges() == "" or str(snapshot.get("viewerSide", "")) not in ["p1", "p2"]:
		return "Calcdex battle identity is invalid."
	if typeof(snapshot.get("turn")) != TYPE_INT or int(snapshot.get("turn")) < 0:
		return "Calcdex battle turn is invalid."
	var revision_value: Variant = snapshot.get("projectionRevision")
	if not (revision_value is Dictionary):
		return "Calcdex projection revision is missing."
	var revision: Dictionary = revision_value as Dictionary
	if not is_valid_projection_revision(revision):
		return "Calcdex projection revision is invalid."
	if not _revisions_equal(revision, expected_revision):
		return "Calcdex snapshot does not match the requested projection."
	if not _is_sha256(str(snapshot.get("safeInputFingerprint", ""))):
		return "Calcdex safe-input fingerprint is invalid."
	var container_error := _validate_contract_containers(snapshot)
	if container_error != "":
		return container_error
	var seen_refs: Dictionary = {}
	for relation: String in ["viewer", "opponent"]:
		var collection_name := "viewerPokemon" if relation == "viewer" else "opponentPokemon"
		var pokemon_value: Variant = snapshot.get(collection_name)
		if not (pokemon_value is Array) or (pokemon_value as Array).size() > 6:
			return "Calcdex Pokémon collection is invalid."
		for pokemon_entry: Variant in pokemon_value:
			if not (pokemon_entry is Dictionary):
				return "Calcdex Pokémon entry is invalid."
			var error := _validate_pokemon(pokemon_entry as Dictionary, relation)
			if error != "":
				return error
			var pokemon_ref := str((pokemon_entry as Dictionary).get("pokemonRef", ""))
			if seen_refs.has(pokemon_ref):
				return "Calcdex public Pokémon references must be unique."
			seen_refs[pokemon_ref] = true
	return ""


static func is_valid_projection_revision(revision: Dictionary) -> bool:
	if not _has_exact_fields(revision, REVISION_FIELDS):
		return false
	if int(revision.get("visibilityContractVersion", 0)) != VISIBILITY_CONTRACT_VERSION:
		return false
	if not _is_sha256(str(revision.get("snapshotFingerprint", ""))):
		return false
	for field_name: String in ["eventSeq", "batchSeq", "mechanicalRevision", "aggregateRevision"]:
		if typeof(revision.get(field_name)) != TYPE_INT or int(revision.get(field_name)) < 0:
			return false
	return typeof(revision.get("battleEventSeq")) == TYPE_INT and int(revision.get("battleEventSeq")) >= -1


static func _validate_pokemon(pokemon: Dictionary, relation: String) -> String:
	if not _has_exact_fields(pokemon, POKEMON_FIELDS):
		return "Calcdex Pokémon fields do not match the frozen contract."
	if str(pokemon.get("relation", "")) != relation:
		return "Calcdex Pokémon relation is invalid."
	var pokemon_ref := str(pokemon.get("pokemonRef", ""))
	if not pokemon_ref.begins_with("%s:public-slot-" % relation):
		return "Calcdex public Pokémon reference is invalid."
	for field_name: String in KNOWLEDGE_FIELDS:
		var value: Variant = pokemon.get(field_name)
		if not (value is Dictionary):
			return "Calcdex knowledge field %s is invalid." % field_name
		var error := _validate_knowledge_value(value as Dictionary, field_name, relation)
		if error != "":
			return error
	var hp_value: Variant = pokemon.get("hp")
	if not (hp_value is Dictionary):
		return "Calcdex HP field is invalid."
	var hp_error := _validate_hp(hp_value as Dictionary, relation)
	if hp_error != "":
		return hp_error
	var moves_value: Variant = pokemon.get("moves")
	if not (moves_value is Array) or (moves_value as Array).size() > 4:
		return "Calcdex move list is invalid."
	for move_value: Variant in moves_value:
		if not (move_value is Dictionary):
			return "Calcdex move entry is invalid."
		var move: Dictionary = move_value as Dictionary
		if not _has_required_and_allowed_fields(move, ["name", "provenance"], ["name", "pp", "maxPp", "provenance"]):
			return "Calcdex move fields are invalid."
		if str(move.get("name", "")).strip_edges() == "" or _validate_provenance(_as_dictionary(move.get("provenance")), relation) != "":
			return "Calcdex move provenance is invalid."
		for pp_field: String in ["pp", "maxPp"]:
			if move.has(pp_field) and (typeof(move.get(pp_field)) != TYPE_INT or int(move.get(pp_field)) < 0 or int(move.get(pp_field)) > 99):
				return "Calcdex move PP is invalid."
		if move.has("pp") and move.has("maxPp") and int(move.get("pp")) > int(move.get("maxPp")):
			return "Calcdex move PP exceeds max PP."
	var volatiles_value: Variant = pokemon.get("volatiles")
	if not (volatiles_value is Array) or (volatiles_value as Array).size() > 32:
		return "Calcdex volatile list is invalid."
	for volatile_value: Variant in volatiles_value:
		if not (volatile_value is Dictionary):
			return "Calcdex volatile entry is invalid."
		var volatile: Dictionary = volatile_value as Dictionary
		if not _has_exact_fields(volatile, ["effectId", "provenance"]) or str(volatile.get("effectId", "")).strip_edges() == "":
			return "Calcdex volatile fields are invalid."
		if _validate_provenance(_as_dictionary(volatile.get("provenance")), relation) != "":
			return "Calcdex volatile provenance is invalid."
	return ""


static func _validate_knowledge_value(knowledge: Dictionary, field_name: String = "", relation: String = "") -> String:
	var state := str(knowledge.get("state", ""))
	var provenance_value: Variant = knowledge.get("provenance")
	if not (provenance_value is Dictionary):
		return "Calcdex provenance is missing."
	var provenance: Dictionary = provenance_value as Dictionary
	var provenance_error := _validate_provenance(provenance, relation)
	if provenance_error != "":
		return provenance_error
	var source := str(provenance.get("source", ""))
	if state == "unknown":
		if not _has_exact_fields(knowledge, ["state", "provenance"]) or source != "unknown":
			return "Unknown Calcdex knowledge must not carry a value."
		return ""
	if state == "known":
		if not _has_exact_fields(knowledge, ["state", "value", "provenance"]) or source == "unknown":
			return "Known Calcdex knowledge must carry non-unknown provenance."
		return _validate_known_value(field_name, knowledge.get("value"))
	return "Calcdex knowledge state is invalid."


static func _validate_known_value(field_name: String, value: Variant) -> String:
	if field_name in ["identity", "item", "ability", "nature"]:
		if typeof(value) != TYPE_STRING or str(value).length() > 128:
			return "Calcdex %s value is invalid." % field_name
		if field_name != "item" and str(value).strip_edges() == "":
			return "Calcdex %s value is invalid." % field_name
	if field_name == "gender" and str(value) not in ["M", "F", "N"]:
		return "Calcdex gender value is invalid."
	if field_name == "level" and (typeof(value) != TYPE_INT or int(value) < 1 or int(value) > 100):
		return "Calcdex level value is invalid."
	if field_name == "status" and (typeof(value) != TYPE_STRING or str(value).length() > 16):
		return "Calcdex status value is invalid."
	if field_name in ["evs", "ivs", "boosts"]:
		if not (value is Dictionary):
			return "Calcdex stat table is invalid."
		var allowed := ["hp", "atk", "def", "spa", "spd", "spe"] if field_name != "boosts" else ["atk", "def", "spa", "spd", "spe", "accuracy", "evasion"]
		var minimum := -6 if field_name == "boosts" else 0
		var maximum := 252 if field_name == "evs" else (31 if field_name == "ivs" else 6)
		for key: Variant in (value as Dictionary).keys():
			if str(key) not in allowed or typeof((value as Dictionary).get(key)) != TYPE_INT:
				return "Calcdex stat table fields are invalid."
			var stat_value := int((value as Dictionary).get(key))
			if stat_value < minimum or stat_value > maximum:
				return "Calcdex stat table value is outside bounds."
	if field_name == "tera":
		if not (value is Dictionary) or not _has_exact_fields(value as Dictionary, ["active", "type"]):
			return "Calcdex Tera value is invalid."
		if typeof((value as Dictionary).get("active")) != TYPE_BOOL or str((value as Dictionary).get("type", "")).strip_edges() == "":
			return "Calcdex Tera value is invalid."
	if field_name == "abilityStatModifier":
		if not (value is Dictionary) or not _has_required_and_allowed_fields(value as Dictionary, ["ability", "stat"], ["ability", "stat", "source"]):
			return "Calcdex ability modifier is invalid."
		if str((value as Dictionary).get("ability", "")) not in ["Protosynthesis", "Quark Drive"]:
			return "Calcdex ability modifier is invalid."
		if str((value as Dictionary).get("stat", "")) not in ["atk", "def", "spa", "spd", "spe"]:
			return "Calcdex ability modifier is invalid."
	return ""


static func _validate_provenance(provenance: Dictionary, relation: String = "") -> String:
	if not _has_required_and_allowed_fields(
		provenance,
		["source", "reasonCode"],
		["source", "sourceRevision", "observedAtTurn", "reasonCode"]
	):
		return "Calcdex provenance fields are invalid."
	var source := str(provenance.get("source", ""))
	if source not in PROVENANCE_SOURCES or not _is_reason_code(str(provenance.get("reasonCode", ""))):
		return "Calcdex provenance is invalid."
	if relation == "opponent" and source == "owned_exact":
		return "Opponent knowledge cannot have owned provenance."
	if provenance.has("observedAtTurn") and (typeof(provenance.get("observedAtTurn")) != TYPE_INT or int(provenance.get("observedAtTurn")) < 0):
		return "Calcdex provenance turn is invalid."
	if provenance.has("sourceRevision") and (typeof(provenance.get("sourceRevision")) != TYPE_STRING or str(provenance.get("sourceRevision")).strip_edges() == "" or str(provenance.get("sourceRevision")).length() > 128):
		return "Calcdex provenance revision is invalid."
	return ""


static func _validate_hp(hp: Dictionary, relation: String) -> String:
	if not _has_required_and_allowed_fields(hp, ["display", "provenance"], ["display", "exact", "intervalPolicy", "provenance"]):
		return "Calcdex HP fields are invalid."
	var display := _as_dictionary(hp.get("display"))
	if not _has_exact_fields(display, ["current", "maximum", "scale"]):
		return "Calcdex HP display is invalid."
	if typeof(display.get("current")) != TYPE_INT or typeof(display.get("maximum")) != TYPE_INT:
		return "Calcdex HP display values are invalid."
	if int(display.get("current")) < 0 or int(display.get("maximum")) < 1 or int(display.get("current")) > int(display.get("maximum")):
		return "Calcdex HP display values are outside bounds."
	var provenance_error := _validate_provenance(_as_dictionary(hp.get("provenance")), relation)
	if provenance_error != "":
		return provenance_error
	if relation == "opponent":
		if hp.has("exact") or str(display.get("scale", "")) != "public_percent_100" or int(display.get("maximum")) != 100:
			return "Opponent exact HP is forbidden."
		if str(hp.get("intervalPolicy", "")) != "showdown_public_condition_v1":
			return "Opponent HP interval policy is invalid."
	else:
		var exact := _as_dictionary(hp.get("exact"))
		if str(display.get("scale", "")) != "exact" or not _has_exact_fields(exact, ["current", "maximum"]):
			return "Owned exact HP is invalid."
		if hp.has("intervalPolicy") or typeof(exact.get("current")) != TYPE_INT or typeof(exact.get("maximum")) != TYPE_INT:
			return "Owned exact HP is invalid."
		if int(exact.get("current")) < 0 or int(exact.get("maximum")) < 1 or int(exact.get("current")) > int(exact.get("maximum")):
			return "Owned exact HP is outside bounds."
	return ""


static func _validate_contract_containers(snapshot: Dictionary) -> String:
	var format := _as_dictionary(snapshot.get("format"))
	if not _has_required_and_allowed_fields(format, ["formatKey", "engineFormatId", "generation", "gameType"], ["formatKey", "engineFormatId", "generation", "gameType", "rulesetRevision", "rulesetHash"]):
		return "Calcdex format identity is invalid."
	if str(format.get("formatKey", "")) not in ["aether-ou", "gen9nationaldex-casual", "gen9nationaldex-pve"] or str(format.get("engineFormatId", "")) != "gen9nationaldex" or int(format.get("generation", 0)) != 9 or str(format.get("gameType", "")) != "singles":
		return "Calcdex format identity is unsupported."
	var manifest := _as_dictionary(snapshot.get("mechanicsManifest"))
	if not _has_exact_fields(manifest, ["contractRevision", "damageCalcVersion", "showdownVersion", "formatDataFingerprint"]):
		return "Calcdex mechanics manifest is invalid."
	if str(manifest.get("contractRevision", "")) != "calc0-2026-08-08" or str(manifest.get("damageCalcVersion", "")) != "0.10.0" or str(manifest.get("showdownVersion", "")) != "0.11.10" or not _is_sha256(str(manifest.get("formatDataFingerprint", ""))):
		return "Calcdex mechanics manifest is unsupported."
	var field := _as_dictionary(snapshot.get("field"))
	if not _has_exact_fields(field, ["effects"]) or not (field.get("effects") is Array) or (field.get("effects") as Array).size() > 64:
		return "Calcdex field snapshot is invalid."
	for effect_value: Variant in field.get("effects") as Array:
		if not (effect_value is Dictionary):
			return "Calcdex field effect is invalid."
		var effect: Dictionary = effect_value as Dictionary
		var allowed_effect_fields := ["effectId", "effect", "effectType", "effectGroup", "scope", "side", "startedTurn", "minDuration", "maxDuration", "minRemainingTurns", "maxRemainingTurns", "layers", "provenance"]
		if not _has_required_and_allowed_fields(effect, ["effectId", "scope", "provenance"], allowed_effect_fields):
			return "Calcdex field effect fields are invalid."
		if str(effect.get("effectId", "")).strip_edges() == "" or str(effect.get("scope", "")) not in ["field", "side"]:
			return "Calcdex field effect is invalid."
		if (str(effect.get("scope")) == "side") != effect.has("side") or (effect.has("side") and str(effect.get("side")) not in ["p1", "p2"]):
			return "Calcdex field effect scope is invalid."
		if _validate_provenance(_as_dictionary(effect.get("provenance"))) != "":
			return "Calcdex field effect provenance is invalid."
	if not (snapshot.get("publicEvidence") is Array) or (snapshot.get("publicEvidence") as Array).size() > 64:
		return "Calcdex public evidence is invalid."
	for evidence_value: Variant in snapshot.get("publicEvidence") as Array:
		if not (evidence_value is Dictionary):
			return "Calcdex public evidence entry is invalid."
		var evidence: Dictionary = evidence_value as Dictionary
		if not _has_exact_fields(evidence, ["evidenceType", "pokemonRef", "turn", "value", "sourceRevision"]):
			return "Calcdex public evidence fields are invalid."
		if not str(evidence.get("pokemonRef", "")).begins_with("opponent:public-slot-") or typeof(evidence.get("turn")) != TYPE_INT or int(evidence.get("turn")) < 0:
			return "Calcdex public evidence entry is invalid."
		var evidence_type := str(evidence.get("evidenceType", ""))
		if evidence_type == "confirmed_move" and typeof(evidence.get("value")) != TYPE_STRING:
			return "Calcdex move evidence is invalid."
		if evidence_type == "stat_stage" and _validate_known_value("boosts", evidence.get("value")) != "":
			return "Calcdex stat-stage evidence is invalid."
		if evidence_type not in ["confirmed_move", "stat_stage"]:
			return "Calcdex public evidence type is invalid."
	return ""


static func _revisions_equal(left: Dictionary, right: Dictionary) -> bool:
	if not is_valid_projection_revision(right):
		return false
	for field_name: String in REVISION_FIELDS:
		if left.get(field_name) != right.get(field_name):
			return false
	return true


static func _has_exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_name: Variant in fields:
		if not value.has(field_name):
			return false
	return true


static func _has_required_and_allowed_fields(value: Dictionary, required: Array, allowed: Array) -> bool:
	for field_name: Variant in required:
		if not value.has(field_name):
			return false
	for field_name: Variant in value.keys():
		if field_name not in allowed:
			return false
	return true


static func _as_dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


static func _is_sha256(value: String) -> bool:
	if value.length() != 64 or value != value.to_lower():
		return false
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true


static func _is_reason_code(value: String) -> bool:
	if value.is_empty() or value.length() > 96:
		return false
	for character: String in value:
		if character not in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_":
			return false
	return true


static func _malformed(message: String) -> Dictionary:
	return {
		"success": false,
		"code": "malformed_calcdex_snapshot",
		"error": message,
	}
