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

enum DevPokemonPopupMode {
	POKEMON,
	TEAM,
}

@onready var party_panel: PanelContainer = $Control/PartyPanel
@onready var party_container: VBoxContainer = $Control/PartyPanel/MarginContainer/VBoxContainer
@onready var party_slot_template: PanelContainer = $Control/PartyPanel/MarginContainer/VBoxContainer/PartySlot
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

var party_slots: Array = []
var dev_pokemon_popup_mode: int = DevPokemonPopupMode.POKEMON

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_build_party_slots()
	_refresh_party()
	
	if not PlayerSave.party_changed.is_connected(_refresh_party):
		PlayerSave.party_changed.connect(_refresh_party)

	send_button.pressed.connect(_on_send_button_pressed)
	chat_input.text_submitted.connect(_on_chat_text_submitted)
	dev_pokemon_button.visible = false
	dev_pokemon_button.disabled = true
	dev_pokemon_add_button.pressed.connect(_on_dev_pokemon_add_button_pressed)
	dev_pokemon_close_button.pressed.connect(_on_dev_pokemon_close_button_pressed)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _input(event: InputEvent) -> void:
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

func _build_party_slots() -> void:
	party_slots.clear()
	
	party_slot_template.visible = false
	party_slots.append(party_slot_template)
	
	for i in range(MAX_PARTY_SIZE - 1):
		var slot := party_slot_template.duplicate()
		party_container.add_child(slot)
		party_slots.append(slot)
		
func _refresh_party() -> void:
	party_panel.visible = PlayerSave.party.size() > 0
	
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

func _show_dev_pokemon_popup(mode: int) -> void:
	if not PlayerSave.is_staff:
		return

	dev_pokemon_popup_mode = mode
	match dev_pokemon_popup_mode:
		DevPokemonPopupMode.TEAM:
			dev_pokemon_title.text = "Add Team"
			dev_pokemon_add_button.text = "Add Team"
			dev_pokemon_text.placeholder_text = "Paste Showdown/Pokepaste team here"
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
		_:
			added = await _handle_add_pokemon_command(dev_pokemon_text.text)

	if added:
		dev_pokemon_text.clear()
		dev_pokemon_popup.visible = false

func _on_dev_pokemon_close_button_pressed() -> void:
	dev_pokemon_popup.visible = false
	dev_pokemon_popup_mode = DevPokemonPopupMode.POKEMON
	chat_input.grab_focus()

func _add_chat_message(text: String) -> void:
	var entry := message_entry_template.duplicate() as RichTextLabel
	message_list.add_child(entry)
	entry.visible = true
	entry.text = text
	entry.fit_content = true
	entry.scroll_active = false
