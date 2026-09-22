extends RefCounted
## Move semantics are shared; which native clip represents a semantic family is
## reviewed per model. An unreviewed or unavailable mapping always uses the
## established physical_attack clip.
const INTENTS = preload("res://data/physical_move_animation_intents.json")
const ALLOWED_ACTIONS := ["physical_attack", "physical_attack_2"]

static func move_key(move_name: String) -> String:
	return move_name.strip_edges().to_lower().replace(" ", "-").replace("_", "-")

static func family_for(move_name: String) -> String:
	var key := move_key(move_name)
	for family: String in INTENTS.data.families:
		if key in INTENTS.data.families[family]:
			return family
	return ""

static func request_for(move_name: String, reviewed_family_actions: Dictionary) -> String:
	var family := family_for(move_name)
	var requested := str(reviewed_family_actions.get(family, "physical_attack"))
	return requested if requested in ALLOWED_ACTIONS else "physical_attack"
