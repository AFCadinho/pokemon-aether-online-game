extends SceneTree

const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"
const MOVE_HOVER_SCRIPT_PATH := "res://scripts/battle/battle_ui/move_hover_card.gd"
const MOVE_HOVER_SCENE_PATH := "res://scenes/battle/move_hover_card.tscn"
const TYPE_ICON_DIRECTORY := "res://assets/battles/types/"
const TYPES := [
	"normal", "fighting", "flying", "poison", "ground", "rock", "bug", "ghost", "steel",
	"fire", "water", "grass", "electric", "psychic", "ice", "dragon", "dark", "fairy",
]

var failed := false

func _init() -> void:
	var battle_script := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var hover_script := FileAccess.get_file_as_string(MOVE_HOVER_SCRIPT_PATH)
	var hover_scene := FileAccess.get_file_as_string(MOVE_HOVER_SCENE_PATH)
	_check_true(battle_script.contains("Z_MOVE_TYPE_ICON_PATH"), "battle maps generic Z-Moves to type icons")
	_check_true(battle_script.contains("Z_CRYSTAL_NAMES"), "generic Z-Move tooltips name the equipped crystal")
	_check_true(battle_script.contains("SIGNATURE_Z_MOVE_NAMES"), "signature Z-Moves retain the neutral fallback")
	_check_true(battle_script.contains('_t("battle.mechanic.z_move_ready")'), "Z-Move activation has a clear localized fallback message")
	_check_true(battle_script.contains("_update_z_move_button_icon"), "Z-Move button refreshes its icon from battle state")
	_check_true(hover_script.contains('category.to_lower() != "status"'), "status moves omit the irrelevant Base Power row")
	_check_true(hover_script.contains('move_data.get("zEffect"'), "status Z-Moves render their presented Z-Effect")
	_check_true(hover_scene.contains('[node name="ZEffectRow"'), "move tooltip has a dedicated Z-Effect row")
	for type_name: String in TYPES:
		_check_true(ResourceLoader.exists("%s%s.svg" % [TYPE_ICON_DIRECTORY, type_name]), "%s Z-Move icon exists" % type_name)
	quit(1 if failed else 0)

func _check_true(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
