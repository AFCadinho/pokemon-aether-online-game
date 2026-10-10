extends SceneTree
## Actual presenter, threaded loader and LRU: normal/shiny switches and repeated battles.
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Cache = preload("res://scripts/battle/battle_ui/model_resource_cache.gd")
const Pair = preload("res://scripts/services/model_pair_pack.gd")
const Pilot = preload("res://scripts/services/model_pair_pilot.gd")
const Store = preload("res://launcher/scripts/asset_bundle_store.gd")
var failures: Array[String] = []
class Sink extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			errors.append(code + " " + rationale)
var sink := Sink.new()

func _init() -> void:
	_run.call_deferred()

func check(value: bool, reason: String) -> bool:
	if not value:
		failures.append(reason)
		print("SHARED_BATTLE_FAIL ", reason)
	return value

func _run() -> void:
	OS.add_logger(sink)
	var args := OS.get_cmdline_user_args()
	if not check(args.size() == 1, "Pilot pack directory"):
		quit(1)
		return
	OS.set_environment("POKEAETHER_SHARED_MODEL_PILOT", "1")
	OS.set_environment("POKEAETHER_MODEL_PAIR_PACKS", args[0])
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_arena = "classic"
	settings.battle_3d_camera_motion = false
	settings.battle_3d_catalog_path = ""
	OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	OS.unset_environment("POKEAETHER_3D_STAGE_REPORT")
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		root.show()
		root.grab_focus()
	var cases := 0
	for species in ["Pikachu", "Charizard", "Palkia"]:
		Cache.clear()
		var previous_ids := {}
		for round_number in 3:
			var stage := Renderer.new()
			root.add_child(stage)
			stage.setup()
			stage.set_combatant(0, species, false)
			stage.set_combatant(1, species, true)
			await stage.await_prepared(true, 45000)
			if not check(stage.active and not stage.preparation_failed and stage.handles("p1") and stage.handles("p2"), "Preparation: " + species + " " + str(stage.catalog_problem)):
				stage.queue_free()
				await process_frame
				break
			check(stage.model_cache_hits == (0 if round_number == 0 else 2), "Prepared scenes reused on repeated battle")
			for identity: String in stage.packed:
				if previous_ids.has(identity):
					check(previous_ids[identity] == stage.packed[identity].get_instance_id(), "Same prepared scene reused")
				previous_ids[identity] = stage.packed[identity].get_instance_id()
				var entry: Dictionary = stage.entries[identity]
				check(int(entry._cache_source_bytes) == Pair.budget(entry._pair_asset, str(entry.variant)), "Dependencies charged to the LRU")
			check(Cache.order.size() <= 2 and Cache.source_bytes <= Cache.MAX_SOURCE_BYTES, "Existing bounded LRU retained")
			stage.set_sleeping(0, true)
			for frame in 8:
				await process_frame
			stage.set_sleeping(0, false)
			stage.set_combatant(0, species, true)
			stage.set_combatant(1, species, false)
			await stage.await_prepared(true, 45000)
			check(stage.active and not stage.preparation_failed and stage.handles("p1") and stage.handles("p2"), "Normal/shiny swap")
			stage.set_combatant(0, "", false, true)
			for frame in 8:
				await process_frame
			check(stage.handles("p2"), "Remaining variant survives the other actor leaving")
			var before := Pair.mounted.size()
			stage.queue_free()
			await process_frame
			await process_frame
			check(Pair.mounted.size() == before, "Repeated encounters do not mount duplicate packs")
			cases += 1
			print("SHARED_BATTLE_ROUND ", species, " round=", round_number)
		Cache.clear()
	check(cases == 9, "Three species across three complete battles")
	check(Pair.mounted.size() == 3, "Only requested pairs are mounted")
	check(not root.get_node("OnDemand3DBundleService").can_clear_cache(), "Mounted on-demand files are kept until restart")
	if not sink.errors.is_empty():
		failures.append_array(sink.errors)
	print("SHARED_MODEL_BATTLE_CHECK ", "OK" if failures.is_empty() else "FAILED", " rounds=", cases, " errors=", failures)
	quit(0 if failures.is_empty() else 1)
