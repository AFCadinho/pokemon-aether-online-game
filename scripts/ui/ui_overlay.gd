extends CanvasLayer

const MAX_PARTY_SIZE := 6
const ADD_POKEMON_COMMAND := "/addpokemon"
const ADD_POKEMON_CLIPBOARD_COMMAND := "/addpokemonclip"
const ADD_POKEMON_CLIPBOARD_ALIAS := "/apc"
const ADD_TEAM_COMMAND := "/addteam"
const ADD_TEAM_ALIAS := "/at"
const ADD_TEAM_CLIPBOARD_COMMAND := "/addteamclip"
const ADD_TEAM_CLIPBOARD_ALIAS := "/atc"
const START_ENCOUNTER_COMMAND := "/encounter"
const START_ENCOUNTER_CLIPBOARD_COMMAND := "/encounterclip"
const START_ENCOUNTER_CLIPBOARD_ALIAS := "/ec"
const SPAWN_COMMAND := "/spawn"
const COLLAPSE_BUTTON_SIZE := Vector2(28, 28)
const COLLAPSE_BUTTON_MARGIN := 6.0

enum DevPokemonPopupMode {
	POKEMON,
	TEAM,
	SPAWN,
}

@onready var root_control: Control = $Control
@onready var party_panel: PanelContainer = $Control/PartyPanel
@onready var party_container: VBoxContainer = $Control/PartyPanel/MarginContainer/VBoxContainer
@onready var party_slot_template: PanelContainer = $Control/PartyPanel/MarginContainer/VBoxContainer/PartySlot
@onready var chat_panel: PanelContainer = $Control/ChatPanel
@onready var location_panel: PanelContainer = $Control/LocationPanel
@onready var options_panel: PanelContainer = $Control/OptionsPanel
@onready var actions_panel: PanelContainer = $Control/ActionsPanel
@onready var message_list: VBoxContainer = $Control/ChatPanel/MarginContainer/VBoxContainer/MessageScroll/MarginContainer/MessageList
@onready var message_entry_template: RichTextLabel = $Control/ChatPanel/MarginContainer/VBoxContainer/MessageScroll/MarginContainer/MessageList/MessageEntry
@onready var chat_input: LineEdit = $Control/ChatPanel/MarginContainer/VBoxContainer/InputRow/ChatInput
@onready var dev_pokemon_button: Button = $Control/ChatPanel/MarginContainer/VBoxContainer/InputRow/DevPokemonButton
@onready var send_button: Button = $Control/ChatPanel/MarginContainer/VBoxContainer/InputRow/SendButton
@onready var parse_pokemon_request: HTTPRequest = $ParsePokemonRequest
@onready var dev_pokemon_popup: PanelContainer = $Control/DevPokemonPopup
@onready var dev_pokemon_title: Label = $Control/DevPokemonPopup/MarginContainer/VBoxContainer/Title
@onready var dev_pokemon_text: TextEdit = $Control/DevPokemonPopup/MarginContainer/VBoxContainer/PokemonText
@onready var dev_pokemon_add_button: Button = $Control/DevPokemonPopup/MarginContainer/VBoxContainer/ButtonRow/AddButton
@onready var dev_pokemon_close_button: Button = $Control/DevPokemonPopup/MarginContainer/VBoxContainer/ButtonRow/CloseButton
@onready var settings_button: TextureButton = $Control/OptionsPanel/MarginContainer/HBoxContainer/SettingsSlot/SettingsButton
@onready var settings_menu: PanelContainer = $Control/SettingsMenu
@onready var repel_toggle_button: Button = $Control/ActionsPanel/MarginContainer/HBoxContainer/RepelToggle
@onready var dev_actions_button: Button = $Control/ActionsPanel/MarginContainer/HBoxContainer/DevActionsButton
@onready var dev_actions_popup: PanelContainer = $Control/DevActionsPopup
@onready var dev_add_pokemon_button: Button = $Control/DevActionsPopup/MarginContainer/VBoxContainer/AddPokemonButton
@onready var dev_add_team_button: Button = $Control/DevActionsPopup/MarginContainer/VBoxContainer/AddTeamButton
@onready var dev_spawn_pokemon_button: Button = $Control/DevActionsPopup/MarginContainer/VBoxContainer/SpawnPokemonButton
@onready var dev_actions_close_button: Button = $Control/DevActionsPopup/MarginContainer/VBoxContainer/CloseButton

var party_slots: Array = []
var dev_pokemon_popup_mode: int = DevPokemonPopupMode.POKEMON
var collapsible_panels: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_build_party_slots()
	_setup_collapsible_panels()
	_refresh_party()
	
	if not PlayerSave.party_changed.is_connected(_refresh_party):
		PlayerSave.party_changed.connect(_refresh_party)

	send_button.pressed.connect(_on_send_button_pressed)
	chat_input.text_submitted.connect(_on_chat_text_submitted)
	dev_pokemon_button.visible = false
	dev_pokemon_button.disabled = true
	dev_pokemon_add_button.pressed.connect(_on_dev_pokemon_add_button_pressed)
	dev_pokemon_close_button.pressed.connect(_on_dev_pokemon_close_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	repel_toggle_button.set_pressed_no_signal(GameState.repel_enabled)
	repel_toggle_button.toggled.connect(_on_repel_toggle_toggled)
	dev_actions_button.pressed.connect(_on_dev_actions_button_pressed)
	dev_add_pokemon_button.pressed.connect(_on_dev_add_pokemon_button_pressed)
	dev_add_team_button.pressed.connect(_on_dev_add_team_button_pressed)
	dev_spawn_pokemon_button.pressed.connect(_on_dev_spawn_pokemon_button_pressed)
	dev_actions_close_button.pressed.connect(_on_dev_actions_close_button_pressed)
	dev_actions_button.visible = PlayerSave.is_staff
	dev_actions_popup.visible = false
	if settings_menu.has_signal("closed"):
		settings_menu.closed.connect(_on_settings_menu_closed)

func _process(_delta: float) -> void:
	_position_collapsible_buttons()

func _input(event: InputEvent) -> void:
	if _is_settings_toggle_event(event):
		_toggle_settings_menu()
		get_viewport().set_input_as_handled()
		return

	if not chat_input.has_focus():
		return
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _is_point_inside_control(chat_input, mouse_event.position):
		return
	if _is_point_inside_control(send_button, mouse_event.position):
		return

	chat_input.release_focus()

func _is_point_inside_control(control: Control, point: Vector2) -> bool:
	return control.get_global_rect().has_point(point)

func _setup_collapsible_panels() -> void:
	_register_collapsible_panel("chat", chat_panel, "left")
	_register_collapsible_panel("party", party_panel, "left")
	_register_collapsible_panel("location", location_panel, "right_center")
	_register_collapsible_panel("options", options_panel, "right")
	_register_collapsible_panel("actions", actions_panel, "left")
	_position_collapsible_buttons()

func _register_collapsible_panel(panel_id: String, panel: Control, side: String) -> void:
	var button := Button.new()
	button.custom_minimum_size = COLLAPSE_BUTTON_SIZE
	button.size = COLLAPSE_BUTTON_SIZE
	button.text = "-"
	button.tooltip_text = "Collapse"
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.z_index = 200
	button.pressed.connect(_on_collapsible_panel_button_pressed.bind(panel_id))
	root_control.add_child(button)

	collapsible_panels[panel_id] = {
		"panel": panel,
		"button": button,
		"side": side,
		"collapsed": false,
		"available": true,
	}

func _on_collapsible_panel_button_pressed(panel_id: String) -> void:
	var state: Dictionary = collapsible_panels.get(panel_id, {})
	if state.is_empty():
		return

	var collapsed := not bool(state.get("collapsed", false))
	state["collapsed"] = collapsed
	collapsible_panels[panel_id] = state
	_apply_collapsible_panel_state(panel_id)

func _set_collapsible_panel_available(panel_id: String, available: bool) -> void:
	var state: Dictionary = collapsible_panels.get(panel_id, {})
	if state.is_empty():
		return

	state["available"] = available
	collapsible_panels[panel_id] = state
	_apply_collapsible_panel_state(panel_id)

func _apply_collapsible_panel_state(panel_id: String) -> void:
	var state: Dictionary = collapsible_panels.get(panel_id, {})
	if state.is_empty():
		return

	var panel: Control = state.get("panel") as Control
	var button: Button = state.get("button") as Button
	if panel == null or button == null:
		return

	var available := bool(state.get("available", true))
	var collapsed := bool(state.get("collapsed", false))
	panel.visible = available and not collapsed
	button.visible = available
	button.text = "+" if collapsed else "-"
	button.tooltip_text = "Expand" if collapsed else "Collapse"
	if collapsed and panel_id == "actions":
		dev_actions_popup.visible = false
	_position_collapsible_button(panel_id)

func _position_collapsible_buttons() -> void:
	for panel_id_value: Variant in collapsible_panels.keys():
		var panel_id := str(panel_id_value)
		_position_collapsible_button(panel_id)

func _position_collapsible_button(panel_id: String) -> void:
	var state: Dictionary = collapsible_panels.get(panel_id, {})
	if state.is_empty():
		return

	var panel: Control = state.get("panel") as Control
	var button: Button = state.get("button") as Button
	if panel == null or button == null:
		return

	var side := str(state.get("side", "right"))
	var collapsed := bool(state.get("collapsed", false))
	var rect := panel.get_rect()
	var position := rect.position
	if collapsed:
		match side:
			"left":
				position.x = rect.position.x + rect.size.x - COLLAPSE_BUTTON_SIZE.x
				position.y = rect.position.y
			"right":
				position.x = rect.position.x
				position.y = rect.position.y
			"right_center":
				position.x = rect.position.x + rect.size.x - COLLAPSE_BUTTON_SIZE.x
				position.y = rect.position.y
			"bottom":
				position.x = rect.position.x + rect.size.x - COLLAPSE_BUTTON_SIZE.x
				position.y = rect.position.y
			_:
				position.x = rect.position.x
				position.y = rect.position.y
	else:
		match side:
			"left":
				position.x = rect.position.x - COLLAPSE_BUTTON_SIZE.x - COLLAPSE_BUTTON_MARGIN
				position.y = rect.position.y
			"right":
				position.x = rect.position.x + rect.size.x + COLLAPSE_BUTTON_MARGIN
				position.y = rect.position.y
			"right_center":
				position.x = rect.position.x + rect.size.x + COLLAPSE_BUTTON_MARGIN
				position.y = rect.position.y + ((rect.size.y - COLLAPSE_BUTTON_SIZE.y) / 2.0)
			"bottom":
				position.x = rect.position.x + rect.size.x - COLLAPSE_BUTTON_SIZE.x
				position.y = rect.position.y + rect.size.y + COLLAPSE_BUTTON_MARGIN
			_:
				position.x = rect.position.x + rect.size.x - COLLAPSE_BUTTON_SIZE.x
				position.y = rect.position.y

	button.position = position
	button.size = COLLAPSE_BUTTON_SIZE

func _is_settings_toggle_event(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false

	var key_event: InputEventKey = event as InputEventKey
	return key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE

func _toggle_settings_menu() -> void:
	if settings_menu.visible:
		if settings_menu.has_method("close"):
			settings_menu.call("close")
			return

		settings_menu.visible = false
		_on_settings_menu_closed()
		return

	_on_settings_button_pressed()

func _build_party_slots() -> void:
	party_slots.clear()
	
	party_slot_template.visible = false
	party_slots.append(party_slot_template)
	
	for i in range(MAX_PARTY_SIZE - 1):
		var slot := party_slot_template.duplicate()
		party_container.add_child(slot)
		party_slots.append(slot)
		
func _refresh_party() -> void:
	_set_collapsible_panel_available("party", PlayerSave.party.size() > 0)
	
	for slot_number in range(party_slots.size()):
		var slot = party_slots[slot_number]
		
		if slot_number < PlayerSave.party.size():
			slot.set_pokemon(PlayerSave.party[slot_number])
		else:
			slot.set_empty()

func _on_send_button_pressed() -> void:
	await _submit_chat_input()

func _on_chat_text_submitted(_text: String) -> void:
	await _submit_chat_input()

func _submit_chat_input() -> void:
	var text := chat_input.text.strip_edges()
	if text == "":
		return

	chat_input.clear()
	chat_input.release_focus()
	if text == START_ENCOUNTER_CLIPBOARD_COMMAND or text == START_ENCOUNTER_CLIPBOARD_ALIAS:
		if not PlayerSave.is_staff:
			_add_chat_message("Command not recognized.")
			return

		await _handle_start_encounter_command(DisplayServer.clipboard_get())
		return

	if text == START_ENCOUNTER_COMMAND or text.begins_with(START_ENCOUNTER_COMMAND + " "):
		if not PlayerSave.is_staff:
			_add_chat_message("Command not recognized.")
			return

		var encounter_text := text.substr(START_ENCOUNTER_COMMAND.length()).strip_edges()
		await _handle_start_encounter_command(encounter_text)
		return

	if text == SPAWN_COMMAND or text.begins_with(SPAWN_COMMAND + " "):
		if not PlayerSave.is_staff:
			_add_chat_message("Command not recognized.")
			return

		var spawn_text := text.substr(SPAWN_COMMAND.length()).strip_edges()
		await _handle_start_encounter_command(spawn_text)
		return

	if text == ADD_POKEMON_CLIPBOARD_COMMAND or text == ADD_POKEMON_CLIPBOARD_ALIAS:
		if not PlayerSave.is_staff:
			_add_chat_message("Command not recognized.")
			return

		await _handle_add_pokemon_command(DisplayServer.clipboard_get())
		return

	if text == ADD_POKEMON_COMMAND or text.begins_with(ADD_POKEMON_COMMAND + " "):
		if not PlayerSave.is_staff:
			_add_chat_message("Command not recognized.")
			return

		var pokemon_text := text.substr(ADD_POKEMON_COMMAND.length()).strip_edges()
		if pokemon_text == "":
			_show_dev_pokemon_popup(DevPokemonPopupMode.POKEMON)
			return

		await _handle_add_pokemon_command(pokemon_text)
		return

	if text == ADD_TEAM_CLIPBOARD_COMMAND or text == ADD_TEAM_CLIPBOARD_ALIAS:
		if not PlayerSave.is_staff:
			_add_chat_message("Command not recognized.")
			return

		await _handle_add_team_command(DisplayServer.clipboard_get())
		return

	if _is_command_with_text(text, ADD_TEAM_COMMAND) or _is_command_with_text(text, ADD_TEAM_ALIAS):
		if not PlayerSave.is_staff:
			_add_chat_message("Command not recognized.")
			return

		var team_text: String = _strip_first_matching_command(text, [ADD_TEAM_ALIAS, ADD_TEAM_COMMAND])
		if team_text == "":
			_show_dev_pokemon_popup(DevPokemonPopupMode.TEAM)
			return

		await _handle_add_team_command(team_text)
		return

	if text.begins_with("/"):
		_add_chat_message("Command not recognized.")
		return

	_add_chat_message("Adinho: %s" % text)

func _handle_start_encounter_command(pokemon_text: String) -> bool:
	pokemon_text = _clean_encounter_paste_text(pokemon_text)
	if pokemon_text.strip_edges() == "":
		_add_chat_message("Paste a Showdown/Pokepaste set first.")
		return false

	if PlayerSave.party.is_empty():
		_add_chat_message("You need a Pokemon in your party first.")
		return false

	var world := GameState.get_world()
	if world == null or not world.has_method("start_dev_wild_battle"):
		_add_chat_message("Cannot start a wild battle from here.")
		return false

	_add_chat_message("Creating wild Pokemon...")
	var response: Dictionary = await PokemonDataApiClient.create_pokemon_from_text(parse_pokemon_request, pokemon_text)
	if not bool(response.get("success", false)):
		_add_chat_message("Create failed: %s" % str(response.get("error", "Unknown error")))
		return false

	var pokemon_value: Variant = response.get("pokemon", {})
	if not (pokemon_value is Dictionary):
		_add_chat_message("Create failed: response did not include Pokemon data.")
		return false

	var pokemon_data: Dictionary = pokemon_value as Dictionary
	var pokemon: Pokemon = PokemonFactory.create_pokemon_from_backend_payload(pokemon_data)
	if pokemon == null:
		print_debug("Dev encounter Pokemon failed after backend create. pokemon_data=", pokemon_data, " response=", response)
		var reason: String = PokemonFactory.last_error_message
		if reason == "":
			reason = "Unknown reason."

		_add_chat_message("Could not create wild Pokemon. Reason: %s" % reason)
		return false

	_add_chat_message("Starting wild encounter: %s Lv. %s." % [pokemon.species, pokemon.level])
	await world.start_dev_wild_battle(pokemon)
	return true

func _handle_add_pokemon_command(pokemon_text: String) -> bool:
	pokemon_text = _clean_pokemon_paste_text(pokemon_text)
	if pokemon_text.strip_edges() == "":
		_add_chat_message("Paste a Showdown/Pokepaste set first.")
		return false

	if PlayerSave.party.size() >= MAX_PARTY_SIZE:
		_add_chat_message("Party is full.")
		return false

	_add_chat_message("Creating Pokemon...")
	var response: Dictionary = await PokemonDataApiClient.create_pokemon_from_text(parse_pokemon_request, pokemon_text)
	if not bool(response.get("success", false)):
		_add_chat_message("Create failed: %s" % str(response.get("error", "Unknown error")))
		return false

	var pokemon_value: Variant = response.get("pokemon", {})
	if not (pokemon_value is Dictionary):
		_add_chat_message("Create failed: response did not include Pokemon data.")
		return false

	var pokemon_data: Dictionary = pokemon_value as Dictionary
	var pokemon: Pokemon = PokemonFactory.create_pokemon_from_backend_payload(pokemon_data)
	if pokemon == null:
		print_debug("Dev add Pokemon failed after backend create. pokemon_data=", pokemon_data, " response=", response)
		var reason: String = PokemonFactory.last_error_message
		if reason == "":
			reason = "Unknown reason."

		_add_chat_message("Could not create Pokemon from backend data. Reason: %s" % reason)
		return false

	PlayerSave.add_pokemon(pokemon)
	_add_chat_message("Added %s Lv. %s to party." % [pokemon.species, pokemon.level])
	return true

func _handle_add_team_command(team_text: String) -> bool:
	team_text = _clean_team_paste_text(team_text)
	if team_text.strip_edges() == "":
		_add_chat_message("Paste a Showdown/Pokepaste team first.")
		return false

	var open_slots: int = MAX_PARTY_SIZE - PlayerSave.party.size()
	if open_slots <= 0:
		_add_chat_message("Party is full.")
		return false

	_add_chat_message("Creating team...")
	var response: Dictionary = await PokemonDataApiClient.create_team_from_text(parse_pokemon_request, team_text)
	if not bool(response.get("success", false)):
		_add_chat_message("Create failed: %s" % str(response.get("error", "Unknown error")))
		return false

	var team_value: Variant = response.get("team", [])
	if not (team_value is Array):
		_add_chat_message("Create failed: response did not include team data.")
		return false

	var team_data: Array = team_value as Array
	if team_data.is_empty():
		_add_chat_message("Create failed: team was empty.")
		return false
	if team_data.size() > open_slots:
		_add_chat_message("Not enough party space. Open slots: %s, parsed Pokemon: %s." % [open_slots, team_data.size()])
		return false

	var parsed_pokemon: Array[Pokemon] = []
	for index in range(team_data.size()):
		var pokemon_value: Variant = team_data[index]
		if not (pokemon_value is Dictionary):
			_add_chat_message("Could not create team. Reason: Pokemon %s did not include Pokemon data." % [index + 1])
			return false

		var pokemon_data: Dictionary = pokemon_value as Dictionary
		var pokemon: Pokemon = PokemonFactory.create_pokemon_from_backend_payload(pokemon_data)
		if pokemon == null:
			print_debug("Dev add team Pokemon failed after backend create. index=", index, " pokemon_data=", pokemon_data, " response=", response)
			var reason: String = PokemonFactory.last_error_message
			if reason == "":
				reason = "Unknown reason."

			_add_chat_message("Could not create team. Pokemon %s reason: %s" % [index + 1, reason])
			return false

		parsed_pokemon.append(pokemon)

	for pokemon in parsed_pokemon:
		PlayerSave.add_pokemon(pokemon)

	_add_chat_message("Added %s Pokemon to party." % parsed_pokemon.size())
	return true

func _clean_pokemon_paste_text(pokemon_text: String) -> String:
	var cleaned_text := pokemon_text.strip_edges()
	cleaned_text = cleaned_text.replace("\\n", "\n")

	for command in [ADD_POKEMON_CLIPBOARD_ALIAS, ADD_POKEMON_CLIPBOARD_COMMAND, ADD_POKEMON_COMMAND]:
		if cleaned_text == command:
			return ""
		if cleaned_text.begins_with(command + " "):
			cleaned_text = cleaned_text.substr(command.length()).strip_edges()
			break

	return cleaned_text

func _clean_team_paste_text(team_text: String) -> String:
	var cleaned_text := team_text.strip_edges()
	cleaned_text = cleaned_text.replace("\\n", "\n")

	for command in [ADD_TEAM_CLIPBOARD_ALIAS, ADD_TEAM_CLIPBOARD_COMMAND, ADD_TEAM_ALIAS, ADD_TEAM_COMMAND]:
		if cleaned_text == command:
			return ""
		if cleaned_text.begins_with(command + " "):
			cleaned_text = cleaned_text.substr(command.length()).strip_edges()
			break

	return cleaned_text

func _is_command_with_text(text: String, command: String) -> bool:
	return text == command or text.begins_with(command + " ")

func _strip_first_matching_command(text: String, commands: Array) -> String:
	var cleaned_text: String = text.strip_edges()
	for command_value in commands:
		var command: String = str(command_value)
		if cleaned_text == command:
			return ""
		if cleaned_text.begins_with(command + " "):
			return cleaned_text.substr(command.length()).strip_edges()

	return cleaned_text

func _clean_encounter_paste_text(pokemon_text: String) -> String:
	var cleaned_text := pokemon_text.strip_edges()
	cleaned_text = cleaned_text.replace("\\n", "\n")

	for command in [START_ENCOUNTER_CLIPBOARD_ALIAS, START_ENCOUNTER_CLIPBOARD_COMMAND, START_ENCOUNTER_COMMAND, SPAWN_COMMAND]:
		if cleaned_text == command:
			return ""
		if cleaned_text.begins_with(command + " "):
			cleaned_text = cleaned_text.substr(command.length()).strip_edges()
			break

	return cleaned_text

func _on_dev_pokemon_button_pressed() -> void:
	_show_dev_pokemon_popup(DevPokemonPopupMode.POKEMON)

func _on_repel_toggle_toggled(toggled_on: bool) -> void:
	GameState.repel_enabled = toggled_on
	var state_text := "enabled" if GameState.repel_enabled else "disabled"
	_add_chat_message("Repel %s." % state_text)

func _on_dev_actions_button_pressed() -> void:
	if not PlayerSave.is_staff:
		return

	dev_actions_popup.visible = not dev_actions_popup.visible

func _on_dev_add_pokemon_button_pressed() -> void:
	dev_actions_popup.visible = false
	_show_dev_pokemon_popup(DevPokemonPopupMode.POKEMON)

func _on_dev_add_team_button_pressed() -> void:
	dev_actions_popup.visible = false
	_show_dev_pokemon_popup(DevPokemonPopupMode.TEAM)

func _on_dev_spawn_pokemon_button_pressed() -> void:
	dev_actions_popup.visible = false
	_show_dev_pokemon_popup(DevPokemonPopupMode.SPAWN)

func _on_dev_actions_close_button_pressed() -> void:
	dev_actions_popup.visible = false

func _show_dev_pokemon_popup(mode: int) -> void:
	if not PlayerSave.is_staff:
		return

	dev_pokemon_popup_mode = mode
	match dev_pokemon_popup_mode:
		DevPokemonPopupMode.TEAM:
			dev_pokemon_title.text = "Add Team"
			dev_pokemon_add_button.text = "Add Team"
			dev_pokemon_text.placeholder_text = "Paste Showdown/Pokepaste team here"
		DevPokemonPopupMode.SPAWN:
			dev_pokemon_title.text = "Spawn Pokemon"
			dev_pokemon_add_button.text = "Spawn"
			dev_pokemon_text.placeholder_text = "Enter a Pokemon name, Showdown set, or Pokepaste"
		_:
			dev_pokemon_title.text = "Add Pokemon"
			dev_pokemon_add_button.text = "Add"
			dev_pokemon_text.placeholder_text = "Paste Showdown/Pokepaste text here"

	dev_pokemon_popup.visible = true
	dev_pokemon_text.grab_focus()

func _on_dev_pokemon_add_button_pressed() -> void:
	var added: bool = false
	match dev_pokemon_popup_mode:
		DevPokemonPopupMode.TEAM:
			added = await _handle_add_team_command(dev_pokemon_text.text)
		DevPokemonPopupMode.SPAWN:
			added = await _handle_start_encounter_command(dev_pokemon_text.text)
		_:
			added = await _handle_add_pokemon_command(dev_pokemon_text.text)

	if added:
		dev_pokemon_text.clear()
		dev_pokemon_popup.visible = false

func _on_dev_pokemon_close_button_pressed() -> void:
	dev_pokemon_popup.visible = false
	dev_pokemon_popup_mode = DevPokemonPopupMode.POKEMON
	chat_input.grab_focus()

func _on_settings_button_pressed() -> void:
	if settings_menu.has_method("open"):
		settings_menu.call("open")
		return

	settings_menu.visible = true

func _on_settings_menu_closed() -> void:
	settings_button.grab_focus()

func _add_chat_message(text: String) -> void:
	var entry := message_entry_template.duplicate() as RichTextLabel
	message_list.add_child(entry)
	entry.visible = true
	entry.text = text
	entry.fit_content = true
	entry.scroll_active = false
