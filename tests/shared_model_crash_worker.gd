extends SceneTree
## Launched in separate processes by run_shared_model_crash_checks.py.
const Pair = preload("res://scripts/services/model_pair_pack.gd")
const LauncherPair = preload("res://launcher/scripts/model_pair_pack.gd")
const Pilot = preload("res://scripts/services/model_pair_pilot.gd")
const Store = preload("res://launcher/scripts/asset_bundle_store.gd")
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func check(value: bool, reason: String) -> bool:
	if not value:
		failures.append(reason)
		print("CRASH_CHECK_FAIL ", reason)
	return value

func write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "\t") + "\n")
	file.close()

func fixture(directory: String, packs: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var base: Dictionary = Pilot.DATA.data.duplicate(true)
	var first: Dictionary = base.assets[0].duplicate(true)
	check(first.dependencies.is_empty(), "Independent first pair")
	base.assets = [first]
	base.catalog_revision = "crash-check-old"
	var source := packs.path_join(str(first.object_key).get_file())
	var checked := Pair.inspect(source, first)
	if not check(str(checked.error).is_empty(), "Verified original source"):
		return
	var changed := base.duplicate(true)
	changed.catalog_revision = "crash-check-update"
	var asset: Dictionary = changed.assets[0]
	asset.version = int(asset.version) + 1
	asset.pair_manifest.version = asset.version
	var members := directory.path_join("members")
	DirAccess.make_dir_recursive_absolute(members)
	var input := FileAccess.open(source, FileAccess.READ)
	var packer := PCKPacker.new()
	var updated := directory.path_join("update.pck")
	check(packer.pck_start(updated) == OK, "Create update fixture")
	for name: String in checked.members:
		var target := members.path_join(name)
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		if name == "bundle.json":
			write_json(target, asset.pair_manifest)
		else:
			var member: Dictionary = checked.members[name]
			input.seek(int(member.offset))
			var output := FileAccess.open(target, FileAccess.WRITE)
			output.store_buffer(input.get_buffer(int(member.bytes)))
			output.close()
		check(packer.add_file(str(asset.pair_manifest.resource_root).path_join(name), target) == OK, "Add fixture member")
	check(packer.flush() == OK, "Finish update pack")
	asset.sha256 = FileAccess.get_sha256(updated)
	var file := FileAccess.open(updated, FileAccess.READ)
	asset.size_bytes = file.get_length()
	asset.object_key = "optional-assets/pokemon_3d/" + str(asset.species_id) + "/" + str(asset.form_id) + "/v" + str(asset.version) + "-" + str(asset.sha256) + ".pck"
	var updated_check := Pair.inspect(updated, JSON.parse_string(JSON.stringify(asset)))
	check(str(updated_check.error).is_empty(), "Valid newly versioned test pack: " + str(updated_check.error))
	write_json(directory.path_join("base.json"), base)
	write_json(directory.path_join("update.json"), changed)
	write_json(directory.path_join("sources.json"), {"base": source, "update": updated})

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 4:
		quit(2)
		return
	var action: String = args[0]
	var fixtures: String = args[1]
	var directory: String = args[2]
	var implementation: String = args[3]
	if action == "fixture":
		fixture(fixtures, directory)
	else:
		var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixtures.path_join("base.json")))
		var update: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixtures.path_join("update.json")))
		var sources: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixtures.path_join("sources.json")))
		var asset: Dictionary = base.assets[0]
		var store := Store.new(directory)
		var object := directory.path_join("objects").path_join(str(asset.sha256))
		var pair_script = Pair if implementation == "game" else LauncherPair
		if action == "setup":
			check(str(store.install_archive(base, asset.asset_id, sources.base).error).is_empty(), "Initial generation")
			write_json(directory.path_join("expected.json"), {"generation": store.active_generation()})
		elif action == "corrupt":
			var output := FileAccess.open(object.path_join("model-pair.pck"), FileAccess.WRITE)
			output.store_string("deliberately corrupt owned test pack")
			output.close()
		elif action in ["install", "repair"]:
			var result: Dictionary = pair_script.install(sources.base, asset, object)
			check(str(result.error).is_empty(), "Install or repair: " + str(result.error))
		elif action == "update":
			check(str(store.install_archive(update, update.assets[0].asset_id, sources.update).error).is_empty(), "Update")
		elif action in ["resume-install", "resume-repair"]:
			check(str(pair_script.install(sources.base, asset, object).error).is_empty(), "Recovery installs verified object")
			check(str(pair_script.object_check(object, asset).error).is_empty(), "Recovered pack passes complete validation")
			if action == "resume-repair":
				var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("expected.json")))
				check(store.active_generation() == expected.generation, "Repair preserves original catalog identity")
			var objects := DirAccess.get_directories_at(directory.path_join("objects"))
			check(objects.size() == 1 and objects[0] == str(asset.sha256), "No abandoned staged or quarantined model copies: " + str(objects))
		elif action == "resume-update":
			check(not store.active_generation().is_empty(), "Restart exposes a complete old or new generation")
			check(not store.catalog_path_for_launch().is_empty(), "Consistent launch handoff after interruption")
			check(str(store.install_archive(update, update.assets[0].asset_id, sources.update).error).is_empty(), "Restart completes update")
			check(int(store.state().assets[asset.asset_id].version) == int(update.assets[0].version), "Updated version activated")
			var active := store.active_generation()
			check(str(store._activate_generation(str(JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("expected.json"))).generation))).is_empty(), "Explicit rollback to prior complete generation")
			check(int(store.state().assets[asset.asset_id].version) == int(asset.version), "Rollback keeps prior version")
			check(str(store._activate_generation(active)).is_empty(), "Complete update can be activated again")
			check(str(store.garbage_collect().error).is_empty(), "Safe cleanup after successful restart")
		else:
			check(false, "Known worker action")
	print("SHARED_CRASH_WORKER ", action, " ", "OK" if failures.is_empty() else "FAILED", " ", failures)
	quit(0 if failures.is_empty() else 1)
