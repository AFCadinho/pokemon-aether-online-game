extends RefCounted
## Explicit model sharing. Battle identity stays distinct from download identity.
## Ratios follow the checked-in form investigation; no geometry is duplicated.
const FORMS := {
	"araquanid-totem": ["araquanid", 31.0 / 18.0],
	"eevee-starter": ["eevee", 1.0],
	"gumshoos-totem": ["gumshoos", 2.0],
	"kommo-o-totem": ["kommo-o", 1.5],
	"lurantis-totem": ["lurantis", 5.0 / 3.0],
	"mimikyu-busted-totem": ["mimikyu-busted", 2.0],
	"mimikyu-totem": ["mimikyu", 2.0],
	"pikachu-starter": ["pikachu", 1.0],
	"ribombee-totem": ["ribombee", 2.0],
	"rockruff-dusk": ["rockruff", 1.0],
	"salazzle-totem": ["salazzle", 1.75],
	"togedemaru-totem": ["togedemaru", 2.0],
	"vikavolt-totem": ["vikavolt", 26.0 / 15.0],
}

static func canonical_species(species: String) -> String:
	return str(FORMS[species][0]) if FORMS.has(species) else species

static func aliases_for(identity: String) -> Array[String]:
	var result: Array[String] = []
	var base := identity.trim_suffix("@shiny")
	var suffix := "@shiny" if identity.ends_with("@shiny") else ""
	for alias: String in FORMS:
		if FORMS[alias][0] == base:
			result.append(alias + suffix)
	return result

static func profile_for(identity: String, profile: Dictionary) -> Dictionary:
	var form := identity.trim_suffix("@shiny")
	if not FORMS.has(form) or float(FORMS[form][1]) == 1.0:
		return profile
	var result := profile.duplicate(true)
	var ratio := float(FORMS[form][1])
	# Scale every world-space clearance together, including sleep offsets.
	# Bounds are in model space and therefore must not be scaled a second time.
	for section: String in ["placement", "grounding", "motion"]:
		if not result.get(section) is Dictionary:
			continue
		for key: String in ["scale", "lift", "hover_height"]:
			if result[section].has(key):
				result[section][key] = float(result[section][key]) * ratio
	if result.get("motion") is Dictionary:
		for clip: Dictionary in result.motion.get("clips", {}).values():
			for i in clip.get("offsets", []).size():
				clip.offsets[i] = float(clip.offsets[i]) * ratio
	return result
