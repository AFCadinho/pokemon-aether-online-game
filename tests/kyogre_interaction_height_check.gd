extends SceneTree

# Keep the real NPC area, facing and interaction lifecycle, without metadata IO.
class ProbeNPC extends "res://scripts/world/npcs/base_npc.gd":
	var openings := 0
	func _ready() -> void:
		set_process(false)
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)
	func _sync_nameplate() -> void:
		pass
	func _sync_thieving_prompt() -> void:
		pass
	func _prefetch_nearby_npc_content() -> void:
		pass
	func _run_story_or_legacy_interaction(_body: Node2D, _trigger: String) -> Dictionary:
		openings += 1
		return {"status": "done"}

class ProbeObject extends "res://scripts/world/interactables/world_interactable.gd":
	var openings := 0
	func _ready() -> void:
		super._ready()
		set_process(false)
	func _run_story_or_legacy_interaction(_body: Node2D, _trigger: String) -> Dictionary:
		openings += 1
		return {"status": "done"}

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var map := Node2D.new()
	map.position = Vector2(512, 256)
	root.add_child(map)
	root.get_node("GameState").current_map = map
	var player: Node2D = load("res://scenes/player.tscn").instantiate()
	player.set_script(load("res://tests/fixtures/mount_depth_player.gd"))
	player.name = "Player"
	player.position = Vector2(112, 112)
	map.add_child(player)
	var npc: Node2D = load("res://scenes/npcs/overworld_pokemon.tscn").instantiate()
	npc.set_script(ProbeNPC)
	map.add_child(npc)
	var object := ProbeObject.new()
	map.add_child(object)
	var feet: Vector2 = player.call("get_feet_position")
	var original_look: Vector2 = player.get_node("Look").position
	var original_collision: Vector2 = player.get_node("DetectionShape").position
	for mount_id: String in ["primal_kyogre", "primal_kyogre_shiny"]:
		player.set("surf_activity_active", true)
		player.set("activity_style", "surf")
		player.set("active_mount_id", mount_id)
		player.call("refresh_appearance")
		player.call("_sync_mount_visual")
		for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT]:
			player.set("last_direction", direction)
			player.call("set_idle_frame")
			var rider: Vector2 = player.get_node("Look/Rider").position
			var mount_position: Vector2 = player.get_node("Look/MountSprite").position
			_check(player.call("get_interaction_position") == feet + Vector2(0, 16), "mouth height changes only the side interaction origin")
			# NPC is one horizontal tile away, on the lower row at the mouth.
			npc.global_position = feet + direction * 32 + Vector2(0, 32)
			object.global_position = npc.global_position
			await _settle_physics()
			_check(npc.get("player_nearby") and npc.get("nearby_player") == player, "real 64px NPC area detects the diagonal physical neighbour")
			_check(object.player_nearby, "object proximity area also detects the player")
			_check(npc.call("_is_player_facing_npc", player), "NPC at mouth height is selected")
			_check(object.call("_is_player_facing_interactable", player), "object at mouth height is selected")
			Input.action_press("interact")
			_check(npc.call("_can_start_manual_interaction"), "interact input accepts mouth-height NPC through the complete gate")
			_check(object.call("_can_start_manual_interaction"), "interact input accepts mouth-height object")
			Input.action_release("interact")
			var openings: int = npc.get("openings")
			await npc.call("_start_manual_interaction", player)
			await object.call("_start_manual_interaction", player)
			_check(npc.get("openings") == openings + 1 and not npc.get("is_interacting"), "NPC interaction completes exactly once")
			_check(player.get("last_direction") == direction, "conversation keeps the player looking sideways, not down")
			_check(npc.get("facing_direction") == -direction, "NPC faces the mouth-height origin")
			_check(not root.get_node("GameState").is_overworld_input_locked(), "interaction releases the input lock")
			_check(player.call("get_feet_position") == feet, "physical feet do not move")
			_check(player.get_node("Look").position == original_look and player.get_node("DetectionShape").position == original_collision, "visual and collision anchors stay unchanged")
			_check(player.get_node("Look/Rider").position == rider and player.get_node("Look/MountSprite").position == mount_position, "rider and mount stay exactly where they were")
			for displacement: Vector2 in [direction * 32, direction * 64 + Vector2(0, 32), -direction * 32 + Vector2(0, 32)]:
				npc.global_position = feet + displacement
				object.global_position = npc.global_position
				_check(not npc.call("_is_player_facing_npc", player), "wrong row, extra distance and rear NPCs stay out of reach")
				_check(not object.call("_is_player_facing_interactable", player), "objects keep the same direction and distance limits")
		for direction: Vector2 in [Vector2.UP, Vector2.DOWN]:
			player.set("last_direction", direction)
			_check(player.call("get_interaction_position") == feet, "front/back interaction remains at the physical tile")
			npc.global_position = feet + direction * 32
			_check(npc.call("_is_player_facing_npc", player), "front/back adjacent NPC remains reachable")
	# Leaving Kyogre or leaving Surf removes the correction immediately.
	for mount_id: String in ["lapras", "magikarp", "rayquaza", ""]:
		player.set("active_mount_id", mount_id)
		player.set("last_direction", Vector2.LEFT)
		_check(player.call("get_interaction_position") == feet, "other mounts retain their ordinary interaction origin")
		npc.global_position = feet + Vector2(-32, 0)
		_check(npc.call("_is_player_facing_npc", player), "ordinary adjacent interaction stays available")
	player.set("active_mount_id", "primal_kyogre")
	player.set("surf_activity_active", false)
	_check(player.call("get_interaction_position") == feet, "inactive saved mount cannot change interaction height")
	root.get_node("GameState").current_map = null
	map.free()
	await process_frame
	print("Kyogre interaction height checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)

func _settle_physics() -> void:
	for _frame in range(4):
		await physics_frame
	await process_frame

func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
