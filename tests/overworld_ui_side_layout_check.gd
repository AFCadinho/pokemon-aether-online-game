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
	var party_margin_block := _node_block(scene_source, '[node name="MarginContainer" type="MarginContainer" parent="Control/PartyPanel"')
	var party_container_block := _node_block(scene_source, '[node name="VBoxContainer" type="VBoxContainer" parent="Control/PartyPanel/MarginContainer"')
	var chat_block := _node_block(scene_source, '[node name="ChatPanel"')
	var chat_tabs_block := _node_block(scene_source, '[node name="ChatTabsPanel"')
	var global_buffs_block := _node_block(scene_source, '[node name="GlobalBuffsPanel"')
	var global_buff_details_block := _node_block(scene_source, '[node name="GlobalBuffDetailsPanel"')
	var personal_buffs_block := _node_block(scene_source, '[node name="PersonalBuffsPanel"')
	var store_block := _node_block(scene_source, '[node name="DonatorStoreButton"')
	var settings_block := _node_block(scene_source, '[node name="SettingsButton" type="Button" parent="Control"]')
	var quest_slot_block := _node_block(scene_source, '[node name="QuestSlot"')
	var quest_button_block := _node_block(scene_source, '[node name="QuestButton"')
	var socials_menu_block := _node_block(scene_source, '[node name="SocialsMenu"')
	var disable_icon_focus_block := _function_block(script_source, "func _disable_icon_button_focus()")

	_check(hotbar_block.contains("anchors_preset = 6"), "hotbar is anchored to the right")
	_check(hotbar_block.contains("offset_right = 0.0"), "hotbar hugs the right screen edge")
	_check(party_block.contains("anchors_preset = 0"), "normal party is anchored to the left")
	_check(party_block.contains("offset_left = 0.0"), "normal party hugs the left screen edge")
	_check(party_block.contains("offset_top = 132.0"), "normal party sits higher while clearing the top toolbar")
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
	_check(global_buffs_block.contains("custom_minimum_size = Vector2(197, 50)"), "global buffs use a compact four-icon tray")
	_check(personal_buffs_block.contains("anchors_preset = 3"), "personal buffs sit above the bottom-right trainer card")
	_check(personal_buffs_block.contains("offset_bottom = -104.0"), "personal buffs leave space above the trainer card")
	_check(personal_buffs_block.contains("custom_minimum_size = Vector2(188, 98)"), "personal buffs have room for readable detail cards")
	_check(store_block.contains("anchors_preset = 3"), "Donator Store is anchored near the trainer card")
	_check(store_block.contains('icon = ExtResource("22_donator_gem")'), "Donator Store uses the purple gem icon")
	_check(store_block.contains("custom_minimum_size = Vector2(42, 42)") and store_block.contains("icon_max_width = 26"), "Donator Store aligns with the personal status rail")
	_check(settings_block.contains("custom_minimum_size = Vector2(42, 42)") and settings_block.contains("offset_bottom = -152.0"), "Settings forms a matching utility button above the Donator Store")
	_check(settings_block.contains('icon = ExtResource("7_settings_icon")'), "relocated Settings keeps its familiar gear icon")
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
	_check(script_source.contains('"ui.staff.dev.heal_party"') and script_source.contains('"ui.staff.dev.preview_evolution"') and script_source.contains('"ui.staff.dev.clear_data"'), "Developer utility and destructive actions remain available")
	_check(script_source.contains('staff_tools_popup.custom_minimum_size = Vector2(390, 0)') and script_source.contains('"ui.staff.tools.subtitle"'), "Staff Tools uses the shared compact launcher")
	_check(script_source.contains('"ui.staff.teleport.action_description"') and script_source.contains('"ui.staff.impersonate.action_description"'), "Staff actions explain Teleport and Impersonate")
	_check(script_source.contains('content_creator_menu_popup.custom_minimum_size = Vector2(390, 0)') and script_source.contains('"ui.staff.alpha.subtitle"'), "Alpha Tools uses the shared compact launcher")
	_check(script_source.contains('"ui.staff.alpha.create_description"') and script_source.contains('"ui.staff.alpha.clear_description"'), "Alpha Tools actions explain their scope")
	_check(scene_source.contains('path="res://assets/ui/alpha_tools.svg" id="15_content_creator"') and script_source.contains('preload("res://assets/ui/alpha_tools.svg")'), "Alpha Tools uses its dedicated validated Alpha icon")
	_check(script_source.contains('const TOOL_CLEAR_DATA_ICON: Texture2D = preload("res://assets/ui/tool_clear_data.svg")') and script_source.contains('const STAFF_IMPERSONATE_ICON: Texture2D = preload("res://assets/ui/staff_impersonate.svg")'), "internal tool launchers use dedicated action icons")
	_check(script_source.contains('_position_action_slot_popup(dev_actions_popup, dev_actions_slot)') and script_source.contains('_position_action_slot_popup(staff_tools_popup, staff_tools_slot)'), "internal tool menus open beside their toolbar actions")
	_check(script_source.contains('{"panel": content_creator_menu_popup, "close": Callable(self, "_hide_content_creator_menu_popup")}'), "Escape closes the Alpha Tools launcher")
	_check(script_source.contains("content_creator_create_pokemon_button.visible = can_use_content_creator_generation") and script_source.contains("staff_impersonate_button.visible = can_impersonate"), "launcher polish preserves permission-based action visibility")
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
	_check(scene_source.count('parent="Control/GlobalBuffsPanel/MarginContainer/Row/BuffSlots"') == 4, "global buff tray exposes four community-goal slots")
	_check(scene_source.count('parent="Control/PersonalBuffsPanel/MarginContainer/Row/BuffSlots"') == 3, "personal buff tray exposes three placeholder slots")
	_check(scene_source.contains('icon = ExtResource("23_global_exp")'), "global EXP goal uses its own icon")
	_check(scene_source.contains('icon = ExtResource("24_global_ev")'), "global EV goal uses its own icon")
	_check(scene_source.contains('icon = ExtResource("25_global_shiny")'), "global Shiny goal uses its own icon")
	_check(scene_source.contains('icon = ExtResource("26_global_rare")'), "rare encounter goal uses its own icon")
	_check(scene_source.count('[node name="ProgressBar" type="ProgressBar" parent="Control/GlobalBuffsPanel') == 4, "each global icon includes compact funding progress")
	_check(global_buff_details_block.contains("visible = false"), "global buff details start closed")
	_check(scene_source.contains('[node name="DonationSection" type="VBoxContainer" parent="Control/GlobalBuffDetailsPanel'), "global buff details expose contribution controls")
	_check(scene_source.count('[node name="NameLabel" type="Label" parent="Control/PersonalBuffsPanel') == 3, "personal buffs render readable effect names")
	_check(scene_source.count('[node name="DescriptionLabel" type="Label" parent="Control/PersonalBuffsPanel') == 3, "personal buffs render readable effect descriptions")
	_check(scene_source.count('[node name="TimeLabel" type="Label" parent="Control/PersonalBuffsPanel') == 3, "personal buffs render remaining durations")
	_check(scene_source.contains('[node name="EmptyLabel" type="Label" parent="Control/PersonalBuffsPanel'), "personal buffs provide an empty-state label")
	_check(scene_source.contains('text = "ui.buff.none"'), "personal empty state uses its localization key")
	_check(scene_source.contains('[node name="ActiveSummaryButton" type="Button" parent="Control/PersonalBuffsPanel'), "active personal buffs use a compact count button")

	_check(script_source.contains('_register_collapsible_panel("hotkey_sidebar", hotkey_sidebar_panel, "left_center")'), "hotbar collapse control sits on its inner edge")
	_check(script_source.contains('_register_collapsible_panel("chat", chat_panel, "right")'), "chat controls sit on its inner edge")
	_check(script_source.contains("[personal_buffs_panel, settings_button, donator_store_button]"), "trainer collapse includes personal buffs, Settings, and the Donator Store")
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
	_check(script_source.contains('_apply_chat_main_tab_style(general_chat_tab_button, general_active)'), "active and inactive main tabs receive distinct styling")
	_check(script_source.contains("style.border_width_bottom = 2"), "selected main tab gets a clear bottom accent")
	_check(script_source.contains("_apply_chat_dock_button_style(send_button, true)"), "Send uses the input dock accent treatment")
	_check(script_source.contains("chat_input_dock.visible = dock_visible"), "System cleanly hides the complete input dock")
	_check(script_source.contains("chat_resize_drag_start_rect.size.x + delta.x"), "dragging chat's right resize handle outward expands it")
	_check(script_source.contains("chat_panel.offset_right = chat_panel.offset_left + clamped_size.x"), "chat resizing preserves the left edge")
	_check(script_source.contains('CHAT_RESIZE_ICON: Texture2D = preload("res://assets/ui/chat_resize.svg")'), "chat resize control uses a dedicated diagonal icon")
	_check(not script_source.contains('chat_resize_button.text = "[]"'), "chat resize control no longer exposes placeholder text")
	_check(script_source.contains("Control.CURSOR_FDIAGSIZE"), "chat resize control uses a diagonal resize cursor")
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
		script_source.contains("func _current_aether_blessing_buff()")
		and script_source.contains('"name_key": "ui.buff.aether_blessing.name"')
		and script_source.contains('"expiresAt": expires_at'),
		"active Aether Blessings appear in the personal buff tray with their expiry"
	)
	_check(
		script_source.contains("func _refresh_personal_buffs_if_needed(delta: float)")
		and script_source.contains("_format_aether_blessing_remaining"),
		"the personal buff tray keeps the Blessing countdown current"
	)
	_check(script_source.contains('personal_buffs_panel.set_meta("group_available", true)'), "personal empty state remains part of the trainer collapse group")
	_check(script_source.contains("PERSONAL_BUFF_PANEL_COMPACT_HEIGHT"), "empty and collapsed active states use a compact panel height")
	_check(script_source.contains("const PERSONAL_BUFF_PANEL_COMPACT_HEIGHT := 42.0"), "personal buff and Store controls share a status-rail height")
	_check(script_source.contains("func _on_personal_buffs_summary_pressed()"), "personal buff count can expand and collapse its details")
	_check(script_source.contains("func _personal_buffs_summary_tooltip()"), "personal buff count exposes hover details")
	_check(script_source.contains('LocalizationManager.plural(') and script_source.contains('"ui.buff.active.one"') and script_source.contains('"ui.buff.active.many"'), "personal buff summary localizes the active count")
	_check(script_source.contains("func _on_global_buff_button_pressed(button: Button)"), "global buff icons open their detail panel")
	_check(script_source.contains('str(buff.get("state", "funding")) == "active"'), "global buff icons distinguish active and funding states")
	_check(script_source.contains('"id": "global_shiny"'), "global buff data includes Shiny encounters")
	_check(script_source.contains('"id": "global_rare_encounter"'), "global buff data includes rarer Pokémon encounters")
	_check(script_source.contains('"ui.buff.contribution_unavailable"'), "localized community contribution placeholder cannot silently spend currency")
	_check(script_source.contains("name_label.text = _localized_buff_name(buff)"), "personal buff rows receive localized readable names")
	_check(donator_store_scene_source.contains("custom_minimum_size = Vector2(1120, 680)"), "Donator Store opens as a full catalog and character-preview interface")
	_check(donator_store_script_source.contains('"membership",') and donator_store_script_source.contains('"cosmetics",') and donator_store_script_source.contains('"mounts",') and donator_store_script_source.contains('"charms",') and donator_store_script_source.contains('"services",'), "Aether Store separates its six scalable catalog categories")
	_check(donator_store_script_source.contains('"membership": "Blessings"') and donator_store_script_source.contains('"membership": "NO BATTLE POWER"') and donator_store_script_source.contains("No battle advantages"), "Blessings establish a fair supporter direction")
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
	_check(script_source.contains("Quest Log is not implemented yet."), "placeholder Quest Log interaction gives clear feedback")
	_check(script_source.contains('const REDEEM_CODE_ICON: Texture2D = preload("res://assets/ui/redeem_code.svg")'), "Trainer Card redeem action uses its own gift-code icon")
	_check(script_source.contains("func _create_trainer_card_redeem_button()") and script_source.contains('header.add_child(_create_trainer_card_redeem_button())'), "Trainer Card places the future Redeem Code action beside Close")
	_check(not script_source.contains('hint_label.text = "Have a gift code?"') and not script_source.contains("RedeemCodePanel"), "Trainer Card omits the redundant redeem footer copy")
	_check(script_source.contains('redeem_button.add_theme_constant_override("icon_max_width", 18)') and not script_source.contains("redeem_button.icon_max_width"), "runtime Redeem Code button sizes its icon through a valid theme override")
	_check(not script_source.contains("redeem_button.pressed.connect"), "Redeem Code remains intentionally non-functional")
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
