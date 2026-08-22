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
	"Greninja Bond": "greninja",
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
const EXPECTED_OGERPON_BATTLE_SPRITES := {
	"ogerpon": {
		"front": "82259de6f5b569cbfd40b665d50acec7f49125b89c31a1cf7553f3e0a64c2333",
		"back": "83de009c1b4368d101c9bdf591fb34ddc8d246e46af8b91d4ee560a62c8b7826",
		"shiny_front": "49480c1b501d56da5ae1626e2228fbfd8bd9cb74c0e3c1e46e2c2b091c5e59ea",
		"shiny_back": "047422582baf1aaf75d33672ceaa5a27f1c4d3498a6233a9a305c10451dc774b",
	},
	"ogerpon-wellspring": {
		"front": "da7866fa3a36ee6f22844a27abef8825a35763771b41494fcacbbda3546a360f",
		"back": "e1e253ccdca7cc303ab676683c363a42eb4582e5756400619a0f1daf2432be5f",
		"shiny_front": "0f399807a7370df226454657f09a7d63ce9e567cc259d435db0c6918adc93040",
		"shiny_back": "332de0f3125802d8aaadde0169adcde9158ae6cb815298c8dfee5d0389cbdaaa",
	},
	"ogerpon-hearthflame": {
		"front": "877230852cec1c69f570149b3d783ec0a4340decb8779a2c2102edd1bd3be8e9",
		"back": "abe56a49b03dd301b831ac303e8a7bab3fb5fe7f5f296d37f744b92f45e6ac31",
		"shiny_front": "0b923ad8807d5e9cec77142adb3371a3a8aa4319bf23513e6f4095f8b4a90cdb",
		"shiny_back": "51383f67522b04095b8285147152cf2ff5401538fb9163a4b81a6a0d45e86be2",
	},
	"ogerpon-cornerstone": {
		"front": "9245aa2e8af735250a08132a8158d5edc59211b98e73f7632ec89869fc1c16b5",
		"back": "771a875134de4ad3e7c688d94bf4a19774333787d568ea24b895a07920ee2f81",
		"shiny_front": "a3426e79801c3be0756862a60b47eca231786bfb828b7931242585603be2597c",
		"shiny_back": "0e19ae4533cd1c039b288d3867b6dc8de9068673e20ef0a7854e0884685ba186",
	},
	"ogerpon-teal-tera": {
		"front": "6b7cfc04d18550a749f2433b7fa61cb78771b477d39912ebfc6147ba77a0a073",
		"back": "0b7671f43475c0ce62c908b6d0d3e60f104235158e8f707be6e8cb8730d13ab3",
		"shiny_front": "6b7cfc04d18550a749f2433b7fa61cb78771b477d39912ebfc6147ba77a0a073",
		"shiny_back": "93a1f01e687376ad45f3ce5f18b15e49c06c3a493e4ed583fb18f1ec451a3e7a",
	},
	"ogerpon-wellspring-tera": {
		"front": "784318e905bfd757aaff02927a4efcd03defcf58f5ba10eed43a85f32900e818",
		"back": "123bec96aec010140a17441e830ba7f71f5d3930045ca37418549299bb039a22",
		"shiny_front": "784318e905bfd757aaff02927a4efcd03defcf58f5ba10eed43a85f32900e818",
		"shiny_back": "ed91794e7709ab04e7ddde543b0e1f78f6b1cf22fe7a243387eec5b9d87c04d7",
	},
	"ogerpon-hearthflame-tera": {
		"front": "380c7217c1e4c526c03a1d9fdfd62dc8ef9f1ea81732a142df11e6d5d7c2d3e6",
		"back": "873956fe4c2802b23ace83e4df8efda9dc819d8143e6eebb4ece80db8161db41",
		"shiny_front": "380c7217c1e4c526c03a1d9fdfd62dc8ef9f1ea81732a142df11e6d5d7c2d3e6",
		"shiny_back": "4ac9e0db31075407913ae992696a878972ab65e0f1fd97d56dd5fd9665afc8db",
	},
	"ogerpon-cornerstone-tera": {
		"front": "c3b3989855f0a2bd8def620f6bc69e641f99d1ce285714ee60e32bfc17dc2a8d",
		"back": "a26d785ad4b9687687a22355c7c5d90cb7bdeb4181e40db44a629ab5586a4f78",
		"shiny_front": "c3b3989855f0a2bd8def620f6bc69e641f99d1ce285714ee60e32bfc17dc2a8d",
		"shiny_back": "42e4756200a17ec28b762c35f91ed496e8d1068f733b606efe0e391146f5b04f",
	},
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
	if not pokedex_source.contains('_get_pokedex_sprite_side(),\n\t\t\tpokedex_shiny_mode,\n\t\t\tfalse'):
		failed = true
		push_error("Pokédex detail sprite probing does not suppress expected candidate misses")
	for sprite_root: String in ["front", "back", "shiny_front", "shiny_back"]:
		_check_battle_sprite_asset("greninja-ash", sprite_root)
		_check_battle_sprite_asset("pikachu-rockstar", sprite_root)
		_check_battle_sprite_asset("raichu-megax", sprite_root)
		_check_battle_sprite_asset("raichu-megay", sprite_root)
	for species_id: String in EXPECTED_OGERPON_BATTLE_SPRITES:
		var expected_hashes := EXPECTED_OGERPON_BATTLE_SPRITES[species_id] as Dictionary
		for sprite_root: String in expected_hashes:
			_check_static_battle_sprite_asset(
				species_id,
				sprite_root,
				str(expected_hashes[sprite_root])
			)

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


func _check_static_battle_sprite_asset(
	species_id: String,
	sprite_root: String,
	expected_sha256: String
) -> void:
	var frame_path := "res://assets/sprites/pokemon/%s/%s/frame_000.png" % [
		sprite_root,
		species_id,
	]
	if not FileAccess.file_exists(frame_path):
		failed = true
		push_error("Missing static Ogerpon battle sprite: %s" % frame_path)
		return
	var actual_sha256 := FileAccess.get_sha256(frame_path)
	if actual_sha256 != expected_sha256:
		failed = true
		push_error("Incorrect Ogerpon battle sprite mapping: %s" % frame_path)
	if sprite_root in ["back", "shiny_back"]:
		var metadata_path := frame_path.get_base_dir().path_join("animation.json")
		if not FileAccess.file_exists(metadata_path):
			failed = true
			push_error("Missing Ogerpon back-sprite metadata: %s" % metadata_path)
