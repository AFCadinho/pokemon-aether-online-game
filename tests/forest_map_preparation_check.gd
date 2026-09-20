extends Node
@onready var root := get_tree().root
class PoolStub extends Node:
	var ready_for_battle := false
	var failed := false
class WorldStub extends "res://scripts/world/world.gd":
	var test_pool: Node
	var fades: Array = []
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass
	func _prefetch_current_map_desktop_arena() -> Node:
		return test_pool
	func _fade_map_transition(alpha: float, _duration: float) -> void:
		fades.append(alpha)
		await get_tree().process_frame
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	var state := root.get_node("GameState")
	var world: Variant = Node2D.new()
	root.add_child(world)
	world.set_script(WorldStub) # Skip unrelated scene-bound @onready references.
	var pool := PoolStub.new()
	world.add_child(pool)
	world.test_pool = pool
	world._await_current_map_desktop_arena()
	await get_tree().process_frame
	await get_tree().process_frame
	assert(state.overworld_input_locked and world.forest_preparation_input_owned)
	pool.ready_for_battle = true
	for frame in 4:
		await get_tree().process_frame
	assert(not state.overworld_input_locked and world.fades == [1.0,0.0])
	state.lock_overworld_input()
	world.is_loading_map = true
	pool.ready_for_battle = false
	world.fades.clear()
	world._await_current_map_desktop_arena()
	await get_tree().process_frame
	pool.ready_for_battle = true
	for frame in 4:
		await get_tree().process_frame
	assert(state.overworld_input_locked and world.fades.is_empty(),"Existing map transition owns its cover and input lock")
	state.unlock_overworld_input()
	world.is_loading_map = false
	pool.ready_for_battle = false
	world._await_current_map_desktop_arena()
	await get_tree().process_frame
	assert(state.overworld_input_locked)
	world.free()
	assert(not state.overworld_input_locked,"World teardown must release its owned preparation lock")
	var source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	assert(source.contains("await _await_current_map_desktop_arena()\n\tvar wild_resume"),"Desktop startup must prepare before resuming battles")
	assert(source.contains("_apply_camera_limits_for_map(new_map)\n\t_prefetch_current_map_desktop_arena()"),"Desktop map entry must prewarm")
	assert(source.contains("if changes_map:\n\t\tawait _await_current_map_desktop_arena()\n\t\tawait _fade_map_transition"),"Desktop teleport must await preparation under its existing cover")
	print("FOREST_MAP_PREPARATION_OK")
	get_tree().quit()
