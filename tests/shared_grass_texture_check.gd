extends SceneTree

const CANONICAL := "res://assets/battles/animations/grassyterrain/PRAS- Grass.png"
const SOURCE := "res://assets/battles/animations/common/grassyterrain/PRAS- Grass.png"
const MOVES := ["grassyterrain", "vinewhip", "leafage", "razorleaf", "growth"]
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var source_hash := FileAccess.get_sha256(SOURCE)
	_check(not source_hash.is_empty() and source_hash == FileAccess.get_sha256(CANONICAL), "Source pixels remain byte-identical")
	var source_import := ConfigFile.new()
	var terrain_import := ConfigFile.new()
	var source_ok := source_import.load(SOURCE + ".import") == OK
	var terrain_ok := terrain_import.load(CANONICAL + ".import") == OK
	_check(source_ok and terrain_ok, "Both texture import settings are available")
	if source_ok and terrain_ok:
		_check(source_import.get_section_keys("params") == terrain_import.get_section_keys("params"), "Texture import parameter keys match")
		for key in source_import.get_section_keys("params"):
			_check(source_import.get_value("params", key) == terrain_import.get_value("params", key), "Import parameter %s remains equal" % key)
	# Hold the real preloaded terrain resource, as the world holds battle.tscn.
	var scene: PackedScene = load("res://scenes/battle/battle.tscn")
	var terrain := ResourceLoader.get_cached_ref(CANONICAL) as Texture2D
	_check(scene != null and terrain != null, "Real battle scene keeps Grass terrain prepared")
	if terrain == null:
		quit(1)
		return
	var router = load("res://scripts/battle/battle_animation_router.gd").new()
	router.prewarm_move_animations(MOVES)
	router.prewarm_effect_animations(["grassy_terrain_start"])
	router.release_threaded_resource_requests()
	var unique := {terrain.get_rid(): true}
	var expect_distinct := "--expect-distinct" in OS.get_cmdline_user_args()
	for key in MOVES:
		var config: Dictionary = router._get_move_animation_config(key)
		var resources: Dictionary = router._get_animation_resources(config)
		var sheet := resources.get("sheet_texture") as Texture2D
		_check(sheet != null, "%s prewarm is ready" % key)
		if sheet != null:
			unique[sheet.get_rid()] = true
			_check((sheet != terrain) if expect_distinct else (sheet == terrain), "%s uses expected sheet identity" % key)
	var effect_config: Dictionary = router._get_effect_animation_config("grassy_terrain_start")
	var effect_sheet := router._get_animation_resources(effect_config).get("sheet_texture") as Texture2D
	_check(effect_sheet != null, "Grass terrain-start effect prewarm is ready")
	if effect_sheet != null:
		unique[effect_sheet.get_rid()] = true
		_check((effect_sheet != terrain) if expect_distinct else (effect_sheet == terrain), "Terrain-start effect uses expected sheet identity")
	_check(unique.size() == (2 if expect_distinct else 1), "Distinct sheet count matches control/candidate")
	router.clear_move_animation_cache()
	_check(router.threaded_resource_requests.is_empty(), "Prewarm tokens are collected on cleanup")
	print("GRASS_TEXTURE_CHECK ", JSON.stringify({"control": expect_distinct,
		"uniqueSheets": unique.size(), "estimatedRGBABytes": unique.size() * 960 * 1920 * 4,
		"headless": true, "realBrowserBattle": false, "success": failures == 0}))
	quit(0 if failures == 0 else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
