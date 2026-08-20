extends SceneTree

const BattleTimerProjectionClass = preload("res://scripts/battle/battle_timer_projection.gd")

func _init() -> void:
	var projection := BattleTimerProjectionClass.new()
	_check_equal(projection.authority, "LEGACY_AUTHORITY", "legacy authority defaults to its canonical explicit mode")
	_check(projection.apply_snapshot({"timerContractVersion": 1, "authority": "BATTLE_BANK_V1_AUTHORITY"}), "canonical authority snapshot applies")
	_check(projection.contract_enabled, "canonical bank authority enables the timer contract")
	projection.reset()
	_check(projection.apply_snapshot({
		"timerContractVersion": 1, "authority": "BATTLE_BANK_V1_SHADOW",
		"timerRevision": 2, "aggregateRevision": 1, "battleEventSeq": 10, "serverNowMs": 1000,
		"participants": {
			"p1": {"status":"RUNNING","decisionId":"d1","decisionGeneration":1,"mainBankRemainingMs":90000,"mainBankMaximumMs":90000,"actionableAtMs":2000,"bankChargeStartsAtMs":2000,"decisionCapAtMs":22000,"bankExhaustionAtMs":92000,"hypotheticalDeadlineAtMs":22000},
			"p2": {"status":"CHOICE_ACCEPTED","decisionId":"d2","decisionGeneration":1,"mainBankRemainingMs":80000,"mainBankMaximumMs":90000,"actionableAtMs":1000,"bankChargeStartsAtMs":1000,"decisionCapAtMs":21000,"hypotheticalDeadlineAtMs":21000},
		}
	}, 5000), "accepts v1 snapshot")
	_check(projection.should_present(true), "valid shadow projection presents by default")
	_check(not projection.has_advanced_beyond_team_preview(), "Team Preview projection has not advanced yet")
	_check(not projection.should_present(false), "non-PvP battle does not present bank timer")
	_check(not projection.should_present(true, false), "debug visibility override can hide bank timer")
	_check_equal(projection.estimated_server_now_ms(5500), 1500, "monotonic server interpolation")
	_check_equal(projection.participant_display("p1", 5500).get("state"), "SCHEDULED", "scheduled before actionable")
	_check_equal(projection.participant_display("p1", 5500).get("bankRemainingMs"), 90000, "no charge before actionable")
	_check_equal(projection.participant_display("p1", 6000).get("state"), "DECIDING", "active exactly actionable")
	_check_equal(projection.participant_display("p1", 6000).get("decisionKind"), "", "privacy-stripped opponent decision kind remains absent")
	_check_equal(projection.participant_display("p1", 6000).get("effectiveDecisionRemainingMs"), 20000, "privacy-stripped active opponent keeps its deadline countdown")
	_check_equal(projection.participant_display("p1", 6500).get("bankRemainingMs"), 89500, "bank drains from charge anchor")
	_check_equal(projection.participant_display("p1", 6500).get("decisionMaximumMs"), 20000, "privacy-safe public anchors recover a missing opponent countdown scale")
	_check_equal(projection.participant_display("p2", 6500).get("state"), "WAITING", "locked participant waits independently")
	projection.apply_event({"battleEventSeq":11,"payload":{"timerRevision":3,"playerId":"p2","decisionGeneration":1,"status":"CHOICE_ACCEPTED","decisionKind":"MOVE_SELECTION","maxDecisionMs":20000,"decisionRemainingMs":14500}})
	_check(projection.has_advanced_beyond_team_preview(), "Move Selection projection proves Team Preview completed")
	_check_equal(projection.participant_display("p2", 16500).get("effectiveDecisionRemainingMs"), 14500, "accepted choice keeps its trusted frozen decision time")
	_check_equal(projection.participant_display("p2", 26500).get("effectiveDecisionRemainingMs"), 14500, "accepted choice countdown remains frozen while waiting")
	_check(not projection.participant_display("p2", 16500).has("decisionId"), "presentation projection never exposes an opaque decision id")
	_check(not projection.participant_display("p2", 16500).has("decisionGeneration"), "presentation projection never exposes an internal decision generation")
	_check_equal(projection.participant_display_for_local_player("p1", "p1", 6500).get("playerId"), "p1", "p1 client keeps server p1 on the local display side")
	_check_equal(projection.participant_display_for_local_player("p2", "p1", 6500).get("playerId"), "p2", "p1 client keeps server p2 on the opponent display side")
	_check_equal(projection.participant_display_for_local_player("p1", "p2", 6500).get("playerId"), "p2", "p2 client maps its own timer to the local display side")
	_check_equal(projection.participant_display_for_local_player("p2", "p2", 6500).get("playerId"), "p1", "p2 client maps the opponent timer to the opponent display side")
	_check(not projection.apply_event({"battleEventSeq":9,"payload":{"timerRevision":1,"playerId":"p1","decisionGeneration":1}}), "stale revision ignored")
	_check(not projection.apply_event({"battleEventSeq":11,"payload":{"timerRevision":3,"playerId":"p1","decisionGeneration":0}}), "stale generation ignored")
	_check(projection.apply_event({"battleEventSeq":12,"payload":{"timerRevision":3,"playerId":"p1","decisionGeneration":2,"status":"PAUSED","mainBankRemainingMs":70000}}), "new generation applied")
	_check_equal(projection.participant_display("p1", 7000).get("state"), "PAUSED", "paused state")
	projection.apply_event({"battleEventSeq":13,"payload":{"timerRevision":4,"playerId":"p1","decisionGeneration":2,"status":"WOULD_EXPIRE","hypotheticalDeadlineAtMs":2000}})
	_check_equal(projection.participant_display("p1", 7000).get("effectiveDecisionRemainingMs"), 0, "clamps deadline at zero")
	_check_equal(projection.participant_display("p1", 7000).get("state"), "EXPIRED", "shadow expiry display only")
	_check(not projection.has_method("submit_expiry"), "projection has no timeout authority")
	projection.resync(10000, 9000)
	_check_equal(projection.estimated_server_now_ms(9000), 10000, "foreground/reconnect snap")
	projection.pause_for_reconnect(9000)
	_check_equal(projection.estimated_server_now_ms(19000), 10000, "disconnect freezes projected server time")
	projection.resume_after_reconnect(19000)
	_check_equal(projection.estimated_server_now_ms(19500), 10500, "reconnect resumes without charging disconnected time")
	projection.reset()
	_check(not projection.contract_enabled, "reset removes stale projection eligibility")
	_check(not projection.should_present(true), "battle without a valid projection remains hidden")
	_check(projection.apply_legacy_snapshot([
		{
			"activeSide": "p1",
			"phase": "team_preview",
			"status": "active",
			"durationSeconds": 90,
			"deadlineAt": "1970-01-01T00:01:40Z",
			"serverNow": "1970-01-01T00:00:10Z",
		},
	], true, 5000), "enabled legacy timer snapshot applies")
	_check(projection.should_present(true), "enabled legacy room timer is presented")
	_check_equal(projection.participant_display("p1", 5000).get("state"), "DECIDING", "legacy timer opens a decision countdown")
	_check_equal(projection.participant_display("p1", 5000).get("effectiveDecisionRemainingMs"), 90000, "legacy timer uses the server deadline")
	# Once sampled, legacy countdowns run exclusively from monotonic time. A
	# later wall-clock/server-anchor correction must not make the visible room
	# timer expire before its authoritative 90-second deadline.
	projection.server_anchor_ms += 60000
	_check_equal(projection.participant_display("p1", 35000).get("effectiveDecisionRemainingMs"), 60000, "legacy countdown ignores later wall-clock drift")
	_check_equal(projection.participant_display("p1", 35000).get("state"), "DECIDING", "legacy countdown stays active until its monotonic deadline")
	_check_equal(projection.participant_display("p1", 95000).get("state"), "EXPIRED", "legacy countdown expires at the authoritative duration")
	_check(projection.apply_legacy_event({"payload": {"side": "p1", "phase": "team_preview", "timerStatus": "consumed"}}), "legacy consumed event applies")
	_check_equal(projection.participant_display("p1").get("state"), "WAITING", "consumed legacy timer stops counting")
	projection.apply_legacy_snapshot([], false)
	_check(not projection.should_present(true), "disabled legacy room timer stays hidden")
	print("PASS battle_timer_projection_check")
	quit(0)

func _check(value: bool, label: String) -> void:
	if value: return
	push_error(label)
	quit(1)

func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	_check(actual == expected, "%s: expected %s got %s" % [label, str(expected), str(actual)])
