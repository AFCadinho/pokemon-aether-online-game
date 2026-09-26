extends SceneTree

const PokemonAssets := preload("res://scripts/data/pokemon_assets.gd")
const NORMAL_HOME_DIR := "res://assets/sprites/pokemon/pokemon_home"
const SHINY_HOME_DIR := "res://assets/sprites/pokemon/pokemon_home_shiny"

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(_count_pngs(NORMAL_HOME_DIR) >= 1000, "normal Pokémon HOME sprite pack is restored before Android export")
	_check(_count_pngs(SHINY_HOME_DIR) >= 1000, "shiny Pokémon HOME sprite pack is restored before Android export")
	_check(PokemonAssets.load_home_sprite("Pikachu") != null, "Android export can resolve the Pikachu HOME icon")
	_check(PokemonAssets.load_home_sprite("Bulbasaur") != null, "Android export can resolve the Bulbasaur HOME icon")
	_check(PokemonAssets.load_home_sprite("Pikachu", true) != null, "Android export can resolve the shiny Pikachu HOME icon")

	if failures == 0:
		print("PASS android_home_sprite_pack_check")
	quit(1 if failures else 0)


func _count_pngs(directory: String) -> int:
	var absolute_path := ProjectSettings.globalize_path(directory)
	var dir := DirAccess.open(absolute_path)
	if dir == null:
		return 0
	var count := 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.to_lower().ends_with(".png"):
			count += 1
		file_name = dir.get_next()
	dir.list_dir_end()
	return count


func _check(ok: bool, message: String) -> void:
	if ok:
		return
	failures += 1
	push_error("FAIL " + message)
