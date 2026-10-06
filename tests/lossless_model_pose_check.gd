extends "res://tools/sprite_factory/native_resource_compression_check.gd"
## Real source/candidate rigs, with client corrections applied before posing.
const Revisions = preload("res://scripts/battle/animations/lossless_model_revisions.gd")
const Reviewed = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Flight = preload("res://scripts/battle/animations/gliscor_flight.gd")
const Standing = preload("res://scripts/battle/animations/mega_garchomp_standing.gd")
const Breath = preload("res://scripts/battle/animations/charmander_breath.gd")

func _run() -> void:
	sink.tree = self
	OS.add_logger(sink)
	if DisplayServer.get_name() == "headless":
		push_error("Pose mesh envelopes require a real rendering driver; omit --headless")
		return
	var fixture_path := OS.get_environment("NATIVE_POSE_FIXTURE")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	assert(fixture.entries.size() == 6)
	report = {"complete": false, "prototype_only": true, "production_approved": false, "comparisons": [],
		"source_script_sha256": FileAccess.get_sha256("res://tests/lossless_model_pose_check.gd"),
		"fixture_sha256": FileAccess.get_sha256(fixture_path),
		"revisions_sha256": FileAccess.get_sha256("res://resources/battle/model_animations/lossless_model_revisions.json"),
		"renderer": RenderingServer.get_current_rendering_method(), "godot": Engine.get_version_info().string}
	for entry: Dictionary in fixture.entries:
		var revision: Dictionary = Revisions.DATA.data.models[entry.identity]
		assert(revision.source_sha256 == FileAccess.get_sha256(entry.source_path))
		assert(revision.sha256 == FileAccess.get_sha256(entry.candidate_path))
		assert(revision.raw_sha256 == entry.raw_sha256)
		var helper = {"gliscor_flight": Flight, "mega_garchomp_standing": Standing, "charmander_breath": Breath}[entry.helper]
		assert(helper.matches(entry.identity, revision.source_sha256))
		assert(helper.matches(entry.identity, revision.sha256))
		assert(not helper.matches(entry.identity, "unreviewed-rig"))
		assert(not helper.matches("other-identity", revision.sha256))
		assert(not Revisions.matches(entry.identity, revision.sha256, {entry.identity: "changed-source"}))
		# Compatibility for an animation is not approval to install new bundles.
		assert(Reviewed.resolve(entry.identity, revision.sha256).is_empty())
		var model: Dictionary = Reviewed.DATA.data.models[entry.identity]
		var original_profile: Dictionary = Reviewed.DATA.data.profiles[model.profile]
		assert(helper.profile_for(entry.identity, revision.source_sha256, original_profile) == helper.profile_for(entry.identity, revision.sha256, original_profile))
		var states := []
		for candidate in [false, true]:
			var path: String = entry.candidate_path if candidate else entry.source_path
			var digest: String = revision.sha256 if candidate else revision.source_sha256
			var packed: PackedScene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
			assert(packed != null)
			var world := Node3D.new()
			root.add_child(world)
			var node := packed.instantiate() as Node3D
			var other := packed.instantiate() as Node3D
			world.add_child(node)
			world.add_child(other)
			await process_frame
			var player := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
			var second := other.find_child("AnimationPlayer", true, false) as AnimationPlayer
			var original_library := second.get_animation_library("")
			assert(helper.apply(player, entry.identity, digest))
			assert(second.get_animation_library("") == original_library)
			assert(helper.apply(second, entry.identity, digest))
			assert(player.get_animation_library("") != second.get_animation_library(""))
			pose(other, "idle", 0.0)
			var independent := signature(other)
			var measured := {}
			for action in player.get_animation_list():
				if action == "RESET": continue
				for fraction in [0.0, 0.5, 0.999]:
					pose(node, action, fraction)
					assert(signature(other) == independent, "Another actor inherited a pose")
					measured[str(action) + ":" + str(fraction)] = {"pose": signature(node), "bounds": bounds(node)}
			states.append(measured)
			player.get_animation("idle").length = 99.0
			assert(second.get_animation("idle").length < 99.0, "Animation library mutation leaked")
			world.queue_free()
			await process_frame
		assert(states[0] == states[1], "Corrected pose or mesh envelope changed: " + entry.identity)
		report.comparisons.append({"identity": entry.identity, "pose_samples": states[0].size(), "exact_skeleton_and_bounds": true, "independent_actors": true})
		print("LOSSLESS_CORRECTED_POSES_OK ", entry.identity, " samples=", states[0].size())
	report.complete = true
	save_report()
	quit()
