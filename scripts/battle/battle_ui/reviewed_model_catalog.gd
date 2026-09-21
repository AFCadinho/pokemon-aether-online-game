extends RefCounted
## Checked-in approval, not metadata supplied by a local catalog or Settings.
const DATA = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.json")

static func key(species: String, shiny: bool) -> String:
	var normalized := species.to_lower().replace(" ", "-")
	return normalized + "@shiny" if shiny and not normalized.is_empty() else normalized

static func entry_key(entry: Dictionary) -> String:
	var species := str(entry.get("species", ""))
	var variant := str(entry.get("variant", "normal"))
	if variant not in ["normal", "shiny"]:
		return ""
	# Read the earlier offline prepared identity as well as explicit variants.
	if species.ends_with("@shiny"):
		if entry.has("variant") and variant != "shiny":
			return ""
		return species
	return key(species, variant == "shiny")

static func supports(identity: String) -> bool:
	return DATA.data.models.has(identity)

static func resolve(identity: String, digest: String) -> Dictionary:
	var model: Dictionary = DATA.data.models.get(identity, {})
	if model.is_empty() or digest != model.sha256:
		return {}
	var profile: Dictionary = DATA.data.profiles[model.profile].duplicate(true)
	profile.grounding["sha256"] = digest
	profile.motion["sha256"] = digest
	return profile
