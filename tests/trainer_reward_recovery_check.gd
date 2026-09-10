extends Node

const WorldScript := preload("res://scripts/world/world.gd")
var failed := false

class FakePositionService extends PlayerGameStateServiceNode:
	func _request_json(_url: String, _method: HTTPClient.Method, _headers: PackedStringArray, _body: String) -> Dictionary:
		return {"success": true, "body": {"hasState": true, "state": {}, "trainerRewardRecovered": true}}

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var service := FakePositionService.new()
	add_child(service)
	var original_token := AuthService.session_token
	var original_user := AuthService.current_user
	AuthService.session_token = "local-recovery-fixture"
	AuthService.current_user = {"id": 1}
	var response := await service.load_player_position()
	AuthService.session_token = original_token
	AuthService.current_user = original_user
	_check(bool(response.get("trainerRewardRecovered", false)), "position client preserves the recovery flag")
	var source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	var begin := source.find('if bool(saved_state_response.get("trainerRewardRecovered", false)):')
	var end := source.find('if bool(saved_state_response.get("success", false))', begin)
	var recovery := source.substr(begin, end - begin)
	for expected in ["_load_player_party_state()", "PlayerWalletService.load_wallet()", "InventoryService.load_inventory()", "PlayerGameStateService.refresh_story()"]:
		_check(recovery.contains(expected), "fallback world login refreshes " + expected)
	service.queue_free()
	await get_tree().process_frame
	print("PASS trainer_reward_recovery_check" if not failed else "FAIL trainer_reward_recovery_check")
	get_tree().quit(1 if failed else 0)

func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
