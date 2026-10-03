@tool
extends Node


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--beacon-editor-check"):
		return
	_check_beacon.call_deferred()


func _check_beacon() -> void:
	if not Engine.is_editor_hint():
		push_error("Run the beacon editor check scene with --editor -- --beacon-editor-check.")
		get_tree().quit(1)
		return
	var beacon := get_node("AetherBeacon")
	var valid: bool = (
		beacon.display_name == "Aether Beacon"
		and not beacon.requires_facing
		and beacon.interaction_shape_size == Vector2(80, 80)
		and not beacon.is_activated()
	)
	if not valid:
		push_error("Beacon editor initialization failed.")
		get_tree().quit(1)
		return
	print("Aether Beacon editor initialization passed.")
	get_tree().quit(0)
