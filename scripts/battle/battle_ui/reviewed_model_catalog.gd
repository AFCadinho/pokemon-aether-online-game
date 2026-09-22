extends RefCounted
## Checked-in approval, not metadata supplied by a local catalog or Settings.
const DATA = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.json")
const SCREENED = preload("res://scripts/battle/battle_ui/screened_model_catalog.json")

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
	return DATA.data.models.has(identity) or SCREENED.data.models.has(identity)

static func approved_digest(model: Dictionary, digest: String) -> bool:
	return not model.is_empty() and (digest == model.get("sha256", "") or digest in model.get("previous_sha256", []))

static func screened_digest(model: Dictionary, digest: String) -> bool:
	# Screened candidates deliberately do not inherit the old-revision allowance.
	# They are local normal-form test assets, not portable reviewed-pack content.
	return not model.is_empty() and digest == model.get("sha256", "")

static func is_screened(identity: String, digest := "") -> bool:
	var model: Dictionary = SCREENED.data.models.get(identity, {})
	return not model.is_empty() and (digest.is_empty() or screened_digest(model, digest))

static func pack_entries(manifest: Dictionary, directory: String) -> Array:
	# Portable packs are stricter than the historical two-model local catalog.
	var engine := Engine.get_version_info()
	if engine.major != 4 or engine.minor != 6 or manifest.get("godot") != "4.6":
		return []
	if manifest.get("schema") != 1 or manifest.get("kind") != "pokeaether-reviewed-model-pack" or manifest.get("qualification_sha256") != DATA.data.qualification_sha256:
		return []
	var entries: Variant = manifest.get("entries")
	if not entries is Array or entries.is_empty() or entries.size() > DATA.data.models.size():
		return []
	var result := []
	var seen := {}
	var total := 0
	var folder := DirAccess.open(directory)
	if folder == null or folder.is_link("models"):
		return []
	for raw: Variant in entries:
		if not raw is Dictionary or not raw.get("species") is String or "@" in raw.species:
			return []
		var identity := entry_key(raw)
		var model: Dictionary = DATA.data.models.get(identity, {})
		if seen.has(identity) or raw.get("runtime_schema") != 1 or not approved_digest(model, str(raw.get("runtime_sha256", ""))):
			return []
		var expected: String = "models/" + str(raw.runtime_sha256) + ".scn"
		var bytes: Variant = raw.get("bytes")
		if raw.get("runtime_path") != expected or folder.is_link(expected) or not (bytes is int or bytes is float):
			return []
		if not is_finite(float(bytes)) or bytes != floor(float(bytes)) or bytes <= 0 or bytes > 134217728:
			return []
		total += int(bytes)
		if total > 536870912:
			return []
		seen[identity] = true
		var entry: Dictionary = raw.duplicate(true)
		entry.runtime_path = directory.path_join(expected)
		result.append(entry)
	return result

static func resolve(identity: String, digest: String) -> Dictionary:
	var model: Dictionary = DATA.data.models.get(identity, {})
	var profiles: Dictionary = DATA.data.profiles
	var accepted := approved_digest(model, digest)
	if not accepted:
		model = SCREENED.data.models.get(identity, {})
		profiles = SCREENED.data.profiles
		accepted = screened_digest(model, digest)
	if not accepted or not profiles.has(model.get("profile", "")):
		return {}
	var profile: Dictionary = profiles[model.profile].duplicate(true)
	# The screened cohort has source timing and placement only. It has not passed
	# arena grounding or motion-clearance calibration, so keep those optional and
	# let the presenter select its existing safe classic-arena fallback.
	if profile.get("grounding") is Dictionary:
		profile.grounding["sha256"] = digest
	if profile.get("motion") is Dictionary:
		profile.motion["sha256"] = digest
	return profile
