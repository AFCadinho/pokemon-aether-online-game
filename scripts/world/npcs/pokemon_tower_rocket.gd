@tool
extends TrainerNPC

## The rescued tower must have neither visible Rockets nor invisible vision
## challenges, including on old saves and while progress metadata refreshes.
func supports_trainer_rematches() -> bool:
	return false


func _can_auto_challenge() -> bool:
	return (
		visible and story_visibility_active
		and _story_requirement_met("rescue_mr_fuji", "rescue_fuji", "active")
		and super._can_auto_challenge()
	)
