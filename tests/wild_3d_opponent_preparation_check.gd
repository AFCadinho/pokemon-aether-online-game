extends SceneTree

class DownloadProbe extends Node:
	signal finish_download
	var requested: Array[String] = []
	var hold_download := false
	var show_download := true
	func ensure_models(identities: Array[String], _catalog: String) -> Dictionary:
		requested = identities.duplicate()
		if hold_download:
			await finish_download
		return {"error": "Offline probe stops before network access."}
	func progress_text() -> String:
		return "Downloading approved model… 50%"
	func battle_download_progress() -> Dictionary:
		return {"received_bytes": 50, "total_bytes": 100} if hold_download and show_download else {}

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
	# Route encounters show a pending arena before the response arrives. Exercise
	# the actual host, with a deliberately slow download and no Pokédex visit.
	for prewarmed in [false, true]:
		await _check_pending_entry(scene, probe, prewarmed)
	probe.free()
	root.add_child(downloader)
	if not failed:
		print("PASS wild_3d_opponent_preparation_check normal=true shiny=true both_leads_before_reveal=true no_interim_2d=true download_progress=true")
	quit(1 if failed else 0)


func _check_pending_entry(scene: PackedScene, probe: DownloadProbe, prewarmed: bool) -> void:
	probe.requested.clear()
	probe.hold_download = true
	probe.show_download = true
	var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	root.add_child(host)
	var battle = scene.instantiate()
	if prewarmed:
		host.prewarm_battle(battle)
	host.mount(battle, null, WildEncounterTransition.STYLE_FULLSCREEN_FADE)
	battle.prepare_pending_entry(&"grass")
	host.reveal_pending_entry()
	for frame in 20:
		await process_frame
	_check(host.fade_progress == 0.0 and host.get_node("Cover").visible, "3D entry retains the outgoing world while its response is pending")
	_check(not host.preparation_ready and probe.requested.is_empty(), "no incomplete pair is downloaded before the response")
	# Exceed the message delay without network I/O. Even a slow local shader
	# warmup must keep the outgoing world clean and retain the readiness gate.
	var stage: Node = battle.animation_router.model_presenter
	host.loading_message_after_ms = Time.get_ticks_msec() - 1
	for phase: String in ["Checking approved 3D models…", "Loading Pokémon models", "Preparing lighting and shaders"]:
		stage.preparation_phase = phase
		host._process(0.0)
		_check(not host.loading_label.is_visible_in_tree() and host.loading_label.text.is_empty(), "local preparation never shows technical text: " + phase)
		_check(host.fade_progress == 0.0 and host.get_node("Cover").visible, "quiet preparation still protects the 3D entrance")
	host.loading_message_after_ms = Time.get_ticks_msec() + 500
	var enemy := Pokemon.new("Hoothoot", 2)
	enemy.shiny = prewarmed
	var p1 := _active("p1", "Zapdos", false)
	var p2 := _active("p2", "Hoothoot", enemy.shiny)
	var response := {"success": true, "battleId": "offline-slow-3d", "formatId": "gen9nationaldex",
		"players": {"p1": {"name": "Player"}, "p2": {"name": "Wild"}},
		"ownTeam": [p1], "trainerTeam": [p2],
		"requests": {"p1": {"side": {"pokemon": [p1]}}, "p2": {"side": {"pokemon": [p2]}}},
		"state": {"turn": 1, "ended": false}, "events": []}
	_check(battle.prepare_wild_battle_from_response(Pokemon.new("Zapdos", 100), enemy, response, &"grass"), "pending encounter accepts its authoritative pair")
	host.request_reveal()
	for frame in 20:
		await process_frame
	_check(probe.requested == ["zapdos", "hoothoot@shiny" if enemy.shiny else "hoothoot"], "uncached pair is requested through the real entry host")
	_check(host.fade_progress == 0.0 and host.get_node("Cover").visible and not host.preparation_ready,
		"slow model download never exposes the interim 2D arena or sprites")
	_check(not host.loading_label.is_visible_in_tree(), "quick preparations do not flash a loading message")
	await create_timer(0.55).timeout
	_check(host.loading_label.is_visible_in_tree() and "50%" in host.loading_label.text, "waiting players can see model download progress")
	_check(host.loading_label.text == root.get_node("LocalizationManager").text("ui.battle.downloading_pokemon") + " 50%", "download feedback uses simple player-facing language")
	probe.show_download = false
	host._process(0.0)
	_check(not host.loading_label.is_visible_in_tree() and host.loading_label.text.is_empty(), "download text disappears as soon as only local preparation remains")
	probe.finish_download.emit()
	# A genuine failure still releases the entry into stable sprite fallback.
	var deadline := Time.get_ticks_msec() + 5000
	while host.get_node("Cover").visible and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(host.preparation_ready and not host.get_node("Cover").visible, "failed download reveals the stable fallback without blocking the encounter")
	_check(battle.animation_router.model_presenter.preparation_failed, "fallback is caused by the explicit download failure")
	host.release()
	host.free()
	probe.hold_download = false
	await process_frame


func _active(side: String, species: String, shiny: bool) -> Dictionary:
	return {"ident": side + "a: " + species, "details": species + ", L100" + (", shiny" if shiny else ""),
		"species": species, "shiny": shiny, "condition": "100/100", "hp": 100, "maxHp": 100, "active": true}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("FAIL " + message)
