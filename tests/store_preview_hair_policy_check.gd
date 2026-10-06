extends SceneTree

const POLICY := preload("res://scripts/services/store_preview_appearance_policy.gd")
const APPEARANCE := preload("res://scripts/services/character_appearance_service.gd")
const STORE := preload("res://scenes/interface/donator_store_popup.tscn")
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := POLICY.configuration().duplicate(true)
	_check(config.get("schema_version") == 1, "preview configuration has a version")
	for gender: String in ["male", "female"]:
		var neutral := POLICY.resolve_hair("aether-voyager-outfit", "card", gender, "", false, "", "")
		_check(neutral["hair"] == "Hair", "%s cards use the neutral hair profile" % gender)
		_check(APPEARANCE.get_part_frames("hair", neutral["hair"], gender) != null, "%s neutral profile has authored art" % gender)
		var inherited := POLICY.resolve_hair("aether-voyager-outfit", "detail", gender, "", false, "Adinho_Hair", "#247aca", true)
		_check(inherited["hair"] == "Adinho_Hair" and inherited["hair_color"] == "#247aca", "detail inherits available player hair and colour")
		var fallback := POLICY.resolve_hair("aether-voyager-outfit", "detail", gender, "", false, "WrongModelHair", "#ff0000", false)
		_check(fallback == neutral, "cross-model/missing appearance uses the correct neutral profile")
		var bald := POLICY.resolve_hair("aether-voyager-outfit", "detail", gender, "", false, "", "#247aca", true)
		_check(bald["hair"] == "", "an explicitly bald trainer remains bald")
		var crown := POLICY.resolve_hair("patreon-supporter-preview", "detail", gender, "AetherRoyal_Crown", false, "Adinho_Hair", "#247aca", true)
		_check(crown == neutral, "crown compatibility uses restrained neutral hair")

	config["outfits"]["fixture-outfit"] = {"card": "hidden", "detail": "hidden"}
	var hidden := POLICY.resolve_hair("fixture-outfit", "detail", "male", "", false, "Hair", "#123456", true, config)
	_check(hidden["hair"] == "", "a specific outfit can hide incompatible hair")
	var included := POLICY.resolve_hair("fixture-outfit", "detail", "male", "Cap", true, "IronFanton_Hair", "#456789", true, config)
	_check(included["hair"] == "IronFanton_Hair" and included["hair_color"] == "#456789", "included hair wins over outfit and headgear exceptions")
	config["outfits"]["fixture-outfit"] = {"detail": "custom", "hair": {"male": {"id": "Aether_Male_Hair_01", "color": "#246abc"}}}
	var custom := POLICY.resolve_hair("fixture-outfit-bound", "detail", "male", "Cap", false, "Hair", "#123456", true, config)
	_check(custom["hair"] == "Aether_Male_Hair_01" and custom["hair_color"] == "#246abc", "per-outfit profile overrides headgear and supports bound aliases")
	var female_custom := POLICY.resolve_hair("fixture-outfit", "detail", "female", "", false, "", "", false, config)
	_check(female_custom["hair"] == "Hair", "a missing custom gender profile never borrows the other model")

	var hood := POLICY.resolve_hair("mysterious-outfit", "detail", "female", "", false, "Aether_Female_Hair_01", "#247aca", true)
	_check(hood["hair"] == "", "the authored full hood prevents tall hair from protruding")

	var layers: Array[Dictionary] = [{"kind": "body"}, {"category": "top", "id": "Mysterious_Shirt"}, {"category": "facegear", "id": "Mysterious_Mask"}]
	var decorated := POLICY.decorate_card_layers("fixture-outfit", "male", layers)
	_check(layers.size() == 3 and decorated.size() == 4, "card styling does not modify product contents")
	_check(decorated[2]["category"] == "hair" and decorated[3]["category"] == "facegear", "hair is below the outfit mask")
	var included_layers: Array[Dictionary] = [{"kind": "body"}, {"category": "hair", "id": "Adinho_Hair"}]
	_check(POLICY.decorate_card_layers("adinho-classic-outfit", "male", included_layers) == included_layers, "cards preserve an included hairstyle")
	var loose: Array[Dictionary] = [{"category": "top", "id": "Adinho_Shirt"}]
	_check(POLICY.decorate_card_layers("adinho-shirt", "male", loose) == loose, "loose item icons do not acquire unrelated hair")

	var store := STORE.instantiate() as DonatorStorePopup
	store.trainer_gender = "male"
	store.trainer_appearance = APPEARANCE.get_default_appearance("male")
	store.trainer_appearance["hair"] = "Aether_Male_Hair_02"
	store.trainer_appearance["hair_color"] = "#247aca"
	store.trainer_appearance["skin_tone"] = "#b87860"
	store.trainer_appearance["eye_color"] = "#4266aa"
	var saved := store.trainer_appearance.duplicate(true)
	root.add_child(store)
	await process_frame
	store.call("_select_category", "cosmetics")
	store.call("_select_cosmetic_subcategory", "outfits")
	store.call("_select_product", "aether-voyager-outfit")
	var state: Dictionary = store.call("_current_character_preview_appearance")
	_check(state["hair"] == "Aether_Male_Hair_02" and state["hair_color"] == "#247aca", "an outfit without hair previews the player's actual hairstyle")
	_check(state["skin_tone"] == "#b87860" and state["eye_color"] == "#4266aa", "preview styling preserves skin and eyes")
	_check((store.call("_selected_purchase_chroma_colors") as Dictionary).is_empty(), "presentation hair never enters checkout colours")
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var localizer := root.get_node("LocalizationManager")
		localizer.set_locale(locale)
		await process_frame
		_check(store.character_preview_note_label.text.contains(localizer.text("ui.store.preview.hair_not_included")), "%s explains hair is not part of the box" % locale)
	store.call("_select_product", "adinho-classic-outfit")
	state = store.call("_current_character_preview_appearance")
	_check(state["hair"] == "Adinho_Hair", "an outfit containing hair replaces the player's style")
	store.call("_select_character_preview_color", "#aa44ff")
	store.call("_select_product", "aether-voyager-outfit")
	state = store.call("_current_character_preview_appearance")
	_check(state["hair_color"] == "#247aca", "product colour experiments do not tint the player's presentation hair")
	_check(store.trainer_appearance == saved, "preview never changes saved appearance or equipped clothing")
	_render_detail_examples(store)
	store.queue_free()
	await process_frame
	var body_and_hair: Array[Dictionary] = [{"kind": "body"}, {"category": "hair", "id": "Hair"}]
	var hair_only: Array[Dictionary] = [{"category": "hair", "id": "Hair"}]
	var full_icon := APPEARANCE._create_battle_appearance_icon(body_and_hair, "male")
	var part_icon := APPEARANCE._create_battle_appearance_icon(hair_only, "male")
	_check(full_icon != null and part_icon != null and full_icon.get_height() * part_icon.get_width() > part_icon.get_height() * full_icon.get_width(), "an included body layer renders the full mannequin, including the head")
	_render_card_examples()
	quit(1 if failures else 0)

func _render_detail_examples(store: DonatorStorePopup) -> void:
	var ids: Array[String] = ["aether-voyager-outfit", "rotom-engineer-outfit", "mysterious-outfit", "adinho-classic-outfit", "ironfanton-outfit", "aether-blossom-outfit"]
	var montage := Image.create(ids.size() * 192, 384, false, Image.FORMAT_RGBA8)
	montage.fill(Color("#111828"))
	for gender_index: int in range(2):
		var gender := "male" if gender_index == 0 else "female"
		store.trainer_gender = gender
		store.trainer_appearance = APPEARANCE.get_default_appearance(gender)
		store.trainer_appearance["hair"] = "Aether_Male_Hair_02" if gender == "male" else "Aether_Female_Hair_01"
		store.trainer_appearance["hair_color"] = "#247aca"
		store.call("_sync_character_preview_colors")
		for index: int in range(ids.size()):
			store.call("_select_product", ids[index])
			var state: Dictionary = store.call("_current_character_preview_appearance")
			var visual: Node2D = store.call("_create_character_preview_visual", state)
			store.call("_set_character_preview_direction", visual)
			var picture := Image.create(64, 64, false, Image.FORMAT_RGBA8)
			for child: Node in visual.get_children():
				var sprite := child as AnimatedSprite2D
				if sprite == null or not sprite.visible or sprite.sprite_frames == null:
					continue
				var frame := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_image()
				frame.convert(Image.FORMAT_RGBA8)
				picture.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i.ZERO)
			picture.resize(192, 192, Image.INTERPOLATE_NEAREST)
			montage.blend_rect(picture, Rect2i(Vector2i.ZERO, picture.get_size()), Vector2i(index * 192, gender_index * 192))
			visual.free()
	_check(montage.save_png("user://store_preview_hair_details.png") == OK, "own-trainer detail comparison saved in slot userdata")
	print("DETAIL COMPARISON ", ProjectSettings.globalize_path("user://store_preview_hair_details.png"))

func _render_card_examples() -> void:
	var ids: Array[String] = ["aether-voyager-outfit", "rotom-engineer-outfit", "mysterious-outfit", "adinho-classic-outfit", "ironfanton-outfit", "aether-blossom-outfit"]
	var montage := Image.create(ids.size() * 128, 512, false, Image.FORMAT_RGBA8)
	montage.fill(Color("#111828"))
	for index: int in range(ids.size()):
		for gender_index: int in range(2):
			var gender := "male" if gender_index == 0 else "female"
			var before := APPEARANCE.get_cosmetic_item_icon(ids[index], gender)
			var after := APPEARANCE.get_store_cosmetic_item_icon(ids[index], gender)
			_check(before != null and after != null, "%s has item and Store thumbnails for %s" % [ids[index], gender])
			if before == null or after == null:
				continue
			var before_image := before.get_image()
			var after_image := after.get_image()
			if ids[index] in ["adinho-classic-outfit", "ironfanton-outfit", "aether-blossom-outfit"]:
				_check(before_image.get_size() == after_image.get_size() and before_image.get_data() == after_image.get_data(), "included hair renders identically across item and Store contexts")
			_check(not after_image.is_empty() and after_image.get_used_rect().has_area(), "Store thumbnail has visible pixels")
			_check(before == APPEARANCE.get_cosmetic_item_icon(ids[index], gender), "Store styling uses a separate icon cache")
			for image_index: int in range(2):
				var picture := (before_image if image_index == 0 else after_image).duplicate() as Image
				picture.resize(picture.get_width() * 2, picture.get_height() * 2, Image.INTERPOLATE_NEAREST)
				montage.blend_rect(picture, Rect2i(Vector2i.ZERO, picture.get_size()), Vector2i(index * 128 + (128 - picture.get_width()) / 2, gender_index * 256 + image_index * 128))
	_check(montage.save_png("user://store_preview_hair_cards.png") == OK, "before/after card comparison saved in slot userdata")
	print("CARD COMPARISON ", ProjectSettings.globalize_path("user://store_preview_hair_cards.png"))

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		push_error("FAIL " + label)
