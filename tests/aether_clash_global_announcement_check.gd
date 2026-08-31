extends SceneTree

const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"
const LOCALES: Array[String] = ["en", "nl", "pt_BR", "zh_CN"]
const MESSAGE_KEYS: Array[String] = [
	"ui.aether_clash.global.started",
	"ui.aether_clash.global.started_staked",
	"ui.aether_clash.global.completed",
	"ui.aether_clash.global.completed_staked",
	"ui.aether_clash.global.completed_no_show",
	"ui.aether_clash.global.completed_no_show_staked",
]

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var localization_manager := root.get_node("LocalizationManager")
	var localize := Callable(localization_manager, "text")
	var overlay_script := load(OVERLAY_SCRIPT_PATH) as Script
	_check(overlay_script != null, "UI overlay script loads with the Aether Clash formatter")
	localization_manager.set_locale("en")

	var started := AetherClashAnnouncementFormatter.format_event({
		"phase": "started",
		"challengerGuildName": "Alpha Guild",
		"challengedGuildName": "Bravo Guild",
		"tierName": "Aether OU",
		"challengerCount": 2,
		"challengedCount": 1,
		"stakeAmount": 100_000,
		"stakePotAmount": 200_000,
	}, localize)
	_check(
		started == "Alpha Guild and Bravo Guild have begun an Aether Clash! 2 vs 1 Trainers · Aether OU · ₽100,000 stake per Guild",
		"Staked start announcement includes Guilds, roster, tier and stake"
	)

	var completed := AetherClashAnnouncementFormatter.format_event({
		"phase": "completed",
		"winnerGuildName": "Bravo Guild",
		"loserGuildName": "Alpha Guild",
		"finishReason": "elimination",
		"stakeAmount": 100_000,
		"stakePotAmount": 200_000,
	}, localize)
	_check(
		completed == "Bravo Guild won the Aether Clash against Alpha Guild and claimed the ₽200,000 prize pot!",
		"Staked result announcement includes the winner and full prize pot"
	)

	localization_manager.set_locale("nl")
	var no_show := AetherClashAnnouncementFormatter.format_event({
		"phase": "completed",
		"winnerGuildName": "Bravo Guild",
		"loserGuildName": "Alpha Guild",
		"finishReason": "no_show",
		"stakeAmount": 0,
		"stakePotAmount": 0,
	}, localize)
	_check(no_show.contains("door een no-show gewonnen"), "No-show results use distinct Dutch wording")

	for locale in LOCALES:
		for key in MESSAGE_KEYS:
			_check(
				bool(localization_manager.call("has_key", key, locale)),
				"%s includes %s" % [locale, key]
			)

	var overlay_source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)
	_check(
		overlay_source.contains('message_type == "system.aether_clash_announcement"')
		and overlay_source.contains("add_system_message(clash_message)"),
		"Realtime Aether Clash announcements enter System chat"
	)

	localization_manager.set_locale("en")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
