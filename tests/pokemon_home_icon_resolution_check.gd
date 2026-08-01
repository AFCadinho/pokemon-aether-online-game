extends SceneTree

var failed := false


func _init() -> void:
	_check_home_icon("Jangmo O")
	_check_home_icon("Hakamo O")
	_check_home_icon("Kommo O")
	_check_home_icon("Necrozma Ultra")
	_check_home_icon("Mimikyu")
	_check_home_icon("Flabébé")
	_check_home_icon("Flabebe Blue")
	_check_home_icon("Flabebe Orange")
	_check_home_icon("Flabebe White")
	_check_home_icon("Flabebe Yellow")
	_check_home_icon("Mime Jr.")
	_check_home_icon("Zigzagoon Galar", true)

	if failed:
		quit(1)
		return

	print("PASS pokemon_home_icon_resolution_check")
	quit(0)


func _check_home_icon(species: String, require_home_asset := false) -> void:
	var texture := PokemonAssets.load_home_sprite(species, false)
	if texture != null and (not require_home_asset or not texture is AtlasTexture):
		return
	failed = true
	push_error("Missing direct normal HOME icon for %s" % species)
