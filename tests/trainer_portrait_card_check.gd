extends SceneTree

const DIALOGUE_BOX_SCRIPT := "res://scripts/ui/dialogue_box.gd"
const TRAINER_NPC_SCENE := "res://scenes/npcs/trainer_npc.tscn"
const PALLET_TOWN_SCENE := "res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn"
const CARD_ROOT := "res://assets/sprites/trainer_cards/showdown/"
const CARD_FILES: Array[String] = [
	"acetrainer-gen6.png",
	"bugcatcher-gen6.png",
	"fisherman-gen6.png",
]

var failed := false


func _init() -> void:
	var dialogue_text := _read_text(DIALOGUE_BOX_SCRIPT)
	_check_true(dialogue_text.contains("TRAINER_CARD_TEXTURE_ROOT"), "Dialogue box recognizes trainer-card textures")
	_check_true(dialogue_text.contains("STRETCH_KEEP_CENTERED"), "Trainer cards remain at native size")
	_check_true(dialogue_text.contains("TEXTURE_FILTER_NEAREST"), "Trainer cards use nearest-neighbour filtering")

	for file_name: String in CARD_FILES:
		_check_true(FileAccess.file_exists(CARD_ROOT + file_name), "Trainer card exists: %s" % file_name)

	var trainer_text := _read_text(TRAINER_NPC_SCENE)
	_check_true(trainer_text.contains(CARD_ROOT + "bugcatcher-gen6.png"), "Bug Catcher uses the trainer-card test portrait")

	var pallet_text := _read_text(PALLET_TOWN_SCENE)
	_check_true(pallet_text.contains(CARD_ROOT + "acetrainer-gen6.png"), "Pallet Town guard uses the Ace Trainer card")
	_check_true(pallet_text.contains(CARD_ROOT + "fisherman-gen6.png"), "Fishing Guru uses the Fisherman card")

	quit(1 if failed else 0)


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


func _check_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
