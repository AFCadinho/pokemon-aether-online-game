extends SceneTree

const ModifierService = preload("res://scripts/battle/held_item_stat_modifier_service.gd")

var failures := 0

func _init() -> void:
	_check_equal(
		ModifierService.effective_stats({"atk": 315, "spa": 212, "spe": 295}, "Choice Scarf", "Samurott-Hisui"),
		{"atk": 315, "spa": 212, "spe": 442},
		"Choice Scarf boosts only Speed with Showdown-style flooring"
	)
	_check_equal(
		ModifierService.effective_stats({"atk": 201, "spa": 199, "spe": 150}, "choice-band", "Garchomp"),
		{"atk": 301, "spa": 199, "spe": 150},
		"Choice Band boosts Attack"
	)
	_check_equal(
		ModifierService.effective_stats({"atk": 101, "spa": 201, "spd": 180}, "Choice Specs", "Gholdengo"),
		{"atk": 101, "spa": 301, "spd": 180},
		"Choice Specs boosts Special Attack"
	)
	_check_equal(
		ModifierService.effective_stats({"atk": 100, "spa": 100, "spe": 100}, "Leftovers", "Pikachu"),
		{"atk": 100, "spa": 100, "spe": 100},
		"non-stat held items leave stats unchanged"
	)
	_check_equal(
		ModifierService.effective_stats({"atk": 100, "spa": 100}, "Light Ball", "Pikachu"),
		{"atk": 200, "spa": 200},
		"species-specific Light Ball modifier is restricted to Pikachu"
	)
	_check_equal(
		ModifierService.effective_stats({"atk": 100, "spa": 100}, "Light Ball", "Raichu"),
		{"atk": 100, "spa": 100},
		"species-specific item does not leak to evolved species"
	)
	print("PASS held_item_stat_modifier_check" if failures == 0 else "FAIL held_item_stat_modifier_check")
	quit(1 if failures > 0 else 0)

func _check_equal(actual: Dictionary, expected: Dictionary, label: String) -> void:
	if actual == expected:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s: expected %s, got %s" % [label, expected, actual])
