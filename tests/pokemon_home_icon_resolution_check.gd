extends SceneTree

var failed := false


func _init() -> void:
	_check_home_icon("Jangmo O")
	_check_home_icon("Hakamo O")
	_check_home_icon("Kommo O")
	_check_home_icon("Necrozma Ultra")

	if failed:
		quit(1)
		return

	print("PASS pokemon_home_icon_resolution_check")
	quit(0)


func _check_home_icon(species: String) -> void:
	var texture := PokemonAssets.load_home_sprite(species, false)
	if texture != null:
		return
	failed = true
	push_error("Missing normal HOME icon for %s" % species)
