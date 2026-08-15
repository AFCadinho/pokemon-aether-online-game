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
	for sprite_root: String in ["front", "back", "shiny_front", "shiny_back"]:
		_check_battle_sprite_asset("pikachu-rockstar", sprite_root)
		_check_battle_sprite_asset("raichu-megax", sprite_root)
		_check_battle_sprite_asset("raichu-megay", sprite_root)

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


func _check_battle_sprite_asset(species_id: String, sprite_root: String) -> void:
	var asset_root := "res://assets/sprites/pokemon/%s/%s" % [sprite_root, species_id]
	var sheet_path := asset_root.path_join("sheet.png")
	var metadata_path := asset_root.path_join("animation.json")
	if not FileAccess.file_exists(sheet_path) or not FileAccess.file_exists(metadata_path):
		failed = true
		push_error("Missing battle sprite asset pair: %s" % asset_root)
		return

	var metadata_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not metadata_value is Dictionary:
		failed = true
		push_error("Invalid battle sprite metadata: %s" % metadata_path)
		return
	var metadata := metadata_value as Dictionary
	var frames_value: Variant = metadata.get("frames", [])
	if not frames_value is Array or (frames_value as Array).is_empty():
		failed = true
		push_error("Battle sprite metadata has no frames: %s" % metadata_path)
