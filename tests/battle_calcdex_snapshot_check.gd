extends SceneTree

const FINGERPRINT := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const CalcdexSnapshot := preload("res://scripts/battle/battle_calcdex_snapshot.gd")
const State := preload("res://scripts/battle/battle_state.gd")


func _init() -> void:
	var revision := _revision()
	var response := {
		"success": true,
		"schemaVersion": 1,
		"routeRevision": "calc1.3-2026-08-08",
		"snapshot": _snapshot(revision),
	}
	var normalized: Dictionary = CalcdexSnapshot.normalize_response(response, revision)
	_check(bool(normalized.get("success", false)), "accepts the frozen provenance snapshot")
	_check(
		str(CalcdexSnapshot.get_active_pokemon(normalized.get("snapshot", {}), "opponent").get("pokemonRef", "")) \
			== "opponent:public-slot-1",
		"selects the active opponent by safe public reference"
	)

	var unknown_with_value: Dictionary = response.duplicate(true)
	unknown_with_value["snapshot"]["opponentPokemon"][0]["item"]["value"] = "Light Ball"
	_check_rejected(unknown_with_value, revision, "rejects values attached to unknown knowledge")

	var exact_opponent_hp: Dictionary = response.duplicate(true)
	exact_opponent_hp["snapshot"]["opponentPokemon"][0]["hp"]["exact"] = {"current": 73, "maximum": 121}
	_check_rejected(exact_opponent_hp, revision, "rejects exact opponent HP")

	var private_field: Dictionary = response.duplicate(true)
	private_field["snapshot"]["opponentPokemon"][0]["privateSet"] = {"item": "Light Ball"}
	_check_rejected(private_field, revision, "rejects extra private Pokémon fields")

	var nested_private_field: Dictionary = response.duplicate(true)
	nested_private_field["snapshot"]["opponentPokemon"][0]["item"]["privateValue"] = "Light Ball"
	_check_rejected(nested_private_field, revision, "rejects extra nested knowledge fields")

	var owned_opponent_value: Dictionary = response.duplicate(true)
	owned_opponent_value["snapshot"]["opponentPokemon"][0]["ability"]["provenance"]["source"] = "owned_exact"
	_check_rejected(owned_opponent_value, revision, "rejects owned provenance on opponent knowledge")

	var stale_revision := revision.duplicate(true)
	stale_revision["eventSeq"] = 6
	_check_rejected(response, stale_revision, "rejects a snapshot from another projection revision")

	var state := State.new()
	state.load_from_api_response({
		"battleId": "battle-1",
		"visibilityContractVersion": 3,
		"snapshotFingerprint": FINGERPRINT,
		"eventSeq": 7,
		"batchSeq": 4,
		"mechanicalRevision": 3,
		"aggregateRevision": 2,
		"battleEventSeq": -1,
	})
	_check(state.get_calcdex_projection_revision() == revision, "BattleState retains the complete projection cursor")
	state.load_from_api_response({"battleId": "battle-2"})
	_check(state.get_calcdex_projection_revision().is_empty(), "a battle change clears the Calcdex cursor")

	print("PASS battle_calcdex_snapshot_check")
	quit(0)


func _snapshot(revision: Dictionary) -> Dictionary:
	return {
		"schemaVersion": 1,
		"battleId": "battle-1",
		"viewerSide": "p1",
		"format": {
			"formatKey": "gen9nationaldex-casual",
			"engineFormatId": "gen9nationaldex",
			"generation": 9,
			"gameType": "singles",
		},
		"turn": 7,
		"projectionRevision": revision.duplicate(true),
		"mechanicsManifest": {
			"contractRevision": "calc0-2026-08-08",
			"damageCalcVersion": "0.10.0",
			"showdownVersion": "0.11.10",
			"formatDataFingerprint": FINGERPRINT,
		},
		"field": {"effects": []},
		"viewerPokemon": [_pokemon("viewer", true)],
		"opponentPokemon": [_pokemon("opponent", false)],
		"publicEvidence": [],
		"safeInputFingerprint": FINGERPRINT,
	}


func _pokemon(relation: String, owned: bool) -> Dictionary:
	var known_source := "owned_exact" if owned else "public_reveal"
	var known := _known("Pikachu", known_source)
	var hp := {
		"display": {"current": 73, "maximum": 100, "scale": "public_percent_100"},
		"intervalPolicy": "showdown_public_condition_v1",
		"provenance": {"source": known_source, "reasonCode": "PUBLIC_HP_DISPLAY"},
	}
	if owned:
		hp = {
			"display": {"current": 73, "maximum": 121, "scale": "exact"},
			"exact": {"current": 73, "maximum": 121},
			"provenance": {"source": known_source, "reasonCode": "OWNED_HP"},
		}
	return {
		"pokemonRef": "%s:public-slot-1" % relation,
		"relation": relation,
		"active": true,
		"fainted": false,
		"identity": known.duplicate(true),
		"level": _known(50, known_source),
		"gender": _unknown(),
		"hp": hp,
		"status": _known("", known_source),
		"moves": [],
		"item": _unknown(),
		"ability": _known("Static", known_source),
		"nature": _unknown(),
		"evs": _unknown(),
		"ivs": _unknown(),
		"boosts": _known({"spa": 1}, "public_derived"),
		"tera": _unknown(),
		"abilityStatModifier": _unknown(),
		"volatiles": [],
	}


func _known(value: Variant, source: String) -> Dictionary:
	return {
		"state": "known",
		"value": value,
		"provenance": {"source": source, "reasonCode": "TEST_KNOWN"},
	}


func _unknown() -> Dictionary:
	return {
		"state": "unknown",
		"provenance": {"source": "unknown", "reasonCode": "TEST_UNKNOWN"},
	}


func _revision() -> Dictionary:
	return {
		"visibilityContractVersion": 3,
		"snapshotFingerprint": FINGERPRINT,
		"eventSeq": 7,
		"batchSeq": 4,
		"mechanicalRevision": 3,
		"aggregateRevision": 2,
		"battleEventSeq": -1,
	}


func _check_rejected(response: Dictionary, revision: Dictionary, label: String) -> void:
	_check(not bool(CalcdexSnapshot.normalize_response(response, revision).get("success", false)), label)


func _check(value: bool, label: String) -> void:
	if value:
		return
	push_error(label)
	quit(1)
