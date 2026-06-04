extends CanvasLayer

const MAX_PARTY_SIZE := 6
const ADD_POKEMON_COMMAND := "/addpokemon"
const ADD_POKEMON_CLIPBOARD_COMMAND := "/addpokemonclip"
const ADD_POKEMON_CLIPBOARD_ALIAS := "/apc"

@onready var party_panel: PanelContainer = $Control/PartyPanel
@onready var party_container: VBoxContainer = $Control/PartyPanel/MarginContainer/VBoxContainer
@onready var party_slot_template: PanelContainer = $Control/PartyPanel/MarginContainer/VBoxContainer/PartySlot
@onready var message_list: VBoxContainer = $Control/ChatPanel/MarginContainer/VBoxContainer/MessageScroll/MarginContainer/MessageList
@onready var message_entry_template: RichTextLabel = $Control/ChatPanel/MarginContainer/VBoxContainer/MessageScroll/MarginContainer/MessageList/MessageEntry
@onready var chat_input: LineEdit = $Control/ChatPanel/MarginContainer/VBoxContainer/InputRow/ChatInput
@onready var send_button: Button = $Control/ChatPanel/MarginContainer/VBoxContainer/InputRow/SendButton
@onready var parse_pokemon_request: HTTPRequest = $ParsePokemonRequest

var party_slots: Array = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_build_party_slots()
	_refresh_party()
	
	if not PlayerSave.party_changed.is_connected(_refresh_party):
		PlayerSave.party_changed.connect(_refresh_party)

	send_button.pressed.connect(_on_send_button_pressed)
	chat_input.text_submitted.connect(_on_chat_text_submitted)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

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
	if text == ADD_POKEMON_CLIPBOARD_COMMAND or text == ADD_POKEMON_CLIPBOARD_ALIAS:
		if not PlayerSave.is_staff:
			_add_chat_message("Command not recognized.")
			return

		await _handle_add_pokemon_command(DisplayServer.clipboard_get())
		return

	if text.begins_with(ADD_POKEMON_COMMAND):
		if not PlayerSave.is_staff:
			_add_chat_message("Command not recognized.")
			return

		var pokemon_text := text.substr(ADD_POKEMON_COMMAND.length()).strip_edges()
		pokemon_text = pokemon_text.replace("\\n", "\n")
		await _handle_add_pokemon_command(pokemon_text)
		return

	if text.begins_with("/"):
		_add_chat_message("Command not recognized.")
		return

	_add_chat_message("Adinho: %s" % text)

func _handle_add_pokemon_command(pokemon_text: String) -> void:
	if pokemon_text.strip_edges() == "":
		_add_chat_message("Usage: /addpokemon <showdown text>, /addpokemonclip, or /apc")
		return

	if PlayerSave.party.size() >= MAX_PARTY_SIZE:
		_add_chat_message("Party is full.")
		return

	_add_chat_message("Parsing Pokemon...")
	var response: Dictionary = await BattleApiClient.parse_pokemon(parse_pokemon_request, pokemon_text)
	if not bool(response.get("success", false)):
		_add_chat_message("Parse failed: %s" % str(response.get("error", "Unknown error")))
		return

	var pokemon_value: Variant = response.get("pokemon", {})
	if not (pokemon_value is Dictionary):
		_add_chat_message("Parse failed: response did not include Pokemon data.")
		return

	var pokemon_data: Dictionary = pokemon_value as Dictionary
	var pokemon := PokemonFactory.create_pokemon_from_data(pokemon_data)
	if pokemon == null:
		print_debug("Dev add Pokemon failed after parse. pokemon_data=", pokemon_data, " response=", response)
		_add_chat_message("Could not create Pokemon from parsed data.")
		return

	PlayerSave.add_pokemon(pokemon)
	_add_chat_message("Added %s Lv. %s to party." % [pokemon.species, pokemon.level])

func _add_chat_message(text: String) -> void:
	var entry := message_entry_template.duplicate() as RichTextLabel
	message_list.add_child(entry)
	entry.visible = true
	entry.text = text
	entry.fit_content = true
	entry.scroll_active = false
