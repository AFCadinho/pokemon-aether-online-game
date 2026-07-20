extends SceneTree

const PartySlotScript := preload("res://scripts/battle/battle_ui/party_slot.gd")
const PartySlotScene := preload("res://scenes/battle/party_slot.tscn")

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

	var visual_slot := PartySlotScene.instantiate()
	visual_slot.icon_only_mode = true
	root.add_child(visual_slot)
	await process_frame
	visual_slot.set_pokemon_data({
		"species": "Pikachu",
		"condition": "0 fnt",
		"hp": 0,
		"maxHp": 100,
		"fainted": true,
	})
	var pokemon_icon := visual_slot.get_node("MarginContainer/HBoxContainer/PokemonIcon") as TextureRect
	var faint_badge := visual_slot.get_node("MarginContainer/HBoxContainer/PokemonIcon/IconStatusBadge") as Label
	_check_equal(faint_badge.text, "FNT", "fainted icon-only slot shows FNT text")
	_check_equal(faint_badge.visible, true, "fainted icon-only slot shows its badge")
	_check_equal(pokemon_icon.modulate, Color.WHITE, "FNT badge parent no longer passes a dark modulate to its children")
	_check_equal(faint_badge.self_modulate, Color.WHITE, "FNT badge keeps its full text and pill brightness")
	_check_equal(pokemon_icon.self_modulate.r < 0.2, true, "fainted Pokemon silhouette remains visibly dark")
	visual_slot.queue_free()
	quit(1 if failed else 0)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
