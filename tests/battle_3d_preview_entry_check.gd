extends SceneTree

const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Cache = preload("res://scripts/battle/battle_ui/model_resource_cache.gd")
const FIXTURE := "user://preview-entry-check"
var failed := false
var originals := {}

class DownloadProbe extends Node:
	signal finish_download
	var requested: Array[String] = []
	var catalog := ""
	var progress := {}
	var error := ""
	var hold_download := true
	func ensure_models(identities: Array[String], _source: String) -> Dictionary:
		requested = identities.duplicate()
		if hold_download: await finish_download
		return {"error": error, "path": catalog, "catalog_changed": true}
	func progress_text() -> String: return "Offline fixture"
	func battle_download_progress() -> Dictionary: return progress

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_arena = "classic"
	settings.battle_ui_layout = "immersive"
	settings._manual_model_catalog_this_session = false
	OS.unset_environment("POKEAETHER_3D_STAGE_REPORT")
	OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	var service := root.get_node("OnDemand3DBundleService")
	root.remove_child(service)
	var probe := DownloadProbe.new()
	probe.name = "OnDemand3DBundleService"
	probe.catalog = _make_fixture()
	root.add_child(probe)
	for scenario in ["training", "p1", "p2", "fallback", "cancel"]:
		await _check_entry(scenario, probe, settings)
	await _check_cached_entry(probe, settings)
	Cache.clear()
	probe.free()
	root.add_child(service)
	var models: Dictionary = Registry.DATA.data.models
	for identity in originals:
		models[identity] = originals[identity]
	for filename in ["dragonite.scn", "pikachu@shiny.scn", "catalog.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE.path_join(filename)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))
	print("BATTLE_3D_PREVIEW_ENTRY_CHECK ", "FAIL" if failed else "PASS", " trainer=true pvp_p1_p2=true preparation_feedback=true progress=true no_2d_flash=true music_after_reveal=true fallback=true cancellation=true cached=true")
	quit(1 if failed else 0)

func _check_entry(scenario: String, probe: Node, settings: Node) -> void:
	print("CASE ", scenario)
	settings.battle_3d_catalog_path = ""
	OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	probe.requested.clear()
	probe.progress = {}
	probe.error = "Offline download failed" if scenario == "fallback" else ""
	var world = Node2D.new()
	root.add_child(world)
	world.set_script(load("res://tests/fixtures/preview_entry_world_probe.gd"))
	world.is_in_battle = true
	world.active_battle_kind = "training_ai" if scenario == "training" else "pvp"
	var transition := WildEncounterTransition.new()
	world.add_child(transition)
	world.wild_encounter_transition = transition
	transition.begin(WildEncounterTransition.STYLE_FULLSCREEN_FADE)
	var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	root.add_child(host)
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	battle.set_script(load("res://tests/fixtures/preview_entry_battle_probe.gd"))
	host.mount(battle, null, WildEncounterTransition.STYLE_FULLSCREEN_FADE)
	world.battle_instance = battle
	world.battle_screen_host = host
	var offline_loader := load("res://tests/fixtures/offline_preview_sprite_loader.gd")
	for layer in [battle.player_team_preview_layer, battle.enemy_team_preview_layer]:
		layer.sprite_loader.free()
		layer.sprite_loader = offline_loader.new()
	var stage: Node = battle.animation_router.model_presenter
	var music := root.get_node("MusicManager")
	var previous_music: String = music.last_requested_track_path
	music.last_requested_track_path = "offline-overworld-sentinel"
	var callback := Callable(world, "_reveal_prepared_training_ai_battle" if scenario == "training" else "_reveal_prepared_pvp_battle")
	battle.run_setup(Pokemon.new("Dragonite", 100), _response("p2" if scenario == "p2" else "p1"), callback, scenario == "training")
	var deadline := Time.get_ticks_msec() + 3000
	while probe.requested.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	_check(probe.requested.size() == 2 and "dragonite" in probe.requested and "pikachu@shiny" in probe.requested,
		"public rosters are requested before reveal, without a selected lead or hidden forms")
	_check(not transition.visible, "outgoing lobby transition relinquishes the loading screen immediately")
	for frame in 10: await process_frame
	_check(host.loading_backdrop.visible and host.loading_backdrop.modulate.a == 1.0 and host.outgoing_snapshot.texture == null,
		"the frozen lobby is replaced by an opaque loading screen")
	_check(host.loading_label.is_visible_in_tree() and host.loading_label.text == root.get_node("LocalizationManager").text("ui.battle.preparing_battle"),
		"local preparation has player-facing feedback")
	_check(host.loading_progress.is_visible_in_tree() and host.loading_progress.indeterminate, "local preparation shows an animated progress indicator")
	_check(host.fade_progress == 0.0 and not host.preparation_ready and not battle.selection_started and battle.battle_input_locked,
		"3D readiness gates the fade and lead input")
	_check(music.last_requested_track_path == "offline-overworld-sentinel", "battle music waits for the visible arena")
	probe.progress = {"received_bytes": 35, "total_bytes": 100}
	await process_frame
	await process_frame
	_check(host.loading_label.text == root.get_node("LocalizationManager").text("ui.battle.downloading_pokemon") + " 35%", "network download progress is visible")
	_check(not host.loading_progress.indeterminate and host.loading_progress.value == 35, "the bar follows actual downloaded bytes")
	await _capture(scenario + "-loading")
	if scenario == "cancel":
		world.is_in_battle = false
		host.release()
		await process_frame
		_check(music.last_requested_track_path == "offline-overworld-sentinel", "cancelled preparation never starts battle music")
	else:
		probe.progress = {}
		probe.finish_download.emit()
		deadline = Time.get_ticks_msec() + 15000
		var flash := false
		while not battle.selection_started and Time.get_ticks_msec() < deadline:
			if host.fade_progress > 0.0 and scenario != "fallback":
				flash = flash or not stage.active or not is_instance_valid(stage.preview_visual) or battle.player_team_preview_layer.visible or battle.enemy_team_preview_layer.visible
			await process_frame
		_check(battle.selection_started and host.preparation_ready and host.fade_progress == 1.0, "readiness completes without waiting for a lead choice")
		_check(not flash, "every visible fade frame already contains native Team Preview")
		if scenario == "fallback":
			_check(not stage.active and battle.player_team_preview_layer.visible, "a failed download reveals the deliberate 2D fallback")
		else:
			_check(stage.preview_visual != null and stage.preview_visual.slots.size() == 2 and not battle.player_team_preview_layer.visible, "preview actors replace the legacy sprites")
			_check(stage.preview_teams[0][0] == ("pikachu@shiny" if scenario == "p2" else "dragonite"), "PvP preview follows the local side mapping")
		_check(music.last_requested_track_path != "offline-overworld-sentinel", "battle music starts after the completed fade")
		await _capture(scenario + "-ready")
	battle.finish_selection.emit()
	await process_frame
	host.release()
	host.free()
	world.battle_instance = null
	world.battle_screen_host = null
	world.free()
	await process_frame
	if scenario == "cancel":
		probe.finish_download.emit()
		await process_frame
	music.last_requested_track_path = previous_music

func _check_cached_entry(probe: Node, settings: Node) -> void:
	print("CASE cached")
	settings.battle_3d_catalog_path = ""
	OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	probe.hold_download = false
	probe.error = ""
	probe.progress = {}
	var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	root.add_child(host)
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	battle.set_script(load("res://tests/fixtures/preview_entry_battle_probe.gd"))
	host.mount(battle, null, WildEncounterTransition.STYLE_FULLSCREEN_FADE)
	var offline_loader := load("res://tests/fixtures/offline_preview_sprite_loader.gd")
	for layer in [battle.player_team_preview_layer, battle.enemy_team_preview_layer]:
		layer.sprite_loader.free()
		layer.sprite_loader = offline_loader.new()
	battle.run_setup(Pokemon.new("Dragonite", 100), _response("p1"), func():
		host.request_reveal()
		await host.wait_until_revealed(), true)
	var deadline := Time.get_ticks_msec() + 5000
	var flash := false
	while not battle.selection_started and Time.get_ticks_msec() < deadline:
		if host.fade_progress > 0.0:
			flash = flash or not battle.animation_router.model_presenter.active or battle.player_team_preview_layer.visible
		await process_frame
	_check(battle.selection_started and not flash and not host.get_node("Cover").visible, "cached models also reveal a prepared native preview without the old 30-second wait")
	_check(not host.loading_label.is_visible_in_tree(), "cached readiness clears loading feedback")
	battle.finish_selection.emit()
	await process_frame
	host.release()
	host.free()
	await process_frame

func _response(player_id: String) -> Dictionary:
	var own := [{"ident": "p1: Dragonite", "species": "Dragonite", "details": "Dragonite, L100", "level": 100,
		"condition": "100/100", "hp": 100, "maxHp": 100, "metadataSlot": 1, "active": false}]
	var enemy := [{"ident": "p2: Pikachu", "species": "Pikachu", "details": "Pikachu, L100, shiny", "level": 100,
		"condition": "100/100", "hp": 100, "maxHp": 100, "metadataSlot": 1, "active": false, "shiny": true}]
	return {"success": true, "battleId": "offline-preview-entry", "playerId": player_id, "phase": "team_preview",
		"battleOptions": {"teamPreview": true}, "battlePurpose": "training", "ownTeam": own, "trainerTeam": enemy,
		"requests": {"p1": {"teamPreview": true, "side": {"pokemon": own}}, "p2": {"teamPreview": true, "side": {"pokemon": enemy}}}}

func _make_fixture() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE))
	var entries := []
	for identity in ["dragonite", "pikachu@shiny"]:
		var actor := MeshInstance3D.new()
		actor.mesh = CapsuleMesh.new()
		var player := AnimationPlayer.new()
		actor.add_child(player)
		player.owner = actor
		var library := AnimationLibrary.new()
		var model: Dictionary = Registry.DATA.data.models[identity]
		for action in Registry.DATA.data.profiles[model.profile].action_timing:
			var animation := Animation.new()
			animation.length = 0.5
			library.add_animation(action, animation)
		player.add_animation_library("", library)
		var packed := PackedScene.new()
		var path := ProjectSettings.globalize_path(FIXTURE.path_join(identity + ".scn"))
		_check(packed.pack(actor) == OK and ResourceSaver.save(packed, path) == OK, "save fixture scene")
		actor.free()
		var digest := FileAccess.get_sha256(path)
		originals[identity] = model.duplicate(true)
		model.sha256 = digest
		model.previous_sha256 = []
		entries.append({"species": "Dragonite" if identity == "dragonite" else "Pikachu", "variant": "normal" if identity == "dragonite" else "shiny",
			"runtime_schema": 1, "runtime_path": path, "runtime_sha256": digest, "bytes": FileAccess.get_file_as_bytes(path).size()})
	var path := ProjectSettings.globalize_path(FIXTURE.path_join("catalog.json"))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(entries))
	return path

func _capture(label: String) -> void:
	var prefix := OS.get_environment("POKEAETHER_PREVIEW_ENTRY_CAPTURE")
	if prefix.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(prefix + "-" + label + ".png") == OK, "capture " + label)

func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
