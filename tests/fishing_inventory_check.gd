extends SceneTree

const FishingRodRulesScript := preload("res://scripts/services/fishing_rod_rules.gd")

var failed := false


func _init() -> void:
	_check_equal(FishingRodRulesScript.resolve_tier([]), 0, "no rod disables fishing")
	_check_equal(
		FishingRodRulesScript.resolve_tier([
			{"itemId": "old-rod", "quantity": 1},
			{"itemId": "potion", "quantity": 10},
		]),
		1,
		"Old Rod grants tier one"
	)
	_check_equal(
		FishingRodRulesScript.resolve_tier([
			{"itemId": "old-rod", "quantity": 1},
			{"itemId": "good-rod", "quantity": 1},
			{"itemId": "super-rod", "quantity": 0},
		]),
		2,
		"highest owned positive-quantity rod wins"
	)
	_check_equal(
		FishingRodRulesScript.resolve_tier([
			{"itemId": "super-rod", "quantity": 1},
		]),
		3,
		"Super Rod grants tier three"
	)
	quit(1 if failed else 0)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failed = true
	push_error("%s expected=%s actual=%s" % [label, str(expected), str(actual)])
