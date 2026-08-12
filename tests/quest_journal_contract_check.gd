extends SceneTree

const QUEST_JOURNAL_VIEW := preload("res://scripts/ui/quest_journal_view.gd")
const QUEST_LOCALIZATION_KEYS: Array[String] = [
	"ui.quest.open_log",
	"ui.quest.log_title",
	"ui.quest.log_subtitle",
	"ui.quest.main_story",
	"ui.quest.side_quest",
	"ui.quest.list_heading",
	"ui.quest.objectives",
	"ui.quest.rewards",
	"ui.quest.empty",
	"ui.quest.empty_filter",
	"ui.quest.empty_title",
	"ui.quest.empty_detail",
	"ui.quest.filter.all",
	"ui.quest.filter.main",
	"ui.quest.filter.side",
	"ui.quest.filter.completed",
	"ui.quest.section.active",
	"ui.quest.section.available",
	"ui.quest.section.history",
	"ui.quest.offer_prompt",
	"ui.quest.offer_decline_hint",
	"ui.quest.offer_accepting",
	"ui.quest.offer_error",
	"ui.quest.status.available",
	"ui.quest.status.active",
	"ui.quest.status.completed",
	"ui.quest.status.failed",
	"story.kanto.choose_starter.title",
	"story.kanto.choose_starter.summary",
	"story.kanto.choose_starter.talk_to_father",
	"story.kanto.choose_starter.choose_starter",
	"story.kanto.train_starter.title",
	"story.kanto.train_starter.summary",
	"story.kanto.train_starter.reach_level_10",
	"story.kanto.gary_starter_battle.title",
	"story.kanto.gary_starter_battle.summary",
	"story.kanto.gary_starter_battle.battle_gary",
	"story.kanto.oaks_parcel.title",
	"story.kanto.oaks_parcel.summary",
	"story.kanto.oaks_parcel.talk_to_oak",
	"story.kanto.oaks_parcel.collect_parcel",
	"story.kanto.oaks_parcel.return_to_oak",
	"story.kanto.get_town_map.title",
	"story.kanto.get_town_map.summary",
	"story.kanto.get_town_map.visit_father",
	"story.kanto.get_town_map.receive_town_map",
	"story.kanto.catch_mankey.title",
	"story.kanto.catch_mankey.summary",
	"story.kanto.catch_mankey.catch",
	"story.kanto.catch_mankey.return",
	"story.kanto.reach_viridian_city.title",
	"story.kanto.reach_viridian_city.summary",
	"story.kanto.reach_viridian_city.travel",
	"story.kanto.reach_viridian_city.return",
	"story.kanto.trainer_school.title",
	"story.kanto.trainer_school.summary",
	"story.kanto.trainer_school.meet_dadinho",
	"story.kanto.trainer_school.continue_to_pewter",
	"story.kanto.challenge_pewter_gym.title",
	"story.kanto.challenge_pewter_gym.summary",
	"story.kanto.challenge_pewter_gym.challenge_brock",
]

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	get_root().size = Vector2i(1280, 720)
	var story_service := get_root().get_node("StoryService")
	var journal_service := get_root().get_node("QuestJournalService")
	var localization_manager := get_root().get_node("LocalizationManager")
	for locale: String in localization_manager.get_supported_locales():
		var catalog: Dictionary = localization_manager.get_catalog(locale)
		for key: String in QUEST_LOCALIZATION_KEYS:
			_expect(catalog.has(key), "%s quest catalog contains %s" % [locale, key])
	var english_catalog: Dictionary = localization_manager.get_catalog("en")
	_expect(
		str(english_catalog.get("story.kanto.trainer_school.meet_dadinho", ""))
		== "Go to the Trainer School in Viridian City and see if you can learn something new.",
		"Trainer School objective invites exploration without revealing Dadinho"
	)
	story_service.apply_story({
		"revision": 1,
		"quests": [{
			"questId": "choose_starter",
			"storylineId": "kanto_main",
			"definitionVersion": 1,
			"questType": "main",
			"titleKey": "story.kanto.choose_starter.title",
			"summaryKey": "story.kanto.choose_starter.summary",
			"status": "active",
			"steps": [
				{
					"stepId": "talk_to_father",
					"objectiveKey": "story.kanto.choose_starter.talk_to_father",
					"status": "active",
					"currentValue": 0,
					"targetValue": 1,
				},
				{
					"stepId": "choose_starter",
					"objectiveKey": "story.kanto.choose_starter.choose_starter",
					"status": "inactive",
					"currentValue": 0,
					"targetValue": 1,
				},
			],
		}, {
			"questId": "help_neighbor",
			"storylineId": "pallet_side",
			"definitionVersion": 1,
			"questType": "side",
			"titleKey": "",
			"summaryKey": "",
			"status": "active",
			"steps": [{
				"stepId": "find_parcel",
				"objectiveKey": "",
				"status": "active",
				"currentValue": 0,
				"targetValue": 1,
			}],
		}, {
			"questId": "lost_keepsake",
			"storylineId": "pallet_side_offer",
			"definitionVersion": 1,
			"questType": "side",
			"titleKey": "",
			"summaryKey": "",
			"status": "available",
			"steps": [{
				"stepId": "find_keepsake",
				"objectiveKey": "",
				"status": "inactive",
				"currentValue": 0,
				"targetValue": 1,
			}],
		}],
	})

	var active_quest: Dictionary = journal_service.get_active_main_quest()
	var active_objective: Dictionary = journal_service.get_active_objective(active_quest)
	_expect(active_quest.get("questId", "") == "choose_starter", "journal selects the active MSQ")
	_expect(
		journal_service.get_active_side_quests().size() == 1,
		"journal exposes active side quests without replacing the active MSQ"
	)
	_expect(
		journal_service.get_entries().size() == 2,
		"available side-quest offers stay hidden until the player accepts them"
	)
	_expect(
		active_objective.get("stepId", "") == "talk_to_father",
		"journal selects the active objective"
	)
	_expect(
		journal_service.get_visible_steps(active_quest).size() == 1,
		"journal hides inactive future objectives"
	)

	var host := Control.new()
	get_root().add_child(host)
	host.position = Vector2.ZERO
	host.size = Vector2(1280, 720)
	var view = QUEST_JOURNAL_VIEW.new()
	host.add_child(view)
	view.set_tracker_top_offset(152.0)
	view.set_tracker_top_offset(152.0)
	await process_frame
	_expect(
		view.tracker_panel.size.y == 90.0,
		"pre-layout rights updates cannot stretch the HUD tracker"
	)
	view.set_tracker_top_offset(76.0)
	_expect(view.tracker_panel.visible, "HUD objective tracker is visible for an active objective")
	var tracker_rect: Rect2 = view.tracker_panel.get_global_rect()
	_expect(
		tracker_rect.position.x > 640.0
		and tracker_rect.end.x <= 1280.0
		and tracker_rect.position.y >= 57.0
		and tracker_rect.end.y <= 166.0,
		"HUD objective tracker aligns below the right action bar"
	)
	_expect(
		view.tracker_objective_label.text == "› Go downstairs and speak with your father.",
		"HUD tracker resolves the objective localization key"
	)
	_expect(
		view.side_tracker_panel.visible
		and view.side_tracker_panel.size.y == 78.0
		and view.side_tracker_panel.get_global_rect().position.y == 174.0
		and view.side_tracker_title_label.text == "Help Neighbor"
		and view.side_tracker_objective_label.text == "› Find Parcel",
		"HUD renders active side-quest data below the main story"
	)
	_expect(view.get_visible_tracker_count() == 2, "HUD reports both active quest trackers")
	view.tracker_collapse_button.pressed.emit()
	_expect(
		not view.tracker_panel.visible
		and not view.side_tracker_panel.visible
		and view.tracker_collapse_button.visible
		and view.get_visible_tracker_count() == 0,
		"quest tracker group collapses without losing its reopen control"
	)
	view.tracker_collapse_button.pressed.emit()
	_expect(
		view.tracker_panel.visible
		and view.side_tracker_panel.visible
		and view.get_visible_tracker_count() == 2,
		"quest tracker group expands with its data-driven contents intact"
	)
	view.set_tracker_top_offset(152.0)
	_expect(
		view.tracker_panel.get_global_rect().position.y == 152.0
		and view.tracker_panel.size.y == 90.0,
		"HUD tracker moves below a rights-based action bar without stretching"
	)
	view.set_tracker_top_offset(152.0)
	_expect(view.tracker_panel.size.y == 90.0, "repeated rights layout updates keep the tracker compact")
	view.set_tracker_top_offset(76.0)
	view.open_journal()
	await process_frame
	_expect(view.is_journal_open(), "quest button target opens the full journal")
	_expect(
		view.get_journal_panel().get_global_rect().end.x <= 1280.0
		and view.get_journal_panel().get_global_rect().end.y <= 720.0,
		"quest journal fits the minimum game viewport"
	)
	for locale: String in localization_manager.get_supported_locales():
		localization_manager.set_locale(locale)
		await process_frame
		var journal_rect: Rect2 = view.get_journal_panel().get_global_rect()
		_expect(
			journal_rect.position.x >= 0.0
			and journal_rect.position.y >= 0.0
			and journal_rect.end.x <= 1280.0
			and journal_rect.end.y <= 720.0,
			"quest journal stays in bounds for %s" % locale
		)
	localization_manager.set_locale("en")
	await process_frame
	_expect(view.detail_steps.get_child_count() == 1, "journal renders only revealed objectives")
	_expect(view.filter_buttons["all"].text == "All  2", "all filter includes accepted quests only")
	_expect(view.filter_buttons["main"].text == "Main  1", "main filter reports its quest count")
	_expect(view.filter_buttons["side"].text == "Side  1", "side filter includes accepted side quests")
	_expect(
		view.filter_buttons["completed"].text == "Completed  0",
		"completed filter reports its quest count"
	)
	view.set_filter("side")
	await process_frame
	_expect(
		view.detail_type_label.text.begins_with("SIDE QUEST"),
		"side filter selects and identifies a side quest"
	)
	_expect(view.detail_title_label.text == "Help Neighbor", "side quests have safe title fallbacks")
	view.call("_on_quest_selected", "help_neighbor")
	_expect(
		view.tracker_title_label.text == "A Journey Begins"
		and view.tracker_objective_label.text == "› Go downstairs and speak with your father.",
		"side quest selection does not replace the MSQ HUD tracker"
	)
	view.set_filter("completed")
	await process_frame
	_expect(view.empty_list_label.visible, "empty filters render the dedicated empty state")
	_expect(
		view.detail_type_label.text == "QUEST JOURNAL",
		"an empty filter uses a neutral journal detail state"
	)
	view.set_filter("all")
	await process_frame
	localization_manager.set_locale("nl")
	await process_frame
	_expect(
		view.tracker_objective_label.text == "› Ga naar beneden en praat met je vader.",
		"HUD tracker refreshes when the player changes language"
	)
	_expect(view.side_tracker_title_label.text == "Help Neighbor", "side quests keep safe localized fallbacks")
	localization_manager.set_locale("en")
	await process_frame

	story_service.apply_story({
		"revision": 2,
		"quests": [{
			"questId": "choose_starter",
			"storylineId": "kanto_main",
			"definitionVersion": 1,
			"questType": "main",
			"titleKey": "story.kanto.choose_starter.title",
			"summaryKey": "story.kanto.choose_starter.summary",
			"status": "active",
			"steps": [
				{
					"stepId": "talk_to_father",
					"objectiveKey": "story.kanto.choose_starter.talk_to_father",
					"status": "completed",
					"currentValue": 1,
					"targetValue": 1,
				},
				{
					"stepId": "choose_starter",
					"objectiveKey": "story.kanto.choose_starter.choose_starter",
					"status": "active",
					"currentValue": 0,
					"targetValue": 1,
				},
			],
		}],
	})
	await process_frame
	_expect(
		view.tracker_objective_label.text == "› Visit Professor Oak at his lab.",
		"HUD tracker updates automatically when story progress changes"
	)
	_expect(
		view.tracker_panel.visible
		and not view.side_tracker_panel.visible
		and view.get_visible_tracker_count() == 1,
		"side tracker disappears when no active side quest remains"
	)
	_expect(view.detail_steps.get_child_count() == 2, "journal retains completed objective history")

	story_service.apply_story({
		"revision": 3,
		"quests": [{
			"questId": "help_neighbor",
			"storylineId": "pallet_side",
			"definitionVersion": 1,
			"questType": "side",
			"titleKey": "",
			"summaryKey": "",
			"status": "active",
			"steps": [{
				"stepId": "find_parcel",
				"objectiveKey": "",
				"status": "active",
				"currentValue": 0,
				"targetValue": 1,
			}],
		}],
	})
	await process_frame
	_expect(
		not view.tracker_panel.visible
		and view.side_tracker_panel.visible
		and view.side_tracker_panel.get_global_rect().position.y == 76.0
		and view.get_visible_tracker_count() == 1,
		"side quests occupy the first tracker position when no main quest is active"
	)

	view.close_journal()
	story_service.reset_story()
	await process_frame
	_expect(
		not view.tracker_panel.visible
		and not view.side_tracker_panel.visible
		and not view.tracker_collapse_button.visible
		and view.get_visible_tracker_count() == 0,
		"quest tracker group disappears when no active objectives remain"
	)
	host.queue_free()
	_verify_integration_contract()
	quit(1 if failed else 0)


func _verify_integration_contract() -> void:
	var overlay := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	_expect(
		overlay.contains("quest_journal_view.open_journal()")
		and overlay.contains("func _refresh_quest_tracker_layout()")
		and overlay.contains('for panel_id in ["actions", "dex_actions"]')
		and overlay.contains("quest_journal_view.set_tracker_top_offset")
		and overlay.contains("tracker_layout_changed.connect(_refresh_quest_tracker_layout)")
		and overlay.contains("quest_journal_view.get_visible_tracker_count()")
		and not overlay.contains("Quest Log is not implemented yet."),
		"HUD quest integration opens the journal and dynamically clears the right-side UI"
	)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
