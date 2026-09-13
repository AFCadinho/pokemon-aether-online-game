extends SceneTree

const LAUNCHER_PATH := "res://launcher/scripts/launcher.gd"
const WORKFLOW_PATH := "res://.github/workflows/deploy-desktop-r2.yml"
const EXPORT_PRESETS_PATH := "res://export_presets.cfg"
const REQUIRED_MUSIC_FILES: Array[String] = [
	"assets/music/login/lugia_theme_lofi.ogg",
	"assets/music/overworld/kanto/towns/pallet_town.ogg",
	"assets/music/overworld/kanto/towns/viridian_city.ogg",
	"assets/music/overworld/kanto/routes/route1.ogg",
	"assets/music/overworld/kanto/interiors/oaks_lab.ogg",
	"assets/music/overworld/kanto/interiors/pokemon_center.ogg",
	"assets/music/battle/wild/Kanto Wild Battle.ogg",
	"assets/music/battle/trainer/Kalos Trainer Battle.ogg",
]

var failures := 0


func _init() -> void:
	var launcher := FileAccess.get_file_as_string(LAUNCHER_PATH)
	var workflow := FileAccess.get_file_as_string(WORKFLOW_PATH)
	var presets := FileAccess.get_file_as_string(EXPORT_PRESETS_PATH)

	for required_file: String in REQUIRED_MUSIC_FILES:
		_check(launcher.contains('"%s"' % required_file), "launcher validates %s" % required_file)
		_check(workflow.contains('"%s"' % required_file), "desktop build restores %s" % required_file)

	_check(
		launcher.contains("ASSET_PACK_REQUIRED_FILES")
			and launcher.contains("FileAccess.file_exists("),
		"launcher verifies required files instead of accepting only the music directory"
	)
	_check(
		workflow.contains("sha256sum --check --strict")
			and workflow.contains("Required music resources failed Godot import."),
		"desktop release verifies the pack and rejects music import errors"
	)
	_check(
		presets.count('exclude_filter="assets/sprites/pokemon/**,assets/music/**"') == 3,
		"desktop exports keep the externally managed music pack outside all game archives"
	)
	print("desktop_music_integrity_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error(label)
