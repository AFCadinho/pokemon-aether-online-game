extends SceneTree

const BATTLE_PATH := "res://scripts/battle/battle.gd"

var failed := false


func _init() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_PATH)
	_check_true(source.contains('"statStage":\n\t\t\t_apply_stat_stage_operation_event(event)'), "battle applies authoritative stat-stage operations")
	_check_true(source.contains('operation == "clearAll"'), "Haze can clear both sides")
	_check_true('"clearPositive"' in source and '"set"' in source and '"invert"' in source and '"swap"' in source, "all public Showdown stat operations are handled")
	_check_true(source.contains("func _stat_stage_operation_stats"), "stat swaps preserve their scoped stat list")
	quit(1 if failed else 0)


func _check_true(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
