extends SceneTree

var failed := false


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
	_check(popup.find_child("GuildRow_1", true, false) != null, "debug directory renders guild rows")
	_check(popup.find_child("GuildDetailPanel", true, false) != null, "guild information panel is present")

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
	_check(popup.find_child("GuildMemberDashboard", true, false) != null, "member dashboard renders")
	_check(popup.find_child("GuildOverviewTab", true, false) != null, "guild overview tab renders")
	_check(popup.find_child("GuildMembersTab", true, false) != null, "guild members tab renders")
	_check(popup.find_child("GuildManagementTab", true, false) != null, "guild management tab renders for leaders")
	_check(popup.find_child("GuildOverviewSection", true, false) != null, "guild dashboard opens on its overview")
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
	_check(popup.find_child("GuildEmblemPreview", true, false) == null, "management keeps emblem controls out of settings")
	var edit_emblem_button := popup.find_child("EditGuildEmblemButton", true, false) as Button
	_check(edit_emblem_button != null, "leader can edit the Guild emblem from the header icon")
	if edit_emblem_button != null:
		edit_emblem_button.pressed.emit()
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
	if color_code_input != null:
		popup._select_emblem_color(0)
		color_code_input.text = "#ff00aa"
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
	popup.guild_home["membership"] = {"guildId": 1, "role": "member"}
	popup.membership = {"guildId": 1, "role": "member"}
	popup._render_guild_home()
	await process_frame
	_check(popup.find_child("GuildManagementTab", true, false) == null, "regular members do not see management")
	_check(popup.find_child("EditGuildEmblemButton", true, false) == null, "regular members cannot edit the Guild emblem")
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
	popup.close()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
