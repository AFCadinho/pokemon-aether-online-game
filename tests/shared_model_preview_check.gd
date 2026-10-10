extends SceneTree
const Preview = preload("res://scripts/ui/pokedex_model_preview.gd")
const Summary = preload("res://scripts/ui/summary_model_preview.gd")
var failures: Array[String] = []
class Sink extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			errors.append(code + " " + rationale)
var sink := Sink.new()

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	OS.add_logger(sink)
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(1)
		return
	OS.set_environment("POKEAETHER_SHARED_MODEL_PILOT", "1")
	OS.set_environment("POKEAETHER_MODEL_PAIR_PACKS", args[0])
	var settings := root.get_node("SettingsManager")
	settings.battle_3d_catalog_path = ""
	OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	var cases := 0
	for kind in ["pokedex", "summary"]:
		var preview: Control = Preview.new() if kind == "pokedex" else Summary.new()
		preview.size = Vector2(380, 276)
		root.add_child(preview)
		for species in ["Pikachu", "Magnemite"]:
			for shiny in [false, true]:
				if not preview.show_species(species, shiny):
					failures.append("Preview starts: " + species)
				var deadline := Time.get_ticks_msec() + 30000
				while (preview.is_loading() or preview.actor == null) and Time.get_ticks_msec() < deadline:
					await process_frame
				if preview.actor == null or preview.player == null:
					failures.append("Loaded " + kind + ": " + species)
				else:
					if not preview.player.has_animation("idle"):
						failures.append("Authored preview animations retained")
					cases += 1
				preview._clear_actor()
				await process_frame
		# A canceled asynchronous pack check must never reveal the old request.
		preview.show_species("Palkia", false)
		preview.show_species("Pikachu", true)
		var deadline := Time.get_ticks_msec() + 30000
		while preview.is_loading() and Time.get_ticks_msec() < deadline:
			await process_frame
		if preview.actor == null or preview.requested_key != "pikachu@shiny":
			failures.append("Canceled preview cannot reveal an old model")
		preview.queue_free()
		await process_frame
		await process_frame
	if cases != 8:
		failures.append("Expected eight normal/shiny preview cases")
	if not sink.errors.is_empty():
		failures.append_array(sink.errors)
	print("SHARED_MODEL_PREVIEW_CHECK ", "OK" if failures.is_empty() else "FAILED", " cases=", cases, " errors=", failures)
	quit(0 if failures.is_empty() else 1)
