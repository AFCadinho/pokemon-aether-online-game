extends SceneTree

const REPORTED_FORM_NAMES: Array[String] = [
	"Mr. Mime Galar",
	"Pichu Spiky eared",
	"Absol Mega Z",
	"Garchomp Mega Z",
	"Lucario Mega Z",
	"Basculin Red-Striped",
	"Darmanitan Galar Zen",
	"Tornadus Incarnate",
	"Thundurus Incarnate",
	"Landorus Incarnate",
	"Keldeo Ordinary",
	"Meloetta Aria",
	"Greninja Bond",
	"Greninja Mega",
	"Furfrou La Reine",
	"Meowstic F Mega",
	"Meowstic M Mega",
	"Ribombee Totem",
	"Rockruff Dusk",
	"Kommo o Totem",
	"Magearna Original Mega",
	"Tatsugiri Curly Mega",
	"Tatsugiri Droopy Mega",
	"Tatsugiri Stretchy Mega",
	"Ogerpon Cornerstone Tera",
	"Ogerpon Hearthflame Tera",
]
const EXPECTED_BATTLE_ALIASES := {
	"Mr. Mime Galar": "mrmime-galar",
	"Pichu Spiky eared": "pichu",
	"Absol Mega Z": "absol-mega",
	"Garchomp Mega Z": "garchomp-mega",
	"Lucario Mega Z": "lucario-mega",
	"Basculin Red-Striped": "basculin",
	"Darmanitan Galar Zen": "darmanitan-galarzen",
	"Tornadus Incarnate": "tornadus",
	"Thundurus Incarnate": "thundurus",
	"Landorus Incarnate": "landorus",
	"Keldeo Ordinary": "keldeo",
	"Meloetta Aria": "meloetta",
	"Greninja Bond": "greninja-ash",
	"Greninja Mega": "greninja",
	"Furfrou La Reine": "furfrou-lareine",
	"Meowstic F Mega": "meowstic-mega",
	"Meowstic M Mega": "meowstic-mega",
	"Ribombee Totem": "ribombee",
	"Rockruff Dusk": "rockruff",
	"Kommo o Totem": "kommoo-totem",
	"Magearna Original Mega": "magearna-mega",
	"Tatsugiri Curly Mega": "tatsugiri-mega",
	"Tatsugiri Droopy Mega": "tatsugiri-mega",
	"Tatsugiri Stretchy Mega": "tatsugiri-mega",
	"Ogerpon Cornerstone Tera": "ogerpon-cornerstonetera",
	"Ogerpon Hearthflame Tera": "ogerpon-hearthflametera",
}

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
	for aliased_species: String in REPORTED_FORM_NAMES:
		_check_home_icon(aliased_species)
		_check_battle_alias(aliased_species)
	var sprite_box_source := FileAccess.get_file_as_string(
		"res://scripts/battle/battle_ui/sprite_box.gd"
	)
	if not sprite_box_source.contains("PokemonAssets.get_battle_sprite_ids(species)"):
		failed = true
		push_error("Battle sprite loader does not use the shared species alias resolver")
	if not sprite_box_source.contains("if report_missing:"):
		failed = true
		push_error("Battle sprite loader cannot suppress expected Pokédex fallback misses")
	var pokedex_source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	if not pokedex_source.contains('"front",\n\t\t\tpokedex_shiny_mode,\n\t\t\tfalse'):
		failed = true
		push_error("Pokédex list fallback does not suppress expected missing-form errors")
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


func _check_battle_alias(species: String) -> void:
	var expected_alias := str(EXPECTED_BATTLE_ALIASES.get(species, ""))
	if PokemonAssets.get_battle_sprite_ids(species).has(expected_alias):
		return
	failed = true
	push_error("Battle sprite aliases do not map %s to %s" % [species, expected_alias])


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
