@tool
extends DialogueNPC

## Fuji's two story placements share a map with other rooms/floors. Flush the
## player's actual position before the server checks his interaction location.
func _run_story_or_legacy_interaction(body: Node2D, trigger: String) -> Dictionary:
	var world: Node = GameState.get_world()
	if world == null or not world.has_method("sync_player_position_for_world_action"):
		return {"success": false, "handled": true, "status": "world_unavailable"}
	var result: Dictionary = await world.call("sync_player_position_for_world_action")
	if not bool(result.get("success", false)):
		await GameErrorDialogService.show_response(result)
		return {"success": false, "handled": true, "status": "position_sync_failed"}
	return await super._run_story_or_legacy_interaction(body, trigger)
