extends SceneTree

const BASE_NPC_SCRIPT_PATH := "res://scripts/world/npcs/base_npc.gd"
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var BaseNPCScript := load(BASE_NPC_SCRIPT_PATH) as Script
	var first_npc: Node = BaseNPCScript.new()
	var second_npc: Node = BaseNPCScript.new()
	var player := load("res://scenes/player.tscn").instantiate() as Node2D
	root.add_child(player)
	await process_frame
	var front_part := player.get_node("Look/Rider/HeadgearSprite") as CanvasItem
	front_part.z_index = 15
	player.call("_cache_appearance_sprites")

	_check(first_npc._get_player_visual_sort_depth(player) == 15, "first NPC resolves player visual depth")
	front_part.z_index = 18
	_check(
		second_npc._get_player_visual_sort_depth(player) == 15,
		"other NPCs reuse the player's unchanged visual-depth cache"
	)
	player.call("_cache_appearance_sprites")
	_check(
		second_npc._get_player_visual_sort_depth(player) == 18,
		"appearance refresh invalidates the player's visual depth"
	)
	var other_player := Node2D.new()
	var other_look := Node2D.new()
	other_look.name = "Look"
	other_look.z_index = 21
	other_player.add_child(other_look)
	_check(
		first_npc._get_player_visual_sort_depth(other_player) == 21,
		"a different player never receives the previous player's cached depth"
	)

	first_npc.free()
	second_npc.free()
	root.remove_child(player)
	player.free()
	other_player.free()
	print("npc_visual_depth_cache_check: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
