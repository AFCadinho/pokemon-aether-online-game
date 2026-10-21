extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Pass the paired backend game-content/data/thieving/targets.json after --")
		quit(1)
		return
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var targets: Array = []
	for npc_id: String in catalog.targets:
		var target: Dictionary = catalog.targets[npc_id].duplicate(true)
		target.merge({"npcId": npc_id, "requiredLevel": 1, "unlocked": true, "availableToday": true})
		targets.append(target)
	var host := Control.new()
	host.size = Vector2(1280, 900)
	root.add_child(host)
	var panel := (load("res://scenes/interface/skills_panel.tscn") as PackedScene).instantiate()
	host.add_child(panel)
	await process_frame
	panel.selected_skill_id = "thieving"
	panel.call("_render_targets", targets)
	var groups: Dictionary = panel.targets_by_town
	var count := 0
	for town_key: String in groups:
		panel.selected_target_town_key = town_key
		panel.call("_render_selected_target_town")
		count += panel.targets_container.get_child_count()
	_check(count == targets.size(), "every catalog target renders under its town")
	for target: Dictionary in targets:
		if target.npcType != "law_enforcement":
			continue
		var row: Control = panel.call("_create_target_row", target)
		var labels := row.find_children("*", "Label", true, false)
		var warning := false
		for label: Label in labels:
			warning = warning or label.text == root.get_node("LocalizationManager").call("text", "ui.skills.thieving.target.police_warning")
		_check(warning, "police targets show guaranteed arrest instead of an ordinary available badge")
		row.free()
	host.free()
	print("TOWN_THIEVING_UI ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
