extends SceneTree

const BattleStateScript := preload("res://scripts/battle/battle_state.gd")
const BattleTimerProjectionScript := preload("res://scripts/battle/battle_timer_projection.gd")

func _init() -> void:
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"battleId": "synthetic-battle",
		"operationalState": {
			"state": "SUSPENDED_MECHANICAL_RECOVERY",
			"revision": 2,
			"message": "Battle suspended due to a server issue",
			"actionsEnabled": false,
			"timerConsequencesEnabled": false,
			"noPenalty": true,
		},
	})
	assert(not state.actions_enabled())
	assert(not state.timer_consequences_enabled())
	assert(state.operational_message() == "Battle suspended due to a server issue")
	assert(not state.is_decision_actionable("p1", 999999))

	# Older reconnect data cannot roll the operational state backwards.
	state.load_from_api_response({
		"battleId": "synthetic-battle",
		"operationalState": {"state": "ACTIVE", "revision": 1, "actionsEnabled": true},
	})
	assert(not state.actions_enabled())

	state.load_from_api_response({
		"battleId": "synthetic-battle",
		"operationalState": {"state": "NO_CONTEST", "revision": 3, "actionsEnabled": false},
	})
	assert(str(state.operational_state.get("state", "")) == "NO_CONTEST")

	var timer = BattleTimerProjectionScript.new()
	timer.apply_snapshot({
		"timerContractVersion": 1,
		"authority": "BATTLE_BANK_V1_SHADOW",
		"timerRevision": 1,
		"serverNowMs": 1000,
		"participants": {"p1": {"status": "ACTIVE", "mainBankRemainingMs": 90000, "bankChargeStartsAtMs": 1000}},
	}, 1000)
	timer.apply_operational_state({"timerConsequencesEnabled": false})
	var display: Dictionary = timer.participant_display("p1", 5000)
	assert(display.get("state") == "PAUSED")
	assert(display.get("bankRemainingMs") == 90000)
	quit(0)
