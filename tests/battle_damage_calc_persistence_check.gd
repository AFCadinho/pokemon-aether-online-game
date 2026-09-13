extends SceneTree

const DamageCalcPersistence := preload("res://scripts/battle/battle_damage_calc_persistence.gd")
const DamageCalcPanel := preload("res://scripts/battle/battle_ui/battle_damage_calc_panel.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var persisted := DamageCalcPersistence.select_persistent_fields(
		{"nature": "Jolly", "boosts": {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0}},
		{"nature": true, "boosts": true}
	)
	if persisted != {"nature": "Jolly"}:
		push_error("Temporary stat stages must never be persisted as species assumptions")
		quit(1)
		return
	var migrated := DamageCalcPersistence.remove_transient_fields({
		"item": "Leftovers", "boosts": {"def": 0},
	})
	if migrated != {"item": "Leftovers"}:
		push_error("Legacy saved stat stages must be removed so public battle stages take precedence")
		quit(1)
		return
	var panel := DamageCalcPanel.new()
	var content := VBoxContainer.new()
	content.name = "VBoxContainer"
	panel.add_child(content)
	root.add_child(panel)
	await process_frame
	panel.set_knowledge_snapshot({
		"format": {"formatKey": "ranked-aether-ou", "engineFormatId": "gen9nationaldex"},
		"viewerPokemon": [{"pokemonRef": "viewer:public-slot-1", "active": true,
			"identity": {"state": "known", "value": "Samurott-Hisui"}}],
		"opponentPokemon": [{"pokemonRef": "opponent:public-slot-1", "active": true,
			"identity": {"state": "known", "value": "Zamazenta"},
			"boosts": {"state": "known", "value": {"def": 1},
				"provenance": {"source": "public_derived", "reasonCode": "TEST_KNOWN"}}}],
	})
	panel.set_defender_assumptions(migrated, {"item": true})
	if panel._get_effective_opponent_boosts() != {"def": 1}:
		panel.queue_free()
		push_error("The current public Defense boost must win after persisted assumptions are cleaned")
		quit(1)
		return
	panel.queue_free()
	await process_frame
	print("PASS: damage calculator persistence keeps stat stages battle-scoped")
	quit()
