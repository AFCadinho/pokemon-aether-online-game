extends SceneTree

var failed := false
var private_message_user: Dictionary = {}
var trainer_card_user: Dictionary = {}


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
	var contacts := popup.find_child("GuildRowContacts_1", true, false) as Label
	_check(discovery != null and discovery.text.contains("PvP") and discovery.text.contains("English"), "guild card shows focus and language")
	_check(availability != null and availability.text.contains("38/50") and availability.text.contains("Applications"), "guild card shows capacity and recruitment")
	_check(
		contacts != null
		and contacts.text.contains("Nova")
		and contacts.text.contains("Maple")
		and contacts.text.contains("Iris"),
		"guild card names its leader and contact Captains"
	)
	var captain_contacts := popup.find_child("GuildCaptainContacts", true, false) as Label
	_check(
		captain_contacts != null
		and captain_contacts.text.contains("Maple")
		and captain_contacts.text.contains("Iris"),
		"selected Guild profile names its Captains"
	)
	_check(popup.find_child("GuildDetailPanel", true, false) != null, "guild information panel is present")
	_check(popup.find_child("GuildDetailScroll", true, false) != null, "long Guild profiles remain scrollable")
	_check(popup.find_child("GuildRequirementsPanel", true, false) != null, "configured requirements render on the Guild profile")
	_check(popup.find_child("GuildRequirementRow_0", true, false) != null, "Guild requirements render as distinct readable rows")
	_check(popup.find_child("GuildRequirementStatus_0", true, false) != null, "objective requirements show the applicant's status")
	_check(popup.find_child("GuildForumButton", true, false) == null, "unavailable forum action stays out of the Guild profile")
	var apply_button := popup.find_child("GuildApplyButton", true, false) as Button
	_check(apply_button != null and apply_button.text == "Apply to Guild", "reviewed Guild exposes its application action")
	if apply_button != null:
		apply_button.pressed.emit()
		await process_frame
	var requirements_dialog := popup.find_child("GuildApplicationRequirementsDialog", true, false) as ConfirmationDialog
	_check(requirements_dialog != null and requirements_dialog.visible, "applicants review requirements before applying")
	_check(requirements_dialog != null and requirements_dialog.dialog_text.contains("Not met"), "the application checklist explains unmet objective requirements")
	_check_dialog_styled(requirements_dialog, "Guild requirements confirmation")
	if requirements_dialog != null:
		requirements_dialog.canceled.emit()
		await process_frame
	popup.pending_applications = [{"id": 42, "guildId": 1, "status": "pending"}]
	popup._render_guild_list()
	await process_frame
	apply_button = popup.find_child("GuildApplyButton", true, false) as Button
	_check(apply_button != null and apply_button.text == "Cancel Application", "pending application can be cancelled")
	_check(popup.find_child("GuildApplyButton", true, false) != null, "pending application remains actionable")
	popup.pending_applications.clear()
	popup.application_cooldowns = [{
		"guildId": 1,
		"reapplyAt": Time.get_datetime_string_from_unix_time(
			int(Time.get_unix_time_from_system()) + 172800,
			true
		) + "Z",
	}]
	popup._render_guild_list()
	await process_frame
	apply_button = popup.find_child("GuildApplyButton", true, false) as Button
	var cooldown_label := popup.find_child("GuildApplicationCooldown", true, false) as Label
	_check(apply_button != null and apply_button.disabled, "declined application cooldown disables reapplying")
	_check(apply_button != null and apply_button.text.contains("Apply in"), "declined application action shows its remaining wait")
	_check(cooldown_label != null and cooldown_label.text.contains("Application declined"), "declined application cooldown is explained on the Guild profile")
	popup.application_cooldowns.clear()
	popup._select_guild(2)
	await process_frame
	_check(popup.find_child("GuildCaptainContacts", true, false) == null, "Guild profiles omit an empty Captain contact line")
	_check(popup.find_child("GuildRequirementsPanel", true, false) == null, "Guild profiles hide the requirements section when none are configured")
	var join_button := popup.find_child("GuildApplyButton", true, false) as Button
	_check(join_button != null and join_button.text == "Join Guild", "open Guild exposes direct joining")
	if join_button != null:
		join_button.pressed.emit()
		await process_frame
	var join_confirmation := popup.find_child("GuildJoinConfirmationDialog", true, false) as ConfirmationDialog
	_check(join_confirmation != null and join_confirmation.visible, "direct Guild joining asks for confirmation")
	_check_dialog_styled(join_confirmation, "join confirmation")
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
	_check(
		filter_dialog != null and filter_dialog.has_theme_stylebox_override("panel"),
		"Guild filter dialog uses the Guild popup styling"
	)
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
	_check(popup.find_child("MyGuildButton", true, false) == null, "member navigation removes the redundant My Guild tab")
	var create_button := popup.find_child("CreateGuildButton", true, false) as Button
	_check(create_button != null and not create_button.visible, "Guild members do not see the create action")
	_check(popup.find_child("GuildMemberDashboard", true, false) != null, "member dashboard renders")
	_check(popup.find_child("GuildOverviewTab", true, false) != null, "guild overview tab renders")
	_check(popup.find_child("GuildBankTab", true, false) != null, "guild bank tab renders")
	_check(popup.find_child("GuildMembersTab", true, false) != null, "guild members tab renders")
	_check(popup.find_child("GuildManagementTab", true, false) != null, "guild management tab renders for leaders")
	var section_navigation := popup.find_child("GuildSectionNavigation", true, false) as HBoxContainer
	var member_browse_button := popup.find_child("BrowseGuildsButton", true, false) as Button
	_check(
		section_navigation != null
		and member_browse_button != null
		and section_navigation.get_parent() == member_browse_button.get_parent()
		and section_navigation.get_index() < member_browse_button.get_index(),
		"Guild member tabs occupy the top navigation before the secondary browse action"
	)
	_check(
		member_browse_button != null and member_browse_button.custom_minimum_size.x <= 150.0,
		"Guild discovery becomes a compact secondary action for members"
	)
	_check(popup.find_child("GuildOverviewSection", true, false) != null, "guild dashboard opens on its overview")
	var announcement_text := popup.find_child("GuildAnnouncementText", true, false) as Label
	_check(announcement_text != null and announcement_text.text.contains("Aether Clash practice"), "guild overview displays the current announcement")
	var leader_options := popup.find_child("GuildOptionsMenuButton", true, false) as MenuButton
	_check(leader_options != null and leader_options.get_popup().is_item_disabled(0), "Guild leaders cannot leave through Guild options")
	var header_travel := popup.find_child("GuildHeaderTravelActions", true, false) as VBoxContainer
	_check(header_travel != null, "guild travel occupies the member header")
	var guild_progress := popup.find_child("GuildExperienceProgress", true, false) as ProgressBar
	_check(guild_progress != null and is_equal_approx(guild_progress.value, 47.5), "guild overview shows authoritative level progress")
	var guild_progress_label := popup.find_child("GuildExperienceProgressLabel", true, false) as Label
	_check(guild_progress_label != null and guild_progress_label.text.contains("500,000"), "guild overview shows total Guild EXP")
	var rewards_button := popup.find_child("GuildLevelRewardsButton", true, false) as Button
	_check(rewards_button != null and not rewards_button.disabled, "guild overview exposes the level unlock roadmap")
	if rewards_button != null:
		rewards_button.pressed.emit()
		await process_frame
	var rewards_window := popup.find_child("GuildLevelRewardsWindow", true, false) as Window
	_check(rewards_window != null and rewards_window.visible, "level unlock roadmap opens in a modal")
	var rewards_list := popup.find_child("GuildLevelRewardsList", true, false) as VBoxContainer
	_check(rewards_list != null and rewards_list.get_child_count() == 20, "level unlock roadmap shows all twenty levels")
	var level_two_unlocks := popup.find_child("GuildLevelRewardUnlocks_2", true, false) as Label
	_check(level_two_unlocks != null and level_two_unlocks.text.contains("+3"), "level two shows its member capacity unlock")
	var level_three_unlocks := popup.find_child("GuildLevelRewardUnlocks_3", true, false) as Label
	_check(level_three_unlocks != null and level_three_unlocks.text.contains("+15"), "level three starts the item capacity checkpoints")
	var level_five_unlocks := popup.find_child("GuildLevelRewardUnlocks_5", true, false) as Label
	_check(level_five_unlocks != null and level_five_unlocks.text.contains("+10"), "level five starts the Pokémon capacity checkpoints")
	var roadmap: Array = popup.guild_home.get("guild", {}).get("levelRewards", [])
	_check(
		roadmap.size() == 20
		and int((roadmap[17] as Dictionary).get("memberCapacity", 0)) == 50
		and int((roadmap[18] as Dictionary).get("bankItemCapacity", 0)) == 200
		and int((roadmap[19] as Dictionary).get("bankPokemonCapacity", 0)) == 120,
		"level roadmap reaches every configured maximum capacity"
	)
	var rewards_close := popup.find_child("CloseGuildLevelRewardsButton", true, false) as Button
	if rewards_close != null:
		rewards_close.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildLevelRewardsWindow", true, false) == null, "level unlock roadmap closes cleanly")
	var lobby_button := popup.find_child("GuildLobbyTeleportButton", true, false) as Button
	_check(lobby_button != null and not lobby_button.disabled, "Aether Clash Lobby travel is available")
	var base_button := popup.find_child("GuildBaseTeleportButton", true, false) as Button
	_check(base_button != null and base_button.disabled, "future Guild Base travel is visible but inactive")
	var overview_tab := popup.find_child("GuildOverviewTab", true, false) as Button
	if overview_tab != null:
		overview_tab.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildLobbyTeleportButton", true, false) != null, "guild overview keeps Lobby travel available below the top tabs")
	_check(popup.find_child("GuildSettingsDescription", true, false) == null, "settings stay out of the guild overview")
	_check(popup.find_child("GuildSettingsAnnouncement", true, false) == null, "announcement editing stays out of the guild overview")
	var bank_tab := popup.find_child("GuildBankTab", true, false) as Button
	if bank_tab != null:
		bank_tab.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildBankSection", true, false) != null, "Guild Bank opens in its own workspace")
	_check(popup.find_child("GuildBankFundsCard", true, false) != null, "Guild Bank shows shared funds")
	_check(popup.find_child("GuildBankPokemonCard", true, false) != null, "Guild Bank shows Pokémon storage")
	_check(popup.find_child("GuildBankItemsCard", true, false) != null, "Guild Bank shows item storage")
	var item_storage_summary := popup._guild_bank_card_description("items")
	_check(item_storage_summary.contains("18 total items") and item_storage_summary.contains("1 / 55"), "Item Storage distinguishes total quantity from used stack slots")
	_check(popup.find_child("GuildBankResourcesCard", true, false) != null, "Guild Bank shows shared consumable resources")
	var funds_action := popup.find_child("GuildBankFundsAction", true, false) as Button
	var pokemon_action := popup.find_child("GuildBankPokemonAction", true, false) as Button
	var items_action := popup.find_child("GuildBankItemsAction", true, false) as Button
	var resources_action := popup.find_child("GuildBankResourcesAction", true, false) as Button
	_check(
		funds_action != null and not funds_action.disabled
		and pokemon_action != null and not pokemon_action.disabled
		and items_action != null and not items_action.disabled
		and resources_action != null and not resources_action.disabled,
		"every Guild member can open each bank category"
	)
	_check(pokemon_action != null and pokemon_action.text == "Enter Vault", "Pokémon category uses a distinct entry label")
	var permission_summary := popup.find_child("GuildBankPermissionSummary", true, false) as Label
	_check(permission_summary != null and permission_summary.text.contains("allowed"), "Guild Bank shows the leader's transaction rights")
	var rank_rights_action := popup.find_child("GuildBankRankRightsButton", true, false) as Button
	_check(rank_rights_action != null, "every Guild member can open the rank-rights page")
	if rank_rights_action != null:
		rank_rights_action.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildBankRankRightsWorkspace", true, false) != null, "Guild Bank rank rights open in a dedicated page")
	var rank_rights_table := popup.find_child("GuildBankRankRightsTable", true, false) as VBoxContainer
	_check(
		rank_rights_table != null and rank_rights_table.get_child_count() == 7,
		"rank-rights page compares all six Bank permissions in clean table rows"
	)
	var rank_rights_back := popup.find_child("GuildBankBackButton", true, false) as Button
	if rank_rights_back != null:
		rank_rights_back.pressed.emit()
		await process_frame
	pokemon_action = popup.find_child("GuildBankPokemonAction", true, false) as Button
	if pokemon_action != null:
		pokemon_action.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildBankWorkspace", true, false) != null, "a bank category opens a dedicated workspace")
	_check(popup.find_child("GuildBankPokemonPreview", true, false) != null, "Pokémon Vault opens with a scalable donation overview")
	_check(popup.find_child("GuildBankPokemonListScroll", true, false) != null, "Pokémon Vault overview remains scrollable at scale")
	_check(popup.find_child("GuildBankPokemonWithdrawButton_21", true, false) == null, "Pokémon Vault overview keeps Guild withdrawals out of the preview")
	_check(popup.find_child("GuildBankPokemonDepositButton_22", true, false) != null, "Pokémon Vault overview keeps direct personal donations available")
	var stored_pokemon_preview := popup.find_child("GuildBankPokemonIcon_21", true, false) as Button
	_check(
		stored_pokemon_preview != null and stored_pokemon_preview.tooltip_text == "Open Summary",
		"stored Pokémon expose their read-only Summary from the overview icon"
	)
	var pokemon_full_action := popup.find_child("GuildBankPokemonOpenFullButton", true, false) as Button
	_check(pokemon_full_action != null, "Pokémon Vault overview exposes its full management view")
	if pokemon_full_action != null:
		pokemon_full_action.pressed.emit()
		await process_frame
	var pokemon_vault_window := popup.find_child("GuildPokemonVaultWindow", true, false) as Window
	_check(pokemon_vault_window != null and pokemon_vault_window.visible, "full Pokémon Vault opens in a dedicated window")
	_check(pokemon_vault_window != null and pokemon_vault_window.find_child("GuildPokemonVaultGrid", true, false) != null, "full Pokémon Vault presents Guild Pokémon in a grid")
	_check(pokemon_vault_window != null and pokemon_vault_window.find_child("GuildPokemonVaultSearchInput", true, false) != null, "full Pokémon Vault provides search")
	_check(pokemon_vault_window != null and pokemon_vault_window.find_child("GuildPokemonVaultFilterSelect", true, false) != null, "full Pokémon Vault provides filters")
	popup._render_guild_home_with_status("Vault action failed", true)
	await process_frame
	var vault_status_panel := pokemon_vault_window.find_child("GuildPokemonVaultStatusPanel", true, false) as PanelContainer
	var vault_status := pokemon_vault_window.find_child("GuildPokemonVaultStatus", true, false) as Label
	_check(
		vault_status_panel != null and vault_status_panel.visible
		and vault_status != null and vault_status.text == "Vault action failed"
		and vault_status.get_theme_color("font_color") == GuildPopup.UI_WARNING,
		"full Pokémon Vault keeps failed-action feedback visible after refresh"
	)
	popup._render_guild_home_with_status("Guild Bank updated.", false)
	await process_frame
	_check(
		vault_status_panel.visible
		and vault_status.text == "Guild Bank updated."
		and vault_status.get_theme_color("font_color") == GuildPopup.UI_SUCCESS,
		"full Pokémon Vault keeps successful-action feedback visible after refresh"
	)
	popup._set_guild_pokemon_vault_status("", false)
	_check(popup.find_child("GuildBankPokemonLogButton", true, false) != null, "Pokémon Vault has a dedicated log action")
	_check(pokemon_vault_window != null and pokemon_vault_window.find_child("GuildBankPokemonDepositButton_22", true, false) == null, "full Pokémon Vault focuses only on Guild-owned assets")
	var original_bank_pokemon: Array = popup.guild_bank_state["pokemon"].duplicate(true)
	var scale_bank_pokemon: Array = original_bank_pokemon.duplicate(true)
	for pokemon_index: int in range(1, 25):
		scale_bank_pokemon.append({
			"pokemonId": 100 + pokemon_index,
			"pokemon": {"name": "Vault Pokémon %d" % pokemon_index, "level": pokemon_index},
			"depositedBy": "Admin",
			"isBorrowed": false,
			"canWithdraw": true,
			"canBorrow": true,
		})
	popup.guild_bank_state["pokemon"] = scale_bank_pokemon
	popup._render_guild_home()
	await process_frame
	var pokemon_grid := pokemon_vault_window.find_child("GuildPokemonVaultGrid", true, false) as GridContainer
	_check(
		pokemon_grid != null and pokemon_grid.columns == 5 and pokemon_grid.get_child_count() == 25,
		"full Pokémon Vault shows a PC-like five-column overview at scale"
	)
	var pokemon_vault_search := pokemon_vault_window.find_child("GuildPokemonVaultSearchInput", true, false) as LineEdit
	if pokemon_vault_search != null:
		pokemon_vault_search.text = "vault pokémon 24"
		pokemon_vault_search.text_changed.emit(pokemon_vault_search.text)
		await process_frame
	_check(pokemon_grid != null and pokemon_grid.get_child_count() == 1, "full Pokémon Vault searches its grid live")
	if pokemon_vault_search != null:
		pokemon_vault_search.text = ""
		pokemon_vault_search.text_changed.emit("")
		await process_frame
	popup.guild_bank_state["pokemon"] = original_bank_pokemon
	popup._render_guild_home()
	await process_frame
	var pokemon_withdraw := popup.find_child("GuildBankPokemonWithdrawButton_21", true, false) as Button
	_check(pokemon_withdraw != null and pokemon_withdraw.text == "Withdraw", "authorized ranks retain permanent Guild withdrawal")
	var pokemon_borrow := popup.find_child("GuildBankPokemonBorrowButton_21", true, false) as Button
	_check(pokemon_borrow != null and pokemon_borrow.text == "Borrow" and not pokemon_borrow.disabled, "available Guild-owned Pokémon expose borrowing without ownership transfer")
	popup.guild_bank_state["access"]["pokemonTradeLevelCap"] = 5
	popup.guild_bank_state["pokemon"][0]["canWithdraw"] = false
	popup.guild_bank_state["pokemon"][0]["canBorrow"] = false
	popup._render_guild_home()
	await process_frame
	pokemon_withdraw = popup.find_child("GuildBankPokemonWithdrawButton_21", true, false) as Button
	pokemon_borrow = popup.find_child("GuildBankPokemonBorrowButton_21", true, false) as Button
	_check(
		pokemon_withdraw != null
		and pokemon_withdraw.disabled
		and pokemon_withdraw.tooltip_text.contains("trade level cap"),
		"Pokémon withdrawal explains the recipient trade level cap"
	)
	_check(
		pokemon_borrow != null
		and pokemon_borrow.disabled
		and pokemon_borrow.tooltip_text.contains("trade level cap"),
		"Pokémon borrowing explains the recipient trade level cap"
	)
	popup.guild_bank_state["access"]["pokemonTradeLevelCap"] = 100
	popup.guild_bank_state["pokemon"][0]["canWithdraw"] = true
	popup.guild_bank_state["pokemon"][0]["canBorrow"] = true
	popup._render_guild_home()
	await process_frame
	popup.guild_bank_state["access"]["lendingEnabled"] = false
	popup.guild_bank_state["access"]["canBorrow"] = false
	popup.guild_bank_state["pokemon"][0]["canBorrow"] = false
	popup._render_guild_home()
	await process_frame
	pokemon_borrow = popup.find_child("GuildBankPokemonBorrowButton_21", true, false) as Button
	_check(
		pokemon_borrow != null
		and pokemon_borrow.disabled
		and pokemon_borrow.tooltip_text.contains("not available"),
		"Pokémon borrowing is disabled with an explanation when server lending is off"
	)
	popup.guild_bank_state["access"]["lendingEnabled"] = true
	popup.guild_bank_state["access"]["canBorrow"] = true
	popup.guild_bank_state["pokemon"][0]["canBorrow"] = true
	popup._render_guild_home()
	await process_frame
	_check(pokemon_vault_window.find_child("GuildPokemonVaultSelectedSummaryButton", true, false) is Button, "full Pokémon Vault keeps Summary previews available")
	var vault_close := pokemon_vault_window.find_child("GuildPokemonVaultCloseButton", true, false) as Button
	if vault_close != null:
		vault_close.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildPokemonVaultWindow", true, false) == null, "full Pokémon Vault closes back to its donation overview")
	var pokemon_deposit := popup.find_child("GuildBankPokemonDepositButton_22", true, false) as Button
	if pokemon_deposit != null:
		pokemon_deposit.pressed.emit()
		await process_frame
	var donation_dialog := popup.find_child("GuildBankDonationConfirmationDialog", true, false) as ConfirmationDialog
	_check(donation_dialog != null and donation_dialog.visible, "depositing a Pokémon confirms permanent Guild ownership")
	_check_dialog_styled(donation_dialog, "Guild Bank donation confirmation")
	if donation_dialog != null:
		donation_dialog.canceled.emit()
		await process_frame
	_check(popup.find_child("GuildBankPokemonPreview", true, false) != null, "closing full Pokémon Vault preserves its donation overview")
	var bank_back := popup.find_child("GuildBankBackButton", true, false) as Button
	if bank_back != null:
		bank_back.pressed.emit()
		await process_frame
	items_action = popup.find_child("GuildBankItemsAction", true, false) as Button
	var original_bank_items: Array = popup.guild_bank_state["items"].duplicate(true)
	var scale_bank_items: Array[Dictionary] = []
	for scale_index: int in range(120):
		scale_bank_items.append({
			"itemId": "scale-item-%d" % scale_index,
			"name": "Scale Item %d" % scale_index,
			"category": "Held Items",
			"quantity": scale_index + 1,
			"availableQuantity": scale_index + 1,
			"borrowedQuantity": 0,
			"lendable": true,
		})
	popup.guild_bank_state["items"] = scale_bank_items
	if items_action != null:
		items_action.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildBankItemsPreview", true, false) != null, "Item Storage opens with a scalable donation overview")
	_check(popup.find_child("GuildBankItemWithdrawButton_scale-item-0", true, false) == null, "Item Storage overview hides Guild withdrawal controls")
	_check(popup.find_child("GuildBankItemDepositButton_exp-share", true, false) != null, "Item Storage overview keeps direct Bag donations available")
	var scale_item_scroll := popup.find_child("GuildBankItemListScroll", true, false) as ScrollContainer
	_check(
		scale_item_scroll != null
		and scale_item_scroll.get_v_scroll_bar().max_value > scale_item_scroll.get_v_scroll_bar().page
		and popup.get_combined_minimum_size().y <= GuildPopup.POPUP_SIZE.y,
		"Item Storage remains scrollable and contained with 120 stored stacks"
	)
	var filter_test_items := original_bank_items.duplicate(true)
	filter_test_items.append({
		"itemId": "choice-scarf",
		"name": "Choice Scarf",
		"category": "Held Items",
		"quantity": 1,
		"availableQuantity": 0,
		"borrowedQuantity": 1,
		"lendable": true,
	})
	popup.guild_bank_state["items"] = filter_test_items
	popup._render_guild_home()
	await process_frame
	var items_full_action := popup.find_child("GuildBankItemsOpenFullButton", true, false) as Button
	if items_full_action != null:
		items_full_action.pressed.emit()
		await process_frame
	var items_storage_window := popup.find_child("GuildItemsStorageWindow", true, false) as Window
	var items_storage_grid := popup.find_child("GuildItemsStorageGrid", true, false) as GridContainer
	_check(items_storage_window != null and items_storage_window.visible, "full Item Storage opens in a dedicated window")
	_check(items_storage_grid != null and items_storage_grid.columns == 5, "full Item Storage presents a five-column asset grid")
	_check(popup.find_child("GuildItemsStorageScroll", true, false) is ScrollContainer, "full Item Storage grid remains scrollable")
	_check(items_storage_window != null and items_storage_window.find_child("GuildBankItemsLogButton", true, false) != null, "Item Storage has a dedicated log action")
	_check(items_storage_window != null and items_storage_window.find_child("GuildBankItemWithdrawButton_leftovers", true, false) != null, "selected reusable items can be withdrawn")
	_check(items_storage_window != null and items_storage_window.find_child("GuildBankItemDepositButton_exp-share", true, false) == null, "full Item Storage focuses only on Guild assets")
	_check(popup.find_child("GuildItemsStorageSlot_leftovers", true, false) is Button, "stored items render as selectable grid slots")
	var stored_item_name := items_storage_window.find_child("GuildBankItemName_leftovers", true, false) as Label
	var stored_item_detail := items_storage_window.find_child("GuildBankItemDetail_leftovers", true, false) as Label
	var stored_item_description := items_storage_window.find_child("GuildItemsStorageSelectedDescription", true, false) as Label
	_check(items_storage_window.find_child("GuildBankItemRow_leftovers", true, false) is PanelContainer, "selected item information and actions use a distinct card")
	_check(stored_item_name != null and stored_item_name.text == "Leftovers", "stored item names remain readable without quantity metadata")
	_check(stored_item_detail != null and stored_item_detail.text.contains("18 stored") and stored_item_detail.text.contains("17 available") and stored_item_detail.text.contains("1 borrowed"), "stored item quantities and loan availability use a dedicated detail line")
	_check(stored_item_description != null and not stored_item_description.text.is_empty(), "selected Item Storage assets show their localized description")
	var asset_search := items_storage_window.find_child("GuildItemsStorageSearchInput", true, false) as LineEdit
	if asset_search != null:
		asset_search.text = "left"
		asset_search.text_changed.emit(asset_search.text)
		await process_frame
	_check(
		items_storage_window.find_child("GuildItemsStorageSlot_leftovers", true, false) != null
		and items_storage_window.find_child("GuildItemsStorageSlot_choice-scarf", true, false) == null,
		"full Item Storage searches Guild assets live"
	)
	if asset_search != null:
		asset_search.text = "exp"
		asset_search.text_changed.emit(asset_search.text)
		await process_frame
	_check(
		items_storage_window.find_child("GuildItemsStorageSlot_leftovers", true, false) == null
		and items_storage_window.find_child("GuildItemsStorageGrid", true, false).get_child_count() == 1,
		"full Item Storage does not mix personal Bag results into Guild search"
	)
	if asset_search != null:
		asset_search.text = ""
		asset_search.text_changed.emit(asset_search.text)
		await process_frame
	var asset_filter := items_storage_window.find_child("GuildItemsStorageFilterSelect", true, false) as OptionButton
	if asset_filter != null:
		_check(asset_filter.get_item_text(2) == "Unavailable", "Item Storage names its unavailable filter clearly")
		asset_filter.select(2)
		asset_filter.item_selected.emit(2)
		await process_frame
	_check(
		items_storage_window.find_child("GuildItemsStorageSlot_leftovers", true, false) == null
		and items_storage_window.find_child("GuildItemsStorageSlot_choice-scarf", true, false) != null,
		"Item Storage unavailable filter shows stacks with no free copies"
	)
	var unavailable_withdraw := items_storage_window.find_child("GuildBankItemWithdrawButton_choice-scarf", true, false) as Button
	_check(
		unavailable_withdraw != null
		and unavailable_withdraw.disabled
		and unavailable_withdraw.tooltip_text.contains("No copies"),
		"Item Storage disables withdrawal when every copy is unavailable"
	)
	popup._set_guild_item_storage_status("items", "Item action failed", true)
	popup._refresh_guild_item_storage_window("items")
	var items_status := items_storage_window.find_child("GuildItemsStorageStatus", true, false) as Label
	_check(items_status != null and items_status.text == "Item action failed" and items_status.visible, "Item Storage keeps action feedback visible while refreshing")
	var items_close := items_storage_window.find_child("GuildItemsStorageCloseButton", true, false) as Button
	if items_close != null:
		items_close.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildItemsStorageWindow", true, false) == null, "closing full Item Storage returns to its donation overview")
	_check(popup.find_child("GuildBankItemsPreview", true, false) != null, "closing full Item Storage preserves its donation overview")
	bank_back = popup.find_child("GuildBankBackButton", true, false) as Button
	if bank_back != null:
		bank_back.pressed.emit()
		await process_frame
	resources_action = popup.find_child("GuildBankResourcesAction", true, false) as Button
	if resources_action != null:
		resources_action.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildBankResourcesPreview", true, false) != null, "Resources opens with a scalable donation overview")
	_check(popup.find_child("GuildBankResourceWithdrawButton_potion", true, false) == null, "Resources overview hides Guild withdrawal controls")
	_check(popup.find_child("GuildBankResourceDepositButton_poke-ball", true, false) != null, "Resources overview keeps direct Bag donations available")
	var resources_full_action := popup.find_child("GuildBankResourcesOpenFullButton", true, false) as Button
	if resources_full_action != null:
		resources_full_action.pressed.emit()
		await process_frame
	var resources_storage_window := popup.find_child("GuildResourcesStorageWindow", true, false) as Window
	var resources_storage_grid := popup.find_child("GuildResourcesStorageGrid", true, false) as GridContainer
	_check(resources_storage_window != null and resources_storage_window.visible, "Resources opens in a dedicated window")
	_check(resources_storage_grid != null and resources_storage_grid.columns == 5, "Resources presents a five-column asset grid")
	_check(resources_storage_window != null and resources_storage_window.find_child("GuildBankResourcesLogButton", true, false) != null, "Resources has a dedicated transaction log")
	_check(resources_storage_window != null and resources_storage_window.find_child("GuildBankResourceWithdrawButton_potion", true, false) != null, "selected Guild consumables can be taken")
	_check(resources_storage_window != null and resources_storage_window.find_child("GuildBankResourceDepositButton_poke-ball", true, false) == null, "full Resources focuses only on Guild supplies")
	_check(resources_storage_window != null and resources_storage_window.find_child("GuildBankItemBorrowButton_potion", true, false) == null, "Resources never expose borrowing")
	var resource_description := resources_storage_window.find_child("GuildResourcesStorageSelectedDescription", true, false) as Label
	_check(resource_description != null and not resource_description.text.is_empty(), "selected Resources show their localized item description")
	_check(resources_storage_window.find_child("GuildBankResourceWithdrawButton_potion", true, false).tooltip_text == "", "authorized Resources withdrawal is immediately available")
	var resources_close := resources_storage_window.find_child("GuildResourcesStorageCloseButton", true, false) as Button
	if resources_close != null:
		resources_close.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildResourcesStorageWindow", true, false) == null, "closing full Resources returns to its donation overview")
	_check(popup.find_child("GuildBankResourcesPreview", true, false) != null, "closing full Resources preserves its donation overview")
	bank_back = popup.find_child("GuildBankBackButton", true, false) as Button
	if bank_back != null:
		bank_back.pressed.emit()
		await process_frame
	funds_action = popup.find_child("GuildBankFundsAction", true, false) as Button
	if funds_action != null:
		funds_action.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildBankFundsWorkspace", true, false) != null, "shared funds render Guild and player balances")
	_check(popup.find_child("GuildBankFundsLogButton", true, false) != null, "Shared Funds has a dedicated log action")
	_check(popup.find_child("GuildBankMoneyDepositButton", true, false) != null, "Guild funds can be deposited")
	_check(popup.find_child("GuildBankMoneyWithdrawButton", true, false) != null, "Guild funds can be withdrawn")
	var money_amount := popup.find_child("GuildBankMoneyAmount", true, false) as SpinBox
	_check(
		money_amount != null
		and money_amount.min_value == 0.0
		and money_amount.value == 0.0
		and money_amount.step == 1.0
		and money_amount.update_on_text_changed,
		"Guild money starts at zero and accepts exact whole amounts without Enter"
	)
	var money_deposit := popup.find_child("GuildBankMoneyDepositButton", true, false) as Button
	if money_deposit != null:
		money_deposit.pressed.emit()
		await process_frame
	_check(
		popup.member_status_label != null
		and popup.member_status_label.text.contains("$1")
		and popup.find_child("GuildBankDonationConfirmationDialog", true, false) == null,
		"a zero money transfer shows minimum validation without opening confirmation"
	)
	if money_amount != null:
		var money_line_edit := money_amount.get_line_edit()
		money_line_edit.text = "150"
		money_line_edit.text_changed.emit(money_line_edit.text)
		await process_frame
		_check(int(money_amount.value) == 150, "Guild money keeps the exact typed amount")
	popup._render_guild_home_with_status("Visible bank feedback", true)
	await process_frame
	_check(
		popup.member_status_label != null and popup.member_status_label.text == "Visible bank feedback",
		"Guild Bank feedback remains visible after a workspace refresh"
	)
	var visible_status := popup.find_child("GuildMemberStatus", true, false) as Label
	var visible_workspace := popup.find_child("GuildBankWorkspace", true, false) as Control
	_check(
		visible_status != null
		and visible_workspace != null
		and visible_status.global_position.y < visible_workspace.global_position.y,
		"Guild Bank feedback renders above the active workspace"
	)
	_check(popup.find_child("GuildHeaderTravelActions", true, false) != null, "guild travel remains available while viewing the bank")
	overview_tab = popup.find_child("GuildOverviewTab", true, false) as Button
	if overview_tab != null:
		overview_tab.pressed.emit()
		await process_frame
	var members_tab := popup.find_child("GuildMembersTab", true, false) as Button
	if members_tab != null:
		members_tab.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildMembersSection", true, false) != null, "members tab opens the roster")
	var members_section := popup.find_child("GuildMembersSection", true, false) as Control
	var widest_member_card := popup.find_child("GuildMemberCard_2", true, false) as Control
	_check(
		members_section != null
		and widest_member_card != null
		and widest_member_card.get_global_rect().end.x <= members_section.get_global_rect().end.x + 1.0,
		"managed member roster cards stay inside the Members panel"
	)
	var leader_contribution := popup.find_child("GuildMemberContributionLabel_1", true, false) as Label
	_check(leader_contribution != null and leader_contribution.text == "124,350", "member roster shows contributed Guild EXP")
	var leader_status_column := popup.find_child("GuildMemberStatusColumn_1", true, false) as Control
	var member_status_column := popup.find_child("GuildMemberStatusColumn_2", true, false) as Control
	var leader_rank_column := popup.find_child("GuildMemberRankColumn_1", true, false) as Control
	var member_rank_column := popup.find_child("GuildMemberRankColumn_2", true, false) as Control
	var leader_exp_column := popup.find_child("GuildMemberContributionColumn_1", true, false) as Control
	var member_exp_column := popup.find_child("GuildMemberContributionColumn_2", true, false) as Control
	var leader_actions_column := popup.find_child("GuildMemberActionsButton_1", true, false) as Control
	var member_actions_column := popup.find_child("GuildMemberActionsButton_2", true, false) as Control
	_check(
		leader_status_column != null and member_status_column != null
		and is_equal_approx(leader_status_column.global_position.x, member_status_column.global_position.x)
		and leader_rank_column != null and member_rank_column != null
		and is_equal_approx(leader_rank_column.global_position.x, member_rank_column.global_position.x)
		and leader_exp_column != null and member_exp_column != null
		and is_equal_approx(leader_exp_column.global_position.x, member_exp_column.global_position.x)
		and leader_actions_column != null and member_actions_column != null
		and is_equal_approx(leader_actions_column.global_position.x, member_actions_column.global_position.x),
		"Leader and managed-member roster cards keep every information column aligned"
	)
	_check(
		leader_actions_column != null and (leader_actions_column as MenuButton).disabled
		and member_actions_column != null and not (member_actions_column as MenuButton).disabled,
		"the current Leader has no self-actions while managed members expose one action menu"
	)
	_check(popup.find_child("GuildHistoryLogButton", true, false) != null, "member roster has a dedicated Guild history action")
	var member_search := popup.find_child("GuildMemberSearchInput", true, false) as LineEdit
	_check(member_search != null, "member roster provides a search field")
	_check(
		popup.find_child("GuildMemberRosterToolbar", true, false) is VBoxContainer,
		"member search occupies its own roster row"
	)
	if member_search != null:
		member_search.text = "pecha"
		popup._filter_guild_member_cards(member_search.text)
		await process_frame
		var maple_card := popup.find_child("GuildMemberCard_2", true, false) as Control
		var pecha_card := popup.find_child("GuildMemberCard_3", true, false) as Control
		_check(maple_card != null and not maple_card.visible and pecha_card != null and pecha_card.visible, "member search filters current Guild members")
		member_search.text = ""
	var invite_action := popup.find_child("OpenGuildInviteDialogButton", true, false) as Button
	_check(
		invite_action != null
		and invite_action.text == "Invite a Player"
		and member_search != null
		and invite_action.global_position.y < member_search.global_position.y,
		"Invite a Player is a separate roster-header action"
	)
	if invite_action != null:
		invite_action.pressed.emit()
		await process_frame
	var invite_dialog := popup.find_child("GuildInviteDialog", true, false) as Window
	var invite_submit := popup.find_child("GuildInviteSubmitButton", true, false) as Button
	var invite_cancel := popup.find_child("GuildInviteCancelButton", true, false) as Button
	var invite_actions := invite_submit.get_parent() as BoxContainer if invite_submit != null else null
	_check(invite_dialog != null and invite_dialog.visible, "invite action opens a dedicated dialog")
	_check(
		invite_dialog != null and invite_dialog.has_theme_stylebox_override("embedded_border"),
		"Guild invite dialog uses the Guild window styling"
	)
	_check(
		invite_submit != null
		and invite_cancel != null
		and invite_submit.has_theme_stylebox_override("normal")
		and invite_cancel.has_theme_stylebox_override("normal"),
		"Guild invite dialog uses styled action buttons"
	)
	_check(
		invite_dialog != null
		and invite_dialog.size.y <= 220
		and invite_actions != null
		and invite_actions.alignment == BoxContainer.ALIGNMENT_END
		and invite_actions.get_theme_constant("separation") == 8,
		"Guild invite dialog keeps its form and actions compactly grouped"
	)
	_check(popup.find_child("GuildInviteUsername", true, false) != null, "invite dialog asks for a Trainer username")
	if invite_dialog != null:
		invite_dialog.queue_free()
		await process_frame
	popup._show_guild_log_window("guild", {
		"entries": [{
			"id": 1, "category": "guild", "action": "joined",
			"target": "Maple", "newRole": "captain", "createdAt": "2026-08-23T10:00:00Z",
		}],
		"nextBeforeId": 0,
	})
	await process_frame
	var history_window := popup.find_child("GuildHistoryLogWindow", true, false) as Window
	_check(history_window != null and history_window.visible, "Guild history opens in a separate window")
	_check(history_window != null and history_window.borderless, "Guild logs hide the unclear native title bar")
	_check(popup.find_child("GuildLogTitleBar", true, false) != null, "Guild logs render a dedicated visible title bar")
	var log_close := popup.find_child("GuildLogCloseButton", true, false) as Button
	_check(log_close != null and log_close.has_theme_stylebox_override("normal"), "Guild log close action is clearly styled")
	var log_search := popup.find_child("GuildLogSearchInput", true, false) as LineEdit
	var log_action_filter := popup.find_child("GuildLogActionFilter", true, false) as OptionButton
	var log_period_filter := popup.find_child("GuildLogPeriodFilter", true, false) as OptionButton
	var log_filter_fields := popup.find_child("GuildLogFilterFields", true, false) as HBoxContainer
	_check(popup.find_child("GuildLogSearchField", true, false) != null, "Guild log search has a visible field label")
	_check(popup.find_child("GuildLogActionField", true, false) != null, "Guild log action choice has a visible field label")
	_check(log_search != null, "Guild logs expose a search field")
	_check(log_action_filter != null and log_action_filter.item_count == 6, "Guild history exposes its relevant action filters")
	_check(log_period_filter != null and log_period_filter.item_count == 5, "Guild logs offer all-time and useful recent periods")
	_check(log_filter_fields != null and log_filter_fields.size.x <= history_window.size.x - 32, "Guild log filter fields fit inside the window")
	if log_period_filter != null:
		log_period_filter.select(2)
		_check(str(popup._selected_guild_log_period(log_period_filter)).ends_with("Z"), "Guild log periods produce a stable UTC boundary")
	_check(popup.find_child("GuildLogApplyFiltersButton", true, false) != null, "Guild logs can apply filters")
	_check(popup.find_child("GuildLogClearFiltersButton", true, false) != null, "Guild log filters can be cleared")
	_check(
		history_window != null and history_window.has_theme_stylebox_override("embedded_border"),
		"Guild history window uses the Guild window styling"
	)
	_check(popup.find_child("GuildLogEntries", true, false) != null, "Guild history renders its activity entries")
	var highlighted_log_message := popup.find_child("GuildLogMessage", true, false) as RichTextLabel
	_check(
		highlighted_log_message != null
		and highlighted_log_message.get_parsed_text().contains("Maple")
		and highlighted_log_message.get_meta("highlighted_player_names", []) == ["Maple"],
		"Guild history highlights the structured Trainer name"
	)
	var multi_player_message := popup._build_guild_log_message("guild", {
		"action": "rank_changed",
		"actor": "Admin",
		"target": "Maple",
		"previousRole": "recruit",
		"newRole": "member",
	})
	_check(
		multi_player_message.get_meta("highlighted_player_names", []) == ["Admin", "Maple"]
		and multi_player_message.get_parsed_text().contains("Admin")
		and multi_player_message.get_parsed_text().contains("Maple"),
		"Guild history highlights both actor and affected Trainer"
	)
	multi_player_message.free()
	if history_window != null:
		history_window.queue_free()
		await process_frame
	var managed_actions := popup.find_child("GuildMemberActionsButton_2", true, false) as MenuButton
	var offline_actions := popup.find_child("GuildMemberActionsButton_3", true, false) as MenuButton
	var self_actions := popup.find_child("GuildMemberActionsButton_1", true, false) as MenuButton
	_check(
		managed_actions != null
		and managed_actions.text.contains("Manage")
		and managed_actions.icon != null
		and managed_actions.custom_minimum_size.x >= 132,
		"managed Guild members expose a clearly labelled management action"
	)
	_check(
		managed_actions != null and managed_actions.get_popup().min_size.x >= 230,
		"Guild member actions open in a readable-width menu"
	)
	_check(
		managed_actions != null
		and managed_actions.get_popup().get_item_index(GuildPopup.GUILD_MEMBER_ACTION_CHANGE_RANK) >= 0,
		"leaders can change a member's rank from the action menu"
	)
	_check(
		managed_actions != null
		and managed_actions.get_popup().get_item_index(GuildPopup.GUILD_MEMBER_ACTION_BANK_RIGHTS) >= 0,
		"permission managers can edit Guild Bank rights from the action menu"
	)
	_check(
		managed_actions != null
		and managed_actions.get_popup().get_item_index(GuildPopup.GUILD_MEMBER_ACTION_KICK) >= 0
		and managed_actions.get_popup().get_item_icon(
			managed_actions.get_popup().get_item_index(GuildPopup.GUILD_MEMBER_ACTION_KICK)
		) != null,
		"Guild leaders can remove members from the action menu"
	)
	_check(
		popup.find_child("GuildMemberPermissionOverrideCount_2", true, false) != null,
		"member cards identify custom Guild Bank rights"
	)
	if managed_actions != null:
		managed_actions.get_popup().id_pressed.emit(GuildPopup.GUILD_MEMBER_ACTION_CHANGE_RANK)
		await process_frame
	var rank_dialog := popup.find_child("GuildMemberRankDialog_2", true, false) as ConfirmationDialog
	_check(rank_dialog != null and rank_dialog.visible, "Change rank opens from the member action menu")
	_check_dialog_styled(rank_dialog, "Guild member rank dialog")
	_check(popup.find_child("GuildMemberRankSelect_2", true, false) != null, "rank changes retain every assignable Guild rank")
	if rank_dialog != null:
		rank_dialog.canceled.emit()
		await process_frame
	if managed_actions != null:
		managed_actions.get_popup().id_pressed.emit(GuildPopup.GUILD_MEMBER_ACTION_BANK_RIGHTS)
		await process_frame
	var bank_permissions_dialog := popup.find_child("GuildMemberBankPermissionsDialog_2", true, false) as ConfirmationDialog
	_check(bank_permissions_dialog != null and bank_permissions_dialog.visible, "member Guild Bank rights open in a dedicated dialog")
	_check_dialog_styled(bank_permissions_dialog, "Guild Bank permissions dialog")
	var borrow_permission_select := popup.find_child("GuildBankPermissionSelect_bank_borrow", true, false) as OptionButton
	var resource_withdraw_select := popup.find_child("GuildBankPermissionSelect_resource_withdraw", true, false) as OptionButton
	_check(
		borrow_permission_select != null
		and str(borrow_permission_select.get_item_metadata(borrow_permission_select.selected)) == "deny",
		"the permissions dialog shows an existing personal denial"
	)
	_check(resource_withdraw_select != null, "leaders can block a member's Resources withdrawal access")
	if bank_permissions_dialog != null:
		bank_permissions_dialog.canceled.emit()
		await process_frame
	if managed_actions != null:
		managed_actions.get_popup().id_pressed.emit(GuildPopup.GUILD_MEMBER_ACTION_KICK)
		await process_frame
	var kick_dialog := popup.find_child("GuildMemberKickDialog_2", true, false) as ConfirmationDialog
	_check(kick_dialog != null and kick_dialog.visible, "removing a Guild member asks for confirmation")
	_check(kick_dialog != null and kick_dialog.dialog_text.contains("Maple"), "Guild removal confirmation identifies the selected Trainer")
	_check_dialog_styled(kick_dialog, "Guild member removal dialog")
	if kick_dialog != null:
		kick_dialog.canceled.emit()
		await process_frame
	var captain_member_actions := popup._build_guild_member_actions_button(
		{"userId": 2, "role": "member", "online": true}, "captain", 1, false
	)
	_check(
		captain_member_actions.get_popup().get_item_index(GuildPopup.GUILD_MEMBER_ACTION_KICK) >= 0,
		"Guild Captains can remove Members and Recruits"
	)
	var captain_peer_actions := popup._build_guild_member_actions_button(
		{"userId": 2, "role": "captain", "online": true}, "captain", 1, false
	)
	_check(
		captain_peer_actions.get_popup().get_item_index(GuildPopup.GUILD_MEMBER_ACTION_KICK) < 0,
		"Guild Captains cannot remove another Captain"
	)
	captain_member_actions.free()
	captain_peer_actions.free()
	_check(popup.find_child("GuildMemberCard_1", true, false) != null, "member roster uses distinct player cards")
	var online_presence := popup.find_child("GuildMemberPresenceLabel_2", true, false) as Label
	var offline_presence := popup.find_child("GuildMemberPresenceLabel_3", true, false) as Label
	_check(online_presence != null and online_presence.text == "Online", "online Guild members are clearly marked")
	_check(offline_presence != null and offline_presence.text.contains("Last online"), "offline Guild members show their last activity")
	_check(self_actions != null and self_actions.disabled, "the current player has no action menu for themselves")
	var online_pm_index := managed_actions.get_popup().get_item_index(GuildPopup.GUILD_MEMBER_ACTION_PM) if managed_actions != null else -1
	var offline_pm_index := offline_actions.get_popup().get_item_index(GuildPopup.GUILD_MEMBER_ACTION_PM) if offline_actions != null else -1
	_check(
		online_pm_index >= 0 and not managed_actions.get_popup().is_item_disabled(online_pm_index),
		"online Guild members expose PM in their action menu"
	)
	_check(
		offline_pm_index >= 0 and offline_actions.get_popup().is_item_disabled(offline_pm_index),
		"offline Guild members keep PM visibly unavailable"
	)
	_check(
		offline_pm_index >= 0 and offline_actions.get_popup().get_item_tooltip(offline_pm_index).contains("Mail"),
		"offline Guild PM explains that Mail handles offline messages"
	)
	if managed_actions != null:
		popup.private_message_requested.connect(_on_private_message_requested, CONNECT_ONE_SHOT)
		managed_actions.get_popup().id_pressed.emit(GuildPopup.GUILD_MEMBER_ACTION_PM)
	_check(
		int(private_message_user.get("userId", 0)) == 2
		and str(private_message_user.get("username", "")) == "maple",
		"Guild member PM action identifies the selected trainer"
	)
	var management_tab := popup.find_child("GuildManagementTab", true, false) as Button
	_check(popup.find_child("GuildApplicationsTab", true, false) == null, "applications no longer occupy the primary Guild navigation")
	_check(popup.find_child("GuildManagementNotificationBadge", true, false) != null, "Management shows pending application notifications")
	var application_badge_count := popup.find_child("GuildApplicationsNotificationCount", true, false) as Label
	_check(application_badge_count != null and application_badge_count.text == "1", "application notification shows the pending count")
	if management_tab != null:
		management_tab.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildManagementNavigation", true, false) != null, "Management opens an organized secondary navigation")
	_check(popup.find_child("GuildManagementProfileTab", true, false) != null, "leaders receive a Guild Profile management page")
	_check(popup.find_child("GuildManagementRecruitmentTab", true, false) != null, "leaders receive a Recruitment management page")
	var applications_tab := popup.find_child("GuildManagementApplicationsTab", true, false) as Button
	_check(applications_tab != null, "Guild staff receive an Applications management page")
	_check(popup.find_child("GuildManagementBankTab", true, false) != null, "leaders receive a Bank Settings management page")
	_check(popup.find_child("GuildApplicationsNotificationBadge", true, false) != null, "the Applications management page repeats its pending badge")
	if applications_tab != null:
		applications_tab.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildApplicationsSection", true, false) != null, "applications open in their own workspace")
	_check(popup.find_child("GuildApplicationsInbox", true, false) != null, "Guild applications use a distinct inbox")
	var application_count := popup.find_child("GuildApplicationsPendingCount", true, false) as Label
	_check(application_count != null and application_count.text.contains("1"), "Guild application inbox shows its pending count")
	_check(popup.find_child("GuildApplicationRow_8", true, false) != null, "pending Guild application renders for staff")
	var trainer_card_button := popup.find_child("ViewGuildApplicantTrainerCardButton_8", true, false) as Button
	_check(trainer_card_button != null and not trainer_card_button.disabled, "each applicant exposes a Trainer Card action")
	if trainer_card_button != null:
		popup.trainer_card_requested.connect(_on_trainer_card_requested, CONNECT_ONE_SHOT)
		trainer_card_button.pressed.emit()
	_check(
		int(trainer_card_user.get("userId", 0)) == 4
		and str(trainer_card_user.get("username", "")) == "red",
		"applicant Trainer Card action identifies the selected Trainer"
	)
	_check(popup.find_child("AcceptGuildApplicationButton_8", true, false) != null, "staff can accept a Guild application")
	_check(popup.find_child("DeclineGuildApplicationButton_8", true, false) != null, "staff can decline a Guild application")
	var profile_tab := popup.find_child("GuildManagementProfileTab", true, false) as Button
	if profile_tab != null:
		profile_tab.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildManagementSection", true, false) != null, "management tab opens guild controls")
	_check(popup.find_child("GuildManagementProfilePage", true, false) != null, "Guild Profile settings stay on their own page")
	_check(popup.find_child("GuildSettingsDescription", true, false) != null, "leader settings render")
	_check(popup.find_child("GuildSettingsAnnouncement", true, false) != null, "leaders can edit the Guild announcement")
	_check(popup.find_child("GuildApplicationsInbox", true, false) == null, "applications do not crowd Guild Profile settings")
	var recruitment_tab := popup.find_child("GuildManagementRecruitmentTab", true, false) as Button
	if recruitment_tab != null:
		recruitment_tab.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildManagementRecruitmentPage", true, false) != null, "Recruitment settings stay on their own page")
	_check(popup.find_child("GuildSettingsRequirements", true, false) != null, "leaders can manage a dynamic requirement list")
	_check(popup.find_child("GuildSettingsRequirement_0", true, false) != null, "saved requirements remain editable")
	var add_requirement := popup.find_child("GuildAddRequirementButton", true, false) as Button
	_check(add_requirement != null, "leaders can add individual requirements")
	if add_requirement != null:
		add_requirement.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildSettingsRequirement_3", true, false) != null, "adding a requirement creates a new editable row")
	var requirement_type := popup.find_child("GuildRequirementType_3", true, false) as OptionButton
	_check(requirement_type != null and requirement_type.item_count == 4, "leaders choose the type of each requirement")
	_check(not bool(popup._validated_settings_requirements().get("success", true)), "incomplete requirements cannot be saved accidentally")
	var requirement_value := popup.find_child("GuildRequirementValue_3", true, false) as LineEdit
	if requirement_value != null:
		requirement_value.text = "Welcome newer Trainers"
		requirement_value.text_changed.emit(requirement_value.text)
	_check(bool(popup._validated_settings_requirements().get("success", false)), "complete dynamic requirements validate before saving")
	popup._on_move_guild_requirement(3, -1)
	_check(str(popup.settings_requirements[2].get("value", "")) == "Welcome newer Trainers", "leaders can reorder requirements")
	popup._on_remove_guild_requirement(2)
	_check(popup.settings_requirements.size() == 3, "leaders can remove requirements")
	var bank_settings_tab := popup.find_child("GuildManagementBankTab", true, false) as Button
	if bank_settings_tab != null:
		bank_settings_tab.pressed.emit()
		await process_frame
	_check(popup.find_child("GuildManagementBankPage", true, false) != null, "Guild Bank rules stay on their own management page")
	_check(popup.find_child("GuildSaveBankSettingsButton", true, false) != null, "Bank Settings expose an independent save action")
	var loan_duration_select := popup.find_child("GuildLoanDurationSelect", true, false) as OptionButton
	_check(
		loan_duration_select != null
		and int(loan_duration_select.get_item_metadata(loan_duration_select.selected)) == 3600,
		"Guild Bank settings default loans to one hour"
	)
	_check(popup.find_child("GuildMemberSearchInput", true, false) == null, "member roster tools do not live under management")
	_check(popup.find_child("GuildEmblemPreview", true, false) == null, "management keeps emblem controls out of settings")
	_check(popup.find_child("EditGuildEmblemButton", true, false) == null, "leader does not see a redundant Guild emblem edit button")
	var edit_emblem_icon_button := popup.find_child("EditGuildEmblemIconButton", true, false) as Button
	_check(edit_emblem_icon_button != null, "leader can edit the Guild emblem by clicking it")
	if edit_emblem_icon_button != null:
		edit_emblem_icon_button.pressed.emit()
		await process_frame
	var emblem_popup := popup.find_child("GuildEmblemEditorPopup", true, false) as PopupPanel
	_check(emblem_popup != null and emblem_popup.visible, "emblem editor opens in a dedicated popup")
	_check(
		emblem_popup != null and emblem_popup.has_theme_stylebox_override("panel"),
		"Guild emblem editor uses the Guild popup styling"
	)
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
	var member_minimum_size := popup.get_combined_minimum_size()
	_check(
		member_minimum_size.x <= GuildPopup.POPUP_SIZE.x and member_minimum_size.y <= GuildPopup.POPUP_SIZE.y,
		"member dashboard fits inside its popup"
	)
	popup.guild_home["pendingApplications"] = []
	popup._show_guild_section("management")
	popup._show_management_section("applications")
	await process_frame
	_check(popup.find_child("GuildApplicationsEmptyState", true, false) != null, "empty Guild application inbox remains clearly visible")
	application_count = popup.find_child("GuildApplicationsPendingCount", true, false) as Label
	_check(application_count != null and application_count.text.contains("0"), "empty Guild application inbox shows zero waiting")
	popup.guild_home["membership"] = {
		"userId": 1,
		"guildId": 1,
		"role": "captain",
		"permissions": ["manage_members"],
	}
	popup.membership = popup.guild_home["membership"]
	popup.active_guild_section = "management"
	popup.active_management_section = "profile"
	popup._render_guild_home()
	await process_frame
	_check(popup.find_child("GuildManagementTab", true, false) != null, "application reviewers can open Management")
	_check(popup.find_child("GuildManagementApplicationsTab", true, false) != null, "application reviewers receive the Applications page")
	_check(popup.find_child("GuildManagementProfileTab", true, false) == null, "captains without Guild settings permission cannot edit the profile")
	_check(popup.find_child("GuildManagementRecruitmentTab", true, false) == null, "captains without Guild settings permission cannot edit recruitment")
	_check(popup.find_child("GuildManagementBankTab", true, false) == null, "captains without Guild settings permission cannot edit Bank settings")
	_check(popup.find_child("GuildApplicationsSection", true, false) != null, "application-only Management defaults to its authorized page")
	popup.guild_home["membership"] = {
		"guildId": 1,
		"role": "member",
		"permissions": ["resource_deposit", "resource_withdraw"],
		"bankPermissionOverrides": {"bank_borrow": "deny"},
	}
	popup.membership = popup.guild_home["membership"]
	popup._render_guild_home()
	await process_frame
	_check(popup.find_child("GuildManagementTab", true, false) == null, "regular members do not see management")
	_check(popup.find_child("GuildManagementApplicationsTab", true, false) == null, "regular members do not see the staff applications inbox")
	popup._show_guild_section("members")
	await process_frame
	var regular_member_actions := popup.find_child("GuildMemberActionsButton_2", true, false) as MenuButton
	_check(
		regular_member_actions != null
		and regular_member_actions.get_popup().get_item_index(GuildPopup.GUILD_MEMBER_ACTION_CHANGE_RANK) < 0,
		"regular members cannot assign Guild ranks"
	)
	_check(
		regular_member_actions != null
		and regular_member_actions.get_popup().get_item_index(GuildPopup.GUILD_MEMBER_ACTION_BANK_RIGHTS) < 0,
		"regular members cannot edit Guild Bank rights"
	)
	_check(
		regular_member_actions != null
		and regular_member_actions.get_popup().get_item_index(GuildPopup.GUILD_MEMBER_ACTION_KICK) < 0,
		"regular members cannot remove Guild members"
	)
	_check(
		popup._guild_bank_borrow_tooltip().contains("personally disabled"),
		"personal Guild Bank denials explain that they are not rank restrictions"
	)
	_check(popup.find_child("EditGuildEmblemButton", true, false) == null, "regular members cannot edit the Guild emblem")
	_check(popup.find_child("EditGuildEmblemIconButton", true, false) == null, "regular members cannot edit the Guild emblem icon")
	popup._show_guild_section("overview")
	await process_frame
	_check(popup.find_child("GuildOverviewSection", true, false) != null, "regular members return to the overview")
	popup.guild_bank_state["access"]["canWithdrawResources"] = false
	popup.guild_bank_state["access"]["bankPermissionOverrides"] = {"resource_withdraw": "deny"}
	popup._show_guild_section("bank")
	await process_frame
	_check(
		popup.find_child("GuildBankRankRightsButton", true, false) != null,
		"regular members can also review the default rank-rights page"
	)
	var blocked_resources_action := popup.find_child("GuildBankResourcesAction", true, false) as Button
	if blocked_resources_action != null:
		blocked_resources_action.pressed.emit()
		await process_frame
	var blocked_resources_full := popup.find_child("GuildBankResourcesOpenFullButton", true, false) as Button
	if blocked_resources_full != null:
		blocked_resources_full.pressed.emit()
		await process_frame
	var blocked_resource_withdraw := popup.find_child("GuildBankResourceWithdrawButton_potion", true, false) as Button
	_check(
		blocked_resource_withdraw != null
		and blocked_resource_withdraw.disabled
		and blocked_resource_withdraw.tooltip_text.contains("personally disabled"),
		"a leader's personal block disables Resources withdrawal with an explanation"
	)
	popup._show_guild_section("overview")
	await process_frame
	var member_options := popup.find_child("GuildOptionsMenuButton", true, false) as MenuButton
	_check(member_options != null and not member_options.get_popup().is_item_disabled(0), "regular members can leave through Guild options")
	_check(
		member_options != null and member_options.get_popup().has_theme_stylebox_override("panel"),
		"Guild options menu uses the Guild dropdown styling"
	)
	if member_options != null:
		member_options.get_popup().id_pressed.emit(1)
		await process_frame
	var leave_dialog := popup.find_child("GuildLeaveConfirmationDialog", true, false) as ConfirmationDialog
	_check(leave_dialog != null and leave_dialog.visible, "leaving a Guild asks for confirmation")
	_check_dialog_styled(leave_dialog, "leave Guild confirmation")
	if leave_dialog != null:
		leave_dialog.canceled.emit()
		await process_frame

	popup.close()
	await process_frame
	_check(not popup.visible, "guild popup closes cleanly")
	popup._show_page("browse")
	popup.open()
	await process_frame
	_check(popup.active_page == "member", "returning guild members land on My Guild")
	popup._on_primary_navigation_pressed("browse")
	_check(popup.active_page == "browse", "guild members can still browse guilds explicitly")
	_check(section_navigation != null and section_navigation.visible, "member section tabs remain available while browsing Guilds")
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


func _on_private_message_requested(user: Dictionary) -> void:
	private_message_user = user.duplicate(true)


func _on_trainer_card_requested(user: Dictionary) -> void:
	trainer_card_user = user.duplicate(true)


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


func _check_dialog_styled(dialog: ConfirmationDialog, label: String) -> void:
	_check(
		dialog != null and dialog.has_theme_stylebox_override("embedded_border"),
		"%s uses the Guild window styling" % label
	)
	_check(
		dialog != null
		and dialog.get_ok_button().has_theme_stylebox_override("normal")
		and dialog.get_cancel_button().has_theme_stylebox_override("normal"),
		"%s uses styled action buttons" % label
	)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
