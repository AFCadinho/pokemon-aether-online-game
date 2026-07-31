extends RefCounted

class_name BattleDisguiseEventOrder


static func move_busted_form_changes_after_recoil(events: Array) -> Array:
	var ordered_events := events.duplicate()
	var form_index := 0
	while form_index < ordered_events.size():
		var event_value: Variant = ordered_events[form_index]
		if not (event_value is Dictionary) or not _is_disguise_busted_form_change(event_value as Dictionary):
			form_index += 1
			continue

		var form_event: Dictionary = event_value as Dictionary
		var recoil_index := _find_disguise_recoil_index(
			ordered_events,
			form_index + 1,
			str(form_event.get("target", ""))
		)
		if recoil_index < 0:
			form_index += 1
			continue

		ordered_events.remove_at(form_index)
		# Removing the earlier form event shifts the recoil one slot left. Inserting
		# at its original index therefore places the form directly after the recoil.
		ordered_events.insert(recoil_index, form_event)
		form_index = recoil_index + 1

	return ordered_events


static func _find_disguise_recoil_index(events: Array, start_index: int, target_ident: String) -> int:
	var target_key := _normalize_ident(target_ident)
	if target_key == "":
		return -1

	for index: int in range(start_index, events.size()):
		var event_value: Variant = events[index]
		if not (event_value is Dictionary):
			continue

		var event_data: Dictionary = event_value as Dictionary
		var event_type := str(event_data.get("type", ""))
		if event_type == "damage" \
			and _normalize_ident(str(event_data.get("target", ""))) == target_key \
			and _is_disguise_recoil_source(str(event_data.get("source", ""))):
			return index

		if event_type in ["move", "switch", "drag", "faint", "turn"]:
			return -1

	return -1


static func _is_disguise_busted_form_change(event: Dictionary) -> bool:
	if str(event.get("type", "")) != "formeChange":
		return false

	var species_key := _normalize_token(str(event.get("species", event.get("displaySpecies", ""))))
	if species_key not in ["mimikyubusted", "mimikyubustedtotem", "mimikyutotembusted"]:
		return false

	var source_key := _normalize_token(str(event.get("source", "")))
	return source_key == "" or source_key.contains("disguise")


static func _is_disguise_recoil_source(source: String) -> bool:
	return _normalize_token(source).contains("mimikyubusted")


static func _normalize_ident(ident: String) -> String:
	var colon_index := ident.find(":")
	if colon_index < 0:
		return ""

	var player_token := ident.substr(0, colon_index).strip_edges().to_lower()
	if player_token.begins_with("p1"):
		player_token = "p1"
	elif player_token.begins_with("p2"):
		player_token = "p2"
	else:
		return ""

	var pokemon_name := ident.substr(colon_index + 1).strip_edges().to_lower()
	var pokemon_key := _normalize_token(pokemon_name)
	if pokemon_key in ["mimikyu", "mimikyudisguised", "mimikyubusted"]:
		pokemon_name = "mimikyu"
	elif pokemon_key in ["mimikyutotem", "mimikyutotemdisguised", "mimikyubustedtotem", "mimikyutotembusted"]:
		pokemon_name = "mimikyu-totem"
	return "%s:%s" % [player_token, pokemon_name]


static func _normalize_token(value: String) -> String:
	return value.to_lower().replace(" ", "").replace("-", "").replace("_", "").replace(":", "").replace("[", "").replace("]", "")
