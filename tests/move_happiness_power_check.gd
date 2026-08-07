extends SceneTree

const MoveHoverCardScript := preload("res://scripts/battle/battle_ui/move_hover_card.gd")

var failures: Array[String] = []

func _init() -> void:
	_check_power("frustration", 0, 102)
	_check_power("frustration", 255, 1)
	_check_power("return", 0, 1)
	_check_power("return", 255, 102)
	_check_power("return", 128, 51)
	_check_power("close-combat", 0, 120, 120)
	_check_power_without_happiness("frustration", 0)

	if failures.is_empty():
		print("Move happiness power checks passed")
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
	quit(0)


func _check_power(move_id: String, happiness: int, expected: int, base_power: int = 0) -> void:
	var move_data := {"id": move_id, "basePower": base_power, "pokemonHappiness": happiness}
	var actual: int = MoveHoverCardScript.effective_base_power(move_data)
	if actual != expected:
		failures.append("%s at happiness %d: expected %d, got %d" % [move_id, happiness, expected, actual])


func _check_power_without_happiness(move_id: String, expected: int) -> void:
	var actual: int = MoveHoverCardScript.effective_base_power({"id": move_id, "basePower": 0})
	if actual != expected:
		failures.append("%s without happiness: expected %d, got %d" % [move_id, expected, actual])
