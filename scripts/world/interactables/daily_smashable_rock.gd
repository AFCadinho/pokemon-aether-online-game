extends FieldMoveObstacle

class_name DailySmashableRock

const LevelPalette := preload("res://scripts/world/interactables/rock_smash_level_palette.gd")

enum RockVisualStyle {
	TRAINING,
	CAVE,
	ROUTE,
}

const TRAINING_ROCK_SHEET: Texture2D = preload(
	"res://assets/world/field_move_obstacles/object_rock_training_pewter.png"
)
const CAVE_ROCK_SHEET: Texture2D = preload(
	"res://assets/world/field_move_obstacles/object_rock.png"
)
@export var rock_id := ""
@export_range(0, 3) var rock_variant := 0
@export var rock_visual_style := RockVisualStyle.TRAINING
@export_range(1, 100, 1) var required_rock_smash_level := 1

var request_pending := false


func _ready() -> void:
	required_field_move = "rock-smash"
	if rock_visual_style == RockVisualStyle.ROUTE:
		display_name = "Route Rock"
		unavailable_message = "This route rock can be smashed with Rock Smash."
	elif rock_visual_style == RockVisualStyle.CAVE:
		display_name = "Cave Rock"
		unavailable_message = "This cave rock can be smashed with Rock Smash."
	else:
		display_name = "Training Rock"
		unavailable_message = "This training rock can be smashed with Rock Smash."
	_configure_variant_frames()
	super._ready()
	_update_sort_z()
	if not RockSmashService.state_changed.is_connected(_on_rock_smash_state_changed):
		RockSmashService.state_changed.connect(_on_rock_smash_state_changed)
	_refresh_daily_state.call_deferred()


func _update_sort_z() -> void:
	var current_map := _resolve_current_map()
	if current_map == null or not current_map.has_method("get_actor_sort_z_floor"):
		return
	var sort_z_floor := int(current_map.call("get_actor_sort_z_floor", global_position))
	if sort_z_floor <= z_index:
		return
	z_as_relative = false
	z_index = clampi(
		sort_z_floor,
		RenderingServer.CANVAS_ITEM_Z_MIN,
		RenderingServer.CANVAS_ITEM_Z_MAX
	)


func _resolve_current_map() -> Node:
	var parent_node := get_parent()
	while parent_node != null:
		if parent_node.has_method("get_actor_sort_z_floor"):
			return parent_node
		parent_node = parent_node.get_parent()

	if GameState.current_map != null and is_instance_valid(GameState.current_map):
		return GameState.current_map
	return null


func interact_with_player(_player: Node2D) -> void:
	if is_cleared or request_pending:
		return
	var field_move_result: Dictionary = FieldMoveService.can_use_field_move(required_field_move)
	if not bool(field_move_result.get("success", false)):
		await show_dialogue([str(field_move_result.get("error", unavailable_message))])
		return

	request_pending = true
	set_process(false)
	var sync_result := await _sync_player_position()
	if not bool(sync_result.get("success", false)):
		request_pending = false
		set_process(true)
		await GameErrorDialogService.show_response(sync_result, "backend.error.rock_smash_unavailable")
		return
	var result: Dictionary = await RockSmashService.smash_rock(rock_id, field_move_result)
	if not bool(result.get("success", false)):
		request_pending = false
		set_process(true)
		if BackendErrorLocalizationService.error_code(result) == "rock_smash_already_smashed":
			call_deferred("queue_free")
			return
		await GameErrorDialogService.show_response(result, "backend.error.rock_smash_unavailable")
		return

	_show_field_move_used_message(
		field_move_result.get("pokemon") as Pokemon,
		str(field_move_result.get("itemName", ""))
	)
	_show_rewards(result)
	await clear_obstacle()


func _refresh_daily_state() -> void:
	if rock_id.strip_edges().is_empty():
		push_warning("DailySmashableRock: rock_id is missing.")
		return
	if not RockSmashService.state_loaded:
		var result: Dictionary = await RockSmashService.load_state()
		if not bool(result.get("success", false)):
			push_warning("DailySmashableRock: state load failed for %s." % rock_id)
			return
	_apply_daily_state()


func _on_rock_smash_state_changed(_state: Dictionary) -> void:
	_apply_daily_state()


func _apply_daily_state() -> void:
	# A successful smash updates RockSmashService before this interaction gets
	# its response. Keep the node alive so the active interaction can animate,
	# unlock overworld input, and then remove the rock itself.
	if request_pending:
		return
	if not is_cleared and RockSmashService.is_rock_smashed_today(rock_id):
		call_deferred("queue_free")


func _configure_variant_frames() -> void:
	if obstacle_sprite == null:
		return
	obstacle_sprite.self_modulate = LevelPalette.color_for_required_level(required_rock_smash_level)
	obstacle_sprite.texture = _frame_texture(0)
	clear_frames = []
	for row in range(1, 4):
		clear_frames.append(_frame_texture(row))


func _frame_texture(row: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = (
		CAVE_ROCK_SHEET
		if rock_visual_style != RockVisualStyle.TRAINING
		else TRAINING_ROCK_SHEET
	)
	texture.region = Rect2(rock_variant * 32, row * 32, 32, 32)
	return texture


func _sync_player_position() -> Dictionary:
	var world := get_tree().get_first_node_in_group("world")
	if world == null or not world.has_method("sync_player_position_for_world_action"):
		return {"success": false, "error": "The overworld is not ready."}
	var result: Variant = await world.call("sync_player_position_for_world_action")
	return result as Dictionary if result is Dictionary else {
		"success": false,
		"error": "The player position could not be synced.",
	}


func _show_rewards(result: Dictionary) -> void:
	var experience := maxi(int(result.get("experienceAwarded", 0)), 0)
	get_tree().call_group(
		"ui_overlay",
		"add_system_message",
		LocalizationManager.text("ui.rock_smash.experience_gained", {"experience": experience})
	)
	var rewards_value: Variant = result.get("rewardItems", [])
	if rewards_value is not Array:
		return
	for reward_value: Variant in rewards_value as Array:
		if reward_value is not Dictionary:
			continue
		var reward := reward_value as Dictionary
		var item_id := str(reward.get("itemId", ""))
		var quantity := maxi(int(reward.get("quantity", 1)), 1)
		get_tree().call_group(
			"ui_overlay",
			"add_system_message",
			LocalizationManager.text("ui.rock_smash.item_found", {
				"item": ItemLocalization.display_name(item_id, item_id.replace("-", " ").capitalize()),
				"quantity": quantity,
			})
		)
