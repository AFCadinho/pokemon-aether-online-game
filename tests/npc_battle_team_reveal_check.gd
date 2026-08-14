extends SceneTree

const RevealPolicy := preload("res://scripts/battle/opponent_party_reveal_policy.gd")
const PartySlotScene := preload("res://scenes/battle/party_slot.tscn")
const POKEBALL_TEXTURE := preload("res://assets/items/icons/POKEBALL.png")

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(
		not RevealPolicy.is_team_preview_enabled(
			{"battleOptions": {"teamPreview": false}, "phase": "team_preview"},
			true
		),
		"an explicit NPC preview opt-out overrides Showdown's mechanical preview phase"
	)
	_check(
		RevealPolicy.is_team_preview_enabled(
			{"battleOptions": {"teamPreview": true}},
			false
		),
		"a configured special NPC battle can enable Team Preview"
	)
	_check(
		RevealPolicy.is_team_preview_enabled({}, true),
		"legacy responses can fall back to the mechanical preview marker"
	)

	var team := [
		{"species": "Pidgey", "metadataSlot": 1, "active": false},
		{"species": "Nidoran-F", "metadataSlot": 2, "active": true},
	]
	var policy := RevealPolicy.new()
	policy.reset(false)

	var hidden_team: Array = policy.mask_team(team)
	_check(bool(hidden_team[0].get("unrevealed", false)), "NPC teams start concealed without Team Preview")
	_check(bool(hidden_team[1].get("unrevealed", false)), "active data is not leaked before the reveal is recorded")

	policy.reveal_active(team)
	var lead_revealed: Array = policy.mask_team(team)
	_check(bool(lead_revealed[0].get("unrevealed", false)), "reserve NPC Pokemon remains concealed")
	_check(str(lead_revealed[1].get("species", "")) == "Nidoran-F", "the NPC lead becomes visible")

	policy.reveal_active([
		{"species": "Pidgey", "metadataSlot": 1, "active": true},
		{"species": "Nidoran-F", "metadataSlot": 2, "active": false},
	])
	var switched_team: Array = policy.mask_team(team)
	_check(str(switched_team[0].get("species", "")) == "Pidgey", "a switched-in NPC Pokemon becomes visible")
	_check(str(switched_team[1].get("species", "")) == "Nidoran-F", "previously revealed NPC Pokemon stays visible")

	policy.reset(true)
	var preview_team: Array = policy.mask_team(team)
	_check(str(preview_team[0].get("species", "")) == "Pidgey", "configured NPC Team Preview still reveals the full team")

	var slot := PartySlotScene.instantiate()
	root.add_child(slot)
	await process_frame
	var hover_count := 0
	slot.pokemon_hovered.connect(func(_data: Dictionary, _rect: Rect2) -> void: hover_count += 1)
	slot.set_pokemon_data({"unrevealed": true, "metadataSlot": 1})
	var icon := slot.get_node("MarginContainer/HBoxContainer/PokemonIcon") as TextureRect
	_check(icon.texture == POKEBALL_TEXTURE, "an unrevealed party slot uses the Pokeball placeholder")
	_check(slot.disabled, "an unrevealed party slot cannot be selected")
	slot.call("_on_mouse_entered")
	_check(hover_count == 0, "an unrevealed party slot cannot expose hover details")

	slot.call("set_empty_visible", true)
	slot.call("set_empty")
	_check(slot.visible, "trainer battle rails keep an empty icon slot visible")
	_check(slot.disabled, "an empty trainer battle slot remains disabled")
	_check(icon.texture == null, "an empty trainer battle slot has no Pokeball or Pokemon icon")

	slot.queue_free()
	await process_frame
	if failures == 0:
		print("PASS npc_battle_team_reveal_check")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failures += 1
	push_error("FAIL %s" % label)
