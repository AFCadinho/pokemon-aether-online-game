extends SceneTree

const TrainerPortraitCatalogScript := preload("res://scripts/services/trainer_portrait_catalog.gd")
const SCENE_PATHS: Array[String] = [
	"res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn",
	"res://scenes/overworld/kanto/towns/cerulean_city/bike_store.tscn",
	"res://scenes/overworld/kanto/towns/cerulean_city/cerulean_gym.tscn",
	"res://scenes/overworld/kanto/towns/cerulean_city/house1.tscn",
	"res://scenes/overworld/kanto/towns/cerulean_city/house2.tscn",
	"res://scenes/overworld/kanto/towns/cerulean_city/house3.tscn",
	"res://scenes/overworld/kanto/towns/cerulean_city/pokemon_center.tscn",
	"res://scenes/overworld/kanto/routes/kanto_route_24.tscn",
	"res://scenes/overworld/kanto/routes/route25/kanto_route_25.tscn",
	"res://scenes/overworld/kanto/routes/route25/bills_house.tscn",
]
const INHERITED_INTERIOR_PORTRAITS := {
	"aether_atelier_tailor": "showdown_beauty_gen6",
}
const INHERITED_NPC_DEFINITIONS := {
	"kanto_cerulean_city_pokemon_center_nurse_joy": "pokemon_center_nurse",
	"kanto_cerulean_city_pokemon_center_clerk": "pokemart_seller",
	"kanto_cerulean_city_pokemon_center_clerk_2": "pokemart_buyer",
}
const INHERITED_NODE_PORTRAITS := {
	"CeruleanCaveAgent": "showdown_policeman_gen8",
	"TransitKeeper": "showdown_psychic_gen6",
}
const INHERITED_SOURCE_REQUIREMENTS: Array[Dictionary] = [
	{
		"path": "res://scenes/npcs/gate_npc.tscn",
		"marker": "res://assets/sprites/trainer_cards/showdown/policeman-gen8.png",
	},
	{
		"path": "res://scenes/npcs/transit_keeper_npc.tscn",
		"marker": 'portrait_id = "showdown_psychic_gen6"',
	},
	{
		"path": "res://scenes/npcs/heal_npc.tscn",
		"marker": 'npc_definition_id = "pokemon_center_nurse"',
	},
	{
		"path": "res://scenes/npcs/market_seller_npc.tscn",
		"marker": 'npc_definition_id = "pokemart_seller"',
	},
	{
		"path": "res://scenes/npcs/market_buyer_npc.tscn",
		"marker": 'npc_definition_id = "pokemart_buyer"',
	},
]

var failed := false
var portrait_catalog: Node
var checked_npc_count := 0


func _init() -> void:
	portrait_catalog = TrainerPortraitCatalogScript.new()
	for scene_path: String in SCENE_PATHS:
		_check_scene_source(scene_path)
	_check_inherited_interior_portraits()
	_check(checked_npc_count >= 45, "all 45 NPCs in the requested areas are audited")
	portrait_catalog.free()
	quit(1 if failed else 0)


func _check_scene_source(scene_path: String) -> void:
	var source := FileAccess.get_file_as_string(scene_path)
	_check(not source.is_empty(), "%s is readable" % scene_path)
	if source.is_empty():
		return
	for block: String in source.split("\n[node "):
		var header_end := block.find("\n")
		if header_end < 0:
			continue
		var header := block.left(header_end)
		if not header.contains('parent="Entities/NPCs"'):
			continue
		checked_npc_count += 1
		var npc_name := _quoted_header_value(header, "name")
		var npc_id := _quoted_property(block, "npc_id")
		var definition_id := _quoted_property(block, "npc_definition_id")
		if definition_id.is_empty() and INHERITED_NPC_DEFINITIONS.has(npc_id):
			definition_id = str(INHERITED_NPC_DEFINITIONS[npc_id])
		var explicit_portrait_id := _quoted_property(block, "portrait_id")
		if explicit_portrait_id.is_empty() and INHERITED_NODE_PORTRAITS.has(npc_name):
			explicit_portrait_id = str(INHERITED_NODE_PORTRAITS[npc_name])
		var resolved_portrait_id: String = portrait_catalog.call(
			"resolve_portrait_id",
			explicit_portrait_id,
			npc_id,
			definition_id
		)
		var has_catalog_portrait := (
			not resolved_portrait_id.is_empty()
			and bool(portrait_catalog.call("has_portrait", resolved_portrait_id))
		)
		var has_custom_mugshot := _has_property(block, "mugshot")
		_check(
			has_catalog_portrait or has_custom_mugshot,
			"%s/%s resolves a non-default mugshot (npc_id=%s, definition=%s)" % [
				scene_path,
				npc_name,
				npc_id,
				definition_id,
			]
		)


func _check_inherited_interior_portraits() -> void:
	for requirement: Dictionary in INHERITED_SOURCE_REQUIREMENTS:
		var source_path := str(requirement.get("path", ""))
		var source := FileAccess.get_file_as_string(source_path)
		var marker := str(requirement.get("marker", ""))
		_check(
			not source.is_empty() and source.contains(marker),
			"%s retains inherited portrait marker %s" % [source_path, marker]
		)
	var template_source := FileAccess.get_file_as_string(
		"res://scenes/overworld/kanto/reusable_interiors/pokemon_center_template.tscn"
	)
	for definition_id: String in INHERITED_INTERIOR_PORTRAITS:
		checked_npc_count += 1
		var expected_portrait_id := str(INHERITED_INTERIOR_PORTRAITS[definition_id])
		var resolved_portrait_id: String = portrait_catalog.call(
			"resolve_portrait_id", "", "", definition_id
		)
		_check(
			template_source.contains("AetherAtelier"),
			"Cerulean's inherited interior includes %s" % definition_id
		)
		_check(
			resolved_portrait_id == expected_portrait_id
			and bool(portrait_catalog.call("has_portrait", resolved_portrait_id)),
			"%s resolves %s" % [definition_id, expected_portrait_id]
		)


func _quoted_header_value(header: String, key: String) -> String:
	var marker := '%s="' % key
	var start := header.find(marker)
	if start < 0:
		return ""
	start += marker.length()
	var finish := header.find('"', start)
	return header.substr(start, finish - start) if finish >= start else ""


func _quoted_property(block: String, key: String) -> String:
	var marker := "\n%s = \"" % key
	var start := block.find(marker)
	if start < 0:
		return ""
	start += marker.length()
	var finish := block.find('"', start)
	return block.substr(start, finish - start) if finish >= start else ""


func _has_property(block: String, key: String) -> bool:
	return block.contains("\n%s = " % key)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
