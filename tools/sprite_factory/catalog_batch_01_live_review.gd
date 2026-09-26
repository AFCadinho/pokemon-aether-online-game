extends SceneTree
## Interactive local normal/shiny review in the real desktop battle screen.
const NAMES := ["charmeleon", "dunsparce", "flaaffy", "houndoom", "houndour", "igglybuff", "mareep", "persian", "phanpy", "skiploom", "slowking", "stantler", "teddiursa", "ursaring"]

var battle: Control
var stage: Control
var host: Control
var info: Label
var index := 0
var busy := false


func _init() -> void:
	_run.call_deferred()


func _button(label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.pressed.connect(action)
	return button


func _overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(190, 8)
	panel.custom_minimum_size = Vector2(900, 88)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.14, 0.94)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	info = Label.new()
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(info)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(controls)
	controls.add_child(_button("← Vorige", func(): _select(-1)))
	controls.add_child(_button("Volgende →", func(): _select(1)))
	controls.add_child(_button("Aanval", func(): _action("physical_attack")))
	controls.add_child(_button("Special", func(): _action("special_attack")))
	controls.add_child(_button("Schade", func(): _action("damage")))
	controls.add_child(_button("Slaap", func(): _action("sleep")))
	controls.add_child(_button("Flauw", _faint))
	controls.add_child(_button("Herstel", func(): _show_pair.call_deferred()))
	controls.add_child(_button("Sluiten", quit))


func _select(delta: int) -> void:
	if busy:
		return
	index = posmod(index + delta, NAMES.size())
	_show_pair.call_deferred()


func _action(action: String) -> void:
	if busy or not stage.active:
		return
	stage.start_action("p1", action)
	stage.start_action("p2", action)


func _faint() -> void:
	if busy or not stage.active:
		return
	stage.play_action("p1", "faint_start")
	stage.play_action("p2", "faint_start")


func _show_pair() -> void:
	busy = true
	var species: String = NAMES[index]
	info.text = "%d/14  %s · normaal links, shiny rechts · laden…" % [index + 1, species.capitalize()]
	stage.set_combatant(0, species, false, true)
	stage.set_combatant(1, species, true, true)
	var deadline := Time.get_ticks_msec() + 30000
	while not stage.active or stage.identities != [species, species + "@shiny"] or stage._models_pending():
		if Time.get_ticks_msec() >= deadline:
			info.text = "Model kon niet laden: " + species + " · " + stage.reason
			busy = false
			if OS.get_environment("POKEAETHER_BATCH01_LIVE_SMOKE") == "1":
				quit(2)
			return
		await process_frame
	battle.player_hud_panel.set_pokemon_data(species.capitalize(), 100, 100, 100)
	battle.enemy_hud_panel.set_pokemon_data((species + " shiny").capitalize(), 100, 100, 100)
	while host.get_node("Cover").visible and Time.get_ticks_msec() < deadline:
		await process_frame
	if host.get_node("Cover").visible:
		info.text = "Battle bleef laden: " + species
		busy = false
		if OS.get_environment("POKEAETHER_BATCH01_LIVE_SMOKE") == "1":
			quit(2)
		return
	info.text = "%d/14  %s · normaal links, shiny rechts · kies een actie" % [index + 1, species.capitalize()]
	busy = false
	if OS.get_environment("POKEAETHER_BATCH01_LIVE_SMOKE") == "1":
		var capture := OS.get_environment("POKEAETHER_BATCH01_LIVE_CAPTURE")
		if capture.is_absolute_path():
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(capture) == OK)
		print("BATCH01_LIVE_REVIEW_OK first_pair=", species)
		quit()


func _run() -> void:
	var catalog := OS.get_environment("POKEAETHER_BATCH01_RUNTIME_CATALOG")
	if not catalog.is_absolute_path() or not FileAccess.file_exists(catalog):
		push_error("Local batch-01 review catalog is missing")
		quit(2)
		return
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_ui_layout = "immersive"
	settings.battle_3d_arena = "classic"
	settings.battle_3d_camera_motion = false
	settings.battle_3d_catalog_path = catalog
	root.size = Vector2i(1280, 720)
	host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	battle = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(host)
	host.mount(battle)
	stage = battle.animation_router.model_presenter
	_overlay()
	await _show_pair()
