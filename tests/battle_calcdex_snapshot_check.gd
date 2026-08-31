extends SceneTree

const FINGERPRINT := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const CalcdexSnapshot := preload("res://scripts/battle/battle_calcdex_snapshot.gd")
const OwnedFormProjection := preload("res://scripts/battle/battle_owned_form_projection.gd")
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
	var mega_format_response: Dictionary = response.duplicate(true)
	mega_format_response["snapshot"]["format"] = {
		"formatKey": "pokeaether-mega-z-test",
		"engineFormatId": "pokeaether-mega-z-test-v1",
		"generation": 9,
		"gameType": "singles",
	}
	_check(
		bool(CalcdexSnapshot.normalize_response(mega_format_response, revision).get("success", false)),
		"accepts the exact Champions ZA calculator format"
	)
	var uu_format_response: Dictionary = response.duplicate(true)
	uu_format_response["snapshot"]["format"] = {
		"formatKey": "aether-uu",
		"engineFormatId": "gen9nationaldex",
		"generation": 9,
		"gameType": "singles",
	}
	_check(
		bool(CalcdexSnapshot.normalize_response(uu_format_response, revision).get("success", false)),
		"accepts the Aether UU calculator format"
	)
	var wire_response: Dictionary = JSON.parse_string(JSON.stringify(response))
	wire_response["status"] = 200.0
	var wire_revision: Dictionary = JSON.parse_string(JSON.stringify(revision))
	_check(
		bool(CalcdexSnapshot.normalize_response(wire_response, wire_revision).get("success", false)),
		"accepts integral JSON numbers and strips known HTTP transport metadata"
	)
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
	var fractional_turn := wire_response.duplicate(true)
	fractional_turn["snapshot"]["turn"] = 7.5
	_check_rejected(fractional_turn, wire_revision, "rejects fractional values in integer contract fields")

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

	_check(
		CalcdexSnapshot.is_valid_mechanics_manifest(_mechanics_manifest()),
		"accepts the exact approved mechanics manifest"
	)
	var mismatched_manifest := _mechanics_manifest()
	mismatched_manifest["damageCalcVersion"] = "0.10.1"
	_check(
		not CalcdexSnapshot.is_valid_mechanics_manifest(mismatched_manifest),
		"rejects an unapproved mechanics manifest"
	)

	var live_mega_stats := OwnedFormProjection.merge_stats(
		{"hp": 318, "atk": 333, "def": 186, "spa": 216, "spd": 196, "spe": 423},
		{"atk": 413, "def": 186, "spa": 297, "spd": 196, "spe": 445}
	)
	_check(live_mega_stats.get("hp") == 318, "keeps owned HP when the live request omits it")
	_check(live_mega_stats.get("atk") == 413, "prefers the live Mega Attack stat")
	_check(live_mega_stats.get("spa") == 297, "prefers the live Mega Special Attack stat")
	_check(live_mega_stats.get("spe") == 445, "prefers the live Mega Speed stat")

	var hover_data := {
		"species": "Zeraora",
		"displaySpecies": "Zeraora",
		"ability": "Volt Absorb",
		"possibleAbilities": ["Volt Absorb"],
		"stats": {"hp": 318, "atk": 333},
	}
	OwnedFormProjection.apply_live_form_to_hover(
		hover_data,
		{
			"ability": "Volt Absorb",
			"stats": {"atk": 413, "def": 186, "spa": 297, "spd": 196, "spe": 445},
		},
		"Zeraora-Mega"
	)
	_check(hover_data.get("species") == "Zeraora-Mega", "party hover uses the live Mega species")
	_check(hover_data.get("displaySpecies") == "Zeraora-Mega", "party hover labels the live Mega form")
	_check(hover_data.get("stats", {}).get("hp") == 318, "party hover retains owned HP")
	_check(hover_data.get("stats", {}).get("atk") == 413, "party hover uses live Mega stats")
	_check(hover_data.get("ability") == "Volt Absorb", "party hover uses the live battle ability")

	var latest_response := {
		"requests": {
			"p1": {
				"side": {
					"pokemon": [{
						"canonicalPartySlot": 1,
						"species": "Dragonite",
						"displaySpecies": "Dragonite-Mega",
						"ability": "Multiscale",
						"stats": {"atk": 381, "def": 266, "spa": 293, "spd": 286, "spe": 299},
					}],
				},
			},
		},
	}
	var latest_dragonite := OwnedFormProjection.find_request_pokemon(latest_response, "p1", 1)
	var stale_display := {
		"species": "Dragonite",
		"displaySpecies": "Dragonite-Mega",
		"ability": "Inner Focus",
		"stats": {"atk": 403, "def": 226, "spa": 212, "spd": 237, "spe": 259},
	}
	OwnedFormProjection.apply_live_request_to_display(stale_display, latest_dragonite)
	_check(stale_display.get("ability") == "Multiscale", "latest owned request replaces the base ability")
	_check(stale_display.get("stats", {}).get("atk") == 381, "latest owned request replaces base-form stats")
	_check(stale_display.get("displaySpecies") == "Dragonite-Mega", "latest owned request keeps the Mega label")

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
		"mechanicsManifest": _mechanics_manifest(),
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


func _mechanics_manifest() -> Dictionary:
	return {
		"contractRevision": "calc0.1-2026-08-21",
		"damageCalcVersion": "0.11.0+upstream.636e5b9.pao2",
		"showdownVersion": "0.11.11",
		"formatDataFingerprint": CalcdexSnapshot.FORMAT_DATA_FINGERPRINT,
	}


func _check_rejected(response: Dictionary, revision: Dictionary, label: String) -> void:
	_check(not bool(CalcdexSnapshot.normalize_response(response, revision).get("success", false)), label)


func _check(value: bool, label: String) -> void:
	if value:
		return
	push_error(label)
	quit(1)
