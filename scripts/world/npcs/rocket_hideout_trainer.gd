@tool
extends TrainerNPC

const QUEST := "confront_team_rocket_boss"

func supports_trainer_rematches() -> bool:
	return false

func _refresh_rematch_marker() -> void:
	super._refresh_rematch_marker()
	if trainer_id == "kanto_rocket_hideout_giovanni" and rematch_marker != null:
		# The main-quest marker owns this space above Giovanni's nameplate.
		rematch_marker.visible = false

func interact_with_player(player: Node2D) -> void:
	if trainer_id == "kanto_rocket_hideout_giovanni" and StoryService.is_requirement_met(QUEST, "learn_plan", "active"):
		await $AfterBattleHook.try_handle_interaction(self, player, "interact")
		return
	await super.interact_with_player(player)
