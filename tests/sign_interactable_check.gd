extends SceneTree

const PROJECT_CONFIG := "res://project.godot"
const SIGN_TEXT_SERVICE_SCRIPT := "res://scripts/services/sign_text_service.gd"
const SIGN_INTERACTABLE_SCRIPT := "res://scripts/world/interactables/sign_interactable.gd"
const SIGN_INTERACTABLE_SCENE := "res://scenes/world/interactables/sign_interactable.tscn"
const LARGE_SIGN_INTERACTABLE_SCENE := "res://scenes/world/interactables/large_sign_interactable.tscn"
const PALLET_TOWN_SCENE := "res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn"
const PALLET_TOWN_SIGN_DATA := "res://data/world_text/signs/en/kanto/pallet_town.json"

const SignTextServiceScript := preload(SIGN_TEXT_SERVICE_SCRIPT)
const SignInteractableScript := preload(SIGN_INTERACTABLE_SCRIPT)

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_service_is_autoloaded()
	_check_service_loads_local_sign_catalog()
	_check_service_uses_global_locale()
	_check_service_falls_back_to_english()
	_check_sign_interactable_contract()
	_check_sign_scene_contract()
	_check_pallet_town_sign_markers()

	quit(1 if failed else 0)


func _check_service_is_autoloaded() -> void:
	var text := _read_text(PROJECT_CONFIG)
	_check_true(
		text.contains("SignTextService=\"*res://scripts/services/sign_text_service.gd\""),
		"SignTextService is autoloaded"
	)


func _check_service_loads_local_sign_catalog() -> void:
	var service: Node = SignTextServiceScript.new()
	var response: Dictionary = service.call("get_sign", "kanto_pallet_town_town_sign", "kanto_pallet_town")
	_check_true(bool(response.get("success", false)), "SignTextService resolves Pallet Town town sign")

	var metadata: Dictionary = response.get("metadata", {})
	_check_equal(str(metadata.get("title", "")), "Pallet Town", "Sign metadata title is normalized")
	_check_equal(str(metadata.get("mapId", "")), "kanto_pallet_town", "Sign metadata mapId is normalized")

	var lines: Array[String] = service.call("get_lines", "kanto_pallet_town_trainer_tips_1", "kanto_pallet_town")
	_check_true(not lines.is_empty(), "SignTextService returns trainer tips lines")
	service.free()


func _check_service_uses_global_locale() -> void:
	var localization_manager := get_root().get_node_or_null("LocalizationManager")
	_check_true(localization_manager != null, "LocalizationManager is available for sign locale resolution")
	if localization_manager == null:
		return

	var original_locale := str(localization_manager.get("current_locale"))
	var service: Node = SignTextServiceScript.new()
	get_root().add_child(service)

	localization_manager.call("set_locale", "nl")
	var dutch_lines: Array[String] = service.call(
		"get_lines",
		"kanto_pallet_town_town_sign",
		"kanto_pallet_town"
	)
	_check_true(dutch_lines.has("Een rustig dorp waar nieuwe reizen beginnen."), "SignTextService uses the global Dutch locale")

	localization_manager.call("set_locale", "pt_BR")
	var portuguese_lines: Array[String] = service.call(
		"get_lines",
		"kanto_pallet_town_town_sign",
		"kanto_pallet_town"
	)
	_check_true(portuguese_lines.has("Uma cidade tranquila onde novas jornadas começam."), "SignTextService maps pt_BR to the pt-BR sign directory")

	localization_manager.call("set_locale", original_locale)
	service.free()


func _check_service_falls_back_to_english() -> void:
	var service: Node = SignTextServiceScript.new()
	var localized_catalog: Dictionary = service.call("_load_sign_catalog", "nl")
	(localized_catalog.get("entries", {}) as Dictionary).erase("kanto_pallet_town_oaks_lab")

	var response: Dictionary = service.call(
		"get_sign",
		"kanto_pallet_town_oaks_lab",
		"kanto_pallet_town",
		"nl"
	)
	_check_true(bool(response.get("success", false)), "Missing localized sign content falls back without blocking")
	var metadata: Dictionary = response.get("metadata", {})
	_check_equal(str(metadata.get("title", "")), "Oaks Lab", "Missing localized sign falls back to English")
	service.free()


func _check_sign_interactable_contract() -> void:
	var sign := SignInteractableScript.new()
	_check_true(sign is WorldInteractable, "SignInteractable extends WorldInteractable")
	_check_true(sign.has_method("show_sign_text"), "SignInteractable exposes show_sign_text")
	_check_true(sign.has_method("interact_with_player"), "SignInteractable exposes interact_with_player")
	sign.free()

	var text := _read_text(SIGN_INTERACTABLE_SCRIPT)
	_check_true(text.contains("@export var sign_id := \"\""), "SignInteractable exports sign_id")
	_check_true(text.contains("@export_enum(\"road\", \"town\", \"building\", \"trainer_tips\", \"notice\", \"generic\")"), "SignInteractable exports sign_type options")
	_check_true(text.contains("@export_enum(\"small\", \"large\")"), "SignInteractable exports sign sizes")
	_check_true(text.contains("@export_enum(\"facing_target_tile\", \"standing_tile\")"), "SignInteractable exports interaction modes")
	_check_true(text.contains("@export_enum(\"any\", \"up\", \"down\", \"left\", \"right\")"), "SignInteractable exports facing directions")
	_check_true(text.contains("/root/SignTextService"), "SignInteractable resolves local text through SignTextService autoload")
	_check_true(text.contains("dialogue_box.start_dialogue(valid_dialogue_lines, speaker, null, false)"), "SignInteractable suppresses mugshots for sign text")
	_check_true(text.contains("func _is_player_on_interaction_tile(player: Node2D) -> bool:"), "SignInteractable supports standing tile interaction")
	_check_true(text.contains("func _get_interaction_area_rect() -> Rect2:"), "SignInteractable supports shaped standing areas")
	_check_true(text.contains("func _get_standing_area_size(fallback_size: Vector2) -> Vector2:"), "SignInteractable derives standing area from sign size")
	_check_true(text.contains("func _get_shape_size_for_sign_size() -> Vector2:"), "SignInteractable maps sign size to shape size")
	_check_true(text.contains("func _is_player_facing_required_direction(player: Node2D) -> bool:"), "SignInteractable supports required facing direction")


func _check_sign_scene_contract() -> void:
	var text := _read_text(SIGN_INTERACTABLE_SCENE)
	_check_true(text.contains("res://scripts/world/interactables/sign_interactable.gd"), "Sign scene references SignInteractable")
	_check_true(text.contains("[node name=\"InteractionArea\" type=\"Area2D\" parent=\".\""), "Sign scene has InteractionArea")
	_check_true(text.contains("[node name=\"CollisionShape2D\" type=\"CollisionShape2D\" parent=\"InteractionArea\""), "Sign scene has collision shape")
	_check_true(text.contains("blocks_movement = false"), "Sign scene defaults to non-blocking")
	_check_true(text.contains("interaction_shape_size = Vector2(32, 32)"), "Sign scene defaults to one-tile standing area")
	_check_true(text.contains("sign_size = \"small\""), "Sign scene is small")

	var large_text := _read_text(LARGE_SIGN_INTERACTABLE_SCENE)
	_check_true(large_text.contains("res://scripts/world/interactables/sign_interactable.gd"), "Large sign scene references SignInteractable")
	_check_true(large_text.contains("interaction_shape_size = Vector2(64, 32)"), "Large sign scene has two-tile standing area")
	_check_true(large_text.contains("sign_size = \"large\""), "Large sign scene is large")


func _check_pallet_town_sign_markers() -> void:
	var scene_text := _read_text(PALLET_TOWN_SCENE)
	_check_true(scene_text.contains("res://scenes/world/interactables/sign_interactable.tscn"), "Pallet Town references sign interactable scene")
	_check_true(scene_text.contains("res://scenes/world/interactables/large_sign_interactable.tscn"), "Pallet Town references large sign interactable scene")
	_check_true(scene_text.contains("[node name=\"Interactables\" type=\"Node2D\" parent=\"Entities\""), "Pallet Town has Entities/Interactables container")
	_check_true(scene_text.contains("sign_id = \"kanto_pallet_town_town_sign\""), "Pallet Town has town sign marker")
	_check_true(_has_sign_instance(scene_text, "kanto_pallet_town_town_sign", "/large_sign_interactable.tscn"), "Pallet Town town sign uses large sign scene")
	_check_true(scene_text.contains("sign_id = \"kanto_pallet_town_oaks_lab\""), "Pallet Town has Oak's Lab sign marker")

	var data_text := _read_text(PALLET_TOWN_SIGN_DATA)
	_check_true(data_text.contains("\"kanto_pallet_town_town_sign\""), "Pallet Town sign data includes town sign")
	_check_true(data_text.contains("\"kanto_pallet_town_trainer_tips_1\""), "Pallet Town sign data includes trainer tips sign")
	_check_true(data_text.contains("\"kanto_pallet_town_oaks_lab\""), "Pallet Town sign data includes Oak's Lab sign")


func _read_text(path: String) -> String:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _has_sign_instance(scene_text: String, sign_id: String, scene_file_name: String) -> bool:
	var ext_resources := {}
	for line: String in scene_text.split("\n"):
		if not line.begins_with("[ext_resource "):
			continue
		var id := _extract_quoted_attribute(line, "id")
		var path := _extract_quoted_attribute(line, "path")
		if id != "" and path.ends_with(scene_file_name):
			ext_resources[id] = true

	var current_uses_target_scene := false
	for block: String in scene_text.split("\n[node "):
		var first_line_end := block.find("\n")
		if first_line_end == -1:
			continue

		var header := "[node %s" % block.substr(0, first_line_end)
		var instance_id := _extract_instance_ext_resource_id(header)
		current_uses_target_scene = ext_resources.has(instance_id)
		if current_uses_target_scene and block.contains("sign_id = \"%s\"" % sign_id):
			return true

	return false


func _extract_quoted_attribute(line: String, attribute_name: String) -> String:
	var marker := " %s=\"" % attribute_name
	var start_index := line.find(marker)
	if start_index == -1:
		return ""
	start_index += marker.length()

	var end_index := line.find("\"", start_index)
	if end_index == -1:
		return ""
	return line.substr(start_index, end_index - start_index)


func _extract_instance_ext_resource_id(line: String) -> String:
	var marker := "instance=ExtResource(\""
	var start_index := line.find(marker)
	if start_index == -1:
		return ""
	start_index += marker.length()

	var end_index := line.find("\"", start_index)
	if end_index == -1:
		return ""
	return line.substr(start_index, end_index - start_index)


func _check_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		print("PASS %s" % message)
		return

	failed = true
	push_error("FAIL %s expected=%s actual=%s" % [message, str(expected), str(actual)])


func _check_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return

	failed = true
	push_error("FAIL %s" % message)
