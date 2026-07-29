extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"

var failed := false
var localization_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	localization_manager = root.get_node_or_null("LocalizationManager")
	_check(localization_manager != null, "PvP localization check can access LocalizationManager")
	if localization_manager == null:
		quit(1)
		return

	var original_locale := str(localization_manager.get("current_locale"))
	_check_pvp_runtime_translation()
	localization_manager.call("set_locale", original_locale)
	await process_frame
	quit(1 if failed else 0)


func _check_pvp_runtime_translation() -> void:
	var packed := load(OVERLAY_SCENE_PATH) as PackedScene
	_check(packed != null, "localized PvP overlay loads")
	if packed == null:
		return

	var overlay := packed.instantiate()
	overlay.set("root_control", overlay.get_node_or_null("Control"))
	localization_manager.call("set_locale", "nl")
	overlay.call("_setup_pvp_room_popup")
	overlay.call("_setup_pvp_queue_compact_panel")
	overlay.call("_setup_pvp_match_countdown_overlay")
	overlay.call("_setup_pvp_mode_menu")

	var popup := overlay.get("pvp_room_popup") as PanelContainer
	var title := overlay.get("pvp_popup_title_label") as Label
	var subtitle := overlay.get("pvp_popup_subtitle_label") as Label
	var ranked_tabs := overlay.get("pvp_ranked_tabs") as TabContainer
	var room_join_button := overlay.get("pvp_room_join_mode_button") as Button
	var room_status := overlay.get("pvp_room_status_label") as Label
	var leaderboard_scope := overlay.get("pvp_leaderboard_scope_select") as OptionButton
	var compact_status := overlay.get("pvp_queue_compact_status_label") as Label

	_check(title != null and title.text == "Ranked", "PvP ranked title renders in Dutch")
	_check(subtitle != null and subtitle.text.begins_with("Competitieve"), "PvP subtitle renders in Dutch")
	_check(ranked_tabs != null and ranked_tabs.get_tab_title(0) == "Spelen", "PvP tab title renders in Dutch")
	_check(room_join_button != null and room_join_button.text == "Deelnemen", "Private room action renders in Dutch")
	_check(leaderboard_scope != null and leaderboard_scope.get_item_text(0) == "Dagelijks", "Leaderboard period renders in Dutch")

	overlay.call("_on_pvp_room_mode_selected", "join")
	overlay.call("_set_pvp_status_key", "ui.pvp.room.waiting")
	overlay.set("pvp_active_queue_entry_id", "queue-entry")
	overlay.set("pvp_active_queue_status", "waiting")
	overlay.set("pvp_queue_compact_minimized", true)
	overlay.call("_refresh_pvp_queue_compact_panel", 0.0)
	_check(room_status != null and room_status.text == "Wachten op een andere speler...", "Dynamic room status renders in Dutch")
	_check(compact_status != null and compact_status.text == "Ranked-wachtrij", "Compact queue status renders in Dutch")
	_check(
		overlay.call("_pvp_history_result_label", {"winnerUserId": 7}, 7) == "Overwinning",
		"PvP history outcome renders in Dutch"
	)

	localization_manager.call("set_locale", "pt_BR")
	overlay.call("_refresh_pvp_localized_ui")
	_check(title != null and title.text == "Ranqueada", "PvP ranked title updates to Portuguese")
	_check(subtitle != null and subtitle.text.begins_with("Pareamento"), "PvP subtitle updates to Portuguese")
	_check(ranked_tabs != null and ranked_tabs.get_tab_title(0) == "Jogar", "PvP tab title updates to Portuguese")
	_check(room_join_button != null and room_join_button.text == "Entrar na sala", "Private room action updates to Portuguese")
	_check(room_status != null and room_status.text == "Aguardando outro jogador...", "Dynamic room status updates to Portuguese")
	_check(leaderboard_scope != null and leaderboard_scope.get_item_text(0) == "Diária", "Leaderboard period updates to Portuguese")
	_check(compact_status != null and compact_status.text == "Fila ranqueada", "Compact queue status updates to Portuguese")

	if popup != null:
		var minimum_size := popup.get_combined_minimum_size()
		_check(minimum_size.x <= 980.0 and minimum_size.y <= 620.0, "PvP translations fit the designed popup bounds")

	for loader_property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader := overlay.get(loader_property) as Node
		if loader != null:
			loader.free()
	overlay.free()


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
