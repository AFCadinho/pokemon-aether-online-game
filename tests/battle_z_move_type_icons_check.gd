extends SceneTree

const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"
const TYPE_ICON_DIRECTORY := "res://assets/battles/types/"
const TYPES := [
	"normal", "fighting", "flying", "poison", "ground", "rock", "bug", "ghost", "steel",
	"fire", "water", "grass", "electric", "psychic", "ice", "dragon", "dark", "fairy",
]

var failed := false

func _init() -> void:
	var battle_script := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	_check_true(battle_script.contains("Z_MOVE_TYPE_ICON_PATH"), "battle maps generic Z-Moves to type icons")
	_check_true(battle_script.contains("Z_CRYSTAL_NAMES"), "generic Z-Move tooltips name the equipped crystal")
	_check_true(battle_script.contains("SIGNATURE_Z_MOVE_NAMES"), "signature Z-Moves retain the neutral fallback")
	_check_true(battle_script.contains("Z-Move ready. Choose a Z-Move!"), "Z-Move activation has a clear fallback message")
	_check_true(battle_script.contains("_update_z_move_button_icon"), "Z-Move button refreshes its icon from battle state")
	for type_name: String in TYPES:
		_check_true(ResourceLoader.exists("%s%s.svg" % [TYPE_ICON_DIRECTORY, type_name]), "%s Z-Move icon exists" % type_name)
	quit(1 if failed else 0)

func _check_true(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
