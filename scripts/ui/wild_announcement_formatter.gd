extends RefCounted


static func format_event(event: Dictionary) -> String:
	var player := str(event.get("displayName", "")).strip_edges()
	var species := str(event.get("species", "")).strip_edges()
	if player == "" or species == "":
		return ""
	var pokemon := ("Shiny " if bool(event.get("shiny", false)) else "") + species
	var article := "an" if pokemon.substr(0, 1).to_lower() in ["a", "e", "i", "o", "u"] else "a"
	match str(event.get("phase", "")):
		"encountered":
			return "%s encountered a wild %s." % [player, pokemon]
		"fainted":
			return "%s has fainted %s %s." % [player, article, pokemon]
		"caught":
			return "%s caught %s %s." % [player, article, pokemon]
		"fled":
			return "%s fled from a wild %s." % [player, pokemon]
		"lost":
			return "%s lost the battle against a wild %s." % [player, pokemon]
	return ""
