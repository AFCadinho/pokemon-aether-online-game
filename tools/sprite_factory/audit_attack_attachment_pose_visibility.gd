extends SceneTree
## Locate previous marker captures affected by backward discrete-track seeking.
const Catalog = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Pose = preload("res://tools/sprite_factory/attack_attachment_pose.gd")
var catalog_path := ""
var output := "res://.tmp/attack-attachments/pose-visibility-audit.json"

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size() - 1:
		if args[index] == "--catalog": catalog_path = args[index + 1]
		if args[index] == "--output": output = args[index + 1]
	_run.call_deferred()

func _run() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	var entries: Array = raw.entries if raw is Dictionary else raw
	var models := {}
	for entry: Dictionary in entries:
		var identity := Catalog.entry_key(entry)
		if identity.ends_with("@shiny"): continue
		assert(FileAccess.get_sha256(entry.runtime_path) == str(entry.runtime_sha256))
		assert(not Catalog.resolve(identity, entry.runtime_sha256).is_empty())
		var packed := ResourceLoader.load(entry.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
		var actor := packed.instantiate() as Node3D
		root.add_child(actor)
		var player: AnimationPlayer = actor.find_children("*", "AnimationPlayer", true, false)[0]
		preload("res://scripts/battle/animations/reviewed_source_visibility.gd").apply(actor, identity, entry.runtime_sha256)
		preload("res://scripts/battle/animations/gliscor_flight.gd").apply(player, identity, entry.runtime_sha256)
		preload("res://scripts/battle/animations/mega_garchomp_standing.gd").apply(player, identity, entry.runtime_sha256)
		preload("res://scripts/battle/animations/charmander_breath.gd").apply(player, identity, entry.runtime_sha256)
		var legacy := {}
		for action: String in player.get_animation_list():
			if action != "idle" and "attack" not in action: continue
			var samples := []
			for fraction: float in [.2, .45, .65, .45]:
				player.play(action)
				player.seek(player.get_animation(action).length * fraction, true)
				player.pause()
				samples.append(Pose.meshes(actor))
			legacy[action] = samples
		var differences := []
		for action: String in legacy:
			for column in 4:
				var fraction: float = [.2, .45, .65, .45][column]
				Pose.sample(player, action, player.get_animation(action).length * fraction)
				var expected := Pose.meshes(actor)
				for mesh: String in expected:
					if expected[mesh] != legacy[action][column][mesh]:
						differences.append({"action":action, "column":column, "fraction":fraction, "mesh":mesh, "previous":legacy[action][column][mesh], "forward":expected[mesh]})
		models[identity] = {"runtime_sha256":entry.runtime_sha256, "differences":differences}
		actor.free()
		print("ATTACHMENT_POSE_VISIBILITY ", identity, " differences=", differences.size())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"models":models, "scope":"mesh visibility and blend-shape differences between previous marker sampling and forward sampling"}, "\t") + "\n")
	file.close()
	quit()
