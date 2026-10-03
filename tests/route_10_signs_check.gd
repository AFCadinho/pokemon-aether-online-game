extends SceneTree

const SCENE_PATH := "res://scenes/overworld/kanto/routes/kanto_route_10.tscn"
const SIGN_DATA_ROOT := "res://data/world_text/signs"
const PORTRAIT_CATALOG := preload("res://scripts/services/sign_portrait_catalog.gd")
const LOCALES: Array[String] = ["en", "nl", "pt-BR", "zh-CN"]
const SIGN_ID := "kanto_route_10_rock_tunnel_sign"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_text := FileAccess.get_file_as_string(SCENE_PATH)
	_check(not scene_text.is_empty(), "Route 10 scene is readable")
	_check(scene_text.contains('[node name="RockTunnelSign"'), "Rock Tunnel sign exists on Route 10")
	_check(scene_text.contains('sign_id = "%s"' % SIGN_ID), "Rock Tunnel sign has its content ID")
	_check(PORTRAIT_CATALOG.has_portrait(SIGN_ID), "Rock Tunnel sign has a location preview")
	var portrait_path := PORTRAIT_CATALOG.get_portrait_path(SIGN_ID)
	_check(ResourceLoader.load(portrait_path) is Texture2D, "Rock Tunnel preview image loads")

	for locale: String in LOCALES:
		var path := "%s/%s/kanto/routes.json" % [SIGN_DATA_ROOT, locale]
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(parsed is Dictionary, "Route signs parse for %s" % locale)
		if not parsed is Dictionary:
			continue
		var found := false
		for sign_value: Variant in parsed.get("signs", []):
			if not sign_value is Dictionary or str(sign_value.get("id", "")) != SIGN_ID:
				continue
			found = true
			_check(str(sign_value.get("mapId", "")) == "kanto_route_10", "Rock Tunnel sign maps correctly in %s" % locale)
			_check(not sign_value.get("lines", []).is_empty(), "Rock Tunnel sign has text for %s" % locale)
			break
		_check(found, "Rock Tunnel sign exists in %s" % locale)

	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL %s" % message)
