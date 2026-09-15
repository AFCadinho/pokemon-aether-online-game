extends SceneTree

const CANONICAL := "res://assets/battles/animations/blackholeeclipse/PRAS- Black BG.png"
const SOURCE := "res://assets/battles/animations/babydolleyes/PRAS- Baby Doll Eyes BG.png"
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# PNG container bytes differ; compare decoded pixels, not filenames or hashes.
	var original := Image.new()
	var canonical := Image.new()
	var decoded := original.load_png_from_buffer(FileAccess.get_file_as_bytes(SOURCE)) == OK and canonical.load_png_from_buffer(FileAccess.get_file_as_bytes(CANONICAL)) == OK
	_check(decoded, "Both source images decode")
	if not decoded:
		quit(1)
		return
	original.convert(Image.FORMAT_RGBA8)
	canonical.convert(Image.FORMAT_RGBA8)
	_check(original.get_size() == canonical.get_size(), "Dimensions remain equal")
	_check(original.get_data() == canonical.get_data(), "Decoded RGBA pixels remain identical")
	var source_import := ConfigFile.new()
	var canonical_import := ConfigFile.new()
	var imports_ok := source_import.load(SOURCE + ".import") == OK and canonical_import.load(CANONICAL + ".import") == OK
	_check(imports_ok, "Both importer configurations are available")
	if imports_ok:
		_check(source_import.get_section_keys("params") == canonical_import.get_section_keys("params"), "Import parameter keys remain equal")
		for key in source_import.get_section_keys("params"):
			_check(source_import.get_value("params", key) == canonical_import.get_value("params", key), "Equal import parameter: %s" % key)
	var router = load("res://scripts/battle/battle_animation_router.gd").new()
	router.prewarm_move_animations(["thunderbolt", "babydolleyes"])
	router.release_threaded_resource_requests()
	var thunder_resources: Dictionary = router._get_animation_resources(router._get_move_animation_config("thunderbolt"))
	var eyes_resources: Dictionary = router._get_animation_resources(router._get_move_animation_config("babydolleyes"))
	var thunder := thunder_resources.get("background_texture") as Texture2D
	var eyes := eyes_resources.get("background_texture") as Texture2D
	_check(thunder != null and eyes != null, "Both backgrounds are ready after prewarm")
	var expect_distinct := "--expect-distinct" in OS.get_cmdline_user_args()
	var unique: Dictionary = {}
	if thunder != null and eyes != null:
		unique[thunder.get_rid()] = true
		unique[eyes.get_rid()] = true
		_check((thunder != eyes) if expect_distinct else (thunder == eyes), "Expected control/candidate resource identity")
		_check(thunder.get_width() == canonical.get_width() and thunder.get_height() == canonical.get_height(), "Imported dimensions remain equal")
	_check(unique.size() == (2 if expect_distinct else 1), "Expected distinct background count")
	router.clear_move_animation_cache()
	_check(router.threaded_resource_requests.is_empty(), "Cleanup collects all load tokens")
	print("BLACK_BACKGROUND_CHECK ", JSON.stringify({"control": expect_distinct, "uniqueTextures": unique.size(),
		"estimatedRGBABytes": unique.size() * canonical.get_width() * canonical.get_height() * 4,
		"realBrowserBattle": false, "success": failures == 0}))
	quit(0 if failures == 0 else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
