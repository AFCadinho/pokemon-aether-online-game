extends SceneTree

const Diagnostics := preload("res://scripts/battle/battle_npc_force_switch_diagnostics.gd")
const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"

var failed := false


func _init() -> void:
	_check_snapshot_exposes_only_safe_identity_digests()
	_check_battle_flow_traces_each_forced_switch_boundary()
	quit(1 if failed else 0)


func _check_snapshot_exposes_only_safe_identity_digests() -> void:
	var raw_key := "private-pokemon-key"
	var raw_ident := "p2: Oddish"
	var snapshot := Diagnostics.build_snapshot(
		"after_submit",
		"Lass Haley",
		1,
		"p2",
		{
			"p2": {
				"forceSwitch": [true],
				"side": {
					"pokemon": [{
						"pokemonKey": raw_key,
						"ident": raw_ident,
						"partySlot": 2,
						"metadataSlot": 1,
						"active": true,
						"condition": "0 fnt",
					}]
				},
			}
		},
		{
			"p2": {
				"status": "LOCKED",
				"decisionKind": "MOVE_SELECTION",
				"decisionGeneration": 3,
				"decisionId": "private-decision-id",
			}
		}
	)
	var encoded := JSON.stringify(snapshot)
	_check(not encoded.contains(raw_key), "raw Pokemon keys stay out of diagnostics")
	_check(not encoded.contains(raw_ident), "raw battle idents stay out of diagnostics")
	_check(encoded.contains(raw_key.sha256_text().left(10)), "stable Pokemon-key digest identifies duplicate slots")
	_check(encoded.contains('"requestForceSwitch":[true]'), "force-switch projection is recorded")
	_check(encoded.contains('"decisionStatus":"LOCKED"'), "decision status is recorded")
	_check(encoded.contains('"decisionKind":"MOVE_SELECTION"'), "decision kind is recorded")
	_check(encoded.contains('"partySlot":2'), "party slot is recorded")
	_check(encoded.contains('"metadataSlot":1'), "metadata slot is recorded")


func _check_battle_flow_traces_each_forced_switch_boundary() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	_check(source.contains('OS.is_debug_build()'), "NPC diagnostics run only in debug builds")
	_check(source.contains('battle_type != BattleType.TRAINER'), "NPC diagnostics run only for trainer battles")
	_check(source.contains('snapshot["uiRequiresSwitch"]'), "UI force-switch inference is recorded")
	_check(source.contains('snapshot["responseRequiresSwitch"]'), "response force-switch inference is recorded")
	for stage in [
		"wait_shown",
		"recovery_started",
		"before_submit",
		"after_submit",
		"after_render",
		"chain_exhausted",
		"recovery_stalled",
	]:
		_check(source.contains('_trace_npc_force_switch("%s"' % stage), "%s boundary is traced" % stage)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failed = true
	push_error("FAIL: %s" % message)
