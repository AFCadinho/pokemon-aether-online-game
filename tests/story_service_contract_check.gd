extends SceneTree

var failed := false
var emitted_revisions: Array[int] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var service := get_root().get_node_or_null("StoryService")
	_expect(service != null, "StoryService is registered as an autoload")
	if service == null:
		quit(1)
		return

	service.story_changed.connect(_on_story_changed)
	service.reset_story()
	service.apply_story({
		"revision": 7,
		"quests": [
			{
				"questId": "kanto_pallet_intro",
				"storylineId": "kanto_main",
				"definitionVersion": 2,
				"questType": "main",
				"titleKey": "story.kanto.choose_starter.title",
				"summaryKey": "story.kanto.choose_starter.summary",
				"status": "active",
				"steps": [
					{
						"stepId": "meet_oak",
						"objectiveKey": "story.kanto.choose_starter.choose_starter",
						"status": "active",
						"currentValue": 0,
						"targetValue": 1,
						"activatedAt": "2026-07-31T08:00:00Z",
						"completedAt": null,
						"serverOnly": "discarded",
					},
				],
				"startedAt": "2026-07-31T08:00:00Z",
				"completedAt": null,
				"serverOnly": "discarded",
			},
			"malformed quest",
		],
		"serverOnly": "discarded",
	})

	var story: Dictionary = service.get_story()
	var quests: Array = story.get("quests", [])
	_expect(service.get_revision() == 7, "apply exposes the authoritative revision")
	_expect(quests.size() == 1, "projection ignores malformed quest values")
	_expect(not story.has("serverOnly"), "projection only keeps story contract fields")
	if quests.size() == 1:
		var quest: Dictionary = quests[0] as Dictionary
		var steps: Array = quest.get("steps", [])
		_expect(quest.get("questId", "") == "kanto_pallet_intro", "quest identity is projected")
		_expect(quest.get("storylineId", "") == "kanto_main", "storyline identity is projected")
		_expect(quest.get("questType", "") == "main", "quest type is projected")
		_expect(
			quest.get("titleKey", "") == "story.kanto.choose_starter.title",
			"quest title localization key is projected"
		)
		_expect(not quest.has("serverOnly"), "projection only keeps quest contract fields")
		_expect(quest.get("completedAt", "unexpected") == null, "nullable quest timestamps remain null")
		if steps.size() == 1:
			var step: Dictionary = steps[0] as Dictionary
			_expect(step.get("targetValue", 0) == 1, "step progress is projected")
			_expect(
				step.get("objectiveKey", "") == "story.kanto.choose_starter.choose_starter",
				"objective localization key is projected"
			)
			_expect(not step.has("serverOnly"), "projection only keeps step contract fields")
			step["currentValue"] = 99
		quest["status"] = "mutated"
		story["revision"] = 99

	var fresh_story: Dictionary = service.get_story()
	var fresh_quest: Dictionary = (fresh_story.get("quests", []) as Array)[0] as Dictionary
	var fresh_step: Dictionary = (fresh_quest.get("steps", []) as Array)[0] as Dictionary
	_expect(fresh_story.get("revision", 0) == 7, "story getter returns a deep copy")
	_expect(fresh_quest.get("status", "") == "active", "nested quest data cannot mutate service state")
	_expect(fresh_step.get("currentValue", -1) == 0, "nested step data cannot mutate service state")
	var bounded_story: Dictionary = service.project_story({
		"revision": -4,
		"quests": [{
			"questId": "bounded_projection",
			"storylineId": "test_storyline",
			"definitionVersion": 0,
			"steps": [{"stepId": "counter", "currentValue": 7, "targetValue": 3}],
		}],
	})
	var bounded_quest: Dictionary = (bounded_story.get("quests", []) as Array)[0] as Dictionary
	var bounded_step: Dictionary = (bounded_quest.get("steps", []) as Array)[0] as Dictionary
	_expect(bounded_story.get("revision", -1) == 0, "projection rejects negative revisions")
	_expect(bounded_quest.get("definitionVersion", 0) == 1, "projection keeps versions positive")
	_expect(bounded_step.get("currentValue", 0) == 3, "projection caps objective progress at its target")

	var quest_list: Array = service.get_quests()
	(quest_list[0] as Dictionary)["status"] = "mutated again"
	_expect(
		service.get_quest("kanto_pallet_intro").get("status", "") == "active",
		"quest getters return deep copies"
	)

	service.apply_story("malformed story")
	_expect(service.get_revision() == 0, "malformed apply safely resets the revision")
	_expect(service.get_quests().is_empty(), "malformed apply safely clears quests")
	service.reset_story()
	_expect(emitted_revisions == [0, 7, 0, 0], "apply and reset emit their resulting revisions")

	_verify_integration_contract()
	quit(1 if failed else 0)


func _verify_integration_contract() -> void:
	var project := _source("res://project.godot")
	var game_state_service := _source("res://scripts/services/player_game_state_service.gd")
	var loading := _source("res://scripts/ui/loading_screen.gd")
	var auth := _source("res://scripts/services/auth_service.gd")
	var overlay := _source("res://scripts/ui/ui_overlay.gd")
	var oak := _source("res://scripts/world/kanto/towns/pallet_town/oak.gd")
	_expect(
		project.contains('StoryService="*res://scripts/services/story_service.gd"'),
		"project registers the story projection"
	)
	_expect(
		project.contains('QuestJournalService="*res://scripts/services/quest_journal_service.gd"'),
		"project registers the quest journal presentation service"
	)
	_expect(
		game_state_service.contains('const PLAYER_STORY_ENDPOINT := "/game/story"')
		and game_state_service.contains('const STORY_BOOTSTRAP_ENDPOINT := "/game/story/bootstrap"')
		and game_state_service.contains("func bootstrap_story() -> Dictionary:")
		and game_state_service.contains('"story": story'),
		"game state service exposes bootstrap, profile, and refresh story payloads"
	)
	_expect(
		loading.contains("await PlayerGameStateService.bootstrap_story()")
		and loading.find("await PlayerGameStateService.bootstrap_story()")
		< loading.find("await PlayerGameStateService.load_player_profile()")
		and loading.contains('StoryService.apply_story(_dictionary_from_value(profile_response.get("story", {})))'),
		"loading bootstraps before hydrating the aggregate story projection"
	)
	_expect(
		oak.contains("await PlayerGameStateService.refresh_story()"),
		"the authoritative starter claim refreshes completed quest progress"
	)
	_expect(
		auth.contains("StoryService.reset_story()")
		and overlay.contains("StoryService.reset_story()"),
		"account changes and new-game reset clear story state"
	)


func _on_story_changed(revision: int) -> void:
	emitted_revisions.append(revision)


func _source(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_expect(false, "can read %s" % path)
		return ""
	return file.get_as_text()


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
