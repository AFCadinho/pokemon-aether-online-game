extends SceneTree

const SCENE_PATH := "res://scenes/overworld/kanto/routes/kanto_route_11.tscn"
const SIGN_DATA_ROOT := "res://data/world_text/signs"
const PORTRAIT_CATALOG := preload("res://scripts/services/sign_portrait_catalog.gd")
const LOCALES: Array[String] = ["en", "nl", "pt-BR", "zh-CN"]
const EXPECTED_SIGNS: Dictionary = {
	"kanto_route_11_digletts_cave_sign": "DiglettCaveSign",
	"kanto_route_11_route_sign": "Route11Sign",
}

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_text := FileAccess.get_file_as_string(SCENE_PATH)
	_check(not scene_text.is_empty(), "Route 11 scene is readable")
	for sign_id: String in EXPECTED_SIGNS:
		var node_name: String = EXPECTED_SIGNS[sign_id]
		_check(scene_text.contains('[node name="%s"' % node_name), "%s exists in Route 11" % node_name)
		_check(scene_text.contains('sign_id = "%s"' % sign_id), "%s is assigned to its scene sign" % sign_id)
		_check(PORTRAIT_CATALOG.has_portrait(sign_id), "%s has a location preview" % sign_id)
		var portrait_path: String = PORTRAIT_CATALOG.get_portrait_path(sign_id)
		_check(ResourceLoader.load(portrait_path) is Texture2D, "%s preview image loads" % sign_id)

		for locale: String in LOCALES:
			var path := "%s/%s/kanto/routes.json" % [SIGN_DATA_ROOT, locale]
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			_check(parsed is Dictionary, "%s catalogue parses for %s" % [sign_id, locale])
			if not parsed is Dictionary:
				continue
			var found := false
			for sign: Variant in parsed.get("signs", []):
				if sign is Dictionary and str(sign.get("id", "")) == sign_id:
					found = true
					_check(not sign.get("lines", []).is_empty(), "%s has localized text for %s" % [sign_id, locale])
					break
			_check(found, "%s exists in %s sign data" % [sign_id, locale])

	if not failed:
		print("PASS Route 11: both signs have localized text and preview art")
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL %s" % message)
