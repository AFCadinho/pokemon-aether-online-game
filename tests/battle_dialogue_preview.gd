extends SceneTree
## Interactive, offline visual harness. Never creates a server battle or saves settings.
var host: Control
var battle: Control
var mode: OptionButton
var arena: OptionButton
var message: LineEdit
var status: Label
var toolbar: VBoxContainer
var loading := false
var freeze_preview := false
var weather_preview := false
var weather_picker: OptionButton
var weather_enabled: CheckButton
const WEATHER_KEYS := ["", "RainDance", "SunnyDay", "Sandstorm", "Snowscape", "Hail", "PrimordialSea", "DesolateLand", "DeltaStream"]
const WEATHER_LABELS := ["Helder", "Regen", "Zon", "Zandstorm", "Sneeuw", "Hagel", "Primordial Sea", "Desolate Land", "Delta Stream"]
var right_species := "Roaring Moon"
var freeze_buttons: Array[Button] = []
const ARENAS := ["stadium", "forest", "cave", "sea"]

func _init() -> void:
	_start.call_deferred()

func _start() -> void:
	freeze_preview = "--freeze" in OS.get_cmdline_user_args()
	weather_preview = "--weather" in OS.get_cmdline_user_args()
	if freeze_preview or weather_preview: right_species = "Pikachu"
	root.title = "PokeAether — Freeze preview" if freeze_preview else "PokeAether — Offline trainer dialogue preview"
	if weather_preview: root.title = "PokeAether — 3D weather preview"
	var layer := CanvasLayer.new()
	layer.layer = 110
	root.add_child(layer)
	var panel := PanelContainer.new()
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 12
	panel.offset_right = 450
	panel.offset_top = -300 if weather_preview else (-275 if freeze_preview else -205)
	panel.offset_bottom = -12
	toolbar = VBoxContainer.new()
	panel.add_child(toolbar)
	var row := HBoxContainer.new()
	toolbar.add_child(row)
	mode = OptionButton.new()
	mode.add_item("2.5D")
	mode.add_item("3D")
	if freeze_preview or weather_preview: mode.select(1)
	row.add_child(mode)
	arena = OptionButton.new()
	for id in ARENAS:
		arena.add_item(id.capitalize())
	row.add_child(arena)
	_button(row, "Load preview", _load_preview)
	_button(row, "Quit", func(): quit())
	message = LineEdit.new()
	message.placeholder_text = "Optional custom dialogue"
	message.custom_minimum_size.x = 420
	toolbar.add_child(message)
	var speech := HBoxContainer.new()
	toolbar.add_child(speech)
	_button(speech, "Left speaks", func(): _say(0))
	_button(speech, "Right speaks", func(): _say(1))
	_button(speech, "Both speak", func(): _say(0); _say(1))
	_button(speech, "Clear", func():
		if is_instance_valid(battle):
			battle.player_trainer_sprite.command_callout.clear_command()
			battle.enemy_trainer_sprite.command_callout.clear_command())
	if freeze_preview:
		var freezing := HBoxContainer.new()
		toolbar.add_child(freezing)
		freeze_buttons.append(_button(freezing, "Bevries links", func(): _freeze(0, true)))
		freeze_buttons.append(_button(freezing, "Bevries rechts", func(): _freeze(1, true)))
		freeze_buttons.append(_button(freezing, "Ontdooi alles", func(): _freeze(0, false); _freeze(1, false)))
		freeze_buttons.append(_button(toolbar, "Aanval geblokkeerd (rechts)", _freeze_blocked))
	if weather_preview:
		weather_picker = OptionButton.new()
		for label in WEATHER_LABELS: weather_picker.add_item(label)
		weather_picker.select(1)
		weather_picker.item_selected.connect(func(_index): _weather())
		toolbar.add_child(weather_picker)
		var weather_row := HBoxContainer.new()
		toolbar.add_child(weather_row)
		weather_enabled = CheckButton.new()
		weather_enabled.text = "Weereffecten"
		weather_enabled.button_pressed = true
		weather_enabled.toggled.connect(func(_enabled): _weather())
		weather_row.add_child(weather_enabled)
		var pause := CheckButton.new()
		pause.text = "Pauze"
		pause.toggled.connect(func(paused):
			if is_instance_valid(battle): battle.animation_router.model_presenter.playback_speed = 0.0 if paused else 1.0)
		weather_row.add_child(pause)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = 420
	toolbar.add_child(status)
	await _load_preview()
	if freeze_preview:
		await _freeze(1, true)
		if battle.animation_router.model_presenter.active:
			print("FREEZE_PREVIEW_READY")
		if "--smoke-freeze" in OS.get_cmdline_user_args():
			await _check_freeze()
			return
	if weather_preview:
		_weather()
		print("WEATHER_PREVIEW_READY")
		if "--smoke-weather" in OS.get_cmdline_user_args():
			await _check_weather()
			return
	if "--smoke" in OS.get_cmdline_user_args():
		await create_timer(0.4).timeout
		_say(0)
		_say(1)
		await create_timer(0.25).timeout
		assert(battle.battle_stage.get_node("SpeakingTrainer0").visible)
		assert(battle.battle_stage.get_node("SpeakingTrainer1").visible)
		assert(battle.battle_state.battle_id.is_empty())
		var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
		if not output.is_empty() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("dialogue-preview.png"))
		await create_timer(3.5).timeout
		assert(not battle.battle_stage.get_node("SpeakingTrainer0").visible)
		await _load_preview()
		await create_timer(0.4).timeout
		_say(1)
		await create_timer(0.2).timeout
		assert(battle.battle_stage.get_node("SpeakingTrainer1").visible)
		print("OFFLINE_DIALOGUE_PREVIEW_OK")
		quit()

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _load_preview() -> void:
	if loading:
		return
	loading = true
	if is_instance_valid(host):
		host.release()
		host.queue_free()
		await process_frame
	var settings = root.get_node("SettingsManager")
	# Direct in-memory assignments deliberately bypass settings persistence.
	settings.battle_ui_layout = "immersive"
	settings.battle_presentation_mode = "2.5d" if mode.selected == 0 else "3d"
	settings.battle_3d_arena = ARENAS[arena.selected]
	if freeze_preview or weather_preview: settings.battle_animations = true
	var catalog := OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	if not catalog.is_empty():
		settings.battle_3d_catalog_path = catalog
	elif freeze_preview or weather_preview:
		# Use the normal pinned asset service in this slot, never another checkout's cache.
		settings.battle_3d_catalog_path = ""
		settings._manual_model_catalog_this_session = false
	else:
		# The ordinary dialogue preview uses only the selected local catalog.
		settings._manual_model_catalog_this_session = true
	status.text = "Loading… No server battle is created."
	host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	root.add_child(host)
	battle = load("res://scenes/battle/battle.tscn").instantiate()
	host.mount(battle)
	battle._show_local_player_trainer()
	var appearance: Dictionary = root.get_node("PlayerSave").to_appearance_state()
	battle.enemy_trainer_sprite.show_player(appearance, Vector2.LEFT)
	battle.vs_panel_container.set_names("You", "Preview rival")
	battle.player_sprite_box.set_single_pokemon_species("Dragonite", "back")
	battle.enemy_sprite_box.set_single_pokemon_species(right_species, "front")
	battle.player_hud_panel.set_pokemon_data("Dragonite", 100, 323, 323)
	battle.enemy_hud_panel.set_pokemon_data(right_species, 100, 351, 351)
	var party := []
	for species in ["Dragonite", "Typhlosion", "Scizor", "Arcanine", "Charizard", right_species]:
		party.append({"species":species,"hp":100,"max_hp":100,"active":species == "Dragonite"})
	battle.player_party_grid.set_party(party)
	battle.get_node("%PlayerStagePartyGrid").set_party(party)
	var opponent_party: Array = party.duplicate(true)
	opponent_party.reverse()
	for pokemon in opponent_party:
		pokemon.active = pokemon.species == right_species
	battle.opponent_party_grid.set_party(opponent_party)
	var parent: Control = battle.player_party_grid
	while parent != battle:
		parent.show()
		parent = parent.get_parent() as Control
	battle.current_action_panel.set_message("Freeze-test — draai de camera en gebruik Bevriezen / Ontdooien" if freeze_preview else "Offline preview — dialogue controls at bottom left")
	# The real controls are display-only: no moves, bags, switches or requests.
	_disable_gameplay(battle)
	var renderer = battle.animation_router.model_presenter
	if mode.selected == 1 and is_instance_valid(renderer):
		renderer.set_combatant(0, "Dragonite")
		renderer.set_combatant(1, right_species)
		await renderer.await_prepared(true, 30000)
		if renderer.preparation_failed or not renderer.active:
			status.text = "3D unavailable: " + renderer.reason + " — choose 2.5D or use the fallback button."
		else:
			renderer.set_actor_shown(0, true)
			renderer.set_actor_shown(1, true)
			status.text = "Ready — drag the arena to orbit. Arena: " + renderer.arena_id
	else:
		status.text = "Ready — 2.5D dialogue preview. Arena selection applies to 3D."
	if weather_preview: battle.current_action_panel.set_message("Weertest — kies een weertype en draai de camera")
	var reveal_deadline := Time.get_ticks_msec() + 35000
	while host.get_node("Cover").visible and Time.get_ticks_msec() < reveal_deadline:
		await process_frame
	loading = false
	if weather_preview: _weather()
	for button in freeze_buttons:
		button.disabled = not is_instance_valid(renderer) or not renderer.active or mode.selected != 1

func _disable_gameplay(node: Node) -> void:
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	node.set_process_unhandled_key_input(false)
	if node is BaseButton:
		node.disabled = true
	for child in node.get_children():
		if child.name != "ImmersiveCameraInput":
			_disable_gameplay(child)

func _say(side: int) -> void:
	if loading or not is_instance_valid(battle) or host.get_node("Cover").visible:
		return
	var text := message.text.strip_edges()
	if text.is_empty():
		text = "Dragonite, use Dragon Dance!" if side == 0 else "Roaring Moon, show them what you can do!"
	battle._show_trainer_command_text("p1" if side == 0 else "p2", text, 3.0)

func _freeze(side: int, enabled: bool) -> void:
	if loading or not is_instance_valid(battle): return
	var renderer: Node = battle.animation_router.model_presenter
	if not is_instance_valid(renderer) or not renderer.handles("p%d" % (side+1)): return
	# Presentation only: no BattleState, party, save or server status is changed.
	renderer.set_status_condition(side, "frz" if enabled else "")
	var hud: Control = battle.player_hud_panel if side == 0 else battle.enemy_hud_panel
	var hp := 323 if side == 0 else 351
	hud.set_pokemon_data("Dragonite" if side == 0 else right_species, 100, hp, hp, "frz" if enabled else "")
	status.text = "Freeze geforceerd — draai de camera; Ontdooi alles verwijdert het effect." if enabled else "Ontdooid — normale animatie hervat."
	if enabled:
		await battle.event_renderer.render_event({"type":"status", "status":"frz"}, {
			"effect_animation_key":"status_frozen", "effect_animation_target_ident":"p%d" % (side+1)
		}, true)

func _freeze_blocked() -> void:
	if loading or not is_instance_valid(battle): return
	var renderer: Node = battle.animation_router.model_presenter
	if not is_instance_valid(renderer) or not renderer.handles("p2"): return
	await _freeze(1, true)
	status.text = "Pikachu kan niet aanvallen door Freeze — eenmalige ijskristallen."
	await battle.event_renderer.render_event({"type":"cant", "reason":"frz", "actor":"p2"}, {
		"effect_animation_key":"status_frozen", "effect_animation_target_ident":"p2"
	}, true)

func _check_freeze() -> void:
	var renderer: Node = battle.animation_router.model_presenter
	if not renderer.active or not is_instance_valid(renderer.status_effects[1]):
		push_error("Freeze preview could not prepare native models: " + renderer.reason)
		quit(1)
		return
	assert(battle.battle_state.battle_id.is_empty())
	assert(renderer.status_conditions[1] == "frozen")
	await process_frame
	assert(renderer.players[1].speed_scale == 0.0)
	assert(renderer.status_effects[1].particles.is_empty())
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	if not output.is_empty() and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(output)
		for i in 20: await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(output.path_join("freeze-preview.png"))
	await _freeze_blocked()
	assert(renderer.status_conditions[1] == "frozen" and renderer.players[1].speed_scale == 0.0)
	await _freeze(1, false)
	await process_frame
	assert(renderer.status_effects[1] == null and renderer.players[1].speed_scale > 0.0)
	await _freeze(0, true)
	await process_frame
	assert(renderer.status_conditions[0] == "frozen" and renderer.players[0].speed_scale == 0.0)
	await _freeze(0, false)
	await process_frame
	assert(renderer.status_effects[0] == null and renderer.players[0].speed_scale > 0.0)
	assert(battle.battle_state.battle_id.is_empty())
	print("FREEZE_PREVIEW_OK both_sides=true thaw=true offline_battle=true")
	host.release()
	host.queue_free()
	await process_frame
	quit.call_deferred()

func _finalize() -> void:
	if is_instance_valid(host):
		host.release()

func _weather() -> void:
	if loading or not is_instance_valid(battle): return
	root.get_node("SettingsManager").weather_effects = weather_enabled.button_pressed
	battle.weather_presentation.update_weather(WEATHER_KEYS[weather_picker.selected])
	status.text = "Weertest: " + WEATHER_LABELS[weather_picker.selected] + " — draai de camera, pauzeer of schakel het effect uit."

func _check_weather() -> void:
	var renderer: Node = battle.animation_router.model_presenter
	if not renderer.active:
		push_error("Weather preview could not prepare native models: " + renderer.reason)
		quit(1)
		return
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	for i in range(1, WEATHER_KEYS.size()):
		weather_picker.select(i)
		_weather()
		await create_timer(0.8).timeout
		assert(is_instance_valid(renderer.weather_effect))
		assert(not battle.weather_particles.visible and not battle.weather_tint.visible)
		assert(battle.battle_state.battle_id.is_empty())
		if not output.is_empty() and DisplayServer.get_name() != "headless":
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png(output.path_join("weather-%s.png" % renderer.weather_effect.key))
	weather_picker.select(0)
	_weather()
	assert(renderer.weather_effect == null)
	print("WEATHER_PREVIEW_OK conditions=8 offline_battle=true")
	host.release()
	host.queue_free()
	await process_frame
	quit.call_deferred()
