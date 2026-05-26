extends CanvasLayer

const MAX_PARTY_SIZE := 6

@onready var party_container: VBoxContainer = $Control/PartyPanel/MarginContainer/VBoxContainer
@onready var party_slot_template: PanelContainer = $Control/PartyPanel/MarginContainer/VBoxContainer/PartySlot

var party_slots: Array = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_build_party_slots()
	_refresh_party()
	
	if not PlayerSave.party_changed.is_connected(_refresh_party):
		PlayerSave.party_changed.connect(_refresh_party)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
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
	for slot_number in range(party_slots.size()):
		var slot = party_slots[slot_number]
		
		if slot_number < PlayerSave.party.size():
			slot.set_pokemon(PlayerSave.party[slot_number])
		else:
			slot.set_empty()
