extends SceneTree

const NpcDialogueServiceScript := preload("res://scripts/services/npc_dialogue_service.gd")
const MATEO_PATH := "res://scripts/world/kanto/towns/ev_training_expert_mateo.gd"
const GIDEON_PATH := "res://scripts/world/kanto/towns/catching_mentor_gideon.gd"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var inferred_fallback: Array = ["Fallback dialogue"]

	var service: Node = NpcDialogueServiceScript.new()
	var service_lines: Array[String] = await service.resolve_lines(
		"",
		inferred_fallback,
		"ArrayTypingCheck"
	)
	_check(service_lines == ["Fallback dialogue"], "central resolver accepts an inferred Array")
	service.free()

	var mateo_source := FileAccess.get_file_as_string(MATEO_PATH)
	_check(
		mateo_source.contains("func _resolve_lines(dialogue_id: String, fallback: Array)"),
		"Mateo accepts an inferred fallback Array"
	)

	var gideon_source := FileAccess.get_file_as_string(GIDEON_PATH)
	_check(
		gideon_source.contains("func _resolve_dialogue_lines(dialogue_id: String, fallback: Array)"),
		"Gideon accepts an inferred fallback Array"
	)

	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
