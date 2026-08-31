extends RefCounted

class_name AetherClashAnnouncementFormatter


static func format_event(message: Dictionary, localize: Callable) -> String:
	var phase := str(message.get("phase", "")).strip_edges().to_lower()
	var stake_amount := maxi(int(message.get("stakeAmount", 0)), 0)
	var values := {
		"challenger": str(message.get("challengerGuildName", "Guild 1")),
		"challenged": str(message.get("challengedGuildName", "Guild 2")),
		"winner": str(message.get("winnerGuildName", "Guild")),
		"loser": str(message.get("loserGuildName", "Guild")),
		"tier": str(message.get("tierName", "Aether OU")),
		"challenger_count": maxi(int(message.get("challengerCount", 0)), 0),
		"challenged_count": maxi(int(message.get("challengedCount", 0)), 0),
		"stake": _format_amount(stake_amount),
		"pot": _format_amount(maxi(int(message.get("stakePotAmount", 0)), 0)),
	}
	if phase == "started":
		return str(localize.call(
			"ui.aether_clash.global.started_staked"
			if stake_amount > 0
			else "ui.aether_clash.global.started",
			values
		))
	if phase == "completed":
		var no_show := str(message.get("finishReason", "")).strip_edges().to_lower() == "no_show"
		var key := "ui.aether_clash.global.completed"
		if no_show:
			key = "ui.aether_clash.global.completed_no_show"
		if stake_amount > 0:
			key += "_staked"
		return str(localize.call(key, values))
	return ""


static func _format_amount(value: int) -> String:
	var digits := str(maxi(value, 0))
	var formatted := ""
	while digits.length() > 3:
		formatted = "," + digits.right(3) + formatted
		digits = digits.left(digits.length() - 3)
	return digits + formatted
