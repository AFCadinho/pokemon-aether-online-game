extends SceneTree

const BOSS_BATTLE_NPC_SCRIPT := "res://scripts/world/npcs/boss_battle_npc.gd"
const BOSS_BATTLE_NPC_SCENE := "res://scenes/npcs/boss_battle_npc.tscn"

var failed := false


func _init() -> void:
	_check_boss_battle_npc_script()
	_check_boss_battle_npc_scene()

	quit(1 if failed else 0)


func _check_boss_battle_npc_script() -> void:
	var text := _read_text(BOSS_BATTLE_NPC_SCRIPT)
	_check_true(text.contains("extends DialogueNPC"), "BossBattleNPC extends DialogueNPC")
	_check_true(text.contains("class_name BossBattleNPC"), "BossBattleNPC class exists")
	_check_true(text.contains("@export var easy_trainer_id := \"\""), "BossBattleNPC exports easy trainer id")
	_check_true(text.contains("@export var normal_trainer_id := \"\""), "BossBattleNPC exports normal trainer id")
	_check_true(text.contains("@export var hard_trainer_id := \"\""), "BossBattleNPC exports hard trainer id")
	_check_true(text.contains("CanvasLayer.new()"), "BossBattleNPC creates custom difficulty layer")
	_check_true(text.contains("PanelContainer.new()"), "BossBattleNPC creates custom difficulty panel")
	_check_true(text.contains("var difficulty_root: Control"), "BossBattleNPC tracks difficulty root")
	_check_true(text.contains("screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE"), "BossBattleNPC difficulty root does not block battle input")
	_check_true(text.contains("difficulty_root.hide()"), "BossBattleNPC hides difficulty root after selection")
	_check_true(text.contains("_make_difficulty_panel_style()"), "BossBattleNPC uses custom panel style")
	_check_true(text.contains("_make_difficulty_button(hard_label, \"hard\""), "BossBattleNPC has hard option")
	_check_true(text.contains("_make_difficulty_button(normal_label, \"normal\""), "BossBattleNPC has normal option")
	_check_true(text.contains("_make_difficulty_button(easy_label, \"easy\""), "BossBattleNPC has easy option")
	_check_true(text.contains("_make_cancel_button()"), "BossBattleNPC has custom cancel option")
	_check_true(text.contains("TrainerMetadataService.get_trainer_metadata(trainer_id)"), "BossBattleNPC loads trainer metadata")
	_check_true(text.contains("var battle_result: Dictionary = await world.start_trainer_battle(trainer_metadata)"), "BossBattleNPC preserves structured battle errors")
	_check_true(text.contains("world.start_trainer_battle(trainer_metadata)"), "BossBattleNPC starts trainer battle")


func _check_boss_battle_npc_scene() -> void:
	var text := _read_text(BOSS_BATTLE_NPC_SCENE)
	_check_true(text.contains("res://scripts/world/npcs/boss_battle_npc.gd"), "BossBattleNPC scene uses script")
	_check_true(text.contains("InteractionArea"), "BossBattleNPC scene has interaction area")
	_check_true(text.contains("FeetMarker"), "BossBattleNPC scene has feet marker")


func _read_text(path: String) -> String:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _check_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return

	failed = true
	push_error("FAIL %s" % message)
