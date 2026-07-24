extends SceneTree

const MARKET_ATTENDANT_SCRIPT := "res://scripts/world/npcs/market_attendant_npc.gd"
const MARKET_ATTENDANT_SCENE := "res://scenes/npcs/market_attendant_npc.tscn"

var failed := false


func _init() -> void:
	_check_market_attendant_script()
	_check_market_attendant_scene()

	quit(1 if failed else 0)


func _check_market_attendant_script() -> void:
	var text := _read_text(MARKET_ATTENDANT_SCRIPT)
	_check_true(text.contains("extends DialogueNPC"), "MarketAttendantNPC extends DialogueNPC")
	_check_true(text.contains("class_name MarketAttendantNPC"), "MarketAttendantNPC class exists")
	_check_true(text.contains("@export var market_id := \"standard\""), "MarketAttendantNPC exports market_id")
	_check_true(text.contains("get_node_or_null(\"/root/MarketService\")"), "MarketAttendantNPC uses MarketService autoload")
	_check_true(text.contains("await _load_npc_metadata()"), "MarketAttendantNPC loads shared NPC metadata")
	_check_true(text.contains('market_service.call("load_market", market_id)'), "MarketAttendantNPC loads its configured market")
	_check_true(text.contains("openingDialogueId"), "MarketAttendantNPC supports opening dialogue metadata")
	_check_true(text.contains("ui_overlay.call(\"open_market\", market)"), "MarketAttendantNPC can open market UI")
	_check_true(text.contains("failure_dialogue_lines"), "MarketAttendantNPC has fallback failure dialogue")


func _check_market_attendant_scene() -> void:
	var text := _read_text(MARKET_ATTENDANT_SCENE)
	_check_true(text.contains("res://scripts/world/npcs/market_attendant_npc.gd"), "MarketAttendant scene uses script")
	_check_true(text.contains("display_name = \"Clerk\""), "MarketAttendant scene has display name")
	_check_true(text.contains("InteractionArea"), "MarketAttendant scene has interaction area")
	_check_true(text.contains("FeetMarker"), "MarketAttendant scene has feet marker")


func _read_text(path: String) -> String:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _check_true(condition: bool, message: String) -> void:
	if condition:
		return

	failed = true
	push_error("FAIL %s" % message)
