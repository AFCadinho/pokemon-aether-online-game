extends "res://scripts/battle/battle_animation_router.gd"

# Presentation-only adapter: these aliases never leave the client or change
# engine/controller identity. Each source/target pair owns its router instance.
var audible := true
signal presentation_tick


func cancel_render() -> void:
	super.cancel_render()
	# Resume pending resource/animation waits before the owning Node is freed.
	presentation_tick.emit()


func _emit_presentation_tick() -> void:
	presentation_tick.emit()


func _wait_for_animation_resources(parent_node: Node, config: Dictionary) -> void:
	if not is_instance_valid(parent_node) or not parent_node.is_inside_tree(): return
	var tree := parent_node.get_tree()
	var epoch := render_generation
	var deadline := Time.get_ticks_msec() + 1500
	tree.process_frame.connect(_emit_presentation_tick)
	while epoch == render_generation and is_instance_valid(parent_node) and parent_node.is_inside_tree():
		if _animation_resources_finished_loading(config) or Time.get_ticks_msec() >= deadline: break
		await presentation_tick
	if tree.process_frame.is_connected(_emit_presentation_tick):
		tree.process_frame.disconnect(_emit_presentation_tick)


func dispose() -> void:
	cancel_render()
	# Every prewarm request owns a threaded-loader reference, including sounds
	# that never played. Drain it before clearing this router's local cache.
	for path: String in threaded_resource_requests:
		var status := ResourceLoader.load_threaded_get_status(path)
		if status in [ResourceLoader.THREAD_LOAD_IN_PROGRESS, ResourceLoader.THREAD_LOAD_LOADED]:
			ResourceLoader.load_threaded_get(path)
	clear_move_animation_cache()
	setup(null, null, null)


func _wait_for_animation_node(animation_node: Node2D, parent_node: Node) -> void:
	if not is_instance_valid(parent_node) or not parent_node.is_inside_tree(): return
	var tree := parent_node.get_tree()
	var epoch := render_generation
	var deadline := Time.get_ticks_msec() + 3500
	tree.process_frame.connect(_emit_presentation_tick)
	while epoch == render_generation and is_instance_valid(animation_node) and animation_node.is_inside_tree():
		if Time.get_ticks_msec() >= deadline: break
		await presentation_tick
	if tree.process_frame.is_connected(_emit_presentation_tick):
		tree.process_frame.disconnect(_emit_presentation_tick)
	if is_instance_valid(animation_node): animation_node.queue_free()


func _play_move_actor_motion_if_needed(config: Dictionary, actor_ident: String) -> void:
	# Secondary spread targets do not repeat the sound, but the selected actor
	# still performs its physical motion for every catalog presentation.
	super._play_move_actor_motion_if_needed(config, actor_ident)


func _hide_move_actor_sprite_if_needed(config: Dictionary, actor_ident: String) -> Array:
	return super._hide_move_actor_sprite_if_needed(config, actor_ident) if audible else []


func _fit_animation_to_parent(animation_node: Node2D, parent_node: Node) -> void:
	# Two doubles positions share each side of the field. Fit one catalog canvas
	# into half its width instead of enlarging a singles effect to cover all four
	# Pokémon. Endpoint conversion uses this same transform.
	if bool(animation_node.get_meta("coop_full_field_effect", false)):
		super._fit_animation_to_parent(animation_node, parent_node)
		return
	const SOURCE_SIZE := Vector2(512, 384)
	if parent_node is Control:
		var available_size: Vector2 = (parent_node as Control).size
		var pair_scale: float = minf(available_size.x / (SOURCE_SIZE.x * 2.0), available_size.y / SOURCE_SIZE.y)
		animation_node.scale = Vector2(pair_scale, pair_scale)
		animation_node.position = (available_size - SOURCE_SIZE * pair_scale) * 0.5
		return
	animation_node.position = Vector2.ZERO


func _create_move_animation_node(config: Dictionary, resources: Dictionary = {}, reverse_battlefield: bool = false) -> MoveAnimationPlayer:
	var node := super._create_move_animation_node(config, resources, reverse_battlefield)
	var category := str(config.get("category", "")).strip_edges().to_lower()
	if category in ["field", "field_hazard", "screen"] or str(config.get("static_visual_anchor", "")).strip_edges().to_lower() == "battlefield":
		node.set_meta("coop_full_field_effect", true)
	if not audible:
		node.sound_paths = {}
		node.sound_streams = {}
		node.custom_sound_events = []
		node.disable_data_sound_events = true
	return node


func _play_one_shot_sound(sound_path: String) -> void:
	if audible:
		super._play_one_shot_sound(sound_path)
