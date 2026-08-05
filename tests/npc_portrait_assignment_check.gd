extends SceneTree

const PortraitCatalogScript := preload("res://scripts/services/trainer_portrait_catalog.gd")
const ASSIGNMENTS_PATH := "res://data/npc_portraits/npc_portrait_assignments.json"
const REQUIRED_NPC_IDS: Array[String] = [
	"kanto_alpha_gym_brock",
	"kanto_alpha_gym_lt_surge",
	"kanto_alpha_gym_misty",
	"kanto_oaklab_oak_1",
	"kanto_oaks_lab_gary",
	"kanto_pallet_town_fishing_guru",
	"kanto_pallet_town_north_guard",
	"kanto_pewter_city_pokemon_center_clerk",
	"kanto_pewter_city_pokemon_center_clerk_2",
	"kanto_pewter_city_pokemon_center_nurse_joy",
	"kanto_players_house_father",
	"kanto_players_house_mom",
	"kanto_route_1_dadinho",
	"kanto_rivals_house_daisy",
	"kanto_route_1_north_guard",
	"kanto_viridian_city_north_route_guard",
	"kanto_viridian_city_pokemon_center_clerk",
	"kanto_viridian_city_pokemon_center_clerk_2",
	"kanto_viridian_city_pokemon_center_nurse_joy",
	"kanto_viridian_city_south_route_guard",
	"kanto_viridian_city_west_route_guard",
]

var failed := false


func _init() -> void:
	var catalog := PortraitCatalogScript.new()
	root.add_child(catalog)
	var assignments := catalog.get_assignments()
	var npc_ids := assignments.get("npc_ids", {}) as Dictionary
	var definition_ids := assignments.get("npc_definition_ids", {}) as Dictionary
	var preserved := assignments.get("preserve_existing", []) as Array

	for npc_id: String in REQUIRED_NPC_IDS:
		_check_true(
			npc_ids.has(npc_id) or preserved.has(npc_id),
			"Existing NPC has a portrait assignment or explicit custom portrait: %s" % npc_id
		)
	for portrait_id: Variant in npc_ids.values():
		_check_true(catalog.has_portrait(str(portrait_id)), "NPC portrait exists: %s" % portrait_id)
	for portrait_id: Variant in definition_ids.values():
		_check_true(catalog.has_portrait(str(portrait_id)), "Profile portrait exists: %s" % portrait_id)

	_check_equal(
		catalog.resolve_portrait_id("", "kanto_oaklab_oak_1", ""),
		"showdown_oak",
		"Named NPC resolves its exact portrait"
	)
	_check_equal(
		catalog.resolve_portrait_id("", "kanto_alpha_gym_lt_surge", ""),
		"showdown_ltsurge",
		"Lt. Surge resolves his exact Showdown portrait"
	)
	_check_equal(
		catalog.resolve_portrait_id("", "unlisted_nurse", "pokemon_center_nurse"),
		"showdown_pokemoncenterlady",
		"Reusable NPC resolves its profile portrait"
	)
	_check_equal(
		catalog.resolve_portrait_id("showdown_red_lgpe", "kanto_oaklab_oak_1", ""),
		"showdown_red_lgpe",
		"Scene/profile override takes precedence"
	)
	_check_equal(
		catalog.resolve_portrait_id("", "kanto_players_house_father", "pokemart_seller"),
		"",
		"Dadinho preserves his custom portrait"
	)
	var oak_texture := catalog.get_texture("showdown_oak")
	_check_true(oak_texture != null, "Assigned portrait texture loads on demand")
	_check_true(catalog.get_texture("showdown_oak") == oak_texture, "Loaded portrait texture is cached")

	catalog.queue_free()
	quit(1 if failed else 0)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	_check_true(actual == expected, "%s (expected %s, got %s)" % [label, expected, actual])


func _check_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
