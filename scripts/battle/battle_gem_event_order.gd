extends RefCounted
## Gems are reported after the move announcement, before its hit. Present the
## offensive activation before starting that move's animation. Keep event data
## and the authoritative damage/consumption results intact.

const GEM_TYPES := ["normal", "fire", "water", "electric", "grass", "ice", "fighting", "poison", "ground", "flying", "psychic", "bug", "rock", "ghost", "dragon", "dark", "steel", "fairy"]

static func before_moves(events: Array) -> Array:
	var ordered := events.duplicate()
	for index in ordered.size():
		if not ordered[index] is Dictionary or ordered[index].get("type") != "move":
			continue
		var actor := _slot(str(ordered[index].get("actor", "")))
		if actor.is_empty():
			continue
		for next in range(index + 1, ordered.size()):
			if not ordered[next] is Dictionary:
				break
			var event: Dictionary = ordered[next]
			if _is_gem_activation(event) and _slot(str(event.get("target", ""))) == actor:
				ordered.remove_at(next)
				ordered.insert(index, event)
				break
			# Never pull an activation across damage, another item/action, a
			# charge turn, or a switch. Only pre-hit metadata may intervene.
			if event.get("type") not in ["criticalHit", "effectiveness", "ability"]:
				break
	return ordered

static func _is_gem_activation(event: Dictionary) -> bool:
	if event.get("type") != "item" or event.get("state") != "end":
		return false
	var source := str(event.get("source", "")).strip_edges().to_lower()
	if source == "gem":
		return true
	if not source.is_empty():
		return false # Fling/Knock Off and other removals are not activations.
	# Older public recordings may omit the source marker.
	var item := str(event.get("item", "")).to_lower().replace(" ", "").replace("-", "")
	return item.ends_with("gem") and item.trim_suffix("gem") in GEM_TYPES

static func _slot(ident: String) -> String:
	return ident.get_slice(":", 0).strip_edges().to_lower()
