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
const ARENAS := ["stadium", "forest", "cave", "sea"]

func _init() -> void:
	_start.call_deferred()

func _start() -> void:
	root.title = "PokeAether — Offline trainer dialogue preview"
	var layer := CanvasLayer.new()
	layer.layer = 110
	root.add_child(layer)
	var panel := PanelContainer.new()
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 12
	panel.offset_right = 450
	panel.offset_top = -205
	panel.offset_bottom = -12
	toolbar = VBoxContainer.new()
	panel.add_child(toolbar)
	var row := HBoxContainer.new()
	toolbar.add_child(row)
	mode = OptionButton.new()
	mode.add_item("2.5D")
	mode.add_item("3D")
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
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = 420
	toolbar.add_child(status)
	await _load_preview()
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

func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)

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
	var catalog := OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	if not catalog.is_empty():
		settings.battle_3d_catalog_path = catalog
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
	battle.enemy_sprite_box.set_single_pokemon_species("Roaring Moon", "front")
	battle.player_hud_panel.set_pokemon_data("Dragonite", 100, 323, 323)
	battle.enemy_hud_panel.set_pokemon_data("Roaring Moon", 100, 351, 351)
	var party := []
	for species in ["Dragonite", "Typhlosion", "Scizor", "Arcanine", "Charizard", "Roaring Moon"]:
		party.append({"species":species,"hp":100,"max_hp":100,"active":species == "Dragonite"})
	battle.player_party_grid.set_party(party)
	battle.get_node("%PlayerStagePartyGrid").set_party(party)
	var opponent_party: Array = party.duplicate(true)
	opponent_party.reverse()
	for pokemon in opponent_party:
		pokemon.active = pokemon.species == "Roaring Moon"
	battle.opponent_party_grid.set_party(opponent_party)
	var parent: Control = battle.player_party_grid
	while parent != battle:
		parent.show()
		parent = parent.get_parent() as Control
	battle.current_action_panel.set_message("Offline preview — dialogue controls at bottom left")
	# The real controls are display-only: no moves, bags, switches or requests.
	_disable_gameplay(battle)
	var renderer = battle.animation_router.model_presenter
	if mode.selected == 1 and is_instance_valid(renderer):
		renderer.set_combatant(0, "Dragonite")
		renderer.set_combatant(1, "Roaring Moon")
		await renderer.await_prepared(true, 30000)
		if renderer.preparation_failed:
			status.text = "3D unavailable: " + renderer.reason + " — choose 2.5D or use the fallback button."
		else:
			renderer.set_actor_shown(0, true)
			renderer.set_actor_shown(1, true)
			status.text = "Ready — drag the arena to orbit. Arena: " + renderer.arena_id
	else:
		status.text = "Ready — 2.5D dialogue preview. Arena selection applies to 3D."
	loading = false

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

func _finalize() -> void:
	if is_instance_valid(host):
		host.release()
