extends SceneTree
## Offline native-render probe: public synthetic actors, actual move effects.
const Marker := "user://android-move-shader-marker.json"
var fixture: Node
var stage: Node
var completed_moves: Array[String] = []
class ErrorSink extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING: errors.append(code + " " + rationale)
var sink := ErrorSink.new()

func _init() -> void:
	ProjectSettings.set_setting("_custom_features", "android,android_3d_experimental")
	_run.call_deferred()

func _mark(move: String, phase: String) -> void:
	var file := FileAccess.open(Marker, FileAccess.WRITE)
	file.store_string(JSON.stringify({"move": move, "phase": phase, "completed": completed_moves}))
	file.close()
	print("ANDROID_MOVE_SHADER_MARKER ", move, " ", phase)

func _run() -> void:
	OS.add_logger(sink)
	fixture = load("res://tests/fixtures/android_move_shader_stage_fixture.gd").new()
	# Do not run the fixture's own suite; use its actual production stage setup.
	root.add_child(fixture)
	fixture._setup()
	stage = fixture.stage
	fixture.set_process(false)
	var light := DirectionalLight3D.new()
	stage.world.add_child(light)
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.shadow_enabled = true
	_mark("setup", "draw")
	await process_frame
	for move: String in stage.MoveEffect.KEYS:
		_mark(move, "create")
		stage.start_move_action("p1", move)
		stage.players[0].pause()
		var effect: Node = stage.create_move_effect(move, "p1", "p2", {"show_impact": true})
		assert(effect != null)
		effect.set_process(false)
		for point: float in [0.0, effect.launch + 0.02, effect.impact + 0.04]:
			_mark(move, "draw_%.3f" % point)
			stage.players[0].seek(point, true)
			effect._process(0.0)
			await process_frame
			if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
			await process_frame
		effect.cancel()
		await process_frame
		completed_moves.append(move)
		_mark(move, "complete")
	_mark("all", "complete")
	fixture.queue_free()
	await process_frame
	OS.remove_logger(sink)
	if not sink.errors.is_empty():
		print("ANDROID_MOVE_SHADER_CHECK FAIL ", sink.errors)
		quit(1)
		return
	print("ANDROID_MOVE_SHADER_CHECK PASS moves=", completed_moves.size())
	quit()
