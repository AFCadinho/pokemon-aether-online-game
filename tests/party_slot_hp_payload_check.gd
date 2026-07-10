extends SceneTree

const PartySlotScript := preload("res://scripts/battle/battle_ui/party_slot.gd")

var failed := false


func _init() -> void:
	var slot = PartySlotScript.new()

	_check_equal(
		slot.call("_get_max_hp_from_data", {"species": "Pikachu", "stats": {"hp": 141}}),
		141,
		"party slot max HP falls back to stats HP"
	)
	_check_equal(
		slot.call("_get_current_hp_from_data", {"species": "Pikachu", "stats": {"hp": 141}}, 141),
		141,
		"party slot treats missing HP as full HP"
	)
	_check_equal(
		slot.call("_get_fainted_from_data", {"species": "Pikachu", "stats": {"hp": 141}}, 141),
		false,
		"party slot does not faint payloads with missing HP"
	)
	_check_equal(
		slot.call("_get_fainted_from_data", {"condition": "0 fnt"}, 0),
		true,
		"party slot still respects fainted conditions"
	)

	slot.free()
	quit(1 if failed else 0)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
