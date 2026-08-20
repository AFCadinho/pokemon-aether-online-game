extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"
const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"
const PARTY_SLOT_SCENE_PATH := "res://scenes/interface/party_slot.tscn"
const PARTY_SLOT_SCRIPT_PATH := "res://scripts/ui/party_slot.gd"
const HOTKEY_SIDEBAR_SCENE_PATH := "res://scenes/interface/hotkey_sidebar.tscn"
const PLAYER_STATUS_SCENE_PATH := "res://scenes/interface/player_status_card.tscn"
const DONATOR_STORE_SCENE_PATH := "res://scenes/interface/donator_store_popup.tscn"
const DONATOR_STORE_SCRIPT_PATH := "res://scripts/ui/donator_store_popup.gd"
const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"
const SETTINGS_MANAGER_PATH := "res://scripts/services/settings_manager.gd"

var failed := false


func _init() -> void:
	var scene_source := FileAccess.get_file_as_string(OVERLAY_SCENE_PATH)
	var script_source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)
	var party_slot_scene_source := FileAccess.get_file_as_string(PARTY_SLOT_SCENE_PATH)
	var party_slot_script_source := FileAccess.get_file_as_string(PARTY_SLOT_SCRIPT_PATH)
	var party_separator_block := _node_block(party_slot_scene_source, '[node name="Seperator"')
	var hotkey_sidebar_scene_source := FileAccess.get_file_as_string(HOTKEY_SIDEBAR_SCENE_PATH)
	var player_status_scene_source := FileAccess.get_file_as_string(PLAYER_STATUS_SCENE_PATH)
	var donator_store_scene_source := FileAccess.get_file_as_string(DONATOR_STORE_SCENE_PATH)
	var donator_store_script_source := FileAccess.get_file_as_string(DONATOR_STORE_SCRIPT_PATH)
	var battle_source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var settings_source := FileAccess.get_file_as_string(SETTINGS_MANAGER_PATH)
	var hotbar_block := _node_block(scene_source, '[node name="HotkeySidebar"')
	var player_status_block := _node_block(scene_source, '[node name="PlayerStatusPanel"')
	var party_block := _node_block(scene_source, '[node name="PartyPanel"')
	var dex_actions_block := _node_block(scene_source, '[node name="DexActionsPanel"')
	var staff_actions_block := _node_block(scene_source, '[node name="StaffActionsPanel"')
	var my_powers_button_block := _node_block(scene_source, '[node name="MyPowersButton"')
	var party_margin_block := _node_block(scene_source, '[node name="MarginContainer" type="MarginContainer" parent="Control/PartyPanel"')
	var party_container_block := _node_block(scene_source, '[node name="VBoxContainer" type="VBoxContainer" parent="Control/PartyPanel/MarginContainer"')
	var chat_block := _node_block(scene_source, '[node name="ChatPanel"')
	var chat_tabs_block := _node_block(scene_source, '[node name="ChatTabsPanel"')
	var global_buffs_block := _node_block(scene_source, '[node name="GlobalBuffsPanel"')
	var global_buff_details_block := _node_block(scene_source, '[node name="GlobalBuffDetailsPanel"')
	var personal_buffs_block := _node_block(scene_source, '[node name="PersonalBuffsPanel"')
	var store_block := _node_block(scene_source, '[node name="DonatorStoreButton"')
	var settings_block := _node_block(scene_source, '[node name="SettingsButton" type="Button" parent="Control"]')
	var mount_button_block := _node_block(scene_source, '[node name="MountButton" type="Button" parent="Control"]')
	var quest_slot_block := _node_block(scene_source, '[node name="QuestSlot"')
	var quest_button_block := _node_block(scene_source, '[node name="QuestButton"')
	var socials_menu_block := _node_block(scene_source, '[node name="SocialsMenu"')
	var disable_icon_focus_block := _function_block(script_source, "func _disable_icon_button_focus()")

	_check(hotbar_block.contains("anchors_preset = 6"), "hotbar is anchored to the right")
	_check(hotbar_block.contains("offset_right = 0.0"), "hotbar hugs the right screen edge")
	_check(
		hotbar_block.contains("offset_left = -60.0")
		and hotbar_block.contains("offset_top = -245.0")
		and hotbar_block.contains("offset_bottom = -26.0"),
		"paginated hotbar starts from a narrow right-edge position"
	)
	_check(
		hotkey_sidebar_scene_source.contains('[node name="SlotStack" type="GridContainer" parent="MarginContainer/Layout"')
		and hotkey_sidebar_scene_source.contains("columns = 1")
		and hotkey_sidebar_scene_source.contains("custom_minimum_size = Vector2(58, 219)")
		and hotkey_sidebar_scene_source.contains('[node name="PageControls" type="HBoxContainer"'),
		"hotbar presents four shortcuts at a time in a narrow paginated column"
	)
	_check(
		script_source.contains('get_node_or_null("MarginContainer/Layout/SlotStack") as GridContainer')
		and script_source.contains("func _set_hotbar_page(page_index: int)")
		and script_source.contains("quest_journal_view.get_visible_tracker_bottom()")
		and script_source.contains("var hotbar_top_offset: float = maxf(HOTBAR_GRID_BASE_TOP_OFFSET, tracker_bottom_offset)")
		and script_source.contains("root_control.resized.connect(_refresh_quest_tracker_layout)")
		and script_source.contains('_position_collapsible_button("hotkey_sidebar")'),
		"quest and viewport updates place the compact hotbar below visible quest cards"
	)
	_check(party_block.contains("anchors_preset = 0"), "normal party is anchored to the left")
	_check(party_block.contains("offset_left = 0.0"), "normal party hugs the left screen edge")
	_check(party_block.contains("offset_top = 76.0") and party_block.contains("offset_bottom = 158.0"), "normal party moves up intact below the single primary left navigation rail")
	_check(
		dex_actions_block.contains("anchors_preset = 1")
		and dex_actions_block.contains("anchor_left = 1.0")
		and dex_actions_block.contains("offset_left = -264.0")
		and dex_actions_block.contains("offset_top = 76.0"),
		"Town Map and Dex shortcuts occupy the freed secondary right navigation rail"
	)
	_check(
		staff_actions_block.contains("visible = false")
		and staff_actions_block.contains("anchors_preset = 3")
		and staff_actions_block.contains("offset_right = -64.0"),
		"account-specific tool icons start hidden in a bottom-right flyout"
	)
	_check(
		my_powers_button_block.contains("anchors_preset = 3")
		and my_powers_button_block.contains('tooltip_text = "ui.navigation.my_powers"')
		and my_powers_button_block.contains('icon = ExtResource("32_my_powers")')
		and scene_source.contains('path="res://assets/ui/my_powers.svg" id="32_my_powers"'),
		"one account-bound My Powers button opens privileged tools beside the trainer card"
	)
	_check(party_margin_block.contains("margin_top = 7") and party_container_block.contains("separation = 5"), "normal party rail uses compact spacing")
	_check(script_source.contains("func _make_party_panel_style()"), "normal party uses a dedicated lighter glass rail")
	_check(party_slot_scene_source.contains("custom_minimum_size = Vector2(260, 68)"), "normal party slots use a compact readable height")
	_check(party_separator_block.contains("custom_minimum_size = Vector2(2, 0)") and not party_separator_block.contains("size_flags_horizontal"), "party names receive the available header width")
	_check(party_slot_scene_source.contains('[node name="LeadAccent" type="Panel" parent="ClickButton"]'), "lead Pokémon accent avoids PanelContainer stretching")
	_check(party_slot_scene_source.contains("custom_minimum_size = Vector2(160, 16)"), "party HP bars use a slimmer profile")
	_check(party_slot_scene_source.contains('text = "✦"') and not party_slot_scene_source.contains('StyleBoxFlat_shiny_badge'), "Shiny state uses a clean unboxed sparkle")
	_check(party_slot_scene_source.contains('[node name="ShinyAccent" type="Panel" parent="ClickButton"]'), "Shiny party slots use a dedicated edge accent")
	_check(party_slot_script_source.contains("SHINY_SLOT_BORDER") and party_slot_script_source.contains("SHINY_SLOT_HOVER_BORDER"), "Shiny party slots retain a distinct cool-toned surface state")
	_check(party_slot_script_source.contains("shiny_accent.visible = current_is_shiny and visible"), "Shiny edge accents follow slot visibility")
	_check(party_slot_script_source.contains("func _update_health_bar_style()"), "party HP bars adapt their color to remaining health")
	_check(party_slot_script_source.contains("func set_dragging(value: bool)") and party_slot_script_source.contains("func set_drop_target(value: bool)"), "party slots distinguish dragging and drop targets")
	_check(script_source.contains("_set_party_drag_drop_target(_get_party_slot_index_at_position"), "party dragging previews the destination slot")
	_check(not player_status_block.contains("anchors_preset = 2"), "mini trainer card keeps its inherited bottom-right layout")
	_check(chat_block.contains("anchors_preset = 2"), "chat is anchored bottom-left")
	_check(chat_tabs_block.contains("anchors_preset = 2"), "chat tabs follow the left-side chat")
	_check(global_buffs_block.contains("anchors_preset = 5"), "global buffs sit beside the top-center location card")
	_check(global_buffs_block.contains("offset_left = 214.0"), "global buffs clear the location collapse button")
	_check(global_buffs_block.contains("custom_minimum_size = Vector2(242, 50)"), "global buffs use a compact five-icon tray")
	_check(personal_buffs_block.contains("anchors_preset = 3"), "personal buffs sit above the bottom-right trainer card")
	_check(personal_buffs_block.contains("offset_bottom = -104.0"), "personal buffs leave space above the trainer card")
	_check(personal_buffs_block.contains("custom_minimum_size = Vector2(188, 98)"), "personal buffs have room for readable detail cards")
	_check(store_block.contains("anchors_preset = 3"), "Donator Store is anchored near the trainer card")
	_check(store_block.contains('icon = ExtResource("22_donator_gem")'), "Donator Store uses the purple gem icon")
	_check(store_block.contains("custom_minimum_size = Vector2(42, 42)") and store_block.contains("icon_max_width = 26"), "Donator Store aligns with the personal status rail")
	_check(settings_block.contains("custom_minimum_size = Vector2(42, 42)") and settings_block.contains("offset_bottom = -152.0"), "Settings forms a matching utility button above the Donator Store")
	_check(settings_block.contains('icon = ExtResource("7_settings_icon")'), "relocated Settings keeps its familiar gear icon")
	_check(
		mount_button_block.contains("custom_minimum_size = Vector2(42, 42)")
		and mount_button_block.contains("offset_top = -242.0")
		and mount_button_block.contains('tooltip_text = "ui.mounts.title"')
		and mount_button_block.contains('icon = ExtResource("33_mounts")')
		and scene_source.contains('path="res://assets/ui/mount_management.svg" id="33_mounts"'),
		"Mount management joins the bottom-right character utility rail"
	)
	_check(
		my_powers_button_block.contains("offset_top = -338.0"),
		"My Powers moves up one slot to keep the character utility rail evenly spaced"
	)
	_check(quest_slot_block.contains("custom_minimum_size = Vector2(52, 52)") and quest_button_block.contains('texture_normal = ExtResource("27_quest_log")'), "Quest Log replaces Settings in the primary navigation bar")
	_check(scene_source.contains('path="res://assets/ui/pvp_battles.svg" id="18_pvp"'), "PvP uses a dedicated versus icon instead of a generic Poke Ball")
	_check(script_source.contains('pvp_mode_menu.custom_minimum_size = Vector2(390, 0)') and script_source.contains('"ui.pvp.title"'), "PvP opens a deliberate battle-mode launcher")
	_check(script_source.contains('"ui.pvp.mode.competitive"') and script_source.contains('"ui.pvp.mode.private"'), "PvP mode cards explain Ranked and Custom battles")
	_check(script_source.contains('pvp_mode_tournaments_button.disabled = true') and script_source.contains('"ui.pvp.mode.coming_soon"'), "unavailable Tournaments are clearly disabled")
	_check(script_source.contains('pvp_mode_close_button.text = "×"') and not script_source.contains('_create_pvp_mode_menu_button("Close")'), "PvP launcher uses a compact header close action")
	_check(socials_menu_block.contains("custom_minimum_size = Vector2(390, 0)"), "Social opens as a readable launcher instead of a narrow button list")
	_check(scene_source.contains('text = "ui.social.subtitle"'), "Social launcher explains its purpose with a localization key")
	_check(
		script_source.contains('"ui.social.friends"')
		and script_source.contains('"ui.social.nearby"')
		and script_source.contains('"ui.social.mail"'),
		"Social launcher keeps all existing destinations"
	)
	_check(script_source.contains('const SOCIALS_NEARBY_ICON: Texture2D = preload("res://assets/ui/socials_nearby.svg")'), "Nearby Trainers uses a dedicated location icon")
	_check(script_source.contains('const SOCIALS_MAIL_ICON: Texture2D = preload("res://assets/ui/socials_mail.svg")'), "Mail uses a dedicated envelope icon")
	_check(script_source.contains('$Control/SocialsMenu/MarginContainer/VBoxContainer/Header/CloseButton'), "Social launcher uses a compact header close action")
	_check(script_source.contains('content.name = "LauncherCardContent"') and script_source.contains("func _configure_launcher_card_button("), "PvP and Social launchers share one card language")
	_check(script_source.contains("socials_friend_list_attention_badge = _create_socials_menu_attention_badge(socials_friend_list_button)"), "friend requests remain visible on the refreshed launcher")
	_check(script_source.contains("socials_mail_attention_badge = _create_socials_menu_attention_badge(socials_mail_button)"), "unread mail remains visible on the refreshed launcher")
	_check(script_source.contains('dev_actions_popup.custom_minimum_size = Vector2(420, 0)') and script_source.contains('"ui.staff.dev.title"'), "Developer Tools uses a structured launcher surface")
	_check(script_source.contains('"DeveloperQuickActions"') and script_source.contains('"ui.staff.dev.world_preview"'), "Developer actions and world preview have separate visual groups")
	_check(script_source.contains('"ui.staff.dev.create_pokemon"') and script_source.contains('"ui.staff.dev.start_encounter"') and script_source.contains('"ui.staff.dev.resources"'), "Developer quick actions use clear task-oriented labels")
	_check(script_source.contains('"ui.staff.dev.heal_party"') and script_source.contains('"ui.staff.dev.trainer_progress"') and script_source.contains('"ui.staff.dev.clear_data"'), "Developer utility and destructive actions remain available")
	_check(not script_source.contains("dev_preview_evolution_button") and not script_source.contains("dev_pickpocket_pose_button"), "Developer Tools omits temporary animation preview actions")
	_check(script_source.contains('staff_tools_popup.custom_minimum_size = Vector2(390, 0)') and script_source.contains('"ui.staff.tools.subtitle"'), "Staff Tools uses the shared compact launcher")
	_check(script_source.contains('"ui.staff.teleport.action_description"') and script_source.contains('"ui.staff.impersonate.action_description"'), "Staff actions explain Teleport and Impersonate")
	_check(script_source.contains('"ui.staff.chat.action_description"') and script_source.contains("CHAT_MODERATION_CENTER_SCRIPT.new()"), "Staff Tools opens the compact chat moderation center")
	_check(script_source.contains('alpha_tools_popup.custom_minimum_size = Vector2(390, 0)') and script_source.contains('"ui.staff.alpha.subtitle"'), "Alpha Tools uses the shared compact launcher")
	_check(script_source.contains('"ui.staff.alpha.create_description"') and script_source.contains('"ui.staff.alpha.clear_description"'), "Alpha Tools actions explain their scope")
	_check(scene_source.contains('path="res://assets/ui/alpha_tools.svg" id="15_content_creator"') and script_source.contains('preload("res://assets/ui/alpha_tools.svg")'), "Alpha Tools uses its dedicated validated Alpha icon")
	_check(script_source.contains('content_creator_tools_popup.custom_minimum_size = Vector2(390, 0)') and script_source.contains('"ui.staff.creator.subtitle"'), "Content Creator Tools uses a separate compact launcher")
	_check(scene_source.contains('path="res://assets/ui/content_creator.svg"') and script_source.contains('preload("res://assets/ui/content_creator.svg")'), "Content Creator Tools uses its dedicated creator icon")
	_check(script_source.contains('const TOOL_CLEAR_DATA_ICON: Texture2D = preload("res://assets/ui/tool_clear_data.svg")') and script_source.contains('const STAFF_IMPERSONATE_ICON: Texture2D = preload("res://assets/ui/staff_impersonate.svg")'), "internal tool launchers use dedicated action icons")
	_check(script_source.contains('_position_action_slot_popup(dev_actions_popup, dev_actions_slot)') and script_source.contains('_position_action_slot_popup(staff_tools_popup, staff_tools_slot)'), "internal tool menus open beside their toolbar actions")
	_check(script_source.contains('{"panel": alpha_tools_popup, "close": Callable(self, "_hide_alpha_tools_popup")}'), "Escape closes the Alpha Tools launcher")
	_check(script_source.contains('{"panel": content_creator_tools_popup, "close": Callable(self, "_hide_content_creator_tools_popup")}'), "Escape closes the Content Creator Tools launcher")
	_check(
		script_source.contains(
			"alpha_create_pokemon_button.visible = can_use_content_creator_generation"
		)
		and script_source.contains(
			"staff_impersonate_button.visible = can_return_from_impersonation or can_impersonate"
		),
		"launcher actions use permission or active-session visibility as appropriate"
	)
	_check(
		disable_icon_focus_block.contains("socials_button")
		and disable_icon_focus_block.contains("pvp_button")
		and disable_icon_focus_block.contains("content_creator_tools_button")
		and disable_icon_focus_block.contains("staff_tools_button")
		and disable_icon_focus_block.contains("dev_actions_button")
		and disable_icon_focus_block.contains("item_dex_button")
		and disable_icon_focus_block.contains("pokedex_button")
		and disable_icon_focus_block.contains("button.focus_mode = Control.FOCUS_NONE"),
		"toolbar menu buttons cannot retain Space-triggerable keyboard focus"
	)
	_check(scene_source.contains('path="res://assets/ui/clan.svg" id="16_guild"') and scene_source.contains('tooltip_text = "ui.navigation.guilds"'), "Guilds use a three-member group crest with a localized tooltip")
	_check(scene_source.contains('path="res://assets/ui/follower_toggle.svg" id="10_follower"'), "Follower toggle shows a trainer and companion")
	_check(scene_source.contains('path="res://assets/ui/running_shoes_toggle.svg" id="11_running_shoe"'), "Running Shoes use a dedicated speed-toggle icon")
	_check(scene_source.contains('path="res://assets/ui/town_map_navigation.svg" id="3_riyyd"'), "Town Map uses a navigation-focused map icon")
	_check(scene_source.contains('path="res://assets/ui/item_dex.svg" id="12_item_dex"') and script_source.contains('const ITEM_DEX_ICON := preload("res://assets/ui/item_dex.svg")'), "Item Dex uses its dedicated item catalogue icon")
	_check(scene_source.contains('path="res://assets/ui/staff_tools.svg" id="13_staff_tools"'), "Staff tools use a moderation shield instead of a rank crown")
	_check(hotkey_sidebar_scene_source.contains("border_width_left = 2") and hotkey_sidebar_scene_source.contains("0.92941177)"), "hotbar rail uses the shared stable-opacity frame")
	_check(script_source.contains('const UI_SURFACE_BASE := Color("#050b14ed")'), "overworld UI declares one semantic base surface")
	_check(script_source.contains('const UI_SURFACE_RAISED := Color("#081522eb")'), "overworld UI declares one semantic raised surface")
	_check(script_source.contains('const UI_SURFACE_HOVER := Color("#112a44f2")'), "overworld UI declares one semantic hover surface")
	_check(party_slot_script_source.contains('const SLOT_BG := Color("#081522eb")') and party_slot_script_source.contains('const SLOT_HOVER_BG := Color("#112a44f2")'), "party slots follow the shared surface hierarchy")
	_check(player_status_scene_source.contains("Color(0.019607844, 0.043137256, 0.078431375, 0.92941177)"), "trainer card follows the shared base surface")
	_check(scene_source.count("Color(0.019607844, 0.043137256, 0.078431375, 0.92941177)") >= 5, "major overworld frames share one neutral navy base")
	_check(scene_source.contains("StyleBoxFlat_personal_buff_slot") and scene_source.contains("Color(0.043137256, 0.101960786, 0.16862746, 0.91764706)"), "buff and action slots use a neutral interactive surface")
	_check(not scene_source.contains('[node name="ScopeLabel"'), "buff tray context labels are removed")
	_check(scene_source.count('parent="Control/GlobalBuffsPanel/MarginContainer/Row/BuffSlots"') == 5, "global buff tray exposes four community goals and Global Heal")
	_check(scene_source.count('parent="Control/PersonalBuffsPanel/MarginContainer/Row/BuffSlots"') == 3, "personal buff tray exposes three placeholder slots")
	_check(scene_source.contains('icon = ExtResource("23_global_exp")'), "global EXP goal uses its own icon")
	_check(scene_source.contains('icon = ExtResource("24_global_ev")'), "global EV goal uses its own icon")
	_check(scene_source.contains('icon = ExtResource("25_global_shiny")'), "global Shiny goal uses its own icon")
	_check(scene_source.contains('icon = ExtResource("26_global_rare")'), "rare encounter goal uses its own icon")
	_check(scene_source.count('[node name="ProgressBar" type="ProgressBar" parent="Control/GlobalBuffsPanel') == 4, "each global icon includes compact funding progress")
	_check(scene_source.contains('[node name="GlobalHealSection" type="VBoxContainer" parent="Control/GlobalBuffDetailsPanel'), "Global Heal has a dedicated action section")
	_check(scene_source.contains('text = "ui.buff.global_heal.receive_requests"'), "Global Heal exposes its request preference beside the action")
	_check(global_buff_details_block.contains("visible = false"), "global buff details start closed")
	_check(scene_source.contains('[node name="DonationSection" type="VBoxContainer" parent="Control/GlobalBuffDetailsPanel'), "global buff details expose contribution controls")
	_check(scene_source.contains('[node name="AmountInput" type="LineEdit" parent="Control/GlobalBuffDetailsPanel/MarginContainer/Content/DonationSection/DonationRow"]'), "global buff contributions use a custom amount input")
	_check(scene_source.contains('[node name="FillRemainingButton" type="Button" parent="Control/GlobalBuffDetailsPanel/MarginContainer/Content/DonationSection"]'), "global buff contributions can fill the exact remaining goal without competing with the main action")
	_check(scene_source.count('[node name="NameLabel" type="Label" parent="Control/PersonalBuffsPanel') == 3, "personal buffs render readable effect names")
	_check(
		scene_source.count('[node name="BadgeLabel" type="Label" parent="Control/PersonalBuffsPanel') == 0
		and scene_source.count('[node name="DescriptionLabel" type="Label" parent="Control/PersonalBuffsPanel') == 0,
		"personal buff rows avoid duplicate badges and clipped descriptions"
	)
	_check(scene_source.count('[node name="TimeLabel" type="Label" parent="Control/PersonalBuffsPanel') == 3, "personal buffs render remaining durations")
	_check(scene_source.contains('[node name="EmptyLabel" type="Label" parent="Control/PersonalBuffsPanel'), "personal buffs provide an empty-state label")
	_check(scene_source.contains('text = "ui.buff.none"'), "personal empty state uses its localization key")
	_check(scene_source.contains('[node name="ActiveSummaryButton" type="Button" parent="Control/PersonalBuffsPanel'), "active personal buffs use a compact count button")

	_check(script_source.contains('_register_collapsible_panel("hotkey_sidebar", hotkey_sidebar_panel, "left_center")'), "hotbar collapse control sits on its inner edge")
	_check(script_source.contains('_register_collapsible_panel("chat", chat_panel, "right")'), "chat controls sit on its inner edge")
	_check(script_source.contains("[personal_buffs_panel, settings_button, mount_button, skills_button, donator_store_button, my_powers_button]"), "trainer collapse includes personal buffs, mount management, Skills, utilities, and My Powers")
	_check(script_source.contains("func _set_my_powers_available") and script_source.contains("func _hide_my_powers_menu"), "My Powers only appears for accounts with available privileged tools")
	_check(script_source.contains('_register_collapsible_panel("party", party_panel, "right")'), "party collapse control sits on its inner edge")
	_check(script_source.contains('_register_collapsible_panel("location", location_panel, "right_center", null, [global_buffs_panel])'), "location collapse includes global buffs")
	_check(script_source.contains("func _collapsible_button_glyph") and script_source.contains("func _apply_collapsible_button_style"), "collapse controls use one directional visual language")
	_check(script_source.contains('"companions": companions'), "collapse state tracks grouped companion controls")
	_check(script_source.contains('bool(companion.get_meta("group_available", true))'), "grouped buff docks stay hidden when no buffs are active")
	_check(script_source.contains("chat_tabs_panel.z_index = UI_CHAT_TABS_Z_INDEX"), "chat tabs render above active party slots")
	_check(script_source.contains("var row_minimum_size := tab_row.get_combined_minimum_size()"), "chat tab panel accounts for every dynamic tab")
	_check(script_source.contains("const CHAT_TABS_LEFT_INSET := 4.0"), "chat tabs keep a clean inset without clipping the first tab")
	_check(script_source.contains('chat_settings_button.text = "⋯"'), "chat tabs use a compact settings affordance")
	_check(script_source.contains("func _setup_chat_tab_settings_ui()"), "chat settings are available without replacing the familiar chat layout")
	_check(script_source.contains("chat_tab_visibility[CHAT_TAB_GENERAL] = true"), "General remains a safe always-visible chat tab")
	_check(script_source.contains("visibility_toggle.toggled.connect(_on_chat_tab_visibility_toggled.bind(tab_id))"), "optional chat tabs can be shown and hidden")
	_check(script_source.contains("move_up_button.pressed.connect(_on_chat_tab_move_pressed.bind(tab_id, -1))"), "chat tabs can be reordered from settings")
	_check(script_source.contains("tab_row.move_child(chat_settings_button, index)"), "the compact settings button remains at the end of the tab row")
	_check(script_source.contains('{"panel": chat_settings_popup, "close": Callable(self, "_hide_chat_settings_popup")}'), "Escape closes chat settings")
	_check(script_source.contains("pm_total_unread_count > 0") and script_source.contains("chat_settings_attention_badge.visible"), "hidden PM activity remains discoverable")
	_check(settings_source.contains('"chat_tab_visibility": chat_tab_visibility'), "chat tab visibility is persisted with local settings")
	_check(settings_source.contains('"chat_tab_order": chat_tab_order'), "chat tab order is persisted with local settings")
	_check(settings_source.contains("func reset_chat_tab_preferences()"), "chat tab settings provide a default reset")
	_check(script_source.contains('"ui.chat.pm.empty_title"'), "PM uses one localized full-width empty state")
	_check(not script_source.contains('"No PMs yet."') and not script_source.contains('"No PM selected"'), "PM removes duplicated empty-state copy")
	_check(not script_source.contains("pm_conversation_sidebar"), "PM conversation navigation moves out of the permanent sidebar")
	_check(script_source.contains("pm_message_area.visible = has_conversations"), "PM gives its empty state the full chat width")
	_check(script_source.contains("chat_input.visible = input_active") and script_source.contains("send_button.visible = input_active"), "message input only appears when the selected context accepts messages")
	_check(script_source.contains("pm_active_conversation_label.text = _pm_conversation_title(user, 0)"), "active PM header keeps the trainer name concise")
	_check(script_source.contains("const CHAT_TAB_DEFAULT_ORDER: Array[String] = [") and script_source.contains("CHAT_TAB_GUILD"), "main chat tabs include the Guild context")
	_check(script_source.contains("guild_chat_attention_badge = _create_attention_badge_for_button"), "Guild chat uses the shared red unread badge")
	_check(script_source.contains("channel == CHAT_TAB_GUILD and active_chat_tab != CHAT_TAB_GUILD"), "incoming Guild messages mark the Guild tab unread")
	_check(script_source.contains("active_chat_tab == CHAT_TAB_GUILD and guild_chat_has_unread"), "opening Guild chat clears its unread badge")
	_check(script_source.contains("trade_chat_tab_button.visible = false") and script_source.contains("help_chat_tab_button.visible = false"), "Trade and Help no longer consume top-tab space")
	_check(script_source.contains('"ui.chat.context.selector"'), "bottom-left selector localizes the active General channel")
	_check(script_source.contains('_add_chat_context_option(LocalizationManager.text("ui.chat.channel.global"), CHAT_TAB_GENERAL'), "General selector exposes localized Global")
	_check(script_source.contains('_add_chat_context_option(LocalizationManager.text("ui.chat.tab.map"), CHAT_TAB_MAP'), "General selector exposes localized Map")
	_check(script_source.contains('_add_chat_context_option(LocalizationManager.text("ui.chat.tab.trade"), CHAT_TAB_TRADE'), "General selector exposes localized Trade")
	_check(script_source.contains('_add_chat_context_option(LocalizationManager.text("ui.chat.tab.help"), CHAT_TAB_HELP'), "General selector exposes localized Help")
	_check(script_source.contains("pm_context_selector_attention_badge = _create_attention_badge_for_button"), "PM selector button has a red unread indicator")
	_check(script_source.contains("pm_context_selector_attention_badge.visible = (") and script_source.contains("_active_primary_chat_tab_id() == CHAT_TAB_PM"), "PM selector badge appears only when unread PMs are actionable")
	_check(script_source.contains("_add_pm_context_option(label, user_id, user_id == active_pm_user_id, unread)"), "PM selector exposes conversation names with their unread state")
	_check(script_source.contains("attention_badge.visible = unread > 0"), "Unread PM conversations receive a red badge")
	_check(script_source.contains("chat_input_row.move_child(chat_context_selector_button, 0)"), "context selector sits left of the message field")
	_check(script_source.contains("_position_action_slot_popup(chat_context_popup, chat_context_selector_button)"), "context menu opens from the bottom selector and is viewport-clamped")
	_check(script_source.contains("minf(float(option_count * 34), 238.0)"), "large PM lists stay inside a scrollable context menu")
	_check(settings_source.contains("CHAT_TAB_GUILD") and not settings_source.contains("CHAT_TAB_TRADE"), "saved tab preferences track main tabs instead of General subchannels")
	_check(script_source.contains("func _make_chat_panel_style()"), "chat uses a dedicated glass frame instead of the generic panel style")
	_check(script_source.contains('chat_input_dock.name = "ChatInputDock"'), "selector, input, and Send share a styled input dock")
	_check(script_source.contains('chat_tabs_background.name = "ChatTabsBackground"'), "main tabs sit on a cohesive translucent rail")
	_check(script_source.contains('message_scroll.add_theme_stylebox_override("panel", _make_chat_message_surface_style())'), "chat messages use a subtle inner surface")
	_check(
		script_source.contains("func _create_chat_sender_message_line(")
		and script_source.contains('entry.append_text(" [color=%s]%s[/color]"')
		and script_source.contains('"\\u00a0".repeat(spacer_count)')
		and script_source.contains("func _sync_chat_inline_header_spacing(")
		and script_source.contains("func _chat_header_prefix_width(")
		and script_source.contains("const CHAT_INLINE_HEADER_CLEARANCE := 24.0")
		and script_source.contains("header_prefix_width > 0.0")
		and script_source.contains("entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART"),
		"visible chat metadata gets first-line clearance while plain names stay left aligned"
	)
	_check(
		script_source.contains("var inline_pokemon_share := (")
		and script_source.contains("and not pokemon_attachments.is_empty()")
		and script_source.contains('attachment_group.name = "InlinePokemonAttachments"')
		and script_source.contains("for attachment_index: int in range(pokemon_attachments.size()):")
		and script_source.contains("attachment_index == 0")
		and script_source.contains('inline_spacer.name = "InlinePokemonSpacer"')
		and script_source.contains("align_icon_left: bool = false")
		and script_source.contains("TextureRect.STRETCH_KEEP_ASPECT\n\t\tif align_icon_left")
		and script_source.contains("not inline_pokemon_share and not pokemon_attachments.is_empty()"),
		"Pokemon-only shares keep a full clickable party with the first sprite close to the sender"
	)
	_check(
		script_source.contains('message_list.add_theme_constant_override("separation", 5)'),
		"separate chat messages keep a small visual gap"
	)
	_check(
		script_source.contains("mouse_event.double_click")
		and script_source.contains("DisplayServer.clipboard_set(text)")
		and script_source.contains("CHAT_CONTEXT_COPY_FULL")
		and script_source.contains("_format_full_chat_message(active_chat_message_context)")
		and script_source.contains("func _show_chat_copy_confirmation()")
		and script_source.contains('confirmation.name = "ChatCopyConfirmation"')
		and script_source.contains('label.text = "✓ %s" % LocalizationManager.text("ui.chat.message.copied")')
		and script_source.contains("_open_chat_sender_context_menu")
		and script_source.contains("open_private_message_conversation(user)")
		and script_source.contains("SocialService.send_friend_request(username)"),
		"chat supports quick copying and sender or message context actions"
	)
	_check(
		script_source.contains("CHAT_CONTEXT_MUTE_PLAYER")
		and script_source.contains("CHAT_CONTEXT_UNMUTE_PLAYER")
		and script_source.contains("ChatModerationService.get_mute_state(target_user_id)")
		and script_source.contains("ChatModerationService.mute_player(target_user_id, duration_minutes, reason)")
		and script_source.contains("ChatModerationService.unmute_player(target_user_id, reason)")
		and script_source.contains("reason.strip_edges().length() < 3")
		and script_source.contains("_has_user_permission(CHAT_MUTE_PERMISSION)"),
		"authorized staff can mute or unmute chat senders with a required reason"
	)
	_check(
		script_source.contains("player_interaction_coordinator.chat_moderation_requested.connect")
		and script_source.contains("func _on_player_interaction_chat_moderation_requested("),
		"direct player actions share the required-reason chat moderation flow"
	)
	_check(
		script_source.contains("func _refresh_chat_sender_moderation_action(")
		and script_source.contains("CHAT_CONTEXT_MUTE_PLAYER"),
		"chat sender moderation remains available while mute state refreshes"
	)
	_check(
		script_source.contains("func _can_use_chat_moderation(")
		and script_source.contains("player_interaction_coordinator.can_moderate_chat()")
		and script_source.contains("_activate_ui_panel(chat_moderation_popup)"),
		"chat and direct player moderation share permission state and an active modal"
	)
	_check(
		script_source.contains("func _user_id_from_state(user: Dictionary) -> int:")
		and script_source.contains("if value is int or value is float:")
		and script_source.contains("if text.is_valid_float():"),
		"chat actions accept numeric user ids decoded from JSON"
	)
	_check(
		script_source.contains("func _chat_mute_remaining_seconds() -> int:")
		and script_source.contains("func _refresh_chat_mute_countdown() -> void:")
		and script_source.contains("ui.chat.muted.remaining")
		and script_source.contains('message_type == "chat.mute.updated"')
		and script_source.contains("ui.chat.muted.notice")
		and script_source.contains("chat_input.editable = input_available"),
		"muted players receive realtime updates and see a countdown in the disabled chat input"
	)
	_check(script_source.contains('_apply_chat_main_tab_style(general_chat_tab_button, general_active)'), "active and inactive main tabs receive distinct styling")
	_check(script_source.contains("style.border_width_bottom = 2"), "selected main tab gets a clear bottom accent")
	_check(script_source.contains("_apply_chat_dock_button_style(send_button, true)"), "Send uses the input dock accent treatment")
	_check(script_source.contains("chat_input_dock.visible = dock_visible"), "System cleanly hides the complete input dock")
	_check(script_source.contains("chat_resize_drag_start_rect.size.x + delta.x"), "dragging chat's right resize handle outward expands it")
	_check(script_source.contains("chat_panel.offset_right = chat_panel.offset_left + clamped_size.x"), "chat resizing preserves the left edge")
	_check(script_source.contains('CHAT_RESIZE_ICON: Texture2D = preload("res://assets/ui/chat_resize.svg")'), "chat resize control uses a dedicated diagonal icon")
	_check(not script_source.contains('chat_resize_button.text = "[]"'), "chat resize control no longer exposes placeholder text")
	_check(script_source.contains("Control.CURSOR_FDIAGSIZE"), "chat resize control uses a diagonal resize cursor")
	_check(script_source.contains("# Let the button receive mouse-up so Godot clears its pressed and hover"), "chat resize forwards mouse release to clear the handle tooltip state")
	_check(script_source.contains("func _on_party_slot_clicked(slot_index: int)"), "normal party slots remain clickable")
	_check(script_source.contains("_show_pokemon_summary(slot_index)"), "normal party slots still open summaries")
	_check(script_source.contains("func set_global_buffs(buffs: Array)"), "global buff tray accepts future live data")
	_check(script_source.count('"current": 0') == 4, "global buffs start with no community funding")
	_check(script_source.count('"state": "funding"') == 4 and not script_source.contains('"state": "active"'), "global buffs start inactive")
	_check(script_source.contains("func _apply_global_buff_slot_visual") and script_source.contains('"ui.buff.waiting_contributions"'), "unfunded global buffs use a localized inactive visual state")
	_check(scene_source.count("value = 0.0") >= 4, "global buff scene defaults avoid flashing funded progress")
	_check(script_source.contains("func set_personal_buffs(buffs: Array)"), "personal buff tray accepts future live data")
	_check(script_source.contains("set_personal_buffs([])"), "personal buffs default to the empty state")
	_check(
		player_status_scene_source.contains('[node name="MembershipBadge"')
		and player_status_scene_source.contains('text = "ui.membership.aether_blessing.badge"')
		and script_source.contains("func _current_aether_blessing_membership()")
		and script_source.contains('"expiresAt": expires_at'),
		"active Aether Blessings appear as membership status in the mini Trainer Card"
	)
	_check(
		script_source.contains("func _refresh_personal_buffs_if_needed(delta: float)")
		and script_source.contains("_refresh_aether_blessing_membership_status()")
		and script_source.contains("_aether_blessing_membership_tooltip"),
		"the mini Trainer Card keeps membership status and details current"
	)
	_check(
		script_source.contains('"aether_blessing_travel_discount",')
		and script_source.contains('"aether_blessing_shop_discount",')
		and script_source.contains("func _current_aether_blessing_shiny_bonus()")
		and script_source.contains("func _current_aether_blessing_travel_discount()")
		and script_source.contains("func _current_aether_blessing_shop_discount()")
		and script_source.contains('"ui.buff.aether_blessing_shiny.name"')
		and script_source.contains('"ui.buff.aether_blessing_travel.name"')
		and script_source.contains('"ui.buff.aether_blessing_shops.name"')
		and not script_source.contains('"name_key": "ui.buff.aether_blessing.name"'),
		"the boost tray shows the membership's concrete Shiny, travel, and shop effects"
	)
	_check(script_source.contains('personal_buffs_panel.set_meta("group_available", true)'), "personal empty state remains part of the trainer collapse group")
	_check(script_source.contains("PERSONAL_BUFF_PANEL_COMPACT_HEIGHT"), "empty and collapsed active states use a compact panel height")
	_check(script_source.contains("const PERSONAL_BUFF_PANEL_COMPACT_HEIGHT := 42.0"), "personal buff and Store controls share a status-rail height")
	_check(script_source.contains("func _on_personal_buffs_summary_pressed()"), "personal buff count can expand and collapse its details")
	_check(script_source.contains("func _personal_buffs_summary_tooltip()"), "personal buff count exposes hover details")
	_check(script_source.contains('LocalizationManager.plural(') and script_source.contains('"ui.buff.active.one"') and script_source.contains('"ui.buff.active.many"'), "personal buff summary localizes the active count")
	_check(script_source.contains("func _on_global_buff_button_pressed(button: Button)"), "global buff icons open their detail panel")
	_check(script_source.contains("await get_tree().process_frame") and script_source.contains("get_combined_minimum_size"), "global buff details wait for their first layout before positioning")
	_check(script_source.contains('str(buff.get("state", "funding")) == "active"'), "global buff icons distinguish active and funding states")
	_check(script_source.contains('"id": "global_shiny"'), "global buff data includes Shiny encounters")
	_check(script_source.contains('["global_exp", "global_ev", "global_shiny", "global_rare_encounter"]'), "Shiny global boost accepts community contributions")
	_check(script_source.contains('"activate_shiny_charm"'), "Shiny Charm can be activated from the Bag")
	_check(script_source.contains('"ui.bag.message.shiny_charm_activated"'), "Shiny Charm activation gives the player clear feedback")
	_check(script_source.contains('"id": "global_rare_encounter"'), "global buff data includes rarer Pokémon encounters")
	_check(script_source.contains('"id": "global_heal"') and script_source.contains("PlayerWalletService.activate_global_heal()"), "Global Heal is an authoritative paid global action")
	_check(script_source.contains("_is_world_battle_active()") and script_source.contains("pending_global_heal_request"), "Global Heal requests wait while a battle is active")
	_check(script_source.contains("PartyHealService.accept_global_heal") and script_source.contains("globalHealRequestsEnabled"), "Global Heal acceptance and request preference use server-backed services")
	_check(script_source.contains("PlayerWalletService.contribute_to_global_exp_boost"), "global EXP contributions use the authoritative wallet service")
	_check(script_source.contains("PlayerWalletService.contribute_to_global_ev_boost"), "global EV contributions use the authoritative wallet service")
	_check(script_source.contains("PlayerWalletService.contribute_to_global_rare_encounter_boost"), "rare encounter contributions use the authoritative wallet service")
	_check(script_source.contains("PlayerWalletService.contribute_to_global_shiny_boost"), "Shiny contributions use the authoritative wallet service")
	_check(script_source.contains("_load_global_shiny_boost.call_deferred()"), "Shiny boost state loads from the server")
	_check(script_source.contains('"goal": 1000000') and script_source.contains('"active_duration": "7d"'), "Shiny boost starts at one million for seven days")
	_check(script_source.contains('message_type == "system.global_exp_boost_contribution"'), "global EXP contributions appear as realtime system messages")
	_check(script_source.contains('message_type == "system.global_ev_boost_contribution"'), "global EV contributions appear as realtime system messages")
	_check(script_source.contains('message_type == "system.global_rare_encounter_boost_contribution"'), "rare encounter contributions appear as realtime system messages")
	_check(script_source.contains('_load_global_boost_state.call_deferred("global_exp")'), "global EXP contribution events refresh authoritative boost state")
	_check(script_source.contains('_load_global_boost_state.call_deferred("global_ev")'), "global EV contribution events refresh authoritative boost state")
	_check(script_source.contains('_load_global_boost_state.call_deferred("global_rare_encounter")'), "rare encounter contribution events refresh authoritative boost state")
	_check(script_source.contains('_load_global_boost_state.call_deferred("global_shiny")'), "global Shiny contribution events refresh authoritative boost state")
	_check(script_source.contains('await _load_global_boost_state(selected_boost_id)'), "stale contribution conflicts recover the authoritative boost state")
	_check(script_source.contains('if int(response.get("status", 0)) == 409:') and script_source.contains('else:\n\t\t\t_add_chat_message'), "stale boost conflicts refresh without showing a misleading payment error")
	_check(script_source.contains('buff["activeUntil"] = str(state.get("activeUntil", ""))'), "active global buffs retain their authoritative expiry")
	_check(script_source.contains("_refresh_global_buffs_if_needed(delta)"), "active global buff countdowns refresh while the overlay remains open")
	_check(not script_source.contains('GameErrorDialogService.show_response(response, "backend.error.transit_unavailable")'), "global EXP contribution errors stay inside the boost flow")
	_check(script_source.contains("const MINIMUM_GLOBAL_BUFF_CONTRIBUTION := 10_000"), "global buff contributions enforce the 10,000 Pokédollar minimum")
	_check(script_source.contains("selected_global_buff_contribution = mini(requested, remaining)"), "global buff contribution input is capped to the remaining goal")
	_check(script_source.contains('"aetheriteReward"'), "global EXP contributions display their personal Aetherite reward")
	_check(
		script_source.contains("const PERSONAL_BUFF_ROW_HEIGHT := 38.0")
		and script_source.contains("name_label.text = _localized_buff_name(buff)"),
		"personal buff rows use compact localized effect labels"
	)
	_check(donator_store_scene_source.contains("custom_minimum_size = Vector2(1120, 680)"), "Donator Store opens as a full catalog and character-preview interface")
	_check(donator_store_script_source.contains('"membership",') and donator_store_script_source.contains('"cosmetics",') and donator_store_script_source.contains('"mounts",') and donator_store_script_source.contains('"charms",') and donator_store_script_source.contains('"services",'), "Aether Store separates its six scalable catalog categories")
	_check(
		donator_store_script_source.contains('"membership": "Blessings"')
		and donator_store_script_source.contains('"membership": "5% SHINY · TRAVEL · NPC SHOPS"')
		and donator_store_script_source.contains("5% better Shiny odds")
		and donator_store_script_source.contains("50% off regional travel")
		and donator_store_script_source.contains("two free Aether Anchors")
		and donator_store_script_source.contains("5% off NPC currency shops")
		and donator_store_script_source.contains("Aether Gems excluded"),
		"Blessings disclose the complete Shiny, travel, anchor, and NPC shop package"
	)
	_check(donator_store_script_source.contains('"name": "Aether Blessing Voucher · 3 Days"') and donator_store_script_source.contains('"badge": "3 DAYS"') and donator_store_script_source.contains('"badge": "7 DAYS"') and donator_store_script_source.contains('"badge": "14 DAYS"') and donator_store_script_source.contains('"badge": "30 DAYS"') and not donator_store_script_source.contains('"badge": "90 DAYS"'), "Aether Blessing offers the intended four tradeable voucher durations")
	_check(
		donator_store_script_source.contains("AETHERBLESSINGVOUCHER3DAYS.png")
		and donator_store_script_source.contains("AETHERBLESSINGVOUCHER7DAYS.png")
		and donator_store_script_source.contains("AETHERBLESSINGVOUCHER14DAYS.png")
		and donator_store_script_source.contains("AETHERBLESSINGVOUCHER30DAYS.png")
		and not script_source.contains("AETHER_BLESSING_VOUCHER_ICON"),
		"each Blessing duration uses its own pixel-art icon in both Store and Bag"
	)
	_check(donator_store_script_source.contains('"name": "Surf Charm"') and donator_store_script_source.contains("Badge and story requirements still apply."), "Store explains that Charms replace HM party requirements without bypassing progression")
	_check(donator_store_script_source.contains('preload("res://assets/items/icons/field_move_charms/SURFCHARM.png")'), "Store Charms use their authentic item icons")
	_check(donator_store_script_source.contains('"name": "Flash Charm"') and donator_store_script_source.contains('"name": "Dive Charm"') and donator_store_script_source.contains('"name": "Defog Charm"'), "Store includes additional traversal Charms")
	_check(donator_store_script_source.contains('"name": "Rain Dance Charm"') and donator_store_script_source.contains('"name": "Snowscape Charm"'), "Store includes overworld weather Charms")
	_check(donator_store_script_source.contains('"charms": "FIELD CONVENIENCE"') and donator_store_script_source.contains("Progression and area rules still apply."), "Charm category covers field convenience without promising progression bypasses")
	_check(
		script_source.contains('{"id": "charms", "labelKey": "ui.bag.category.charms", "iconItemId": "surf-charm"}')
			and script_source.contains('"medicine", "machines", "charms",'),
		"tradeable field Charms use their own Bag category instead of Key Items"
	)
	_check(
		donator_store_script_source.contains('"name": "Name Change Ticket"')
		and donator_store_script_source.contains('"name": "Gender Chance Ticket"')
		and not donator_store_script_source.contains('"id": "appearance_reset_ticket"'),
		"Trainer Services contain only the requested name and gender tickets"
	)
	_check(
		donator_store_script_source.contains("NAMECHANGETICKET.png")
		and donator_store_script_source.contains("GENDERCHANCETICKET.png"),
		"Trainer Service tickets use dedicated pixel-art item icons"
	)
	_check(
		donator_store_script_source.contains('"ui.store.title"')
		and donator_store_script_source.contains('"ui.store.subtitle"'),
		"Gift Store presents itself as a clearly labeled authoritative catalog"
	)
	_check(not donator_store_script_source.contains('"personal_buffs"') and not donator_store_script_source.contains('"personal_buff"'), "paid personal buffs stay outside the Store catalog")
	_check(
		donator_store_script_source.contains("func set_gem_balance(amount: int)")
		and donator_store_script_source.contains('"ui.store.balance"'),
		"Donator Store labels its authoritative Aether Gem balance"
	)
	_check(
		donator_store_script_source.contains("authoritative_gem_prices")
		and donator_store_script_source.contains("purchase_requested.emit(selected_item_id, _selected_purchase_chroma_colors())")
		and script_source.contains("DonatorStoreService.purchase_item(item_id, chroma_colors)"),
		"Donator Store purchases use the authoritative Aether Gem checkout"
	)
	_check(
		script_source.contains('"ui.store.purchase.system_success"')
		and script_source.contains('{"item": purchased_item_name}'),
		"successful Aether Gift Store purchases use a localized System message"
	)
	_check(
		donator_store_script_source.contains("Tradeable voucher. Use it from the Bag")
		and script_source.contains('"id": "vouchers", "labelKey": "ui.bag.category.vouchers"')
		and script_source.contains('use_action == "redeem_aether_blessing"')
		and script_source.contains('LocalizationManager.text("ui.bag.message.blessing_extended"'),
		"Blessing purchases remain tradeable vouchers until redeemed from the Bag"
	)
	_check(
		script_source.contains("func _create_trainer_card_wallet_tab()")
		and script_source.contains('tab.name = "Wallet"')
		and script_source.contains('"ui.trainer_card.wallet.money"')
		and script_source.contains('"ui.trainer_card.wallet.gems"')
		and script_source.contains('"ui.trainer_card.wallet.aetherite"')
		and script_source.contains('"ui.trainer_card.wallet.battle_points"')
		and script_source.contains('cards.columns = 2'),
		"Trainer Card has a 2x2 Wallet grid for all currencies"
	)
	_check(script_source.contains("donator_store_popup.open_store()") and not script_source.contains("The Aether Store is not connected yet."), "purple gem button opens the Store interface")
	_check(
		script_source.contains('content_scroll.name = "AppearanceContentScroll"')
		and script_source.contains("content_scroll.add_child(content_stack)")
		and script_source.contains("content_stack.add_child(grid)"),
		"Appearance items and palettes share one usable scrolling content area"
	)
	_check(script_source.contains('{"panel": donator_store_popup, "close": Callable(self, "_hide_donator_store_popup")}'), "Escape closes the Donator Store")
	_check(
		script_source.contains("quest_journal_view.open_journal()")
		and not script_source.contains("Quest Log is not implemented yet."),
		"Quest Log navigation opens the implemented journal"
	)
	_check(script_source.contains('const REDEEM_CODE_ICON: Texture2D = preload("res://assets/ui/redeem_code.svg")'), "Trainer Card redeem action uses its own gift-code icon")
	_check(script_source.contains("func _create_trainer_card_redeem_button()") and script_source.contains('header.add_child(_create_trainer_card_redeem_button())'), "Trainer Card places the future Redeem Code action beside Close")
	_check(not script_source.contains('hint_label.text = "Have a gift code?"') and not script_source.contains("RedeemCodePanel"), "Trainer Card omits the redundant redeem footer copy")
	_check(script_source.contains('redeem_button.add_theme_constant_override("icon_max_width", 18)') and not script_source.contains("redeem_button.icon_max_width"), "runtime Redeem Code button sizes its icon through a valid theme override")
	_check(script_source.contains("redeem_button.pressed.connect(_open_trainer_card_redeem_popup)"), "Redeem Code opens the live gift-code flow")
	_check(script_source.contains("const TRAINER_CARD_SIZE := Vector2(720, 500)"), "Trainer Card has enough room for a breathable passport layout")
	_check(script_source.contains("func _make_trainer_card_outer_style()") and script_source.contains("func _make_trainer_card_section_style"), "Trainer Card uses dedicated semantic surfaces")
	_check(script_source.contains("func _apply_trainer_card_tabs_style") and script_source.contains("TRAINER_CARD_ACCENT, true"), "Trainer Card tabs use a restrained selected accent")
	_check(script_source.contains('"ui.trainer_card.passport"'), "Trainer Card header prioritizes localized passport identity")
	_check(script_source.contains('_set_localized_control_property(title, "text", title_key)') and script_source.contains('title.add_theme_font_size_override("font_size", 11)'), "Trainer Card section headings use compact localized hierarchy")
	_check(script_source.contains('redeem_button.custom_minimum_size = Vector2(142, 30)') and script_source.contains("_apply_button_style(redeem_button)"), "Redeem Code remains a compact secondary header action")
	_check(not script_source.contains('trainer_card_popup.add_theme_stylebox_override("panel", _make_gold_panel_style'), "Trainer Card no longer uses the legacy heavy gold frame")
	_check(script_source.contains('button.texture_normal = _load_item_icon(entry_id)') and script_source.contains('button.texture_normal = _load_item_icon("%s-charm" % move_id)'), "hotbar keeps authentic item and field-move charm icons")
	_check(script_source.contains("var occupied := not _hotbar_entry_for_slot(slot_index).is_empty()"), "empty hotbar slots use reduced visual priority")
	_check(battle_source.contains("BATTLE_UI_DEFAULT_HORIZONTAL_OFFSET := 130.0"), "battle UI defaults to the right of the party column")
	_check(battle_source.contains("(parent_control.size.x - size.x) * 0.5 + BATTLE_UI_DEFAULT_HORIZONTAL_OFFSET"), "battle UI applies its horizontal default offset")

	quit(1 if failed else 0)


func _node_block(source: String, header_prefix: String) -> String:
	var start := source.find(header_prefix)
	if start < 0:
		return ""
	var end := source.find("\n\n", start)
	return source.substr(start) if end < 0 else source.substr(start, end - start)


func _function_block(source: String, function_header: String) -> String:
	var start := source.find(function_header)
	if start < 0:
		return ""
	var end := source.find("\nfunc ", start + function_header.length())
	return source.substr(start) if end < 0 else source.substr(start, end - start)


func _check(value: bool, label: String) -> void:
	if value:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
