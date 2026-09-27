extends SceneTree

const APPEARANCE := preload("res://scripts/services/character_appearance_service.gd")
const BATTLE := preload("res://scripts/battle/battle_ui/battle_player_trainer_catalog.gd")
const SETS := {
	"male": {
		"top": "AetherWayfarer_Male_Shirt",
		"bottom": "AetherWayfarer_Male_Trousers",
		"shoes": "AetherWayfarer_Male_Shoes",
	},
	"female": {
		"top": "AetherWayfarer_Female_Shirt",
		"bottom": "AetherWayfarer_Female_Trousers",
		"shoes": "AetherWayfarer_Female_Shoes",
	},
}
var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for gender: String in SETS:
		var parts: Dictionary = SETS[gender]
		var other_gender := "female" if gender == "male" else "male"
		for category: String in parts:
			var part_id := str(parts[category])
			_check(APPEARANCE.get_available_part_ids(category, gender).has(part_id), "%s is registered for %s" % [part_id, gender])
			_check(not APPEARANCE.get_available_part_ids(category, other_gender).has(part_id), "%s stays %s-only" % [part_id, gender])
			_check(not APPEARANCE.is_free_part_id(category, part_id), "%s is a cosmetic unlock" % part_id)
			for movement: String in ["walk", "fish", "ride"]:
				var suffix := "fish" if movement == "fish" else ("ride" if movement == "ride" else "")
				var frames: SpriteFrames = APPEARANCE.get_part_frames(category, part_id, gender, movement)
				_check(frames != null, "%s loads %s frames" % [part_id, movement])
				if frames == null:
					continue
				var expected := "res://assets/player/%s/%s/%s%s%s.png" % [gender, category, suffix + "/" if suffix != "" else "", part_id, "_" + suffix if suffix != "" else ""]
				for direction: String in ["down", "left", "right", "up"]:
					var animation := StringName("walk_" + direction)
					_check(frames.get_frame_count(animation) == 4, "%s %s %s has four frames" % [part_id, movement, direction])
					var atlas := frames.get_frame_texture(animation, 0) as AtlasTexture
					_check(atlas != null and atlas.atlas.resource_path == expected, "%s %s resolves its authored sheet" % [part_id, movement])
			var trainer_appearance := {"gender": gender, "top": parts["top"], "bottom": parts["bottom"], "shoes": parts["shoes"]}
			var resolved := {}
			for layer: Dictionary in BATTLE.build_layers(trainer_appearance):
				resolved[str(layer.get("category"))] = layer
			var battle_layer: Dictionary = resolved.get(category, {})
			var texture := battle_layer.get("texture") as Texture2D
			_check(str(battle_layer.get("part_id", "")) == part_id and texture != null and texture.get_size() == Vector2(160, 160), "%s resolves the trainer sprite" % part_id)
	for gender: String in SETS:
		for item_type: String in ["outfit", "shirt", "trousers", "shoes"]:
			var item_id := "aether-wayfarer-%s-%s" % [gender, item_type]
			_check(APPEARANCE.get_cosmetic_item_allowed_genders(item_id) == [gender], "%s is gender-locked" % item_id)
			var icon := APPEARANCE.get_cosmetic_item_icon(item_id, "male" if gender == "female" else "female")
			_check(icon != null and icon.get_image().get_used_rect().has_area(), "%s has a visible bag icon" % item_id)
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/items/%s.json" % locale))
		for gender: String in SETS:
			for item_type: String in ["outfit", "shirt", "trousers", "shoes"]:
				_check(catalog.has("aether-wayfarer-%s-%s" % [gender, item_type]), "%s has %s item text" % [locale, item_type])
	var store_source := FileAccess.get_file_as_string("res://scripts/ui/donator_store_popup.gd")
	_check(not store_source.contains("aether-wayfarer-"), "Wayfarer outfit boxes are absent from the store")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failed = true
		push_error("FAIL %s" % label)
