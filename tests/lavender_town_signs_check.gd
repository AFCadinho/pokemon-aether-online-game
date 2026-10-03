extends SceneTree

const SCENE_PATH := "res://scenes/overworld/kanto/towns/lavender_town/lavender_town.tscn"
const SIGN_DATA_ROOT := "res://data/world_text/signs"
const SIGN_PORTRAIT_CATALOG := preload("res://scripts/services/sign_portrait_catalog.gd")
const LOCALES: Array[String] = ["en", "nl", "pt-BR", "zh-CN"]
const EXPECTED_SIGNS := {
	"LavenderTownSign": "kanto_lavender_town_town_sign",
	"PokemonTowerSign": "kanto_lavender_town_pokemon_tower_sign",
}

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_text := FileAccess.get_file_as_string(SCENE_PATH)
	_check(not scene_text.is_empty(), "Lavender Town scene is readable")
	for node_name: String in EXPECTED_SIGNS:
		var sign_id: String = EXPECTED_SIGNS[node_name]
		_check(scene_text.contains('[node name="%s"' % node_name), "%s exists in Lavender Town" % node_name)
		_check(scene_text.contains('sign_id = "%s"' % sign_id), "%s has its content ID" % node_name)
		_check(SIGN_PORTRAIT_CATALOG.has_portrait(sign_id), "%s has an illustrated preview" % sign_id)
		var portrait_path := SIGN_PORTRAIT_CATALOG.get_portrait_path(sign_id)
		_check(ResourceLoader.load(portrait_path) is Texture2D, "%s preview image loads" % sign_id)

	for locale: String in LOCALES:
		var path := "%s/%s/kanto/lavender_town.json" % [SIGN_DATA_ROOT, locale]
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(parsed is Dictionary, "Lavender Town sign data parses for %s" % locale)
		if not parsed is Dictionary:
			continue
		var data := parsed as Dictionary
		_check(str(data.get("mapId", "")) == "kanto_lavender_town", "Sign data belongs to Lavender Town in %s" % locale)
		for sign_id: String in EXPECTED_SIGNS.values():
			var found := false
			for sign_value: Variant in data.get("signs", []):
				if sign_value is Dictionary and str(sign_value.get("id", "")) == sign_id:
					found = true
					_check(not sign_value.get("lines", []).is_empty(), "%s has text in %s" % [sign_id, locale])
					break
			_check(found, "%s exists in %s" % [sign_id, locale])

	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL %s" % message)
