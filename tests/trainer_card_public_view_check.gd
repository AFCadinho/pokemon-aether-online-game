extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var localization_manager := root.get_node_or_null("LocalizationManager")
	_check(localization_manager != null, "public Trainer Card check can access localization")
	if localization_manager == null:
		quit(1)
		return
	var original_locale := str(localization_manager.get("current_locale"))
	localization_manager.call("set_locale", "en")
	var packed := load(OVERLAY_SCENE_PATH) as PackedScene
	var overlay := packed.instantiate() if packed != null else null
	_check(overlay != null, "public Trainer Card overlay loads")
	if overlay == null:
		quit(1)
		return
	overlay.set("root_control", overlay.get_node_or_null("Control"))
	overlay.call("_show_public_trainer_card", {
		"userId": 42,
		"username": "misty",
		"displayName": "Misty",
		"createdAt": "2026-05-04T12:00:00Z",
		"guildName": "Cerulean Waves",
		"mapId": "private_internal_map_id",
		"appearance": {},
		"badges": {
			"badges": [
				{"region": "kanto", "badgeId": "boulder", "earned": true},
				{"region": "kanto", "badgeId": "cascade", "earned": true},
			],
		},
		"playtimeSeconds": 7200,
		"pvp": {
			"formatKey": "singles",
			"points": 30,
			"gamesPlayed": 5,
			"wins": 4,
			"losses": 1,
			"winRate": 80.0,
		},
	})
	await process_frame

	var popup := overlay.get("public_trainer_card_popup") as PanelContainer
	var tabs := popup.find_child("PublicTrainerCardTabs", true, false) as TabContainer if popup != null else null
	var overview_tab := tabs.get_node_or_null("Overview") as Control if tabs != null else null
	var badges_tab := tabs.get_node_or_null("Badges") as Control if tabs != null else null
	_check(popup != null, "public Trainer Card opens as a dedicated view")
	_check(
		popup != null
		and popup.get_combined_minimum_size().x <= 720.0
		and popup.get_combined_minimum_size().y <= 500.0,
		"public Trainer Card fits the designed popup bounds"
	)
	_check(
		tabs != null
		and tabs.get_tab_count() == 3
		and tabs.get_tab_title(0) == "Overview"
		and tabs.get_tab_title(1) == "Badges"
		and tabs.get_tab_title(2) == "PvP",
		"public Trainer Card exposes simple Overview, Badges and PvP navigation"
	)
	_check(
		tabs != null and tabs.get_tab_bar().focus_mode == Control.FOCUS_ALL,
		"public Trainer Card tabs support keyboard and controller focus"
	)
	_check(_find_label(popup, "Misty") != null, "public Trainer Card leads with trainer identity")
	_check(_find_label(popup, "Cerulean Waves") != null, "public Trainer Card shows Guild identity")
	_check(
		_find_label(overview_tab, "Gym Badges") == null and _find_label(overview_tab, "2 / 8") == null,
		"public Trainer Card keeps Gym Badges out of Overview"
	)
	_check(
		_find_label(badges_tab, "GYM BADGES · 2/8") != null,
		"public Trainer Card keeps Gym Badge progress in the Badges tab"
	)
	_check(_find_label(popup, "80%") != null, "public Trainer Card presents the PvP win rate")
	_check(
		_find_label(popup, "private_internal_map_id") == null,
		"public Trainer Card never exposes a raw internal map identifier"
	)
	var message_button := _find_button(popup, "Message")
	_check(
		message_button != null and message_button.focus_mode == Control.FOCUS_ALL,
		"public Trainer Card provides a focused primary social action"
	)

	localization_manager.call("set_locale", original_locale)
	for loader_property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader := overlay.get(loader_property) as Node
		if loader != null:
			loader.free()
	overlay.free()
	quit(1 if failed else 0)


func _find_label(node: Node, text: String) -> Label:
	if node == null:
		return null
	if node is Label and (node as Label).text == text:
		return node as Label
	for child: Node in node.get_children():
		var result := _find_label(child, text)
		if result != null:
			return result
	return null


func _find_button(node: Node, text: String) -> Button:
	if node == null:
		return null
	if node is Button and (node as Button).text == text:
		return node as Button
	for child: Node in node.get_children():
		var result := _find_button(child, text)
		if result != null:
			return result
	return null


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
