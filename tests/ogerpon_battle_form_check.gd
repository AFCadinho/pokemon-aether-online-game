extends SceneTree

const Resolver := preload("res://scripts/battle/ogerpon_battle_form.gd")

var failed := false


func _init() -> void:
	_check_wellspring_form()
	_check_other_masks()
	_check_base_form()
	_check_non_ogerpon_is_untouched()
	_check_ivy_cudgel_type_is_battle_only()
	_check_wellspring_sprite_is_available()
	quit(1 if failed else 0)


func _check_wellspring_form() -> void:
	var data := {"species": "Ogerpon", "types": ["grass"], "ability": "defiant"}
	Resolver.apply_to_display_data(data, "Ogerpon", "Wellspring Mask")
	_check_equal(data.get("species"), "Ogerpon Wellspring", "Wellspring Mask selects the Wellspring battle forme")
	_check_equal(data.get("types"), ["grass", "water"], "Wellspring battle display has both types")
	_check_equal(data.get("ability"), "water-absorb", "Wellspring battle display has Water Absorb")


func _check_other_masks() -> void:
	_check_equal(
		Resolver.resolve_species("Ogerpon", "Hearthflame Mask"),
		"Ogerpon Hearthflame",
		"Hearthflame Mask selects the Hearthflame battle forme"
	)
	_check_equal(
		Resolver.resolve_species("Ogerpon", "Cornerstone Mask--held"),
		"Ogerpon Cornerstone",
		"held-item storage suffix is accepted for Cornerstone Mask"
	)


func _check_base_form() -> void:
	_check_equal(Resolver.resolve_species("Ogerpon"), "Ogerpon", "unmasked Ogerpon stays in its base forme")


func _check_non_ogerpon_is_untouched() -> void:
	_check_equal(
		Resolver.resolve_species("Landorus-Therian", "Rocky Helmet"),
		"Landorus-Therian",
		"other Pokemon are untouched"
	)


func _check_ivy_cudgel_type_is_battle_only() -> void:
	var source_moves := [{"id": "ivycudgel", "name": "Ivy Cudgel", "type": "grass"}]
	var battle_moves := Resolver.apply_ivy_cudgel_type(source_moves, "Ogerpon", "Wellspring Mask")
	_check_equal(battle_moves[0].get("type"), "water", "Wellspring Ivy Cudgel displays as Water")
	_check_equal(source_moves[0].get("type"), "grass", "the saved move metadata remains unchanged")


func _check_wellspring_sprite_is_available() -> void:
	_check_equal(
		PokemonAssets.load_home_sprite("Ogerpon-Wellspring") != null,
		true,
		"Wellspring battle display has a form-specific sprite fallback"
	)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
