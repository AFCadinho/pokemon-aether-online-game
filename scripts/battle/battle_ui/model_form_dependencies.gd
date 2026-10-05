extends RefCounted
## Art dependencies only. Never predicts an opponent's item or activates a form.
const Reviewed = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const MegaCatalog = preload("res://scripts/data/mega_champions_catalog.gd")
const STANCE_FORMS := {
	"terapagos": ["terapagos-terastal", "terapagos-stellar"],
	"terapagos-terastal": ["terapagos-stellar"],
	"mimikyu": ["mimikyu-busted"], "mimikyu-disguised": ["mimikyu-busted"],
	"palafin": ["palafin-hero"],
	"eiscue": ["eiscue-noice"], "eiscue-noice": ["eiscue"],
	"aegislash": ["aegislash-blade"], "aegislash-shield": ["aegislash-blade"],
	"aegislash-blade": ["aegislash-shield"],
	"wishiwashi": ["wishiwashi-school"], "wishiwashi-school": ["wishiwashi"],
	"morpeko": ["morpeko-hangry"], "morpeko-hangry": ["morpeko"],
	"darmanitan": ["darmanitan-zen"], "darmanitan-standard": ["darmanitan-zen"],
	"darmanitan-zen": ["darmanitan-standard"],
}
static var _mega_targets: Dictionary = {}
static var _indexed := false

static func anticipated(identity: String) -> Array[String]:
	_index_megas()
	var shiny := identity.ends_with("@shiny")
	var species := identity.trim_suffix("@shiny").to_lower().replace(" ", "-")
	var targets: Array = STANCE_FORMS.get(species, []).duplicate()
	targets.append_array(_mega_targets.get(species, []))
	var result: Array[String] = []
	for target: String in targets:
		var key := Reviewed.key(target, shiny)
		if Reviewed.supports(key) and key not in result:
			result.append(key)
	return result

static func with_forms(identities: Array[String]) -> Array[String]:
	# Keep the actual party/encounters ahead of optional forms in background I/O.
	var result: Array[String] = []
	for identity in identities:
		if not identity.is_empty() and identity not in result:
			result.append(identity)
	for identity in identities:
		for target in anticipated(identity):
			if target not in result:
				result.append(target)
	return result

static func _add(base: String, target: String) -> void:
	if base.is_empty() or not Reviewed.supports(target):
		return
	if not _mega_targets.has(base):
		_mega_targets[base] = []
	if target not in _mega_targets[base]:
		_mega_targets[base].append(target)

static func _index_megas() -> void:
	if _indexed:
		return
	_indexed = true
	# Native catalog links cover exceptional base names (Floette-Eternal,
	# Meowstic genders, Zygarde percentages, and regional/form-specific bases).
	var described := {}
	for entry in MegaCatalog.all_entries():
		var target := str(entry.get("pokeaetherSpeciesId", ""))
		described[target] = true
		for base: Dictionary in entry.get("baseForms", []):
			for field in ["pokeaetherSpeciesId", "showdownSpeciesName"]:
				_add(str(base.get(field, "")).to_lower().replace(" ", "-"), target)
	# Older reviewed Megas have conventional base-mega[-x/y] identities.
	# Never override an explicit catalog relation with a guessed base form.
	for identity: String in Reviewed.DATA.data.models:
		if identity.ends_with("@shiny") or described.has(identity):
			continue
		var marker := identity.find("-mega")
		if marker > 0:
			_add(identity.left(marker), identity)
	for base: String in _mega_targets:
		_mega_targets[base].sort()
