extends SceneTree
## The Android bounds fallback must work even when native pose baking is invalid.
const Stage = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
var failures := 0

class ErrorSink extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING: errors.append(code + " " + rationale)

func _init() -> void:
	# Android guard only: omitting mobile keeps update/music services offline.
	ProjectSettings.set_setting("_custom_features", "android,android_3d_experimental")
	_run.call_deferred()

func _run() -> void:
	var sink := ErrorSink.new()
	OS.add_logger(sink)
	var stage := Stage.new()
	var world := Node3D.new()
	root.add_child(world)
	stage.world = world
	var actor := Node3D.new()
	world.add_child(actor)
	actor.position = Vector3(4, 1, -2)
	actor.scale = Vector3.ONE * 2
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = Vector3(2, 4, 6)
	mesh.mesh = shape
	mesh.position.y = 2
	# A skin with no registered skeleton would fail in the native baker; the
	# fallback only needs stored AABBs, and must never enter that native method.
	mesh.skin = Skin.new()
	actor.add_child(mesh)
	var hidden := MeshInstance3D.new()
	hidden.mesh = BoxMesh.new()
	hidden.scale = Vector3.ONE * 100
	hidden.visible = false
	actor.add_child(hidden)
	stage.actors[0] = actor
	stage.identities[0] = "android-bounds-fixture"
	var bounds: Dictionary = stage._effect_bounds(0)
	_check(bounds.position.is_equal_approx(Vector3(4, 1, -2)), "mesh transforms and actor placement own the effect base")
	_check(is_equal_approx(bounds.height, 8.0) and is_equal_approx(bounds.radius, 6.6), "stored mesh bounds retain dimensions without including hidden meshes")
	_check(bounds.half_extents.is_equal_approx(Vector3(2, 4, 6)), "contact clearance retains all three extents")
	actor.scale = Vector3.ONE * 3
	bounds = stage._effect_bounds(0)
	_check(is_equal_approx(bounds.height, 12.0), "cached model units still apply the current live scale")
	stage.visual_bounds[stage.identities[0]] = {"idle": {"min": [-0.5, 0, -0.5], "size": [1, 1, 1]}}
	bounds = stage._effect_bounds(0)
	_check(is_equal_approx(bounds.height, 3.0), "reviewed idle bounds take precedence over the fallback")
	_check(sink.errors.is_empty(), "Android bounds never invoke invalid native pose baking: %s" % str(sink.errors))
	stage.free()
	world.free()
	OS.remove_logger(sink)
	print("ANDROID_3D_MOVE_BOUNDS_CHECK ", "PASS" if failures == 0 else "FAIL")
	quit(failures)

func _check(ok: bool, reason: String) -> void:
	if not ok:
		failures += 1
		push_error(reason)
