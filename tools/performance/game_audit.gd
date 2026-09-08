extends SceneTree

# Offline/headless CPU probe. No world is started and no sessions are loaded here.
# Scene instances stay outside the tree, so map/NPC _ready hooks do not run.
const Appearance := preload("res://scripts/services/character_appearance_service.gd")
const Blocking := preload("res://scripts/world/map_character_blocking.gd")

class SyntheticBlocker extends Node2D:
	func blocks_world_position(_position: Vector2) -> bool:
		return false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for path: String in [
		"res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn",
		"res://scenes/overworld/kanto/towns/pewter_city/pewter_city.tscn",
		"res://scenes/overworld/kanto/routes/kanto_route_3.tscn",
		"res://scenes/overworld/kanto/routes/route25/kanto_route_25.tscn",
		"res://scenes/interface/ui_overlay.tscn",
	]:
		var started := Time.get_ticks_usec()
		var scene := load(path) as PackedScene
		var load_ms := (Time.get_ticks_usec() - started) / 1000.0
		started = Time.get_ticks_usec()
		var instance := scene.instantiate()
		var instantiate_ms := (Time.get_ticks_usec() - started) / 1000.0
		var nodes := _count_nodes(instance)
		var topology := _blocking_topology(instance)
		started = Time.get_ticks_usec()
		for _i in 300:
			Blocking.is_position_blocked_by_character(topology, Vector2(-100000, -100000))
		var collision_ms := (Time.get_ticks_usec() - started) / 300000.0
		print(JSON.stringify({"scene": path, "load_ms": load_ms, "instantiate_ms": instantiate_ms,
			"nodes_before_ready": nodes, "synthetic_topology_scan_ms": collision_ms}))
		topology.free()
		var detached_loaders: Array[Node] = []
		for property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
			if property in instance:
				detached_loaders.append(instance.get(property))
		instance.free()
		var survivors := 0
		for loader in detached_loaders:
			if is_instance_valid(loader):
				survivors += 1
				loader.free()
		if survivors > 0:
			print(JSON.stringify({"scene": path, "detached_loaders_surviving_owner_free": survivors,
				"probe_cleanup": "freed explicitly after observation"}))
	for side: int in [128, 256, 512]:
		var pixels := Image.create(side, side, false, Image.FORMAT_RGBA8)
		pixels.fill(Color(0.7, 0.6, 0.4, 1.0))
		var texture := ImageTexture.create_from_image(pixels)
		var times: Array[float] = []
		for _i in 7:
			var started := Time.get_ticks_usec()
			var tinted := Appearance._make_tinted_texture(texture, Color.CORNFLOWER_BLUE, true)
			times.append((Time.get_ticks_usec() - started) / 1000.0)
			assert(tinted != null)
		times.sort()
		print(JSON.stringify({"synthetic_tint_side": side, "median_ms": times[3]}))
	var remote_script := load("res://scripts/world/remote_player_avatar.gd") as Script
	var avatar: Node2D = remote_script.new()
	avatar.call("_create_visual")
	var state := {"userId": 1, "username": "SyntheticTrainer", "displayName": "SyntheticTrainer",
		"mapId": "cerulean_city", "position": {"x": 32, "y": 32}, "facingDirection": "down"}
	avatar.call("apply_state", state)
	for method: String in ["apply_state", "_update_animation"]:
		var started := Time.get_ticks_usec()
		for _i in 1000:
			if method == "apply_state":
				avatar.call(method, state)
			else:
				avatar.call(method, false)
		print(JSON.stringify({"remote_method": method, "warm_mean_ms": (Time.get_ticks_usec() - started) / 1000000.0}))
	var pixels: Array = []
	pixels.resize(1024)
	pixels.fill(0)
	state["guildEmblem"] = {"palette": ["#ffffffff"], "pixels": pixels}
	var guild_started := Time.get_ticks_usec()
	for _i in 1000:
		avatar.call("apply_state", state)
	print(JSON.stringify({"remote_method": "apply_state_with_guild", "warm_mean_ms": (Time.get_ticks_usec() - guild_started) / 1000000.0}))
	var base_frames := Appearance.get_body_frames(Appearance.DEFAULT_MALE_BODY_ID, "male")
	var body_times: Array[float] = []
	for _i in 7:
		var started := Time.get_ticks_usec()
		var tinted := Appearance._build_skin_tinted_sprite_frames(base_frames, Color("#c58a5c"))
		body_times.append((Time.get_ticks_usec() - started) / 1000.0)
		assert(tinted != null)
	body_times.sort()
	print(JSON.stringify({"actual_asset": "Gen4_Base_v1 skin tint complete animation set", "median_ms": body_times[3]}))
	avatar.free()
	var sprite_script := load("res://scripts/battle/battle_ui/sprite_box.gd") as Script
	var sprite_loader: Node = sprite_script.new()
	for species: String in ["pikachu", "charizard", "gyarados"]:
		var started := Time.get_ticks_usec()
		var frames: SpriteFrames = sprite_loader.call("_load_sprite_frames", species, "front", false)
		var cold_ms := (Time.get_ticks_usec() - started) / 1000.0
		started = Time.get_ticks_usec()
		var cached: SpriteFrames = sprite_loader.call("_load_sprite_frames", species, "front", false)
		print(JSON.stringify({"battle_species": species, "first_load_ms": cold_ms,
			"cached_load_ms": (Time.get_ticks_usec() - started) / 1000.0,
			"frames": frames.get_frame_count("idle"), "same_cached_resource": cached == frames}))
	sprite_loader.free()
	await process_frame
	await process_frame
	quit()


func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count


func _blocking_topology(node: Node) -> Node:
	# Preserve actual map topology, but avoid gameplay/story callbacks outside a world.
	# This measures only traversal overhead with constant-false synthetic blockers.
	var copy: Node = SyntheticBlocker.new() if node.has_method("blocks_world_position") else Node.new()
	copy.name = node.name
	for child in node.get_children():
		copy.add_child(_blocking_topology(child))
	return copy
