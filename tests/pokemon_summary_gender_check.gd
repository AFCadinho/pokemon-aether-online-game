extends SceneTree

const GENDER_DISPLAY := preload("res://scripts/ui/pokemon_gender_display.gd")
const UI_OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"

var failures := 0


func _init() -> void:
	_check_gender("male", true, "♂", Color("#62d7ff"), "male gender")
	_check_gender("FEMALE", true, "♀", Color("#ff82ba"), "female gender is case-insensitive")
	_check_gender("m", true, "♂", Color("#62d7ff"), "short male gender")
	_check_gender("♀", true, "♀", Color("#ff82ba"), "female symbol input")
	_check_gender("genderless", false, "", Color.WHITE, "genderless Pokémon")
	_check_gender("", false, "", Color.WHITE, "missing gender")
	_check_summary_card_wiring()

	if failures == 0:
		print("Pokemon summary gender checks passed.")
		quit(0)
		return

	push_error("Pokemon summary gender checks failed: %d" % failures)
	quit(1)


func _check_gender(
	gender: String,
	expected_visible: bool,
	expected_symbol: String,
	expected_color: Color,
	label: String
) -> void:
	var result: Dictionary = GENDER_DISPLAY.presentation(gender)
	_check(bool(result.get("visible", false)) == expected_visible, "%s visibility" % label)
	_check(str(result.get("symbol", "")) == expected_symbol, "%s symbol" % label)
	_check((result.get("color", Color.TRANSPARENT) as Color).is_equal_approx(expected_color), "%s color" % label)


func _check_summary_card_wiring() -> void:
	var source := FileAccess.get_file_as_string(UI_OVERLAY_PATH)
	_check(
		source.contains("title_row.add_child(pokemon_summary_gender_label)"),
		"summary places gender in the Pokémon name row"
	)
	_check(
		source.contains("_apply_pokemon_summary_gender_label(pokemon_summary_gender_label, pokemon.gender)"),
		"summary refreshes the gender label"
	)
	_check(
		source.contains('"gender_label": pokemon_summary_gender_label if mode == "interactive" else null'),
		"multi-card summary context retains its gender label"
	)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return

	failures += 1
	push_error("FAIL: %s" % label)
