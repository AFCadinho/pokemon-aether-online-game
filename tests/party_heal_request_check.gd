extends SceneTree

const PartyHealServiceScript := preload("res://scripts/services/party_heal_service.gd")

var failed := false


func _init() -> void:
	var heal_service := PartyHealServiceScript.new()
	var status_only_pokemon := Pokemon.new("Pikachu", 5)
	status_only_pokemon.has_saved_hp_state = true
	status_only_pokemon.status = "psn"
	_check(
		heal_service.party_needs_heal([status_only_pokemon]),
		"A status condition makes an otherwise healthy party eligible for healing"
	)
	heal_service.free()

	var pvp_body: Dictionary = PartyHealServiceScript.build_heal_request_body({}, false)
	_check(
		pvp_body == {"publicService": false},
		"PvP healing omits an empty respawn point"
	)

	var respawn_point := {
		"mapId": "kanto_pallet_town",
		"mapScenePath": "res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn",
		"position": {"x": 368, "y": 272},
		"facingDirection": "down",
	}
	var npc_body: Dictionary = PartyHealServiceScript.build_heal_request_body(respawn_point, true)
	_check(
		npc_body == {
			"publicService": true,
			"respawnPoint": respawn_point,
		},
		"NPC healing keeps a complete respawn point"
	)
	_check(
		npc_body.get("respawnPoint") is Dictionary \
			and not is_same(npc_body.get("respawnPoint"), respawn_point),
		"Heal request owns a defensive respawn-point copy"
	)

	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
