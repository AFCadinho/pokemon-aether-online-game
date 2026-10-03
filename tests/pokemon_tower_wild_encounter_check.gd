extends SceneTree

const TOWER := "res://scenes/overworld/kanto/towns/lavender_town/pokemon_tower.tscn"
const Provider := preload("res://scripts/world/map_encounter_provider.gd")
var failures := 0

class FeetProbe extends Node2D:
	var feet_offset := Vector2.ZERO
	func get_feet_position() -> Vector2:
		return global_position + feet_offset

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var map := (load(TOWER) as PackedScene).instantiate()
	# Exercise gameplay lookup without making NPC/dialogue requests.
	for holder in ["Entities/NPCs", "Entities/Pokemon"]:
		for entity in map.get_node(holder).get_children():
			entity.free()
	var player := FeetProbe.new()
	player.name = "Player"
	player.feet_offset = Vector2(0, 16)
	map.get_node("Entities/Players").add_child(player)
	map.position = Vector2(64, 96)
	root.add_child(map)
	var mask := map.get_node("FloorVisibilityMask")
	_check(map.get_battle_environment_id() == "cave", "Tower walking uses cave encounters")
	_check(is_equal_approx(map.cave_encounter_chance, 0.07), "Tower uses existing cave step frequency")
	_check(map.encounter_area_id.is_empty(), "No map-wide fallback can enable encounters on 1F/2F")
	_check(map.get_node("EncounterRegions").get_child_count() == 6, "Five encounter floors and one safe seal")
	map.cave_encounter_chance = 1.0
	seed(123)
	for floor_number in range(1, 8):
		var floor_name := StringName("floor_%d" % floor_number)
		var bounds: Rect2 = mask.floor_regions[floor_name]
		var feet_position := Vector2(1488, 1360) if floor_number == 5 else bounds.get_center()
		player.position = feet_position - player.feet_offset
		mask.show_floor(&"floor_1")
		var encounter := Provider.resolve_wild_encounter(map, player.get_feet_position(), "cave")
		if floor_number < 3:
			_check(map.get_wild_encounter_area_id().is_empty(), "%dF has no encounter area" % floor_number)
			_check(not encounter.available, "%dF cannot resolve a wild encounter" % floor_number)
			for attempt in 10:
				_check(not map.should_trigger_wild_encounter("cave"), "%dF never rolls a battle" % floor_number)
		else:
			var expected := "kanto_pokemon_tower_%df" % floor_number
			_check(map.get_wild_encounter_area_id() == expected, "%dF selects the correct table before mask update" % floor_number)
			_check(encounter.available and encounter.area_id == expected and encounter.encounter_type == "cave", "%dF uses its cave region" % floor_number)
			_check(encounter.use_map_trigger, "Floor encounter uses the Tower chance policy")
			_check(map.should_trigger_wild_encounter("cave"), "%dF can trigger battles" % floor_number)
		for method in ["grass", "surf", "old_rod", "good_rod", "super_rod"]:
			_check(not map.should_trigger_wild_encounter(method), "Tower has no " + method + " encounters")
	# Restored floor/stair positions must select the right table independently of mask timing.
	for spawn in map.get_node("Spawns").get_children():
		player.position = spawn.position - player.feet_offset
		mask.show_floor(&"floor_1")
		var expected := ""
		for number in range(3, 8):
			if mask.floor_regions[StringName("floor_%d" % number)].has_point(spawn.position):
				expected = "kanto_pokemon_tower_%df" % number
		_check(map.get_wild_encounter_area_id() == expected, "Arrival resolves its own floor: " + spawn.name)
	# Every tile occupied by the cyan seal stays safe, including the healing respawn.
	var seal: Rect2 = map.get_node("EncounterRegions/HealingSeal").get_meta("pao_region_rect")
	var details := map.get_node("Visual/GroundDetail") as TileMapLayer
	var checked_seal_tiles := 0
	for cell in details.get_used_cells():
		var local_feet := Vector2(cell * 32) + Vector2(16, 16)
		if not mask.floor_regions[&"floor_5"].has_point(local_feet):
			continue
		checked_seal_tiles += 1
		_check(seal.has_point(local_feet), "Safe zone covers every cyan tile")
		player.position = local_feet - player.feet_offset
		var encounter := Provider.resolve_wild_encounter(map, player.get_feet_position(), "cave")
		_check(encounter.region_id == "pokemon_tower_healing_seal", "Seal takes priority over the 5F region")
		_check(encounter.use_map_trigger and not map.should_trigger_wild_encounter("cave"), "Seal cannot start a wild battle")
		_check(map.get_wild_encounter_area_id() == "kanto_pokemon_tower_5f", "Safe zone keeps 5F encounter information accessible")
	_check(checked_seal_tiles == 16, "All sixteen cyan seal tiles checked")
	player.position = Vector2(1488, 1360) - player.feet_offset
	_check(map.should_trigger_wild_encounter("cave"), "Walking away from the seal enables 5F encounters")
	map.cave_encounter_chance = 0.0
	_check(not map.should_trigger_wild_encounter("cave"), "Zero chance cannot roll a battle")
	player.position = Vector2(-32, -32) - player.feet_offset
	_check(map.get_wild_encounter_area_id().is_empty(), "Outside floor bounds has no encounter area")
	_check(not Provider.resolve_wild_encounter(map, player.get_feet_position(), "cave").available, "Outside floors cannot use a fallback table")
	map.free()
	if failures == 0:
		print("POKEMON_TOWER_WILD_ENCOUNTERS PASS: 3F–7F tables, no 1F/2F battles, safe 5F seal, immediate arrival/save lookup")
	quit(1 if failures else 0)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)
