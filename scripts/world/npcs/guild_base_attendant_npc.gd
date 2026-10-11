@tool
extends DialogueNPC

@export_enum("directory", "lift") var service_kind := "directory"
var guild_service: Node

func _ready() -> void:
	if not Engine.is_editor_hint():
		if guild_service == null:
			guild_service = get_node("/root/GuildService")
		display_name = LocalizationManager.text("npc.guild_base." + service_kind)
	super._ready()

func _loads_pickpocket_profile_from_npc_metadata() -> bool:
	return false

func _prefetches_dialogue_metadata_on_approach() -> bool:
	return false

func interact_with_player(_player: Node2D) -> void:
	var world: Node = GameState.get_world()
	if world == null:
		return
	var synced: Dictionary = await world.sync_player_position_for_world_action()
	if not bool(synced.get("success", false)):
		await GameErrorDialogService.show_response(synced)
		return
	var result: Dictionary = await guild_service.base_room_directory(service_kind == "lift")
	if not bool(result.get("success", false)):
		await GameErrorDialogService.show_response(result)
		return
	var menu := preload("res://scripts/ui/guild_base_room_directory.gd").new()
	world.add_child(menu)
	menu.open(result.state, service_kind == "lift")
	var floor: int = await menu.resolved
	if floor < 0:
		return
	var begun: Dictionary = await world.begin_authorized_teleport(true, true)
	if not bool(begun.get("success", false)):
		await GameErrorDialogService.show_response(begun)
		return
	var travel: Dictionary = await guild_service.base_lift_travel(floor)
	if not bool(travel.get("success", false)):
		world.cancel_authorized_teleport()
		await GameErrorDialogService.show_response(travel)
		return
	# The NPC is freed during map replacement, so release its legacy interaction
	# lock before handing off. The world already owns the teleport input lock.
	GameState.unlock_overworld_input()
	# Let the NPC interaction finish before map replacement destroys it.
	world.call_deferred("apply_authorized_teleport_state", travel.state)


func _sync_nameplate() -> void:
	super._sync_nameplate()
	if nameplate == null or nameplate_background == null or not is_inside_tree():
		return
	var map: Node = get_parent()
	while map != null and not map.has_node("FloorVisibilityMask"):
		map = map.get_parent()
	if not map is Node2D:
		return
	var region: Rect2 = map.get_node("FloorVisibilityMask").get_active_floor_region()
	var npc_position: Vector2 = map.to_local(global_position)
	var left := npc_position.x + nameplate.position.x + nameplate_background.offset_left
	var right := npc_position.x + nameplate.position.x + nameplate_background.offset_right
	# Both attendants stand near a side wall. Keep their localized labels clear
	# of the room's visibility mask rather than clipping the service name.
	var shift := maxf(region.position.x + 4 - left, 0)
	shift = minf(shift, region.end.x - 4 - right)
	nameplate.position.x += shift
