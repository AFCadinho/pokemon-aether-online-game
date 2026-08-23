extends SceneTree

var failed := false
var guild_chat_open_requested := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/interface/guild_popup.tscn") as PackedScene
	_check(packed != null, "guild popup scene loads at runtime")
	if packed == null:
		quit(1)
		return

	var popup := packed.instantiate() as GuildPopup
	root.add_child(popup)
	await process_frame
	popup.show_debug_preview()
	popup.open()
	await process_frame

	_check(popup.visible, "guild popup opens")
	_check(popup.size == GuildPopup.POPUP_SIZE, "guild popup uses the intended desktop size")
	var minimum_size := popup.get_combined_minimum_size()
	_check(
		minimum_size.x <= GuildPopup.POPUP_SIZE.x and minimum_size.y <= GuildPopup.POPUP_SIZE.y,
		"guild content fits inside its popup"
	)
	_check(popup.find_child("BrowseGuildsButton", true, false) != null, "browse action is present")
	_check(popup.find_child("CreateGuildButton", true, false) != null, "create action is present")
	_check(popup.find_child("GuildSearchInput", true, false) != null, "guild search is present")
	_check(popup.find_child("GuildDirectoryFilters", true, false) != null, "guild discovery filters are present")
	var filter_button := popup.find_child("GuildFilterButton", true, false) as Button
	_check(filter_button != null, "one Guild filter button is present")
	_check(popup.find_child("GuildFilterOpen", true, false) == null, "quick filter buttons stay out of the directory")
	_check(popup.find_child("GuildRow_1", true, false) != null, "debug directory renders guild rows")
	var discovery := popup.find_child("GuildRowDiscovery_1", true, false) as Label
	var availability := popup.find_child("GuildRowAvailability_1", true, false) as Label
	_check(discovery != null and discovery.text.contains("PvP") and discovery.text.contains("English"), "guild card shows focus and language")
	_check(availability != null and availability.text.contains("38/50") and availability.text.contains("Applications"), "guild card shows capacity and recruitment")
	_check(popup.find_child("GuildDetailPanel", true, false) != null, "guild information panel is present")
	_check(popup.find_child("GuildForumButton", true, false) == null, "unavailable forum action stays out of the Guild profile")
	var apply_button := popup.find_child("GuildApplyButton", true, false) as Button
	_check(apply_button != null and apply_button.text == "Apply to Guild", "reviewed Guild exposes its application action")
	popup.pending_applications = [{"id": 42, "guildId": 1, "status": "pending"}]
	popup._render_guild_list()
	await process_frame
	apply_button = popup.find_child("GuildApplyButton", true, false) as Button
	_check(apply_button != null and apply_button.text == "Cancel Application", "pending application can be cancelled")
	_check(popup.find_child("GuildApplyButton", true, false) != null, "pending application remains actionable")
	popup.pending_applications.clear()
	popup._select_guild(2)
	await process_frame
	var join_button := popup.find_child("GuildApplyButton", true, false) as Button
	_check(join_button != null and join_button.text == "Join Guild", "open Guild exposes direct joining")
	if join_button != null:
		join_button.pressed.emit()
		await process_frame
	var join_confirmation := popup.find_child("GuildJoinConfirmationDialog", true, false) as ConfirmationDialog
	_check(join_confirmation != null and join_confirmation.visible, "direct Guild joining asks for confirmation")
	if join_confirmation != null:
		join_confirmation.canceled.emit()
		await process_frame
	popup._select_guild(1)
	await process_frame
	if filter_button != null:
		filter_button.pressed.emit()
		await process_frame
	var filter_dialog := popup.find_child("GuildFilterDialog", true, false) as PopupPanel
	_check(filter_dialog != null and filter_dialog.visible, "Guild filter button opens the filter dialog")
	var focus_filter := popup.find_child("GuildFocusFilterSelect", true, false) as OptionButton
	var language_filter := popup.find_child("GuildLanguageFilterSelect", true, false) as OptionButton
	_check(language_filter != null and language_filter.item_count == 11, "Guild filters offer every supported language")
	_check(_option_has_metadata(language_filter, "spanish"), "Guild filters include Spanish")
	_check(_option_has_metadata(language_filter, "portuguese"), "Guild filters include Portuguese")
	_check(_option_has_metadata(language_filter, "italian"), "Guild filters include Italian")
	_check(_option_has_metadata(language_filter, "chinese"), "Guild filters include Chinese")
	_check(_option_has_metadata(language_filter, "french"), "Guild filters include French")
	_check(popup.language_select != null and popup.language_select.item_count == 10, "Guild creation uses the full language list")
	popup.directory_language_filter = "english"
	_check(popup._matches_directory_filter({"language": "Dutch / English"}), "English filter includes bilingual Guilds")
	popup.directory_language_filter = "french"
	_check(popup._matches_directory_filter({"language": "French"}), "French filter matches French Guilds")
	_check(not popup._matches_directory_filter({"language": "German"}), "French filter excludes other languages")
	popup.directory_language_filter = "chinese"
	_check(popup._matches_directory_filter({"language": "Chinese"}), "Chinese filter matches Chinese Guilds")
	popup.directory_language_filter = "all"
	_select_option_with_metadata(focus_filter, "pvp")
	var apply_filters := popup.find_child("GuildFiltersApplyButton", true, false) as Button
	if apply_filters != null:
		apply_filters.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildRow_1", true, false) != null, "PvP filter keeps mixed PvP Guilds")
	_check(popup.find_child("GuildRow_2", true, false) == null, "PvP filter hides PvE Guilds")
	_check(popup.find_child("GuildRow_3", true, false) != null, "PvP filter keeps competitive PvP Guilds")
	_check(filter_button != null and filter_button.text.contains("1"), "filter button shows the active filter count")
	if filter_button != null:
		filter_button.pressed.emit()
		await process_frame
	var clear_filters := popup.find_child("GuildFiltersClearButton", true, false) as Button
	if clear_filters != null:
		clear_filters.pressed.emit()
	if apply_filters != null:
		apply_filters.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildRow_2", true, false) != null, "clearing the dialog restores all Guilds")
	if filter_button != null:
		filter_button.pressed.emit()
		await process_frame
	var recruitment_filter := popup.find_child("GuildRecruitmentFilterSelect", true, false) as OptionButton
	_select_option_with_metadata(recruitment_filter, "open")
	_select_option_with_metadata(language_filter, "dutch")
	if apply_filters != null:
		apply_filters.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildRow_1", true, false) == null, "combined filters hide Guilds outside either choice")
	_check(popup.find_child("GuildRow_2", true, false) != null, "combined filters keep an open Dutch Guild")
	_check(filter_button != null and filter_button.text.contains("2"), "filter button counts combined choices")
	if filter_button != null:
		filter_button.pressed.emit()
		await process_frame
	if clear_filters != null:
		clear_filters.pressed.emit()
	if apply_filters != null:
		apply_filters.pressed.emit()
		await process_frame

	popup.incoming_invitations = [{"id": 7, "guildName": "Aether Vanguard", "invitedBy": "Nova"}]
	popup._render_incoming_invitations()
	await process_frame
	_check(popup.find_child("AcceptGuildInvitationButton", true, false) != null, "incoming invitation can be accepted")
	_check(popup.find_child("DeclineGuildInvitationButton", true, false) != null, "incoming invitation can be declined")

	popup.set_guilds([])
	await process_frame
	var empty_state := popup.find_child("GuildDirectoryEmptyState", true, false) as Control
	var empty_message := popup.find_child("GuildDirectoryEmptyMessage", true, false) as Control
	_check(empty_state != null, "empty guild directory state renders")
	_check(
		empty_state != null and empty_state.size.x >= 300.0,
		"empty guild directory state keeps a readable width"
	)
	_check(
		empty_message != null and empty_message.size.x >= 300.0,
		"empty guild directory message does not wrap per character"
	)

	popup.show_debug_member_preview()
	await process_frame
	_check(popup.find_child("MyGuildButton", true, false) != null, "member navigation is present")
	var create_button := popup.find_child("CreateGuildButton", true, false) as Button
	_check(create_button != null and not create_button.visible, "Guild members do not see the create action")
	_check(popup.find_child("GuildMemberDashboard", true, false) != null, "member dashboard renders")
	_check(popup.find_child("GuildOverviewTab", true, false) != null, "guild overview tab renders")
	_check(popup.find_child("GuildMembersTab", true, false) != null, "guild members tab renders")
	_check(popup.find_child("GuildManagementTab", true, false) != null, "guild management tab renders for leaders")
	_check(popup.find_child("GuildOverviewSection", true, false) != null, "guild dashboard opens on its overview")
	var guild_chat_button := popup.find_child("GuildChatShortcutButton", true, false) as Button
	_check(guild_chat_button != null, "guild overview renders a Guild chat shortcut")
	if guild_chat_button != null:
		popup.guild_chat_requested.connect(_on_guild_chat_requested, CONNECT_ONE_SHOT)
		guild_chat_button.pressed.emit()
	_check(guild_chat_open_requested, "Guild chat shortcut requests the Guild channel")
	var members_shortcut := popup.find_child("GuildMembersShortcutButton", true, false) as Button
	_check(members_shortcut != null, "guild overview renders a member roster shortcut")
	if members_shortcut != null:
		members_shortcut.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildMembersSection", true, false) != null, "member roster shortcut opens the roster")
	var overview_tab := popup.find_child("GuildOverviewTab", true, false) as Button
	if overview_tab != null:
		overview_tab.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildLobbyTeleportButton", true, false) != null, "guild overview renders free Lobby travel")
	_check(popup.find_child("GuildSettingsDescription", true, false) == null, "settings stay out of the guild overview")
	var members_tab := popup.find_child("GuildMembersTab", true, false) as Button
	if members_tab != null:
		members_tab.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildMembersSection", true, false) != null, "members tab opens the roster")
	var management_tab := popup.find_child("GuildManagementTab", true, false) as Button
	if management_tab != null:
		management_tab.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildManagementSection", true, false) != null, "management tab opens guild controls")
	_check(popup.find_child("GuildSettingsDescription", true, false) != null, "leader settings render")
	_check(popup.find_child("GuildApplicationsInbox", true, false) != null, "Guild applications use a distinct inbox card")
	var application_count := popup.find_child("GuildApplicationsPendingCount", true, false) as Label
	_check(application_count != null and application_count.text.contains("1"), "Guild application inbox shows its pending count")
	_check(popup.find_child("GuildApplicationRow_8", true, false) != null, "pending Guild application renders for staff")
	_check(popup.find_child("AcceptGuildApplicationButton_8", true, false) != null, "staff can accept a Guild application")
	_check(popup.find_child("DeclineGuildApplicationButton_8", true, false) != null, "staff can decline a Guild application")
	_check(popup.find_child("GuildEmblemPreview", true, false) == null, "management keeps emblem controls out of settings")
	_check(popup.find_child("EditGuildEmblemButton", true, false) == null, "leader does not see a redundant Guild emblem edit button")
	var edit_emblem_icon_button := popup.find_child("EditGuildEmblemIconButton", true, false) as Button
	_check(edit_emblem_icon_button != null, "leader can edit the Guild emblem by clicking it")
	if edit_emblem_icon_button != null:
		edit_emblem_icon_button.pressed.emit()
		await process_frame
	var emblem_popup := popup.find_child("GuildEmblemEditorPopup", true, false) as PopupPanel
	_check(emblem_popup != null and emblem_popup.visible, "emblem editor opens in a dedicated popup")
	var emblem_grid := popup.find_child("GuildEmblemGrid", true, false) as GridContainer
	_check(
		emblem_grid != null and emblem_grid.columns == 32 and emblem_grid.get_child_count() == 1024,
		"emblem editor renders a 32 by 32 pixel grid"
	)
	_check(popup.find_child("CancelGuildEmblemButton", true, false) != null, "emblem editor can discard changes")
	_check(popup.find_child("SaveGuildEmblemButton", true, false) != null, "emblem editor can save changes")
	var saved_template_select := popup.find_child("GuildSavedEmblemSelect", true, false) as OptionButton
	var apply_saved_template := popup.find_child("ApplySavedGuildEmblemButton", true, false) as Button
	_check(
		saved_template_select != null
		and saved_template_select.item_count == 1
		and not saved_template_select.disabled,
		"emblem editor lists templates permanently unlocked for this Guild"
	)
	_check(
		apply_saved_template != null and not apply_saved_template.disabled,
		"Guild leader can restore an unlocked emblem template"
	)
	popup.emblem_palette = [
		"#a6e2fa", "#22bdd9", "#f9f9f9", "#282828",
		"#f5d8b8", "#c28a4d", "#935d37", "#d91e25",
	]
	popup._refresh_emblem_palette_controls()
	var palette_grid := popup.find_child("GuildEmblemPaletteGrid", true, false) as GridContainer
	_check(
		palette_grid != null and palette_grid.columns == 2 and popup.emblem_color_buttons.size() == 8,
		"emblem editor keeps imported eight-colour templates editable"
	)
	var color_code_input := popup.find_child("GuildEmblemColorCode", true, false) as LineEdit
	_check(color_code_input != null, "emblem editor accepts a hex colour code")
	var color_code_preview := popup.find_child("GuildEmblemColorCodePreview", true, false) as PanelContainer
	_check(color_code_preview != null, "emblem editor shows a colour preview beside the hex code")
	if color_code_input != null:
		popup._select_emblem_color(0)
		color_code_input.text = "#ff00aa"
		popup._on_emblem_color_code_changed(color_code_input.text)
		var live_preview_style := (
			color_code_preview.get_theme_stylebox("panel") as StyleBoxFlat
			if color_code_preview != null
			else null
		)
		_check(
			live_preview_style != null and live_preview_style.bg_color.is_equal_approx(Color("#ff00aa")),
			"valid hex input updates the colour preview immediately"
		)
		popup._apply_emblem_color_code()
		_check(popup.emblem_palette[0] == "#ff00aa", "valid emblem hex colour is applied")
		color_code_input.text = "#invalid"
		popup._apply_emblem_color_code()
		_check(popup.emblem_palette[0] == "#ff00aa", "invalid emblem hex colour is rejected")
		var color_status := popup.find_child("GuildEmblemColorCodeStatus", true, false) as Label
		_check(color_status != null and color_status.visible, "invalid emblem hex colour shows validation")
	var legacy_pixels: Array = []
	legacy_pixels.resize(64)
	legacy_pixels.fill(-1)
	legacy_pixels[0] = 0
	legacy_pixels[63] = 1
	var upgraded_pixels := popup._normalized_emblem_pixels({
		"size": 8,
		"pixels": legacy_pixels,
	})
	_check(
		upgraded_pixels.size() == 1024
		and upgraded_pixels[0] == 0
		and upgraded_pixels[3] == 0
		and upgraded_pixels[1023] == 1,
		"legacy 8 by 8 emblems are preserved at 32 by 32"
	)
	popup._cancel_emblem_edit()
	await process_frame
	_check(emblem_popup != null and not emblem_popup.visible, "emblem editor closes without saving")
	_check(popup.find_child("GuildInviteUsername", true, false) != null, "member invitation form renders")
	var member_minimum_size := popup.get_combined_minimum_size()
	_check(
		member_minimum_size.x <= GuildPopup.POPUP_SIZE.x and member_minimum_size.y <= GuildPopup.POPUP_SIZE.y,
		"member dashboard fits inside its popup"
	)
	popup.guild_home["pendingApplications"] = []
	popup._render_guild_home()
	await process_frame
	_check(popup.find_child("GuildApplicationsEmptyState", true, false) != null, "empty Guild application inbox remains clearly visible")
	application_count = popup.find_child("GuildApplicationsPendingCount", true, false) as Label
	_check(application_count != null and application_count.text.contains("0"), "empty Guild application inbox shows zero waiting")
	popup.guild_home["membership"] = {"guildId": 1, "role": "member"}
	popup.membership = {"guildId": 1, "role": "member"}
	popup._render_guild_home()
	await process_frame
	_check(popup.find_child("GuildManagementTab", true, false) == null, "regular members do not see management")
	_check(popup.find_child("EditGuildEmblemButton", true, false) == null, "regular members cannot edit the Guild emblem")
	_check(popup.find_child("EditGuildEmblemIconButton", true, false) == null, "regular members cannot edit the Guild emblem icon")
	_check(popup.find_child("GuildOverviewSection", true, false) != null, "regular members return to the overview")

	popup.close()
	await process_frame
	_check(not popup.visible, "guild popup closes cleanly")
	popup._show_page("browse")
	popup.open()
	await process_frame
	_check(popup.active_page == "member", "returning guild members land on My Guild")
	popup._on_primary_navigation_pressed("browse")
	_check(popup.active_page == "browse", "guild members can still browse guilds explicitly")
	var localization_manager := root.get_node_or_null("LocalizationManager")
	if localization_manager != null:
		localization_manager.set_locale("nl")
		await process_frame
		var browse_button := popup.find_child("BrowseGuildsButton", true, false) as Button
		_check(
			browse_button != null and browse_button.text.contains("Guilds bekijken"),
			"Guild navigation refreshes live in Dutch"
		)
		var search := popup.find_child("GuildSearchInput", true, false) as LineEdit
		_check(
			search != null and search.placeholder_text == "Zoek op naam, taal of focus",
			"Guild search refreshes live in Dutch"
		)
		localization_manager.set_locale("en")
		await process_frame
	popup.close()
	quit(1 if failed else 0)


func _on_guild_chat_requested() -> void:
	guild_chat_open_requested = true


func _select_option_with_metadata(select: OptionButton, value: String) -> void:
	if select == null:
		return
	for item_index: int in range(select.item_count):
		if str(select.get_item_metadata(item_index)) == value:
			select.select(item_index)
			return


func _option_has_metadata(select: OptionButton, value: String) -> bool:
	if select == null:
		return false
	for item_index: int in range(select.item_count):
		if str(select.get_item_metadata(item_index)) == value:
			return true
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
