extends SceneTree

const MAP_NPCS := {
	"res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn": ["Entities/NPCs/PalletResident"],
	"res://scenes/overworld/kanto/towns/pallet_town/oaks_lab.tscn": ["Entities/NPCs/ResearchAideNoah", "Entities/NPCs/ResearchAideEmma"],
	"res://scenes/overworld/kanto/towns/pallet_town/rivals_house.tscn": ["Entities/NPCs/DaisyOak"],
	"res://scenes/overworld/kanto/routes/kanto_route_1.tscn": ["Entities/NPCs/YoungsterLiam", "Entities/NPCs/LassZoe", "Entities/NPCs/Dialogue/MartEmployee", "Entities/NPCs/Dialogue/CamperQuinn"],
	"res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn": ["Entities/NPCs/LeagueFanDorian", "Entities/NPCs/ForestScoutNico", "Entities/NPCs/SchoolKidJune", "Entities/NPCs/CatchingMentorGideon"],
	"res://scenes/overworld/kanto/routes/kanto_route_22.tscn": ["Entities/NPCs/GaryOak", "Entities/NPCs/LeagueHikerGrant", "Entities/NPCs/YoungsterCaleb", "Entities/NPCs/LassPaige"],
	"res://scenes/overworld/kanto/routes/kanto_route_2.tscn": ["Entities/NPCs/CaveResearcherOwen", "Entities/NPCs/ForestWatcherIvy", "Entities/NPCs/YoungsterMason", "Entities/NPCs/BugCatcherCale"],
	"res://scenes/overworld/kanto/routes/viridian_forest.tscn": ["Entities/NPCs/BugCatcherRick", "Entities/NPCs/BugCatcherDoug", "Entities/NPCs/BugCatcherAnthony", "Entities/NPCs/BugCatcherSammy", "Entities/NPCs/LostCamperDana", "Entities/NPCs/ForestResearcherLeah"],
	"res://scenes/overworld/kanto/towns/pewter_city/pewter_city.tscn": ["Entities/NPCs/MuseumGuideTheo", "Entities/NPCs/HikerBruno", "Entities/NPCs/GymFanMax", "Entities/NPCs/DigSiteWorkerCole", "Entities/NPCs/PewterResidentNora"],
}

const CLASS_FRAME_PATHS := [
	"res://assets/npcs/classes/blue_frames.tres",
	"res://assets/npcs/classes/bug_catcher_frames.tres",
	"res://assets/npcs/classes/camper_frames.tres",
	"res://assets/npcs/classes/elder_frames.tres",
	"res://assets/npcs/classes/hiker_frames.tres",
	"res://assets/npcs/classes/lass_frames.tres",
	"res://assets/npcs/classes/mart_m_frames.tres",
	"res://assets/npcs/classes/poke_fan_f_frames.tres",
	"res://assets/npcs/classes/school_kid_f_frames.tres",
	"res://assets/npcs/classes/school_kid_m_frames.tres",
	"res://assets/npcs/classes/scientist_f_frames.tres",
	"res://assets/npcs/classes/scientist_m_frames.tres",
	"res://assets/npcs/classes/worker_frames.tres",
	"res://assets/npcs/classes/youngster_frames.tres",
]

const TRANSITION_ATTENDANTS := {
	"res://scenes/overworld/kanto/transition_buildings/route_2_gate.tscn": "kanto_route_2_gate_attendant",
	"res://scenes/overworld/kanto/transition_buildings/route_2_viridian_forest_north_gate.tscn": "kanto_viridian_forest_north_gate_attendant",
	"res://scenes/overworld/kanto/transition_buildings/route_2_viridian_forest_south_gate.tscn": "kanto_viridian_forest_south_gate_attendant",
}

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_removed_placeholders()
	_check_class_frames()
	for scene_path: String in MAP_NPCS:
		_check_map(scene_path, MAP_NPCS[scene_path])
	for scene_path: String in TRANSITION_ATTENDANTS:
		_check_transition_attendant(scene_path, TRANSITION_ATTENDANTS[scene_path])
	quit(1 if failed else 0)


func _check_removed_placeholders() -> void:
	var route_1 := FileAccess.get_file_as_string("res://scenes/overworld/kanto/routes/kanto_route_1.tscn")
	for old_id: String in ["kanto_route_1_alder", "kanto_route_1_bug_catcher_big_d", "kanto_route_1_cynthia", "kanto_route_1_gary"]:
		_check(not route_1.contains('npc_id = "%s"' % old_id), "Route 1 removed placeholder %s" % old_id)
	var pallet := FileAccess.get_file_as_string("res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn")
	var viridian := FileAccess.get_file_as_string("res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn")
	_check(not pallet.contains('[node name="AshKetchum"'), "Pallet Town removed the Red test battle")
	_check(not viridian.contains('[node name="AshKetchum"'), "Viridian City removed the Red test battle")
	var pewter := FileAccess.get_file_as_string("res://scenes/overworld/kanto/towns/pewter_city/pewter_city.tscn")
	_check(not pewter.contains('[node name="AlphaGymMisty"'), "Misty is not placed in Pewter City")
	_check(not pewter.contains('[node name="AlphaGymLtSurge"'), "Lt. Surge is not placed in Pewter City")


func _check_class_frames() -> void:
	for frame_path: String in CLASS_FRAME_PATHS:
		var frames := load(frame_path) as SpriteFrames
		_check(frames != null, "%s loads" % frame_path.get_file())
		if frames == null:
			continue
		_check(frames.get_frame_count("default") == 1, "%s exposes its source atlas" % frame_path.get_file())


func _check_map(scene_path: String, npc_paths: Array) -> void:
	var packed := load(scene_path) as PackedScene
	_check(packed != null, "%s loads" % scene_path.get_file())
	if packed == null:
		return
	var map := packed.instantiate()
	var collision := map.get_node_or_null("Collision") as TileMapLayer
	_check(collision != null, "%s has collision data" % scene_path.get_file())
	for npc_path_value: Variant in npc_paths:
		var npc_path := str(npc_path_value)
		var npc := map.get_node_or_null(npc_path) as Node2D
		_check(npc != null, "%s places %s" % [scene_path.get_file(), npc_path.get_file()])
		if npc == null or collision == null:
			continue
		var npc_script := npc.get_script() as Script
		if npc_script != null and npc_script.resource_path == "res://scripts/world/npcs/dialogue_npc.gd":
			_check(
				str(npc.call("_get_npc_metadata_id")) == str(npc.get("npc_id")),
				"%s loads dialogue with its placed NPC identity" % npc_path.get_file()
			)
		var cell := collision.local_to_map(collision.to_local(npc.global_position))
		_check(collision.get_cell_source_id(cell) == -1, "%s stands on a walkable tile" % npc_path.get_file())
	map.free()


func _check_transition_attendant(scene_path: String, expected_npc_id: String) -> void:
	var packed := load(scene_path) as PackedScene
	_check(packed != null, "%s loads" % scene_path.get_file())
	if packed == null:
		return
	var map := packed.instantiate()
	var attendant := map.get_node_or_null("Entities/NPCs/GateNPC")
	_check(attendant != null, "%s places its attendant" % scene_path.get_file())
	if attendant != null:
		_check(attendant.npc_id == expected_npc_id, "%s uses unique attendant id" % scene_path.get_file())
		_check(not attendant.requires_party_pokemon, "%s attendant does not block passage" % scene_path.get_file())
	map.free()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
