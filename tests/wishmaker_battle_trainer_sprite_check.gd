extends SceneTree

const BattlePlayerTrainerCatalog := preload("res://scripts/battle/battle_ui/battle_player_trainer_catalog.gd")

var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var appearance := {
		"gender": "female",
		"bottom": "Trousers",
		"shoes": "Wishmaker_Shoes",
		"top": "Wishmaker_Dress",
		"hair": "Wishmaker_Hair",
		"facegear": "Wishmaker_Earrings",
	}
	var layers := BattlePlayerTrainerCatalog.build_layers(appearance)
	_check(layers.size() == 6, "female Wishmaker appearance builds a base, trousers, and four battle-art layers")
	for expected: Dictionary in [
		{"category": "shoes", "part_id": "Wishmaker_Shoes"},
		{"category": "top", "part_id": "Wishmaker_Dress"},
		{"category": "hair", "part_id": "Wishmaker_Hair"},
		{"category": "facegear", "part_id": "Wishmaker_Earrings"},
	]:
		var layer := _find_layer(layers, str(expected["category"]))
		_check(not layer.is_empty() and layer.get("part_id", "") == expected["part_id"], "female %s uses Wishmaker battle art" % expected["category"])
		if not layer.is_empty():
			var texture := layer.get("texture") as Texture2D
			_check(texture != null and texture.get_size() == Vector2(80, 80), "female %s preserves the supplied 80px sprite" % expected["category"])

	var male_layers := BattlePlayerTrainerCatalog.build_layers({
		"gender": "male",
		"bottom": "Trousers",
		"shoes": "Wishmaker_Shoes",
		"top": "Wishmaker_Dress",
		"hair": "Wishmaker_Hair",
		"facegear": "Wishmaker_Earrings",
	})
	for expected: Dictionary in [
		{"category": "shoes", "part_id": "Wishmaker_Shoes"},
		{"category": "top", "part_id": "Wishmaker_Dress"},
		{"category": "hair", "part_id": "Wishmaker_Hair"},
		{"category": "facegear", "part_id": "Wishmaker_Earrings"},
	]:
		var layer := _find_layer(male_layers, str(expected["category"]))
		_check(layer.is_empty() or layer.get("part_id", "") != expected["part_id"], "male catalog does not contain female-only Wishmaker %s art" % expected["category"])
	quit(1 if failed else 0)

func _find_layer(layers: Array[Dictionary], category: String) -> Dictionary:
	for layer: Dictionary in layers:
		if layer.get("category", "") == category:
			return layer
	return {}

func _check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failed = true
