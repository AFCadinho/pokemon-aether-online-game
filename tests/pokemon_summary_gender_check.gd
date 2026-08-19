extends SceneTree

const GENDER_DISPLAY := preload("res://scripts/ui/pokemon_gender_display.gd")
const UI_OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"
const UI_OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_gender("male", true, "♂", Color("#62d7ff"), "male gender")
	_check_gender("FEMALE", true, "♀", Color("#ff82ba"), "female gender is case-insensitive")
	_check_gender("m", true, "♂", Color("#62d7ff"), "short male gender")
	_check_gender("♀", true, "♀", Color("#ff82ba"), "female symbol input")
	_check_gender("genderless", false, "", Color.WHITE, "genderless Pokémon")
	_check_gender("", false, "", Color.WHITE, "missing gender")
	_check_summary_card_wiring()
	await _check_interactive_name_layout()

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


func _check_interactive_name_layout() -> void:
	var packed := load(UI_OVERLAY_SCENE_PATH) as PackedScene
	_check(packed != null, "interactive summary scene loads")
	if packed == null:
		return

	var overlay := packed.instantiate()
	var host := Control.new()
	host.size = Vector2(1280, 720)
	root.add_child(host)
	overlay.set("root_control", host)
	overlay.call("_setup_pokemon_summary_popup", "gender-layout-check")
	var popup := overlay.get("pokemon_summary_popup") as PanelContainer
	if popup != null:
		popup.visible = true

	var name_label := overlay.get("pokemon_summary_title_label") as Label
	var gender_label := overlay.get("pokemon_summary_gender_label") as Label
	_check(name_label != null, "interactive summary exposes its Pokémon name label")
	_check(gender_label != null, "interactive summary exposes its gender label")
	if name_label != null and gender_label != null:
		name_label.text = "Alakazam"
		overlay.call("_apply_pokemon_summary_gender_label", gender_label, "male")
		await process_frame
		await process_frame
		_check(name_label.size.x >= 50.0, "Pokémon name keeps visible layout width")
		_check(gender_label.visible and gender_label.text == "♂", "gender symbol remains visible")
		var name_right := name_label.position.x + name_label.size.x
		var gender_gap := gender_label.position.x - name_right
		_check(
			gender_label.position.x >= name_right
				and gender_gap <= 8.0,
			"gender symbol stays directly beside the Pokémon name (gap=%s name_pos=%s name_size=%s gender_pos=%s)" % [
				gender_gap,
				name_label.position,
				name_label.size,
				gender_label.position,
			]
		)

	for loader_property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader := overlay.get(loader_property) as Node
		if loader != null:
			loader.free()
	overlay.free()
	host.queue_free()
	await process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return

	failures += 1
	push_error("FAIL: %s" % label)
