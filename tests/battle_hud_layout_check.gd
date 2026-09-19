extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var hud: PanelContainer = load("res://scenes/battle/pokemon_hud_panel.tscn").instantiate()
	root.add_child(hud)
	hud.set_pokemon_data("Jigglypuff", 6, 26, 30)
	await process_frame
	var rows: GridContainer = hud.get_node("MarginContainer/VBoxContainer")
	var first: Control = rows.get_node("PokemonInfoHud")
	var bar: ProgressBar = first.get_node("MarginContainer/VBoxContainer/HPRow/HpBar")
	_check(rows.columns == 1 and first.size.x >= 240 and bar.size.x >= 160 and hud.size.x == 280,
		"single battle HP contents fill the compact 280-pixel panel")
	hud.set_double_layout(true)
	hud.set_double_position(1, {"species": "Ekans", "level": 5, "hp": 20, "maxHp": 20})
	await process_frame
	var second: Control = rows.get_node("PokemonInfoHud2")
	_check(rows.columns == 2 and first.size.x >= 200 and second.size.x >= 200 and hud.size.x >= 460,
		"double battle HP contents sit side by side")
	hud.set_double_layout(false)
	hud.set_double_position(1, {})
	await process_frame
	_check(rows.columns == 1 and first.size.x >= 240 and bar.size.x >= 160 and hud.size.x == 280,
		"returning to a single battle restores full-width HP contents")
	hud.queue_free()
	quit(0 if not _failed else 1)


var _failed := false


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failed = true
		printerr("FAIL: ", message)
