extends SceneTree

const BATTLE := preload("res://scripts/battle/battle_ui/battle_player_trainer_catalog.gd")
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var outfits: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/male_adventure_outfits.json"))
	for outfit: Dictionary in outfits:
		for gender: String in ["male", "female"]:
			_check_outfit(outfit, gender)
	quit(1 if failed else 0)

func _check_outfit(outfit: Dictionary, gender: String) -> void:
	var parts: Dictionary = outfit["parts"]
	var appearance: Dictionary = parts.duplicate()
	appearance["gender"] = gender
	appearance["body"] = "Gen4_Base_F_v1" if gender == "female" else "Gen4_Base_v1"
	appearance["hair"] = "Hair"
	var layers: Array[Dictionary] = BATTLE.build_layers(appearance)
	for category: String in parts:
		var found := false
		for layer: Dictionary in layers:
			if str(layer.get("category")) != category:
				continue
			var texture := layer.get("texture") as Texture2D
			var expected := "res://assets/battles/trainers/player/%s/adventure_outfits/%s/%s.png" % [gender, outfit["slug"], category]
			found = str(layer.get("part_id")) == parts[category] and not bool(layer.get("fallback", true)) and texture != null and texture.resource_path == expected and texture.get_size() == Vector2(160, 160) and is_equal_approx(float(layer.get("scale", 0)), 1.0)
		_check(found, "%s %s %s resolves authored trainer art" % [outfit["name"], gender, category])
	var image := Image.create(160, 160, false, Image.FORMAT_RGBA8)
	for layer: Dictionary in layers:
		var texture := layer.get("texture") as Texture2D
		if texture == null:
			continue
		var part := texture.get_image()
		part.convert(Image.FORMAT_RGBA8)
		image.blend_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), Vector2i.ZERO)
	_check(image.save_png("user://%s_%s_trainer_check.png" % [outfit["slug"], gender]) == OK, "trainer composite saved")
	var portrait := BATTLE.build_dialogue_portrait(appearance)
	_check(portrait != null and portrait.get_size() == Vector2(160, 160), "dialogue portrait uses the new trainer layers")
	var mirrored := image.duplicate() as Image
	mirrored.flip_x()
	_check(portrait != null and portrait.get_image().get_data() == mirrored.get_data(), "dialogue portrait preserves the correctly mirrored outfit")

func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		failed = true
		push_error("FAIL " + label)
