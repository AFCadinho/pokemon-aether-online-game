extends SceneTree

const PROJECT_CONFIG := "res://project.godot"
const SIGN_TEXT_SERVICE_SCRIPT := "res://scripts/services/sign_text_service.gd"
const SIGN_INTERACTABLE_SCRIPT := "res://scripts/world/interactables/sign_interactable.gd"
const SIGN_INTERACTABLE_SCENE := "res://scenes/world/interactables/sign_interactable.tscn"
const LARGE_SIGN_INTERACTABLE_SCENE := "res://scenes/world/interactables/large_sign_interactable.tscn"
const PALLET_TOWN_SCENE := "res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn"
const PALLET_TOWN_SIGN_DATA := "res://data/world_text/signs/en/kanto/pallet_town.json"
const VIRIDIAN_CITY_SCENE := "res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn"
const VIRIDIAN_CITY_SIGN_DATA := "res://data/world_text/signs/en/kanto/viridian_city.json"
const PEWTER_CITY_SCENE := "res://scenes/overworld/kanto/towns/pewter_city/pewter_city.tscn"
const PEWTER_CITY_SIGN_DATA := "res://data/world_text/signs/en/kanto/pewter_city.json"
const CERULEAN_CITY_SCENE := "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn"
const CERULEAN_CITY_SIGN_DATA := "res://data/world_text/signs/en/kanto/cerulean_city.json"
const ROUTE_3_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_3.tscn"
const ROUTE_24_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_24.tscn"
const ROUTE_25_SCENE := "res://scenes/overworld/kanto/routes/route25/kanto_route_25.tscn"
const ROUTE_SIGN_DATA := "res://data/world_text/signs/en/kanto/routes.json"

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
	_check_viridian_city_sign_markers()
	_check_pewter_city_and_route_3_sign_markers()
	_check_cerulean_city_sign_markers()
	_check_cerulean_route_sign_markers()

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

	localization_manager.call("set_locale", "zh_CN")
	var chinese_lines: Array[String] = service.call(
		"get_lines",
		"kanto_pallet_town_town_sign",
		"kanto_pallet_town"
	)
	_check_true(chinese_lines.has("一座宁静的小镇，新的旅程从这里开始。"), "SignTextService maps zh_CN to the zh-CN sign directory")

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


func _check_viridian_city_sign_markers() -> void:
	var scene_text := _read_text(VIRIDIAN_CITY_SCENE)
	_check_true(scene_text.contains("sign_id = \"kanto_viridian_city_jail\""), "Viridian City has jail sign marker")
	_check_true(scene_text.contains("sign_id = \"kanto_viridian_city_trainer_school\""), "Viridian City has Trainer School sign marker")
	_check_true(scene_text.contains("sign_id = \"kanto_viridian_city_gym\""), "Viridian City has Gym sign marker")

	var data_text := _read_text(VIRIDIAN_CITY_SIGN_DATA)
	_check_true(data_text.contains("\"kanto_viridian_city_jail\""), "Viridian City sign data includes jail sign")
	_check_true(data_text.contains("\"kanto_viridian_city_trainer_school\""), "Viridian City sign data includes Trainer School sign")
	_check_true(data_text.contains("\"kanto_viridian_city_gym\""), "Viridian City sign data includes Gym sign")


func _check_pewter_city_and_route_3_sign_markers() -> void:
	var pewter_scene_text := _read_text(PEWTER_CITY_SCENE)
	_check_true(
		pewter_scene_text.contains('sign_id = "kanto_pewter_city_gym"'),
		"Pewter City has its Gym sign marker"
	)
	var pewter_data_text := _read_text(PEWTER_CITY_SIGN_DATA)
	_check_true(
		pewter_data_text.contains('"kanto_pewter_city_gym"'),
		"Pewter City sign data includes its Gym sign"
	)

	var route_3_scene_text := _read_text(ROUTE_3_SCENE)
	_check_true(
		route_3_scene_text.contains('sign_id = "kanto_route_3_mt_moon_sign"'),
		"Route 3 has its Mt. Moon sign marker"
	)
	var route_data_text := _read_text(ROUTE_SIGN_DATA)
	_check_true(
		route_data_text.contains('"kanto_route_3_mt_moon_sign"'),
		"Route sign data includes the Mt. Moon sign"
	)


func _check_cerulean_city_sign_markers() -> void:
	var scene_text := _read_text(CERULEAN_CITY_SCENE)
	var sign_data_text := _read_text(CERULEAN_CITY_SIGN_DATA)
	var expected_signs := {
		"kanto_cerulean_city_town_sign": "/large_sign_interactable.tscn",
		"kanto_cerulean_city_gym": "/sign_interactable.tscn",
		"kanto_cerulean_city_bike_shop": "/sign_interactable.tscn",
	}

	for sign_id: String in expected_signs:
		_check_true(scene_text.contains('sign_id = "%s"' % sign_id), "Cerulean City places %s" % sign_id)
		_check_true(sign_data_text.contains('"%s"' % sign_id), "Cerulean City sign data includes %s" % sign_id)
		_check_true(
			_has_sign_instance(scene_text, sign_id, str(expected_signs[sign_id])),
			"Cerulean City uses the correct interactable for %s" % sign_id
		)

	var service: Node = SignTextServiceScript.new()
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		for sign_id: String in expected_signs:
			var lines: Array[String] = service.call("get_lines", sign_id, "kanto_cerulean_city", locale)
			_check_true(not lines.is_empty(), "Cerulean City resolves %s text in %s" % [sign_id, locale])
	service.free()


func _check_cerulean_route_sign_markers() -> void:
	var route_data_text := _read_text(ROUTE_SIGN_DATA)
	var expected_signs := {
		"kanto_route_24_route_sign": [ROUTE_24_SCENE, "kanto_route_24"],
		"kanto_route_25_route_sign": [ROUTE_25_SCENE, "kanto_route_25"],
	}

	var service: Node = SignTextServiceScript.new()
	for sign_id: String in expected_signs:
		var scene_path: String = expected_signs[sign_id][0]
		var map_id: String = expected_signs[sign_id][1]
		var scene_text := _read_text(scene_path)
		_check_true(scene_text.contains('sign_id = "%s"' % sign_id), "%s places its route sign" % map_id)
		_check_true(route_data_text.contains('"%s"' % sign_id), "Route sign data includes %s" % sign_id)
		_check_true(
			_has_sign_instance(scene_text, sign_id, "/large_sign_interactable.tscn"),
			"%s uses the large sign interactable" % map_id
		)
		for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
			var lines: Array[String] = service.call("get_lines", sign_id, map_id, locale)
			_check_true(not lines.is_empty(), "%s resolves text in %s" % [map_id, locale])
	service.free()


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
