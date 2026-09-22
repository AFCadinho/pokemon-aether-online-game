extends SceneTree
const Pack = preload("res://tools/sprite_factory/visibility_pack.gd")

func _initialize() -> void:
	run.call_deferred()

func fixture() -> Node3D:
	var actor := Node3D.new()
	actor.name = "Actor"
	for name in ["body_mesh", "tool_mesh"]:
		var mesh := MeshInstance3D.new()
		mesh.name = name
		mesh.mesh = BoxMesh.new()
		actor.add_child(mesh)
		mesh.owner = actor
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	actor.add_child(player)
	player.owner = actor
	var library := AnimationLibrary.new()
	player.add_animation_library("", library)
	for name in ["idle", "attack", "sleep", "faint_loop"]:
		var animation := Animation.new()
		animation.length = 1.0
		animation.loop_mode = Animation.LOOP_LINEAR if name != "attack" else Animation.LOOP_NONE
		library.add_animation(name, animation)
	return actor

func manifest() -> Dictionary:
	var result := {"schema": 1, "glb_sha256": "a".repeat(64), "clips": {}}
	for action in ["idle", "attack", "sleep", "faint_loop"]:
		result.clips[action] = {"duration": 1.0, "loop": action != "attack", "source_sha256": "b".repeat(64), "tracks": [
			{"mesh": "body_mesh", "source_target": "body_mesh_shape", "keys": [[0.0, true]]},
			{"mesh": "tool_mesh", "source_target": "tool_mesh_shape", "keys": [[0.0, false], [0.25, true], [0.75, false]] if action == "attack" else ([[0.0, true], [0.5, false]] if action == "idle" else [[0.0, false]])}]}
	return result

func sample(actor: Node, action: String, time: float) -> void:
	var player: AnimationPlayer = actor.get_node("AnimationPlayer")
	player.play(action)
	player.pause()
	player.seek(time, true)
	player.advance(0)

func verify(actor: Node) -> void:
	var tool: MeshInstance3D = actor.get_node("tool_mesh")
	for action in ["idle", "sleep", "faint_loop", "idle"]:
		sample(actor, action, 0)
		assert(tool.visible == (action == "idle"), action)
	for time in [0.0, 0.249, 0.25, 0.5, 0.749, 0.75, 1.0]:
		sample(actor, "attack", time)
		assert(tool.visible == (time >= 0.25 and time < 0.75), str(time))
	sample(actor, "sleep", 0)
	sample(actor, "RESET", 0)
	assert(tool.visible)
	var player: AnimationPlayer = actor.get_node("AnimationPlayer")
	player.play("idle")
	player.advance(0.6)
	assert(not tool.visible)
	player.advance(0.5)
	assert(tool.visible, "Loop restart must restore key zero")
	player.pause()

func run() -> void:
	var actor := fixture()
	root.add_child(actor)
	var pack := Pack.new()
	assert(pack.apply(actor, manifest(), "a".repeat(64)), pack.failure)
	verify(actor)
	var scene := PackedScene.new()
	assert(scene.pack(actor) == OK)
	var path := "user://visibility-track-test.scn"
	assert(ResourceSaver.save(scene, path) == OK)
	var loaded: PackedScene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	var copy := loaded.instantiate()
	root.add_child(copy)
	verify(copy)
	sample(actor, "sleep", 0)
	assert(not actor.get_node("tool_mesh").visible and copy.get_node("tool_mesh").visible)
	actor.free()
	copy.free()
	for fault in ["hash", "missing_mesh", "missing_clip", "bad_clock", "bad_key", "duplicate"]:
		actor = fixture()
		root.add_child(actor)
		var data := manifest()
		match fault:
			"hash": data.glb_sha256 = "c".repeat(64)
			"missing_mesh": data.clips.idle.tracks[0].mesh = "unknown"
			"missing_clip": data.clips.erase("sleep")
			"bad_clock": data.clips.idle.duration = 2.0
			"bad_key": data.clips.idle.tracks[0]["keys"] = [[0.2, true]]
			"duplicate": data.clips.idle.tracks.append(data.clips.idle.tracks[0])
		assert(not pack.apply(actor, data, "a".repeat(64)), fault)
		assert(actor.get_node("AnimationPlayer").get_animation("idle").get_track_count() == 0, "Partial mutation")
		actor.free()
	print("VISIBILITY_TRACKS_PASS: switch, seek boundaries, RESET, reload, isolated instances, fail-closed binding")
	quit()
