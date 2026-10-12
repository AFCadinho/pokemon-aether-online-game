extends "catalog_urshifu_battle_review.gd"
## Apply the declared conservative idle clearance margin, then measure at 120 Hz.
func _measure(entry: Dictionary, model: Node3D, player: AnimationPlayer) -> Dictionary:
	var measured: Dictionary = await super._measure(entry, model, player)
	var path := OS.get_environment("POKEAETHER_PHASE5_CANDIDATES")
	if path.is_empty() or entry.species == "dragonite":
		return measured
	var proposal: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	if proposal.has("all_clip_clearance_pad"):
		assert(is_equal_approx(float(proposal.all_clip_clearance_pad), .001))
		measured.candidate_lift += .001
		for action in measured.clips:
			measured.clips[action].clearance_with_idle_lift += .001
		measured["recovery_clearance_pad"] = .001
	return measured
