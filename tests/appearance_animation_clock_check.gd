extends SceneTree

class ClockHarness extends Node:
	var local: Node
	var remote: Node
	var moving := true
	func _process(_delta: float) -> void:
		local._sync_appearance_sprite_frames()
		remote._update_animation(moving)

var failed := false

func _init() -> void:
	run.call_deferred()

func run() -> void:
	Engine.max_fps = 60
	var service = load("res://scripts/services/character_appearance_service.gd")
	var local = load("res://scenes/player.tscn").instantiate()
	var remote = load("res://scripts/world/remote_player_avatar.gd").new()
	var harness := ClockHarness.new()
	harness.local = local
	harness.remote = remote
	var bodies: Array[AnimatedSprite2D] = []
	var followers: Array[Array] = [[], []]
	var specs := {"top": ["TopSprite", "TeamRocket_Shirt"], "bottom": ["BottomSprite", "TeamRocket_Trousers"], "shoes": ["ShoesSprite", "TeamRocket_Shoes"], "headgear": ["HeadgearSprite", "TeamRocket_Cap"]}
	for index: int in range(2):
		var group := Node2D.new()
		harness.add_child(group)
		var target: Node = local if index == 0 else remote
		var body := AnimatedSprite2D.new()
		body.name = "BodySprite"
		body.sprite_frames = service.get_body_frames("Gen4_Base_v1", "male")
		group.add_child(body)
		target.appearance_sprites.append(body)
		bodies.append(body)
		if index == 0:
			local.master_appearance_sprite = body
			body.frame_changed.connect(local._sync_appearance_sprite_frames)
		else:
			body.frame_changed.connect(remote._sync_all_part_sprites_to_body)
		for category: String in specs:
			var part := AnimatedSprite2D.new()
			part.name = specs[category][0]
			part.sprite_frames = service.get_part_frames(category, specs[category][1], "male")
			group.add_child(part)
			target.appearance_sprites.append(part)
			followers[index].append(part)
	root.add_child(harness)
	# Observe completed engine ticks, including repeated starts/stops and facing
	# changes. Calling the sync methods once cannot detect double advancement.
	for direction: Vector2 in [Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.RIGHT]:
		local.last_direction = direction
		remote.last_direction = direction
		harness.moving = true
		local.play_walk_animation(direction)
		remote._update_animation(true)
		var matches: Array[bool] = [true, true]
		var visited: Array[Dictionary] = [{}, {}]
		for tick: int in range(36):
			await process_frame
			for index: int in range(2):
				visited[index][bodies[index].frame] = true
				for part: AnimatedSprite2D in followers[index]:
					matches[index] = matches[index] and part.frame == bodies[index].frame and part.animation == bodies[index].animation
		for index: int in range(2):
			check(matches[index] and visited[index].size() == 4, "%s %s clothing follows all four body frames during engine playback" % ["local" if index == 0 else "remote", direction])
		harness.moving = false
		for sprite: AnimatedSprite2D in local.appearance_sprites:
			local._set_idle_animation(sprite, direction)
		remote._update_animation(false)
		for tick: int in range(3):
			await process_frame
		for index: int in range(2):
			var idle_matches := true
			for part: AnimatedSprite2D in followers[index]:
				idle_matches = idle_matches and part.frame == 0 and part.animation == bodies[index].animation
			check(idle_matches, "%s %s clothing stays aligned after stopping" % ["local" if index == 0 else "remote", direction])
	harness.set_process(false)
	bodies[0].frame_changed.disconnect(local._sync_appearance_sprite_frames)
	bodies[1].frame_changed.disconnect(remote._sync_all_part_sprites_to_body)
	harness.free()
	local.free()
	remote.free()
	quit(1 if failed else 0)

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		failed = true
		push_error("FAIL " + label)
