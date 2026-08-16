extends SceneTree

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var mentor_script := load(
		"res://scripts/world/kanto/towns/thieving_mentor_rook.gd"
	) as Script
	_check(
		mentor_script != null and mentor_script.can_instantiate(),
		"Rook's turn-in reward flow compiles"
	)
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
