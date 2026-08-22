@tool
extends DialogueNPC

class_name TransitKeeperNPC

const TransitMenuScript := preload("res://scripts/ui/transit_menu.gd")

@export var local_destination_id := ""


func _loads_pickpocket_profile_from_npc_metadata() -> bool:
	# Transit Keepers use localized client copy and the transit network service.
	return false


func _prefetches_dialogue_metadata_on_approach() -> bool:
	return false


func interact_with_player(_player: Node2D) -> void:
	var network_result: Dictionary = await TransitService.load_network()
	if not bool(network_result.get("success", false)):
		await GameErrorDialogService.show_response(network_result, "backend.error.transit_unavailable")
		return
	var network := network_result.get("body", {}) as Dictionary
	if (
		not local_destination_id.is_empty()
		and str(network.get("localDestinationId", "")) == local_destination_id
		and not bool(network.get("localAttuned", false))
	):
		await show_dialogue([LocalizationManager.text("npc.transit.attune_beacon_hint")])
		return

	var menu := TransitMenuScript.new() as TransitMenu
	get_tree().current_scene.add_child(menu)
	menu.open(network)
	var destination_id: String = await menu.resolved
	if destination_id.is_empty():
		return
	var world := get_tree().current_scene
	if world == null or not world.has_method("begin_authorized_teleport") or not world.has_method("apply_authorized_teleport_state"):
		await show_dialogue([LocalizationManager.text("npc.transit.unavailable")])
		return
	var begin_result: Dictionary = await world.call("begin_authorized_teleport", true, true)
	if not bool(begin_result.get("success", false)):
		await GameErrorDialogService.show_response(begin_result, "backend.error.transit_unavailable")
		return
	var travel_result: Dictionary = await TransitService.travel(destination_id)
	if not bool(travel_result.get("success", false)):
		world.call("cancel_authorized_teleport")
		await GameErrorDialogService.show_response(travel_result, "backend.error.transit_unavailable")
		return
	var body := travel_result.get("body", {}) as Dictionary
	PlayerWalletService.apply_wallet_result({"success": true, "wallet": body.get("wallet", {})})
	var apply_result: Dictionary = await world.call("apply_authorized_teleport_state", body.get("state", {}))
	if not bool(apply_result.get("success", false)):
		await GameErrorDialogService.show_response(apply_result, "backend.error.transit_unavailable")
