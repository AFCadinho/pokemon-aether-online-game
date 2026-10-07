extends SceneTree

# Run through ops/worktrees/slot-env. No account/session or service requests.
const POPUP_METHODS: Array[String] = [
	"_setup_trainer_card_popup", "_setup_donator_store_popup", "_setup_market_popup",
	"_setup_aether_exchange_popup", "_setup_aether_atelier_popup", "_setup_bank_popup",
	"_setup_move_mentor_popup", "_setup_move_deleter_popup", "_setup_shiny_tracker_popup",
]

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := load("res://scenes/interface/ui_overlay.tscn") as PackedScene
	for sample in range(5):
		var instantiated_at := Time.get_ticks_usec()
		var overlay := scene.instantiate()
		if "--full" in OS.get_cmdline_user_args():
			var instantiated_ms := (Time.get_ticks_usec() - instantiated_at) / 1000.0
			var ready_at := Time.get_ticks_usec()
			root.add_child(overlay)
			var ready_ms := (Time.get_ticks_usec() - ready_at) / 1000.0
			print("STARTUP_OVERLAY sample=%d instantiate_ms=%.3f ready_ms=%.3f nodes=%d" % [
				sample, instantiated_ms, ready_ms, _node_count(overlay),
			])
			overlay.free()
			await process_frame
			continue
		var control: Control = overlay.get_node("Control")
		overlay.remove_child(control)
		control.owner = null
		root.add_child(control)
		overlay.set("root_control", control)
		for method: String in POPUP_METHODS:
			var before := _node_count(control)
			var started := Time.get_ticks_usec()
			overlay.call(method)
			var elapsed := Time.get_ticks_usec() - started
			print("STARTUP_POPUP sample=%d method=%s ms=%.3f nodes=%d" % [
				sample, method, elapsed / 1000.0, _node_count(control) - before,
			])
		overlay.free()
		control.free()
		await process_frame
	quit()

func _node_count(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _node_count(child)
	return count
