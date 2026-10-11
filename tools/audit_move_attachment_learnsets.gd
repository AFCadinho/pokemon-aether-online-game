extends SceneTree
## Read-only cross-reference of actual learnsets and the current runtime routing.
## Configuration presence is not anatomical or visual approval.
const Attachments = preload("res://scripts/battle/battle_ui/move_attachments_3d.gd")
const Catalog = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Recipes = preload("res://scripts/battle/battle_ui/move_recipe_3d.gd")
const MoveEffect = preload("res://scripts/battle/battle_ui/move_effect_3d.gd")
const Stage = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const FILE_ALIASES := {"charizard-mega-x":"charizard-megax", "charizard-mega-y":"charizard-megay", "mewtwo-mega-x":"mewtwo-megax", "mewtwo-mega-y":"mewtwo-megay"}
const BUCKETS := ["level_up_moves", "evolution_moves", "egg_moves", "tm_moves", "tutor_moves", "special_moves", "event_moves", "legacy_moves", "legacy_event_moves", "pre_evolution_moves"]

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var source := ""
	var output := "res://.tmp/attack-attachments/learnset-routing.json"
	for i in args.size():
		if args[i] not in ["--learnsets", "--output"]: continue
		if i + 1 >= args.size():
			printerr("Missing value for ", args[i])
			quit(1)
			return
		if args[i] == "--learnsets": source = args[i+1]
		else: output = args[i+1]
	if not DirAccess.dir_exists_absolute(source):
		printerr("Supply --learnsets with the paired backend pokemon-data/data/species directory")
		quit(1)
		return
	var models: Dictionary = Catalog.SCREENED.data.models.duplicate()
	models.merge(Catalog.DATA.data.models, true)
	var rows := {}
	var errors: Array[String] = []
	var totals := {"species_forms":0, "supported_move_pairs":0, "configured_move_pairs":0, "missing_parts":{}}
	var identities := models.keys()
	identities.sort()
	# Use the actual battle selector without loading scenes or starting a battle.
	var stage := Stage.new()
	for identity: String in identities:
		if identity.ends_with("@shiny"): continue
		var profile := Catalog.resolve(identity, str(models[identity].sha256))
		var timing: Dictionary = profile.get("action_timing", {})
		stage.identities[0] = identity
		stage.entries = {identity: profile}
		var filename: String = FILE_ALIASES.get(identity, identity) + ".json"
		var path := source.path_join(filename)
		if not FileAccess.file_exists(path):
			errors.append("Missing learnset: " + filename)
			continue
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not raw is Dictionary:
			errors.append("Invalid species data: " + filename)
			continue
		var moves := {}
		for bucket: String in BUCKETS:
			for value in raw.get(bucket, []):
				var move_name := str(value.get("move", "")) if value is Dictionary else str(value)
				var move := Recipes.key(move_name)
				if move.is_empty():
					errors.append("Empty move: " + filename + ":" + bucket)
					continue
				moves[move] = move_name
		var groups := {}
		var routes := {}
		var unsupported: Array[String] = []
		var keys := moves.keys()
		keys.sort()
		for move: String in keys:
			if not MoveEffect.supports(move):
				unsupported.append(move)
				continue
			# These two renderers reserve explicit orb clearance before sampling
			# anatomical attachments. Report their effective runtime behavior.
			var part := "orb_clearance" if move in ["moonblast", "dracometeor"] else Attachments.part_for(identity, move)
			# The category index uses hyphenated learnset IDs. Recipe keys have
			# removed those separators and must not be fed to the selector.
			var requested := stage.attack_action_for(str(moves[move]), "p1")
			var mapped := Stage.ActionMap.resolve(requested, PackedStringArray(timing.keys()), timing)
			var action := str(mapped.get("action", ""))
			if action.is_empty(): errors.append("Missing attack action: " + identity + ":" + move)
			var configured := not Attachments.definitions_for(identity, part, action).is_empty()
			routes[move] = {"part":part, "requested_action":requested, "native_action":action,
				"configured":configured, "visual_review":"pending"}
			if not groups.has(part): groups[part] = []
			groups[part].append(move)
			totals.supported_move_pairs += 1
			if configured: totals.configured_move_pairs += 1
		var missing: Array[String] = []
		for part: String in groups:
			if part in ["body", "orb_clearance"]: continue
			if groups[part].any(func(move: String) -> bool: return not bool(routes[move].configured)):
				missing.append(part)
				totals.missing_parts[part] = totals.missing_parts.get(part, 0) + 1
		missing.sort()
		rows[identity] = {"learnset_file":filename, "learnset_sha256":FileAccess.get_sha256(path),
			"runtime_sha256":models[identity].sha256, "move_routes":routes,
			"moves_by_runtime_part":groups, "without_3d_effect_presenter":unsupported,
			"unconfigured_anatomical_parts":missing, "anatomical_routing_review":"pending",
			"move_effect_review":"pending"}
		totals.species_forms += 1
	stage.free()
	var report := {"schema":2, "scope":"supported_3d_presenters_intersected_with_all_learnset_buckets",
		"complete_visual_review":false, "counts":totals, "errors":errors, "species_forms":rows,
		"source_sha256":{}}
	for path: String in ["res://data/battle_move_recipes_3d.json", "res://data/battle_move_attachments_3d.json", "res://scripts/battle/battle_ui/move_attachments_3d.gd", "res://scripts/battle/battle_ui/move_effect_3d.gd", "res://scripts/battle/battle_ui/experimental_battle_3d.gd", "res://scripts/battle/animations/model_action_map.gd", "res://scripts/battle/battle_ui/reviewed_model_catalog.json", "res://scripts/battle/battle_ui/screened_model_catalog.json"]:
		report.source_sha256[path.trim_prefix("res://")] = FileAccess.get_sha256(path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write ", output)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t", true) + "\n")
	file.close()
	print("ATTACHMENT_LEARNSETS ", JSON.stringify(totals), " errors=", errors.size())
	for error: String in errors: printerr(error)
	quit(0 if errors.is_empty() else 1)
