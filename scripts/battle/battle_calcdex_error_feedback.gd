extends RefCounted

class_name BattleCalcdexErrorFeedback

const SAFE_SNAPSHOT_REQUIRED_KEY := "battle.calc.error.safe_snapshot_required"
const INVALID_SNAPSHOT_DATA_KEY := "battle.calc.error.invalid_snapshot_data"


static func message_key(response: Dictionary) -> String:
	var error_code := str(response.get("errorCode", response.get("code", ""))).strip_edges()
	var detail: Variant = response.get("detail")
	if detail is Dictionary:
		error_code = str((detail as Dictionary).get("code", error_code)).strip_edges()
	if error_code.to_upper() == "CALC_INVALID_SELECTION":
		return INVALID_SNAPSHOT_DATA_KEY
	return SAFE_SNAPSHOT_REQUIRED_KEY
