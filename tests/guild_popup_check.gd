extends SceneTree

const GUILD_POPUP_SCENE_PATH := "res://scenes/interface/guild_popup.tscn"
const GUILD_POPUP_SCRIPT_PATH := "res://scripts/ui/guild_popup.gd"
const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"

var failed := false


func _init() -> void:
	var popup_scene_source := FileAccess.get_file_as_string(GUILD_POPUP_SCENE_PATH)
	var popup_source := FileAccess.get_file_as_string(GUILD_POPUP_SCRIPT_PATH)
	var overlay_source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)

	_check_contains(popup_scene_source, "guild_popup.gd", "guild popup scene loads its controller")
	_check_contains(popup_source, '"ui.guild.title"', "guildless interface has a localized title")
	_check_contains(popup_source, '"ui.guild.tab.browse"', "guildless interface exposes localized guild discovery")
	_check_contains(popup_source, '"ui.guild.tab.create"', "guildless interface exposes localized guild creation")
	_check_contains(popup_source, "func _render_guild_list", "guild directory renders a compact guild list")
	_check_contains(popup_source, "func _render_selected_guild", "selected guild has a public information panel")
	_check_contains(popup_source, '"ui.guild.forum"', "guild profile reserves the localized official forum action")
	_check_contains(popup_source, '"ui.guild.create.emblem_note"', "creation flow explains the optional emblem through localization")
	_check_contains(popup_source, "CREATION_COST := 100000", "creation flow shows the Pokédollar gate")
	_check_contains(popup_source, "REQUIRED_BADGES := 3", "creation flow shows the badge gate")
	_check_contains(popup_source, "_player_badge_count() < REQUIRED_BADGES", "creation flow evaluates server badge progress")
	_check_contains(popup_source, '"create_guild"', "creation flow calls the authoritative guild service")
	_check_contains(popup_source, '"apply_wallet_result"', "successful creation applies the charged wallet")
	_check_contains(popup_source, "func _render_guild_home", "guild members receive a dedicated dashboard")
	_check_contains(popup_source, '_show_page("member" if not membership.is_empty() else "browse")', "guild members land on their own dashboard")
	_check_contains(popup_source, "has_explicit_page_selection", "explicit guild navigation is preserved")
	_check_contains(popup_source, "GuildOverviewTab", "guild dashboard separates its overview")
	_check_contains(popup_source, "GuildMembersTab", "guild dashboard separates its member roster")
	_check_contains(popup_source, "GuildManagementTab", "guild dashboard separates management controls")
	_check_contains(popup_source, '"ui.guild.roster"', "guild dashboard renders its localized member roster")
	_check_contains(popup_source, "GUILD_EMBLEM_SIZE := 32", "guild emblems use the intended 32 by 32 resolution")
	_check_contains(popup_source, "EditGuildEmblemButton", "guild dashboard opens the emblem editor on demand")
	_check_contains(popup_source, '"ui.guild.emblem.edit"', "editable guild emblem explains its localized action")
	_check_contains(popup_source, "GuildEmblemEditorPopup", "guild emblem editor uses a dedicated popup")
	_check_contains(popup_source, "GuildEmblemColorCode", "guild emblem palette accepts exact hex colour codes")
	_check_contains(popup_source, "GuildSavedEmblemSelect", "guild emblem editor lists Guild-owned templates")
	_check_contains(popup_source, "ApplySavedGuildEmblemButton", "guild emblem editor can restore a Guild-owned template")
	_check_contains(popup_source, '"ui.guild.invite.title"', "guild leaders and officers can invite trainers")
	_check_contains(popup_source, "func _on_accept_invitation", "guildless trainers can accept invitations")
	_check_contains(overlay_source, "GUILD_POPUP_SCENE", "main overlay loads the guild popup")
	_check_contains(overlay_source, "_open_guild_popup()", "existing guild button opens the new interface")

	quit(1 if failed else 0)


func _check_contains(source: String, expected: String, label: String) -> void:
	if source.contains(expected):
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
