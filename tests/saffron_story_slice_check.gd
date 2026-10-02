extends SceneTree

const OAK_SCENE := "res://scenes/overworld/kanto/towns/pallet_town/oaks_lab.tscn"
const LAVENDER_SCENE := "res://scenes/overworld/kanto/towns/lavender_town/lavender_town.tscn"
const LAVENDER_CENTER_SCENE := "res://scenes/overworld/kanto/towns/lavender_town/pokemon_center.tscn"
const GATE_SCENE := "res://scenes/overworld/kanto/transition_buildings/route_6_saffron_gate.tscn"
const ROUTE_5_GATE_SCENE := "res://scenes/overworld/kanto/transition_buildings/route_5_saffron_gate.tscn"
const STORY_HOOK_SCRIPT := "res://scripts/world/story/story_hook.gd"

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_check_gate()
	_check_route_5_gate()
	_check_oak()
	_check_lavender()
	_check_lavender_pokemon_center()
	quit(1 if failures > 0 else 0)


func _check_gate() -> void:
	var packed := load(GATE_SCENE) as PackedScene
	_check(packed != null, "Route 6 Saffron gate scene loads")
	if packed == null:
		return
	var gate := packed.instantiate()
	var npc := gate.get_node_or_null("Entities/NPCs/GateNPC")
	_check(npc != null, "Route 6 gate attendant is present")
	if npc != null:
		_check(npc.get("preload_quest_markers") == true, "gate attendant preloads active quest markers")
		_check(npc.get("blocked_dialogue_id") == "kanto_route_6_saffron_gate_unsafe", "gate attendant uses the lockdown dialogue")
		_check(
			npc.get("guard_role") == "transition_guard"
			and npc.get("guarded_transition_id") == "kanto_route_6_saffron_gate__to_saffron_city",
			"Route 6 attendant presents denied Saffron entry as the guard"
		)
		var hook := npc.get_node_or_null("SaffronClosedStoryHook")
		var hook_script: Script = hook.get_script() as Script if hook != null else null
		_check(hook_script != null and hook_script.resource_path == STORY_HOOK_SCRIPT, "gate attendant has a story interaction hook")
		if hook != null:
			_check(hook.get("interaction_id") == "kanto_route_6_saffron_gate_closed", "gate hook records the expected quest event")
	gate.free()


func _check_route_5_gate() -> void:
	var packed := load(ROUTE_5_GATE_SCENE) as PackedScene
	_check(packed != null, "Route 5 Saffron gate scene loads")
	if packed == null:
		return
	var gate := packed.instantiate()
	var npc := gate.get_node_or_null("Entities/NPCs/GateNPC")
	_check(
		npc != null
		and npc.get("guard_role") == "transition_guard"
		and npc.get("guarded_transition_id") == "kanto_route_5_saffron_gate__to_saffron_city",
		"Route 5 attendant also presents denied Saffron entry as the guard"
	)
	gate.free()


func _check_oak() -> void:
	var packed := load(OAK_SCENE) as PackedScene
	_check(packed != null, "Oak's Lab scene loads")
	if packed == null:
		return
	var lab := packed.instantiate()
	var oak := lab.get_node_or_null("Entities/NPCs/Oak")
	_check(oak != null, "Professor Oak is present")
	if oak != null:
		var parcel_hook := oak.get_node_or_null("ParcelRequestStoryHook")
		var advice_hook := oak.get_node_or_null("RockTunnelAdviceStoryHook")
		_check(parcel_hook != null, "Oak retains the Parcel story interaction")
		_check(advice_hook != null, "Oak has a separate Rock Tunnel advice interaction")
		if advice_hook != null:
			_check(advice_hook.get("interaction_id") == "kanto_oaks_lab_oak_rock_tunnel_advice", "Oak advice hook matches the main quest catalog")
	lab.free()


func _check_lavender() -> void:
	var packed := load(LAVENDER_SCENE) as PackedScene
	_check(packed != null, "Lavender Town scene loads")
	if packed == null:
		return
	var town := packed.instantiate()
	var resident := town.get_node_or_null("Entities/NPCs/LavenderResident")
	var arrival := town.get_node_or_null("StoryTriggers/LavenderArrival")
	_check(resident != null, "Lavender resident is present")
	_check(arrival != null, "Lavender arrival warning trigger is present")
	_check(town.get_node_or_null("Entities/NPCs/TowerWatcher") != null, "Lavender Tower watcher is present")
	_check(town.get_node_or_null("Entities/NPCs/PokecenterVisitor") != null, "Lavender Pokémon Center visitor is present")
	_check(town.get_node_or_null("Entities/Pokemon/Meowth") != null, "Meowth appears in Lavender Town")
	_check(town.get_node_or_null("Entities/Pokemon/Cubone") == null, "Cubone is reserved for Mr. Fuji's future home")
	_check(town.get_node_or_null("Entities/Pokemon/Clefairy") != null, "Clefairy appears in Lavender Town")
	var collision_layer := town.get_node("Tiles/Collision") as TileMapLayer
	for node_path: NodePath in [
		NodePath("Entities/NPCs/LavenderResident"),
		NodePath("Entities/NPCs/TowerWatcher"),
		NodePath("Entities/NPCs/PokecenterVisitor"),
		NodePath("Entities/Pokemon/Meowth"),
		NodePath("Entities/Pokemon/Clefairy"),
	]:
		var actor := town.get_node_or_null(node_path) as Node2D
		_check(
			actor != null and collision_layer.get_cell_source_id(collision_layer.local_to_map(actor.position)) == -1,
			"%s is placed on an unblocked Lavender tile" % node_path
		)
	var center_exit := town.get_node_or_null("Exits/ToPokecenter")
	_check(
		center_exit != null
		and center_exit.get("target_scene_path") == LAVENDER_CENTER_SCENE,
		"Lavender Town exit connects to its Pokémon Center"
	)
	var beacon := town.get_node_or_null("Entities/Interactables/AetherBeacon")
	var keeper := town.get_node_or_null("Entities/NPCs/TransitKeeperNPC")
	var transit_arrival := town.get_node_or_null("Spawns/TransitArrival") as Marker2D
	_check(beacon != null and beacon.get("destination_id") == "kanto_lavender_town", "Lavender Beacon attunes the Aethernet destination")
	_check(keeper != null and keeper.get("local_destination_id") == "kanto_lavender_town", "Lavender Keeper opens the local Aethernet destination")
	_check(transit_arrival != null and transit_arrival.position == Vector2(752, 784), "Lavender has the server-owned Aethernet arrival point")
	if transit_arrival != null:
		_check(collision_layer.get_cell_source_id(collision_layer.local_to_map(transit_arrival.position)) == -1, "Aethernet arrival point has no terrain collision")
	if arrival != null:
		_check(arrival.get("required_quest_id") == "travel_to_lavender_town", "arrival warning is tied to the Lavender quest")
		var hook := arrival.get_node_or_null("StoryHook")
		_check(hook != null and hook.get("interaction_id") == "kanto_lavender_town_resident_warning", "arrival trigger records the warning interaction")
	town.free()


func _check_lavender_pokemon_center() -> void:
	var packed := load(LAVENDER_CENTER_SCENE) as PackedScene
	_check(packed != null, "Lavender Pokémon Center scene loads")
	if packed == null:
		return
	var center := packed.instantiate()
	_check(center.get("map_id") == "kanto_lavender_town_pokemon_center", "center has its world map ID")
	_check(center.get_node_or_null("Entities/Pokemon/Cubone") == null, "Cubone is not left in the Pokémon Center")
	_check(
		center.get_node_or_null("Exits/ToOutside") != null
		and center.get_node("Exits/ToOutside").get("target_scene_path") == LAVENDER_SCENE,
		"center return exit points back to Lavender Town"
	)
	_check(
		center.get_node_or_null("Entities/NPCs/NurseJoy") != null,
		"Lavender Pokémon Center has Nurse Joy"
	)
	center.free()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		push_error("FAIL " + label)
