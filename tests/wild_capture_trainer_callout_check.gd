extends SceneTree

const BATTLE_SCRIPT := "res://scripts/battle/battle.gd"
const LOCALE_PATHS := [
	"res://localization/en.json",
	"res://localization/nl.json",
	"res://localization/pt_BR.json",
	"res://localization/zh_CN.json",
]
const CALLOUT_KEYS := [
	"battle.capture.callout.throw",
	"battle.capture.callout.caught",
	"battle.capture.callout.almost",
	"battle.capture.callout.broke_free",
]

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var battle_source := FileAccess.get_file_as_string(BATTLE_SCRIPT)
	_check(battle_source.contains("func _show_wild_capture_throw_callout"), "wild capture has a throw callout")
	_check(battle_source.contains("func _show_wild_capture_result_callout"), "wild capture has an outcome callout")
	_check(battle_source.contains("func _clear_wild_capture_trainer"), "wild capture cleans up its trainer")
	_check(
		battle_source.contains("battle_type != BattleType.WILD or not has_meta(\"immersive_battle_ui\")"),
		"callouts are limited to immersive wild battles"
	)
	_check(
		battle_source.contains("_show_local_player_trainer()"),
		"the local trainer appears for the throw"
	)
	for locale_path: String in LOCALE_PATHS:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(locale_path))
		_check(parsed is Dictionary, "%s parses" % locale_path)
		if not (parsed is Dictionary):
			continue
		var locale: Dictionary = parsed
		for key: String in CALLOUT_KEYS:
			_check(not str(locale.get(key, "")).strip_edges().is_empty(), "%s provides %s" % [locale_path, key])
	print("wild_capture_trainer_callout_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error(label)
