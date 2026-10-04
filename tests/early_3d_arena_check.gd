extends SceneTree

const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Pool = preload("res://scripts/battle/arenas/shared/environment_pool.gd")
const Cache = preload("res://scripts/battle/battle_ui/model_resource_cache.gd")
const FIXTURE := "user://early-arena-check"

class DownloadProbe extends Node:
	signal finish_download
	var requested: Array[String] = []
	var catalog := ""
	func ensure_models(identities: Array[String], _source: String) -> Dictionary:
		requested = identities.duplicate()
		await finish_download
		return {"error": "", "path": catalog, "catalog_changed": true}
	func progress_text() -> String:
		return "Checking local files"
	func battle_download_progress() -> Dictionary:
		return {} # Deliberately hold local preparation, without network access.

var failed := false
var originals := {}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_catalog_path = ""
	var requested_arena := OS.get_environment("POKEAETHER_TEST_ENTRY_ARENA")
	settings.battle_3d_arena = requested_arena if not requested_arena.is_empty() else "stadium"
	var previous_catalog := OS.get_environment("POKEAETHER_MODEL_CATALOG")
	var downloader := root.get_node("OnDemand3DBundleService")
	root.remove_child(downloader)
	var probe := DownloadProbe.new()
	probe.name = "OnDemand3DBundleService"
	probe.catalog = _make_fixture()
	root.add_child(probe)
	Cache.clear()
	# Use the actual map-owned environment pool, including its shader warmup.
	var pool := Pool.prepare(root, settings.get_battle_3d_forest_manifest(), Vector2i(960, 540), settings.battle_3d_arena)
	_check(pool != null, "arena source is available")
	if pool == null:
		quit(1)
		return
	var deadline := Time.get_ticks_msec() + 30000
	while not pool.ready_for_battle and not pool.failed and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(pool.ready_for_battle, "the arena is prepared before an encounter")
	for round_index in 2:
		OS.unset_environment("POKEAETHER_MODEL_CATALOG")
		probe.requested.clear()
		var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
		root.add_child(host)
		var battle = load("res://scenes/battle/battle.tscn").instantiate()
		host.prewarm_battle(battle)
		host.mount(battle, null, WildEncounterTransition.STYLE_FULLSCREEN_FADE)
		battle.prepare_pending_entry(&"grass")
		var started := Time.get_ticks_msec()
		host.reveal_pending_entry()
		deadline = started + 3000
		while host.fade_progress < 1.0 and Time.get_ticks_msec() < deadline:
			await process_frame
		var stage: Node = battle.animation_router.model_presenter
		_check(host.fade_progress == 1.0 and host.entry_arena_ready and not host.preparation_ready,
			"the existing fade finishes before a response or model load")
		_check(stage.viewport == pool.passes[0].viewport and stage.is_visible_in_tree(), "entry reuses the already drawn arena")
		_check(stage.actors[0] == null and stage.actors[1] == null, "pending entry has no placeholder actors")
		await _capture("pending-%d" % round_index)
		var retained_viewport: SubViewport = stage.viewport
		var waiting := {"finished": false}
		_wait_for_ready(host, waiting)
		var p1 := _active("p1", "Dragonite", false)
		var p2 := _active("p2", "Garchomp", true)
		var response := {"success": true, "battleId": "offline-early-arena", "formatId": "gen9nationaldex",
			"players": {"p1": {"name": "Player"}, "p2": {"name": "Wild"}},
			"ownTeam": [p1], "trainerTeam": [p2],
			"requests": {"p1": {"side": {"pokemon": [p1]}}, "p2": {"side": {"pokemon": [p2]}}},
			"state": {"turn": 1, "ended": false}, "events": []}
		var enemy := Pokemon.new("Garchomp", 100)
		enemy.shiny = true
		_check(battle.prepare_wild_battle_from_response(Pokemon.new("Dragonite", 100), enemy, response, &"grass"), "authoritative pair is accepted")
		host.request_reveal()
		deadline = Time.get_ticks_msec() + 3000
		while probe.requested.is_empty() and Time.get_ticks_msec() < deadline:
			await process_frame
		for frame in 10:
			await process_frame
			_check(stage.viewport == retained_viewport and stage.is_visible_in_tree(), "arena stays visible throughout local model preparation")
			_check(battle.player_sprite_box.model_sprites_hidden and battle.enemy_sprite_box.model_sprites_hidden, "sprite frame refresh cannot flash a 2D Pokémon")
		_check(probe.requested == ["dragonite", "garchomp@shiny"], "normal and shiny leads are both requested")
		_check(not waiting.finished and battle.battle_input_locked and not battle.battle_actions_ready and battle.has_meta("battle_screen_preparing"), "early fade does not release the intro or first-turn controls")
		_check(not host.loading_label.is_visible_in_tree(), "local preparation stays quiet on the arena")
		await _capture("loading-%d" % round_index)
		probe.finish_download.emit()
		deadline = Time.get_ticks_msec() + 10000
		while not waiting.finished and Time.get_ticks_msec() < deadline:
			await process_frame
		_check(waiting.finished and host.preparation_ready and not host.get_node("Cover").visible, "verified models release the normal intro readiness gate")
		_check(stage.viewport == retained_viewport and stage.handles("p1") and stage.handles("p2"), "ready actors use the original arena with no rebuild")
		_check(stage.actors[0].visible and stage.actors[1].visible and not stage.warming_render, "both real actors appear in their actual entry visibility")
		if round_index == 1:
			_check(stage.model_cache_hits >= 2, "repeated encounter reuses the prepared models")
		await _capture("ready-%d" % round_index)
		host.release()
		host.free()
		await process_frame
		_check(pool.borrower == null, "leaving the encounter returns the arena to its world owner")
	await _check_empty_preview(pool)
	await _check_cancelled_entry(probe, pool)
	Cache.clear()
	pool.free()
	probe.free()
	root.add_child(downloader)
	var models: Dictionary = Registry.DATA.data.models
	for identity: String in originals:
		models[identity] = originals[identity]
	for filename in ["dragonite.scn", "garchomp@shiny.scn", "catalog.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE.path_join(filename)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))
	if previous_catalog.is_empty():
		OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	else:
		OS.set_environment("POKEAETHER_MODEL_CATALOG", previous_catalog)
	print("EARLY_3D_ARENA_CHECK ", "FAIL" if failed else "PASS", " arena=", settings.battle_3d_arena,
		" pending_response=true held_models=true normal_shiny=true repeated=true empty_preview=true cancellation=true")
	quit(1 if failed else 0)

func _check_empty_preview(pool: Node) -> void:
	OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	root.add_child(host)
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	host.mount(battle, null, WildEncounterTransition.STYLE_FULLSCREEN_FADE)
	battle.prepare_pending_entry(&"grass")
	battle.team_preview_lead_selection_active = true
	host.reveal_pending_entry()
	var deadline := Time.get_ticks_msec() + 3000
	while host.get_node("Cover").visible and Time.get_ticks_msec() < deadline:
		await process_frame
	for frame in 5:
		await process_frame
	var stage: Node = battle.animation_router.model_presenter
	_check(host.preparation_ready and not host.get_node("Cover").visible and stage.active and stage.viewport == pool.passes[0].viewport,
		"empty Team Preview remains in 3D without requiring a Pokémon catalog")
	_check(stage.actors[0] == null and stage.actors[1] == null, "preview readiness never invents active combatants")
	host.release()
	host.free()
	await process_frame

func _check_cancelled_entry(probe: DownloadProbe, pool: Node) -> void:
	OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	probe.requested.clear()
	var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	root.add_child(host)
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	host.mount(battle, null, WildEncounterTransition.STYLE_FULLSCREEN_FADE)
	battle.prepare_pending_entry(&"grass")
	host.reveal_pending_entry()
	var stage: Node = battle.animation_router.model_presenter
	stage.set_combatant(0, "Dragonite")
	stage.set_combatant(1, "Garchomp", true)
	battle.remove_meta("battle_entry_pending")
	var deadline := Time.get_ticks_msec() + 3000
	while probe.requested.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not probe.requested.is_empty(), "cancel fixture is waiting for the actual model handoff")
	host.release()
	_check(stage.preparation_cancelled and not stage.entry_arena_requested, "cancelled entry stops arena reveal and preparation")
	host.free()
	await process_frame
	probe.finish_download.emit()
	for frame in 5:
		await process_frame
	_check(pool.borrower == null, "cancelled download cannot retain or reacquire the shared arena")

func _capture(name: String) -> void:
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	if not output.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func _wait_for_ready(host: Control, state: Dictionary) -> void:
	await host.wait_until_revealed()
	state.finished = true

func _make_fixture() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE))
	var entries := []
	var models: Dictionary = Registry.DATA.data.models
	for identity in ["dragonite", "garchomp@shiny"]:
		var actor := Node3D.new()
		actor.name = "FixtureActor"
		var mesh := MeshInstance3D.new()
		mesh.mesh = SphereMesh.new()
		actor.add_child(mesh)
		mesh.owner = actor
		var player := AnimationPlayer.new()
		actor.add_child(player)
		player.owner = actor
		var library := AnimationLibrary.new()
		var profile: Dictionary = Registry.DATA.data.profiles[models[identity].profile]
		for action: String in profile.action_timing:
			var animation := Animation.new()
			animation.length = float(profile.action_timing[action].frames) / 60.0
			library.add_animation(action, animation)
		player.add_animation_library("", library)
		var packed := PackedScene.new()
		var path := ProjectSettings.globalize_path(FIXTURE.path_join(identity + ".scn"))
		_check(packed.pack(actor) == OK and ResourceSaver.save(packed, path) == OK, "create standalone animated model fixture")
		actor.free()
		var digest := FileAccess.get_sha256(path)
		originals[identity] = models[identity].duplicate(true)
		models[identity].sha256 = digest
		models[identity].previous_sha256 = []
		entries.append({"species": identity.trim_suffix("@shiny"), "variant": "shiny" if identity.ends_with("@shiny") else "normal",
			"runtime_schema": 1, "runtime_path": path, "runtime_sha256": digest, "bytes": FileAccess.get_file_as_bytes(path).size()})
	var catalog := ProjectSettings.globalize_path(FIXTURE.path_join("catalog.json"))
	var file := FileAccess.open(catalog, FileAccess.WRITE)
	file.store_string(JSON.stringify(entries))
	file.close()
	return catalog

func _active(side: String, species: String, shiny: bool) -> Dictionary:
	return {"ident": side + "a: " + species, "details": species + ", L100" + (", shiny" if shiny else ""),
		"species": species, "shiny": shiny, "condition": "100/100", "hp": 100, "maxHp": 100, "active": true}

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("FAIL " + message)
