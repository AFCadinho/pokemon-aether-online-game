extends SceneTree

const CITY_SCENE := "res://scenes/overworld/kanto/towns/vermilion_city/vermilion_city.tscn"
const SIGN_DATA_ROOT := "res://data/world_text/signs"
const SIGN_PORTRAIT_CATALOG := preload("res://scripts/services/sign_portrait_catalog.gd")
const EXPECTED_SIGNS := {
	"kanto_vermilion_city_gym": "GymSign",
	"kanto_vermilion_city_pokemon_fan_club": "PokemonFanClubSign",
	"kanto_vermilion_city_guild_base": "GuildBaseSign",
}
const LOCALES: Array[String] = ["en", "nl", "pt-BR", "zh-CN"]

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_text := FileAccess.get_file_as_string(CITY_SCENE)
	for sign_id: String in EXPECTED_SIGNS:
		_check(scene_text.contains('sign_id = "%s"' % sign_id), "%s is assigned to its scene sign" % sign_id)
		_check(SIGN_PORTRAIT_CATALOG.has_portrait(sign_id), "%s has a preview image" % sign_id)
		var portrait_path := SIGN_PORTRAIT_CATALOG.get_portrait_path(sign_id)
		_check(ResourceLoader.load(portrait_path) is Texture2D, "%s preview image loads" % sign_id)

		for locale: String in LOCALES:
			var path := "%s/%s/kanto/vermilion_city.json" % [SIGN_DATA_ROOT, locale]
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			_check(parsed is Dictionary, "%s sign data parses for %s" % [sign_id, locale])
			if not parsed is Dictionary:
				continue
			var signs: Array = parsed.get("signs", [])
			var found := false
			for sign: Variant in signs:
				if sign is Dictionary and str(sign.get("id", "")) == sign_id:
					found = true
					_check(not sign.get("lines", []).is_empty(), "%s has text for %s" % [sign_id, locale])
					break
			_check(found, "%s is present in %s sign data" % [sign_id, locale])

	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL %s" % message)
