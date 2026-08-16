extends SceneTree

const SERVICE_PATH := "res://scripts/services/badge_progression_service.gd"
const PLAYER_DATA_PATH := "res://scripts/data/player_data.gd"
const PROFILE_SERVICE_PATH := "res://scripts/services/player_game_state_service.gd"
const LOADING_SCREEN_PATH := "res://scripts/ui/loading_screen.gd"
const OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"
const GUILD_PATH := "res://scripts/ui/guild_popup.gd"
const WALLET_SERVICE_PATH := "res://scripts/services/player_wallet_service.gd"
const WORLD_PATH := "res://scripts/world/world.gd"
const POPUP_SCENE_PATH := "res://scenes/interface/dev_badge_progress_popup.tscn"
const POPUP_SCRIPT_PATH := "res://scripts/ui/dev_badge_progress_popup.gd"

var failed := false


func _init() -> void:
	var service := FileAccess.get_file_as_string(SERVICE_PATH)
	var player_data := FileAccess.get_file_as_string(PLAYER_DATA_PATH)
	var profile_service := FileAccess.get_file_as_string(PROFILE_SERVICE_PATH)
	var loading := FileAccess.get_file_as_string(LOADING_SCREEN_PATH)
	var overlay := FileAccess.get_file_as_string(OVERLAY_PATH)
	var guild := FileAccess.get_file_as_string(GUILD_PATH)
	var wallet_service := FileAccess.get_file_as_string(WALLET_SERVICE_PATH)
	var world := FileAccess.get_file_as_string(WORLD_PATH)
	var popup_script := FileAccess.get_file_as_string(POPUP_SCRIPT_PATH)

	_check(ProjectSettings.has_setting("autoload/BadgeProgressionService"), "badge service is registered as an autoload")
	_check(ResourceLoader.exists(POPUP_SCENE_PATH), "developer badge popup scene exists")
	_check_contains(service, 'BADGES_ENDPOINT := "/game/progression/gym-badges"', "client reads server badge progression")
	_check_contains(service, 'DEV_BADGES_ENDPOINT := "/game/dev/progression/gym-badges"', "developer controls use the protected server endpoint")
	_check_contains(service, "await PlayerPartyStateService.load_party()", "developer badge changes refresh authoritative level caps")
	_check_contains(player_data, "func apply_gym_badge_state", "PlayerSave can apply the canonical badge projection")
	_check_contains(player_data, "func has_gym_badge", "PlayerSave exposes badge ownership")
	_check_contains(profile_service, '"badges": badges', "profile service preserves badge progress")
	_check_contains(profile_service, 'DEV_STORY_CHECKPOINT_ENDPOINT := "/game/dev/progression/story-checkpoint"', "trainer progress can update the authoritative story checkpoint")
	_check_contains(profile_service, "StoryService.apply_story(story)", "story checkpoints immediately refresh local story state")
	_check_contains(popup_script, '"trainer_school"', "trainer progress exposes the Trainer School checkpoint")
	_check_contains(popup_script, '"pewter_gym"', "trainer progress exposes the Pewter Gym checkpoint")
	_check_contains(loading, "PlayerSave.apply_gym_badge_state", "login applies server badge progress")
	_check_contains(overlay, "PlayerSave.has_gym_badge(region, badge_id)", "Trainer Card renders actual badge ownership")
	_check_contains(overlay, "PlayerSave.gym_badges_changed.connect(_refresh_trainer_card_gym_badges)", "Trainer Card reacts immediately when badge progress changes")
	_check_contains(overlay, "_create_public_trainer_gym_badges_panel(card)", "public Trainer Cards render server-provided Gym Badges")
	_check_contains(overlay, "_gym_badge_state_has(", "public Trainer Cards distinguish earned and locked badges")
	_check_contains(overlay, '"ui.staff.dev.trainer_progress"', "Developer Tools exposes trainer progress")
	_check_contains(guild, "func _player_badge_count", "guild requirements read canonical badge progress")
	_check_contains(guild, "_player_badge_count() < REQUIRED_BADGES", "guild creation preview enforces the badge gate")
	_check_contains(wallet_service, '"gymBadgeAward"', "trainer reward response preserves Gym Badge awards")
	_check_contains(wallet_service, "PlayerSave.apply_gym_badge_state", "trainer rewards refresh canonical badge progress")
	_check_contains(world, "func _notify_gym_badge_award", "Gym victory announces the awarded badge")
	_check_contains(world, '"playItemReceivedSfx": bool(gym_badge_award.get("awarded", false))', "new Gym Badges schedule the received-item jingle")

	quit(1 if failed else 0)


func _check_contains(source: String, expected: String, label: String) -> void:
	_check(source.contains(expected), label)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
