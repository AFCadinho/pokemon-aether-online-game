extends SceneTree

const SIGN_TEXT_ROOT := "res://data/world_text/signs"
const SUPPORTED_LOCALES: Array[String] = ["en", "nl", "pt_BR", "zh_CN"]
const EXPECTED_SIGN_MAPS: Dictionary = {
	"kanto_cerulean_city_town_sign": "kanto_cerulean_city",
	"kanto_cerulean_city_gym": "kanto_cerulean_city",
	"kanto_cerulean_city_bike_shop": "kanto_cerulean_city",
	"kanto_pallet_town_town_sign": "kanto_pallet_town",
	"kanto_pallet_town_trainer_tips_1": "kanto_pallet_town",
	"kanto_pallet_town_oaks_lab": "kanto_pallet_town",
	"kanto_pewter_city_gym": "kanto_pewter_city",
	"kanto_route_1_route_sign": "kanto_route_1",
	"kanto_route_1_viridian_city_sign": "kanto_route_1",
	"kanto_route_2_route_sign": "kanto_route_2",
	"kanto_route_2_digletts_cave": "kanto_route_2",
	"kanto_route_22_route_sign": "kanto_route_22",
	"kanto_route_3_mt_moon_sign": "kanto_route_3",
	"kanto_route_24_route_sign": "kanto_route_24",
	"kanto_route_25_route_sign": "kanto_route_25",
	"kanto_viridian_city_town_sign": "kanto_viridian_city",
	"kanto_viridian_city_jail": "kanto_viridian_city",
	"kanto_viridian_city_trainer_school": "kanto_viridian_city",
	"kanto_viridian_city_gym": "kanto_viridian_city",
}
const SignTextServiceScript := preload("res://scripts/services/sign_text_service.gd")

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var sign_root := DirAccess.open(SIGN_TEXT_ROOT)
	_check(sign_root != null, "sign catalogue root is readable through res://")
	if sign_root != null:
		sign_root.list_dir_end()

	var service: Node = SignTextServiceScript.new()
	for locale: String in SUPPORTED_LOCALES:
		var catalog: Dictionary = service.call("_load_sign_catalog", locale)
		var entries: Dictionary = catalog.get("entries", {})
		_check(
			entries.size() == EXPECTED_SIGN_MAPS.size(),
			"%s catalogue exposes all %d signs" % [locale, EXPECTED_SIGN_MAPS.size()]
		)
		for sign_id: String in EXPECTED_SIGN_MAPS:
			var lines: Array[String] = service.call(
				"get_lines",
				sign_id,
				str(EXPECTED_SIGN_MAPS[sign_id]),
				locale
			)
			_check(not lines.is_empty(), "%s resolves %s" % [locale, sign_id])
	service.free()

	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return
	failed = true
	push_error("FAIL %s" % message)
