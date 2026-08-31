@tool
extends DialogueNPC

class_name AetherClashGuideNPC

const MENTOR_TOPIC_MENU := preload("res://scripts/ui/mentor_topic_menu.gd")

const ROOT_TOPICS: Array[Dictionary] = [
	{
		"id": "overview",
		"label_key": "npc.aether_clash_guide.topic.overview",
		"line_keys": [
			"npc.aether_clash_guide.answer.overview.1",
			"npc.aether_clash_guide.answer.overview.2",
		],
	},
	{
		"id": "guild_duel",
		"label_key": "npc.aether_clash_guide.topic.guild_duel",
		"mode_id": "guild_duel",
	},
	{
		"id": "battle_royale",
		"label_key": "npc.aether_clash_guide.topic.battle_royale",
		"mode_id": "battle_royale",
	},
	{
		"id": "battle_flow",
		"label_key": "npc.aether_clash_guide.topic.battle_flow",
		"line_keys": [
			"npc.aether_clash_guide.answer.battle_flow.1",
			"npc.aether_clash_guide.answer.battle_flow.2",
			"npc.aether_clash_guide.answer.battle_flow.3",
		],
	},
	{
		"id": "rules",
		"label_key": "npc.aether_clash_guide.topic.rules",
		"line_keys": [
			"npc.aether_clash_guide.answer.rules.1",
			"npc.aether_clash_guide.answer.rules.2",
			"npc.aether_clash_guide.answer.rules.3",
		],
	},
	{
		"id": "joining",
		"label_key": "npc.aether_clash_guide.topic.joining",
		"line_keys": [
			"npc.aether_clash_guide.answer.joining.1",
			"npc.aether_clash_guide.answer.joining.2",
			"npc.aether_clash_guide.answer.joining.3",
		],
	},
]

const MODE_GUIDES: Dictionary = {
	"guild_duel": {
		"title_key": "npc.aether_clash_guide.guild_duel.title",
		"prompt_key": "npc.aether_clash_guide.guild_duel.prompt",
		"topics": [
			{
				"id": "challenges",
				"label_key": "npc.aether_clash_guide.guild_duel.topic.challenges",
				"line_keys": [
					"npc.aether_clash_guide.answer.guild_duel.challenges.1",
					"npc.aether_clash_guide.answer.guild_duel.challenges.2",
				],
			},
			{
				"id": "entry",
				"label_key": "npc.aether_clash_guide.guild_duel.topic.entry",
				"line_keys": [
					"npc.aether_clash_guide.answer.guild_duel.entry.1",
					"npc.aether_clash_guide.answer.guild_duel.entry.2",
					"npc.aether_clash_guide.answer.guild_duel.entry.3",
				],
			},
			{
				"id": "winning",
				"label_key": "npc.aether_clash_guide.guild_duel.topic.winning",
				"line_keys": [
					"npc.aether_clash_guide.answer.guild_duel.winning.1",
					"npc.aether_clash_guide.answer.guild_duel.winning.2",
				],
			},
			{
				"id": "matchmaking",
				"label_key": "npc.aether_clash_guide.guild_duel.topic.matchmaking",
				"line_keys": [
					"npc.aether_clash_guide.answer.guild_duel.matchmaking.1",
					"npc.aether_clash_guide.answer.guild_duel.matchmaking.2",
				],
			},
		],
	},
	"battle_royale": {
		"title_key": "npc.aether_clash_guide.battle_royale.title",
		"prompt_key": "npc.aether_clash_guide.battle_royale.prompt",
		"topics": [
			{
				"id": "format",
				"label_key": "npc.aether_clash_guide.battle_royale.topic.format",
				"line_keys": [
					"npc.aether_clash_guide.answer.battle_royale.format.1",
					"npc.aether_clash_guide.answer.battle_royale.format.2",
				],
			},
			{
				"id": "events",
				"label_key": "npc.aether_clash_guide.battle_royale.topic.events",
				"line_keys": [
					"npc.aether_clash_guide.answer.battle_royale.events.1",
					"npc.aether_clash_guide.answer.battle_royale.events.2",
				],
			},
			{
				"id": "winning",
				"label_key": "npc.aether_clash_guide.battle_royale.topic.winning",
				"line_keys": [
					"npc.aether_clash_guide.answer.battle_royale.winning.1",
					"npc.aether_clash_guide.answer.battle_royale.winning.2",
				],
			},
		],
	},
}


func _prefetches_dialogue_metadata_on_approach() -> bool:
	return false


func _loads_pickpocket_profile_from_npc_metadata() -> bool:
	# The guide is entirely client-authored and is not a thieving target.
	return false


func interact_with_player(_player: Node2D) -> void:
	await show_dialogue(
		[LocalizationManager.text("npc.aether_clash_guide.intro")],
		display_name
	)
	while true:
		var topic_id := await _choose_root_topic()
		if topic_id.is_empty():
			return
		var topic := _topic_by_id(ROOT_TOPICS, topic_id)
		var mode_id := str(topic.get("mode_id", "")).strip_edges()
		if not mode_id.is_empty():
			await _show_mode_guide(mode_id)
			continue
		await show_dialogue(_localized_lines(topic), display_name)


func _choose_root_topic() -> String:
	return await _choose_topic(
		LocalizationManager.text("npc.aether_clash_guide.menu.title"),
		LocalizationManager.text("npc.aether_clash_guide.menu.prompt"),
		ROOT_TOPICS,
		LocalizationManager.text("npc.aether_clash_guide.menu.close"),
		2,
		true
	)


func _show_mode_guide(mode_id: String) -> void:
	var guide := _dictionary(MODE_GUIDES.get(mode_id, {}))
	if guide.is_empty():
		return
	var topics := _dictionary_array(guide.get("topics", []))
	while true:
		var topic_id := await _choose_topic(
			LocalizationManager.text(str(guide.get("title_key", ""))),
			LocalizationManager.text(str(guide.get("prompt_key", ""))),
			topics,
			LocalizationManager.text("npc.aether_clash_guide.menu.back"),
			2,
			true
		)
		if topic_id.is_empty():
			return
		await show_dialogue(_localized_lines(_topic_by_id(topics, topic_id)), display_name)


func _choose_topic(
	title: String,
	prompt: String,
	topic_definitions: Array[Dictionary],
	close_text: String,
	column_count: int = 1,
	compact: bool = false
) -> String:
	var menu := MENTOR_TOPIC_MENU.new()
	add_child(menu)
	var topic_id: String = await menu.choose_topic(
		title,
		prompt,
		_localized_topics(topic_definitions),
		LocalizationManager.text("npc.aether_clash_guide.menu.eyebrow"),
		close_text,
		column_count,
		compact
	)
	menu.queue_free()
	return topic_id


func _localized_topics(topic_definitions: Array[Dictionary]) -> Array[Dictionary]:
	var topics: Array[Dictionary] = []
	for definition: Dictionary in topic_definitions:
		topics.append({
			"id": str(definition.get("id", "")),
			"label": LocalizationManager.text(str(definition.get("label_key", ""))),
		})
	return topics


func _localized_lines(topic: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var line_keys_value: Variant = topic.get("line_keys", [])
	if not line_keys_value is Array:
		return lines
	for key_value: Variant in line_keys_value as Array:
		var key := str(key_value).strip_edges()
		if not key.is_empty():
			lines.append(LocalizationManager.text(key))
	return lines


func _topic_by_id(topics: Array[Dictionary], topic_id: String) -> Dictionary:
	for topic: Dictionary in topics:
		if str(topic.get("id", "")) == topic_id:
			return topic
	return {}


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var dictionaries: Array[Dictionary] = []
	if value is Array:
		for item: Variant in value as Array:
			if item is Dictionary:
				dictionaries.append(item as Dictionary)
	return dictionaries


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}
