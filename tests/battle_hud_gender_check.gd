extends SceneTree

const HUD_SCENE := preload("res://scenes/battle/pokemon_hud_panel.tscn")
const MALE_ICON := preload("res://assets/gender/male.png")
const FEMALE_ICON := preload("res://assets/gender/female.png")

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var hud := HUD_SCENE.instantiate()
	root.add_child(hud)
	await process_frame

	var rows: Array = hud.get("active_info_rows")
	var gender_icon := rows[0].get_node_or_null(
		"MarginContainer/VBoxContainer/TopRow/NameContainer/GenderIcon"
	) as TextureRect
	_check(gender_icon != null, "Battle HUD exposes its gender icon")
	if gender_icon != null:
		_check_gender(hud, gender_icon, "M", MALE_ICON, "male Showdown value")
		_check_gender(hud, gender_icon, "female", FEMALE_ICON, "normalized female value")
		_check_gender(hud, gender_icon, "♂", MALE_ICON, "male symbol value")

		hud.call("set_pokemon_data", "Magnemite", 5, 18, 18, "", "N")
		_check(not gender_icon.visible, "Genderless Pokémon hide the gender icon")
		_check(gender_icon.texture == null, "Hidden gender icon clears its previous texture")

	hud.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check_gender(
	hud: Node,
	gender_icon: TextureRect,
	gender: String,
	expected_texture: Texture2D,
	label: String
) -> void:
	hud.call("set_pokemon_data", "Abra", 5, 18, 18, "", gender)
	_check(gender_icon.visible, "%s is visible" % label)
	_check(gender_icon.texture == expected_texture, "%s uses the correct artwork" % label)
	_check(gender_icon.modulate.is_equal_approx(Color.WHITE), "%s keeps its original color" % label)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
