extends SceneTree

const Resolver := preload("res://scripts/battle/ogerpon_battle_form.gd")

var failed := false


func _init() -> void:
	_check_wellspring_form()
	_check_other_masks()
	_check_base_form()
	_check_non_ogerpon_is_untouched()
	_check_ivy_cudgel_type_is_battle_only()
	_check_mask_battle_sprites_are_available()
	_check_front_battle_sprite_scale()
	_check_initial_battle_setup_uses_mask_form()
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


func _check_mask_battle_sprites_are_available() -> void:
	var battle_species := {
		"Ogerpon": "ogerpon",
		"Ogerpon Wellspring": "ogerpon-wellspring",
		"Ogerpon Hearthflame": "ogerpon-hearthflame",
		"Ogerpon Cornerstone": "ogerpon-cornerstone",
	}
	for species: String in battle_species:
		var asset_id := str(battle_species[species])
		_check_equal(
			PokemonAssets.get_battle_sprite_ids(species).has(asset_id),
			true,
			"%s resolves to its canonical battle asset" % species
		)
		for side: String in ["front", "back"]:
			var texture := PokemonAssets.load_texture(
				"res://assets/sprites/pokemon/%s/%s/frame_000.png" % [side, asset_id]
			)
			var expected_size := Vector2(192, 192) if side == "front" else Vector2(288, 288)
			_check_equal(
				texture.get_size() if texture != null else Vector2.ZERO,
				expected_size,
				"%s uses the Gen 9 %s battle asset instead of a HOME fallback" % [species, side]
			)


func _check_front_battle_sprite_scale() -> void:
	var sprite_box_source := FileAccess.get_file_as_string(
		"res://scripts/battle/battle_ui/sprite_box.gd"
	)
	_check_equal(
		sprite_box_source.contains("func _apply_species_render_scale_override(")
		and sprite_box_source.contains('side.strip_edges().to_lower() != "front"')
		and sprite_box_source.contains('_normalize_species_asset_id(species).begins_with("ogerpon")')
		and sprite_box_source.contains("_set_sprite_frames_render_scale(sprite_frames, 2.0)"),
		true,
		"the 192 px Ogerpon front sheet renders at its authored 2x scale"
	)


func _check_initial_battle_setup_uses_mask_form() -> void:
	var battle_source := FileAccess.get_file_as_string("res://scripts/battle/battle.gd")
	_check_equal(
		battle_source.contains("func _get_saved_pokemon_battle_boundary_species("),
		true,
		"battle setup exposes a held-mask boundary resolver"
	)
	_check_equal(
		battle_source.count("_get_saved_pokemon_battle_boundary_species(") >= 5,
		true,
		"wild and trainer setup resolve Ogerpon before their first sprite render"
	)
	_check_equal(
		battle_source.contains('player_sprite_box.set_single_pokemon(player_pokemon, "back")'),
		false,
		"initial setup never renders the saved base Ogerpon before resolving its mask"
	)
	_check_equal(
		battle_source.count('"-wellspring", "-hearthflame", "-cornerstone"') >= 2,
		true,
		"PvP ident repair preserves Ogerpon mask formes for the active back sprite"
	)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
