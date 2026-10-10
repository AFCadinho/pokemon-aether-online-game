extends SceneTree
## Isolate per-pack mount/index overhead from shader and actor warm-up.
const Pair = preload("res://scripts/services/model_pair_pack.gd")
const Pilot = preload("res://scripts/services/model_pair_pilot.gd")
var failures: Array[String] = []
var samples: Array[Dictionary] = []

func _init() -> void:
	_run.call_deferred()

func check(value: bool, reason: String) -> void:
	if not value:
		failures.append(reason)
		print("MOUNT_BUDGET_FAIL ", reason)

func mount(asset: Dictionary, packs: String) -> void:
	var path := packs.path_join(str(asset.object_key).get_file())
	var verified := Pair.inspect(path, asset)
	check(str(verified.error).is_empty(), "Physical pack verification")
	check(Pair.mount_checked(path, asset, verified).is_empty(), "Closed verified mount")

func sample(label: String) -> Dictionary:
	var result := {"label": label, "static_bytes": OS.get_static_memory_usage(),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"mounts": Pair.mounted.size(), "namespaces": Pair.namespaces.size(), "closures": Pair.closed.size(),
		"registry_json_bytes": JSON.stringify([Pair.mounted, Pair.namespaces, Pair.closed]).to_utf8_buffer().size()}
	samples.append(result)
	return result

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not args[0].is_absolute_path() or not args[1].is_absolute_path():
		quit(2)
		return
	await create_timer(1.1).timeout
	sample("baseline")
	var assets: Array[Dictionary] = []
	var members := 0
	for asset: Dictionary in Pilot.DATA.data.assets:
		if asset.get("format") != Pair.FORMAT:
			continue
		assets.append(asset)
		members += asset.pair_manifest.files.size() + 1
		mount(asset, args[0])
		sample(str(asset.asset_id))
	await create_timer(1.1).timeout
	var warm := sample("all-mounted")
	for _sweep in 5:
		for asset: Dictionary in assets:
			mount(asset, args[0])
	await create_timer(1.1).timeout
	var final := sample("five-repeat-sweeps")
	check(final.mounts == assets.size() and final.namespaces == assets.size() and final.closures == assets.size(), "One retained index per unique pack")
	check(final.registry_json_bytes == warm.registry_json_bytes, "Repeated mounts do not grow registries")
	check(final.resources == warm.resources and final.static_bytes <= warm.static_bytes + 1048576, "Repeated validation leaves no accumulating resources or allocations")
	var receipt := {"schema": 1, "ok": failures.is_empty(), "godot": Engine.get_version_info().string,
		"pairs": assets.size(), "declared_pck_members": members, "repeat_mount_requests": assets.size() * 5,
		"samples": samples, "errors": failures}
	var output := FileAccess.open(args[1], FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(receipt, "\t") + "\n")
		output.close()
	else:
		check(false, "Write budget receipt")
	print("SHARED_MODEL_MOUNT_BUDGET_CHECK ", "OK" if failures.is_empty() else "FAILED", " ", JSON.stringify(receipt))
	quit(0 if failures.is_empty() else 1)
