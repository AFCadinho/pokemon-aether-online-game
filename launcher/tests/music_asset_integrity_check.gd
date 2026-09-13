extends SceneTree

const ASSET_PACK_INTEGRITY := preload("res://scripts/asset_pack_integrity.gd")
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
	var install_dir := "user://music_asset_integrity_check_%d" % Time.get_ticks_usec()
	var absolute_install_dir := ProjectSettings.globalize_path(install_dir)
	DirAccess.make_dir_recursive_absolute(absolute_install_dir.path_join("assets/music"))

	_check(
		not ASSET_PACK_INTEGRITY.has_required_contents(
			install_dir,
			"assets/music",
			REQUIRED_MUSIC_FILES
		),
		"launcher rejects a versioned music directory when required tracks are absent"
	)

	for required_file: String in REQUIRED_MUSIC_FILES:
		var absolute_file := absolute_install_dir.path_join(required_file)
		DirAccess.make_dir_recursive_absolute(absolute_file.get_base_dir())
		var output := FileAccess.open(absolute_file, FileAccess.WRITE)
		if output != null:
			output.store_8(1)

	_check(
		ASSET_PACK_INTEGRITY.has_required_contents(
			install_dir,
			"assets/music",
			REQUIRED_MUSIC_FILES
		),
		"launcher accepts the music pack only after every required track exists"
	)
	print("music_asset_integrity_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error(label)
