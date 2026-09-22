extends RefCounted
## Move semantics are shared; which native clip represents a semantic family is
## reviewed per model. An unreviewed or unavailable mapping always uses the
## established physical_attack clip.
const MOVE_FAMILIES := {
	"bite": [
		"bite", "bug-bite", "crunch", "fire-fang", "fishious-rend",
		"hyper-fang", "ice-fang", "jaw-lock", "poison-fang", "psychic-fangs",
		"thunder-fang"
	],
	"claw": [
		"cross-poison", "crush-claw", "dragon-claw", "fury-cutter",
		"metal-claw", "night-slash", "scratch", "shadow-claw", "slash",
		"solar-blade", "x-scissor"
	],
}
const ALLOWED_ACTIONS := ["physical_attack", "physical_attack_2"]

static func move_key(move_name: String) -> String:
	return move_name.strip_edges().to_lower().replace(" ", "-").replace("_", "-")

static func family_for(move_name: String) -> String:
	var key := move_key(move_name)
	for family: String in MOVE_FAMILIES:
		if key in MOVE_FAMILIES[family]:
			return family
	return ""

static func request_for(move_name: String, reviewed_family_actions: Dictionary) -> String:
	var family := family_for(move_name)
	var requested := str(reviewed_family_actions.get(family, "physical_attack"))
	return requested if requested in ALLOWED_ACTIONS else "physical_attack"
