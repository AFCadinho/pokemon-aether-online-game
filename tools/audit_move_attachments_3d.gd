extends SceneTree
## Inventory configured emitters for every supported 3D model and battle alias.
## This checks configuration coverage, not the visual placement of every rig.
const Attachments = preload("res://scripts/battle/battle_ui/move_attachments_3d.gd")
const Catalog = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const REPORT := "res://docs/3d/move-attachment-coverage.json"
const SUMMARY := "res://docs/3d/move-attachment-coverage.md"
const SOURCES := [
	"res://scripts/battle/battle_ui/move_attachments_3d.gd",
	"res://scripts/battle/battle_ui/reviewed_model_catalog.gd",
	"res://scripts/battle/battle_ui/reviewed_model_catalog.json",
	"res://scripts/battle/battle_ui/screened_model_catalog.json",
]

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var identities: Dictionary = Catalog.SCREENED.data.models.duplicate()
	identities.merge(Catalog.DATA.data.models, true)
	var rows := {}
	var aliases := {}
	var counts := {"catalog_identities": identities.size(), "normal": 0, "shiny": 0,
		"species_forms": 0, "with_any_attachment": 0, "without_attachments": 0,
		"with_mouth": 0, "with_hand": 0, "with_cannons": 0, "with_electric_body": 0}
	var keys: Array = identities.keys()
	keys.sort()
	for identity: String in keys:
		var species := identity.trim_suffix("@shiny")
		var variant := "shiny" if identity.ends_with("@shiny") else "normal"
		counts[variant] += 1
		if not rows.has(species):
			var parts: Array = Attachments.PROFILES.get(species, {}).keys()
			parts.sort()
			rows[species] = {"variants": [], "attachments": parts,
				"status": "configured" if not parts.is_empty() else "bounds_fallback_only"}
		rows[species].variants.append(variant)
		for alias: String in Catalog.aliases_for(identity):
			if not Catalog.supports(alias) or Catalog.canonical_identity(alias) != identity:
				_fail("Invalid catalog alias: " + alias)
				return
			var alias_parts: Dictionary = Attachments.PROFILES.get(alias.trim_suffix("@shiny"), {})
			aliases[alias] = {"canonical_identity": identity, "attachments": alias_parts.keys()}
	counts.species_forms = rows.size()
	for row: Dictionary in rows.values():
		if row.attachments.is_empty(): counts.without_attachments += 1
		else: counts.with_any_attachment += 1
		for part: String in row.attachments:
			var counter := "with_" + part
			counts[counter] = counts.get(counter, 0) + 1
	var profiles := {}
	for species: String in Attachments.PROFILES:
		if not rows.has(species):
			_fail("Attachment profile is absent from supported catalogs: " + species)
			return
		profiles[species] = {}
		for part: String in Attachments.PROFILES[species]:
			var definitions: Array = Attachments.PROFILES[species][part]
			if definitions.is_empty():
				_fail("Empty attachment: " + species + ":" + part)
				return
			profiles[species][part] = []
			for definition: Array in definitions:
				if definition.size() != 2 or not definition[0] is String or definition[0].is_empty() or not definition[1] is Vector3 or not definition[1].is_finite():
					_fail("Invalid attachment definition: " + species + ":" + part)
					return
				var offset: Vector3 = definition[1]
				profiles[species][part].append({"bone": definition[0], "offset": [offset.x, offset.y, offset.z]})
	var hashes := {}
	for path: String in SOURCES: hashes[path.trim_prefix("res://")] = FileAccess.get_sha256(path)
	var report := {"schema": 1, "scope": "configured_3d_attachment_coverage",
		"rigs_visually_verified_by_this_audit": false,
		"learnsets_checked": false,
		"counts": counts, "source_sha256": hashes, "profiles": profiles,
		"aliases": aliases, "species_forms": rows}
	var summary := _summary(counts, profiles, aliases.size())
	var serialized := JSON.stringify(report, "\t", true) + "\n"
	if "--check" in OS.get_cmdline_user_args():
		if FileAccess.get_file_as_string(REPORT) != serialized or FileAccess.get_file_as_string(SUMMARY) != summary:
			_fail("Attachment coverage reports are stale; rerun without --check")
			return
	else:
		for output: Array in [[REPORT, serialized], [SUMMARY, summary]]:
			var file := FileAccess.open(output[0], FileAccess.WRITE)
			if file == null:
				_fail("Cannot write " + str(output[0]))
				return
			file.store_string(output[1])
	print("MOVE_ATTACHMENT_COVERAGE_OK ", JSON.stringify(counts), " aliases=", aliases.size())
	quit()

func _summary(counts: Dictionary, profiles: Dictionary, alias_count: int) -> String:
	var lines: Array[String] = [
		"# 3D move attachment coverage", "",
		"Generated from the runtime attachment registry and both supported model catalogs.",
		"The [complete inventory](move-attachment-coverage.json) includes every catalog species/form, normal/shiny variant, battle alias, configured part, and source digest.", "",
		"## Results", "",
		"- Catalog models: %d species/forms, %d normal + %d shiny = %d identities." % [counts.species_forms, counts.normal, counts.shiny, counts.catalog_identities],
		"- Additional battle lookup aliases checked separately: %d (including spelling aliases and shared-model forms)." % alias_count,
		"- At least one configured anatomical attachment: %d species/forms." % counts.with_any_attachment,
		"- No anatomical attachment profile: %d species/forms; these use bounds-based fallback positions." % counts.without_attachments,
		"- Mouth attachments: %d species/forms." % counts.with_mouth,
		"", "| Species/form | Configured parts | Shiny routing |", "| --- | --- | --- |",
	]
	var keys: Array = profiles.keys()
	keys.sort()
	for species: String in keys:
		var parts: Array = profiles[species].keys()
		parts.sort()
		lines.append("| %s | %s | Same attachment profile |" % [species, ", ".join(parts)])
	lines.append_array([
		"", "## Interpretation", "",
		"Configured parts are partial coverage: Charmander's hand does not provide a foot or tail anchor, and Pikachu's electric-body anchor is not a mouth anchor. Unconfigured parts still fall back to model bounds. Mega and other alternate forms do not inherit base-form profiles; shiny variants do.", "",
		"This audit checks whether attachment definitions exist. It does not certify bone availability, mouth placement, or every move animation on the actual models. It does not intersect moves with learnsets, so an absent mouth anchor does not imply that a species needs or can use Flamethrower. Bounds fallback can look correct in some poses without following the anatomical part.", "",
		"## Reproduce", "", "From the workspace root, in the assigned task slot:", "", "```bash",
		"ops/worktrees/slot-env slot-b -- godot --headless --path .worktrees/slot-b/frontend --script res://tools/audit_move_attachments_3d.gd",
		"ops/worktrees/slot-env slot-b -- godot --headless --path .worktrees/slot-b/frontend --script res://tools/audit_move_attachments_3d.gd -- --check",
		"```", "",
	])
	return "\n".join(lines)

func _fail(message: String) -> void:
	printerr(message)
	quit(1)
