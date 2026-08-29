extends SceneTree

const ROUTE_25_SCENE := "res://scenes/overworld/kanto/routes/route25/kanto_route_25.tscn"
const BILLS_HOUSE_SCENE := "res://scenes/overworld/kanto/routes/route25/bills_house.tscn"

var failed := false


class SystemMessageOverlay extends Node:
	var messages: Array[String] = []

	func add_system_message(message: String) -> void:
		messages.append(message)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var system_overlay := SystemMessageOverlay.new()
	system_overlay.add_to_group("ui_overlay")
	root.add_child(system_overlay)
	root.get_node("StoryService").call("apply_story", {
		"revision": 1,
		"quests": [{
			"questId": "help_bill",
			"storylineId": "kanto_main",
			"definitionVersion": 1,
			"questType": "main",
			"titleKey": "story.kanto.help_bill.title",
			"summaryKey": "story.kanto.help_bill.summary",
			"status": "active",
			"steps": [{
				"stepId": "meet_bill",
				"objectiveKey": "story.kanto.help_bill.meet_bill",
				"status": "active",
				"currentValue": 0,
				"targetValue": 1,
			}],
		}],
	})
	var route_25 := await _instantiate_map(ROUTE_25_SCENE)
	var bills_house := await _instantiate_map(BILLS_HOUSE_SCENE)

	_check_transition(
		route_25,
		"Exits/ToBillsHouse",
		BILLS_HOUSE_SCENE,
		"FromRoute25",
		"kanto_route_25__to_bills_house"
	)
	_check_transition(
		bills_house,
		"Exits/ToRoute25",
		ROUTE_25_SCENE,
		"FromBillsHouse",
		"kanto_route_25_bills_house__to_route_25"
	)
	_check(route_25.get_node_or_null("Spawns/FromBillsHouse") is Marker2D, "Route 25 has Bill's House return spawn")
	_check(bills_house.get_node_or_null("Spawns/FromRoute25") is Marker2D, "Bill's House has its Route 25 arrival spawn")

	var visual := bills_house.get_node_or_null("BillsHouseVisual")
	_check(visual != null, "Bill's House instantiates its imported visual")
	if visual != null:
		var visual_map := visual.get_meta("tiled_visual_map", {}) as Dictionary
		_check(visual_map.get("width") == 25, "Bill's House preserves the 25-tile visual width")
		_check(visual_map.get("height") == 20, "Bill's House preserves the 20-tile visual height")
		for layer_name: String in ["Ground", "GroundDetail", "Objects", "ObjectsTop"]:
			_check(visual.get_node_or_null(layer_name) is TileMapLayer, "Bill's House preserves its %s layer" % layer_name)

	var collision := bills_house.find_map_tilemap_layer("Collision") as TileMapLayer
	_check(collision != null, "Bill's House has a collision layer ready for editing")
	_check(
		collision != null and not collision.get_used_cells().is_empty(),
		"Bill's House collision layer contains its imported collision"
	)

	var catalog_value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	var catalog := catalog_value as Dictionary if catalog_value is Dictionary else {}
	var areas := catalog.get("areas", {}) as Dictionary
	var transitions := catalog.get("transitions", {}) as Dictionary
	_check(areas.has("kanto_route_25_bills_house"), "World access catalog includes Bill's House")
	_check(transitions.has("kanto_route_25__to_bills_house"), "World access catalog includes the entrance transition")
	_check(transitions.has("kanto_route_25_bills_house__to_route_25"), "World access catalog includes the return transition")

	var trapped_bill := bills_house.get_node_or_null("Entities/NPCs/TrappedBill")
	var restored_bill := bills_house.get_node_or_null("Entities/NPCs/Bill")
	var computer := bills_house.get_node_or_null("Entities/Interactables/CellSeparatorComputer")
	_check(trapped_bill != null, "Bill begins the rescue inside a Clefairy body")
	_check(restored_bill != null, "Bill's human form is ready for the completed rescue state")
	_check(computer != null, "Bill's computer can activate the Cell Separation System")
	if trapped_bill != null:
		_check(trapped_bill.visible, "Clefairy-form Bill is visible while the rescue is active")
		_check(str(trapped_bill.get("display_name")) == "Clefairy", "Bill's transformed form is labeled Clefairy")
		_check(not bool(trapped_bill.get("dialogue_portrait_visible")), "Clefairy-form Bill does not fall back to Professor Oak's portrait")
		_check(trapped_bill.position == Vector2(464, 272), "Clefairy uses the edited machine position")
		_check(str(trapped_bill.get("visibility_required_quest_id")) == "help_bill", "trapped Bill follows the active rescue quest")
		var hook := trapped_bill.get_node_or_null("StoryHook")
		_check(hook != null and str(hook.get("interaction_id")) == "kanto_bills_house_meet_bill", "talking to trapped Bill advances the first rescue step")
	if restored_bill != null:
		_check(not restored_bill.visible, "human Bill stays hidden before separation")
		_check(str(restored_bill.get("visibility_required_quest_status")) == "completed", "human Bill appears after the rescue")
		_check(restored_bill.get("mugshot") is Texture2D, "human Bill has his dialogue mugshot")
	if computer != null:
		_check(str(computer.get("interactable_id")) == "kanto_bills_house_cell_separator_computer", "the computer uses its server story identity")
		_check(computer.get("blocked_tile_offset") == Vector2i(-1, 0), "the computer interaction follows its tile one cell to the left")
		var hook := computer.get_node_or_null("StoryHook")
		_check(hook != null and str(hook.get("interaction_id")) == "kanto_bills_house_activate_cell_separator", "the computer completes the separation step")
		_check(computer.get_node_or_null("MachineFlash") is Polygon2D, "the separation machine has a visible activation flash")
		var machine_source := FileAccess.get_file_as_string("res://scripts/world/kanto/routes/bills_house_machine.gd")
		_check(machine_source.contains("current_stage >= 2"), "Bill's human portrait only appears after cell separation")
		var interactable_source := FileAccess.get_file_as_string("res://scripts/world/interactables/world_interactable.gd")
		_check(interactable_source.contains("mugshot_override != null"), "the computer hides the default portrait when no mugshot is supplied")
		await computer.call("_play_cell_separation")
		_check(
			trapped_bill != null and restored_bill != null and not trapped_bill.visible and restored_bill.visible,
			"the machine replaces Clefairy-form Bill with human Bill"
		)
		var ticket_effects := [{
			"alreadyGranted": false,
			"grants": [{"itemId": "ss-ticket", "quantity": 1}],
		}]
		_check(bool(computer.call("_present_ticket_reward", ticket_effects)), "a new S.S. Ticket grant is presented")
		_check(system_overlay.messages.size() == 1 and system_overlay.messages[0].contains("S.S. Ticket"), "the S.S. Ticket produces a localized System message")
		var ticket_icon := load("res://assets/items/icons/SSTICKET.png") as Texture2D
		_check(ticket_icon != null and ticket_icon.get_size() == Vector2(48, 48), "the S.S. Ticket has a dedicated 48px pixel-art Bag icon")

	route_25.queue_free()
	bills_house.queue_free()
	system_overlay.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _instantiate_map(scene_path: String) -> Node:
	var packed := load(scene_path) as PackedScene
	_check(packed != null, "%s loads" % scene_path.get_file())
	if packed == null:
		return Node.new()
	var map := packed.instantiate()
	root.add_child(map)
	await process_frame
	return map


func _check_transition(map: Node, path: String, target_scene: String, target_spawn: String, transition_id: String) -> void:
	var exit := map.get_node_or_null(path)
	_check(exit != null, "%s has %s" % [map.name, path])
	if exit == null:
		return
	_check(exit.target_scene_path == target_scene, "%s targets the reciprocal scene" % path)
	_check(exit.target_spawn_name == target_spawn, "%s targets the reciprocal spawn" % path)
	_check(exit.transition_id == transition_id, "%s has a stable transition ID" % path)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
