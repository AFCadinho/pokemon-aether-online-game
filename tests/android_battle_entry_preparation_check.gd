extends "res://tests/early_3d_arena_check.gd"
var Entry: Script
class LocalModels extends Node:
	var catalog := ""
	func ensure_models(_identities: Array[String], _source: String) -> Dictionary:
		return {"error": "", "path": catalog, "catalog_changed": true}
	func progress_text() -> String: return ""
	func battle_download_progress() -> Dictionary: return {}

func _init() -> void:
	ProjectSettings.set_setting("_custom_features", "mobile,android,android_3d_experimental,android_3d_move_warmup")
	super._init()

func _run() -> void:
	Entry = load("res://tests/fixtures/android_battle_entry_trial.gd")
	create_timer(120).timeout.connect(func(): quit(1))
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_ui_layout = "immersive"
	settings.battle_3d_catalog_path = ""
	settings.battle_3d_arena = "stadium"
	settings.android_3d_idle_camera_motion = false
	settings.android_3d_move_camera = false
	root.get_node("Android3DEnvironmentService").verified = true
	var original := root.get_node("OnDemand3DBundleService")
	root.remove_child(original)
	var local := LocalModels.new()
	local.name = "OnDemand3DBundleService"
	local.catalog = _make_fixture()
	root.add_child(local)
	var pool := Pool.prepare(root, "", root.size, "stadium")
	while not pool.ready_for_battle and not pool.failed: await process_frame
	_check(pool.ready_for_battle, "real stadium pool prepared")
	for kind in Entry.CASES + ["late_moves_wild"]:
		var trial: RefCounted = Entry.new()
		await trial.mount(self, kind, "Dragonite", "Garchomp", true)
		_check(trial.stage.android_move_preparation_enabled(), "real Android/Mobile trial gate enabled")
		var row: Dictionary = await trial.finish(self)
		print("ENTRY_CASE ", JSON.stringify(row))
		_check(trial.errors.is_empty() and row.ready, "normal intro is ready: " + kind)
		_check(row.available_keys == Entry.MOVE_KEYS, "authoritative request supplied real move IDs: " + kind)
		_check(row.input_held_during_preparation and row.samples_hidden, "preparation preserves input/visibility: " + kind)
		for key in Entry.MOVE_KEYS:
			_check(row.prepared.has(key), "own move was prepared before first turn: " + kind + "/" + key)
		if kind == "early_wild": _check(row.early_visible_before_response, "early arena revealed before response")
		if kind == "preview_trainer":
			_check(row.previews_have_no_casts and row.selected_slot == 2, "real preview input selected changed lead without warming guessed moves")
			_check(row.actors[0] == "garchomp@shiny", "chosen lead supplies actual casting actor")
		if row.prepared.has("rockslide"):
			trial.stage.start_move_action("p1", "Rock Slide")
			var effect: Node = trial.stage.create_move_effect("Rock Slide", "p1", "p2", {"show_impact": true})
			_check(effect.get_instance_id() == row.prepared.rockslide, "real factory consumes the entry preparation")
			effect.cancel()
			var round_count: int = trial.stage.android_move_preparation_metrics.rounds.size()
			await trial.stage.prepare_android_move_effects(trial.battle.battle_state.get_available_moves("p1"))
			_check(not trial.stage.android_move_warmup.retained.has("rockslide") and trial.stage.android_move_preparation_metrics.rounds.size() == round_count, "same request neither extends budget nor refills consumed effects")
		trial.close()
		await process_frame
		_check(pool.borrower == null, "entry releases shared arena")
	await _check_warm_cancellation(false)
	await _check_warm_cancellation(true)
	pool.free()
	local.free()
	root.add_child(original)
	var models: Dictionary = Registry.DATA.data.models
	for identity in originals: models[identity] = originals[identity]
	Cache.clear()
	print("ANDROID_BATTLE_ENTRY_PREPARATION_", "FAIL" if failed else "OK", " actual_host=true actual_requests=true covered=true early=true preview_changed_lead=true cancellation=true")
	quit(1 if failed else 0)

func _check_warm_cancellation(late: bool) -> void:
	var trial: RefCounted = Entry.new()
	await trial.mount(self, "late_moves_wild" if late else "covered_wild", "Dragonite", "Garchomp", true)
	var deadline := Time.get_ticks_msec() + 10000
	while (not trial.stage.android_move_warmup.busy or (late and not trial.host.preparation_ready)) and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(trial.stage.android_move_warmup.busy, "cancel while normal host warms effects")
	var stage: Control = trial.stage
	trial.host.release()
	for i in 4: await process_frame
	_check(stage.preparation_cancelled and not stage.android_move_warmup.busy and stage.android_move_warmup.retained.is_empty(), "release cancels preparations without first-turn input")
	_check(not trial.battle.battle_actions_ready, "cancelled intro cannot enable actions")
	if not late: _check(not trial.host.preparation_ready, "cancelled host stays unready")
	trial.close()
	await process_frame
