extends SceneTree

const OAK_SCENE := "res://scenes/overworld/kanto/towns/pallet_town/oaks_lab.tscn"
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


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		push_error("FAIL " + label)
