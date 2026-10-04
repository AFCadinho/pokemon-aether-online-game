extends SceneTree

class DownloadProbe extends Node:
	var requested: Array[String] = []
	func ensure_models(identities: Array[String], _catalog: String) -> Dictionary:
		requested = identities.duplicate()
		return {"error": "Offline probe stops before network access."}

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_catalog_path = ""
	settings.battle_3d_arena = "stadium"
	var downloader := root.get_node("OnDemand3DBundleService")
	root.remove_child(downloader)
	var probe := DownloadProbe.new()
	probe.name = "OnDemand3DBundleService"
	root.add_child(probe)
	var scene := load("res://scenes/battle/battle.tscn") as PackedScene
	for shiny in [false, true]:
		var battle := scene.instantiate()
		root.add_child(battle)
		await process_frame
		var player := Pokemon.new("Zapdos", 100)
		var enemy := Pokemon.new("Hoothoot", 2)
		enemy.shiny = shiny
		var p1 := _active("p1", "Zapdos", false)
		var p2 := _active("p2", "Hoothoot", shiny)
		var response := {"success": true, "battleId": "offline-wild-3d", "formatId": "gen9nationaldex",
			"players": {"p1": {"name": "Player"}, "p2": {"name": "Wild"}},
			"ownTeam": [p1], "trainerTeam": [p2],
			"requests": {"p1": {"side": {"pokemon": [p1]}}, "p2": {"side": {"pokemon": [p2]}}},
			"state": {"turn": 1, "ended": false}, "events": []}
		_check(battle.prepare_wild_battle_from_response(player, enemy, response, &"grass"), "authoritative wild snapshot is accepted")
		var stage: Node = battle.animation_router.model_presenter
		_check(stage.combatants[0].species == "zapdos" and stage.combatants[1].species == "hoothoot",
			"both leads are known before the encounter cover can release")
		_check(stage.combatants[1].shiny == shiny, "opponent appearance is staged before downloads")
		probe.requested.clear()
		await stage._ensure_downloaded_models()
		_check("zapdos" in probe.requested, "player is included in pre-battle model preparation")
		_check(("hoothoot@shiny" if shiny else "hoothoot") in probe.requested,
			"uncached normal/shiny opponent is requested before revealing the battle")
		battle.free()
		await process_frame
	probe.free()
	root.add_child(downloader)
	if not failed:
		print("PASS wild_3d_opponent_preparation_check normal=true shiny=true both_leads_before_reveal=true")
	quit(1 if failed else 0)


func _active(side: String, species: String, shiny: bool) -> Dictionary:
	return {"ident": side + "a: " + species, "details": species + ", L100" + (", shiny" if shiny else ""),
		"species": species, "shiny": shiny, "condition": "100/100", "hp": 100, "maxHp": 100, "active": true}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("FAIL " + message)
