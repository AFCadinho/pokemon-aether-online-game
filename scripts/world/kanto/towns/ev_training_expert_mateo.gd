@tool
extends DialogueNPC

class_name EvTrainingExpertMateo

signal pokemon_selected(pokemon_id: int)

const QUEST_ID := "viridian_ev_training"
const MENTOR_TOPIC_MENU := preload("res://scripts/ui/mentor_topic_menu.gd")

var quest_reward_id := ""
var quest_reward_received_dialogue_id := ""
var quest_reward_completed_dialogue_id := ""
var choice_layer: CanvasLayer
var choice_root: Control


func interact_with_player(_player: Node2D) -> void:
	var metadata_response: Dictionary = await _load_npc_metadata()
	if not bool(metadata_response.get("success", false)):
		await show_dialogue(["I cannot begin the lesson right now."], display_name)
		return
	if StoryService.is_requirement_met(QUEST_ID, "return_to_mateo", "active"):
		await _claim_reward()
		return
	if StoryService.is_requirement_met(QUEST_ID, "allocate_training_evs", "active"):
		await _guide_allocation()
		return
	if StoryService.is_requirement_met(QUEST_ID, "defeat_training_targets", "active"):
		await _show_battle_progress()
		return
	if StoryService.is_requirement_met(QUEST_ID, "choose_focus", "active"):
		await _choose_focus()
		return
	if StoryService.is_requirement_met(QUEST_ID, "", "completed"):
		await _show_completed_help()
		return
	await show_dialogue()


func _apply_npc_metadata(metadata: Dictionary) -> void:
	super._apply_npc_metadata(metadata)
	quest_reward_id = str(metadata.get("questRewardId", "")).strip_edges()
	quest_reward_received_dialogue_id = str(metadata.get("questRewardReceivedDialogueId", "")).strip_edges()
	quest_reward_completed_dialogue_id = str(metadata.get("questRewardCompletedDialogueId", "")).strip_edges()


func _choose_focus() -> void:
	var response: Dictionary = await EvTrainingService.get_session()
	if not bool(response.get("success", false)):
		await GameErrorDialogService.show_response(response, "Could not prepare the EV lesson.")
		return
	var tutorial: Dictionary = response.get("tutorial", {})
	var party: Array = tutorial.get("party", []) as Array
	if party.is_empty():
		await show_dialogue(["Bring at least one Pokemon in your party and return to me."], display_name)
		return
	await show_dialogue([
		"EV means Effort Value. A Pokemon that participates in a victory stores the Effort Values granted by the defeated species.",
		"First choose one Pokemon to focus on. I will look at its natural strengths and select a useful stat for this lesson.",
		"After four victories, I will show you how to apply those stored points through Party, Summary, and the EVs tab.",
	], display_name)
	var pokemon_id := await _show_party_prompt(party)
	if pokemon_id <= 0:
		return
	var focus_response: Dictionary = await EvTrainingService.select_focus_pokemon(pokemon_id)
	if not bool(focus_response.get("success", false)):
		await GameErrorDialogService.show_response(focus_response, "Could not select that Pokemon for the lesson.")
		return
	var focus: Dictionary = focus_response.get("tutorial", {})
	await show_dialogue([
		"%s's final evolution, %s, is especially strong in %s. That will be our focus." % [str(focus.get("pokemonName", "Your Pokemon")), str(focus.get("trainingSpeciesName", focus.get("pokemonName", "its final evolution"))), _stat_label(str(focus.get("stat", "")))],
		"Defeat four %s in the practice field. %s must take part in each battle to earn the Effort Values." % [str(focus.get("targetSpeciesName", "targets")), str(focus.get("pokemonName", "Your Pokemon"))],
		"My assistants at either entrance will let you in free while the lesson is active.",
	], display_name)


func _show_battle_progress() -> void:
	var response: Dictionary = await EvTrainingService.get_session()
	var tutorial: Dictionary = response.get("tutorial", {})
	await show_dialogue([
		"%s has participated in %d of %d victories over %s." % [str(tutorial.get("pokemonName", "Your Pokemon")), int(tutorial.get("defeated", 0)), int(tutorial.get("requiredDefeats", 4)), str(tutorial.get("targetSpeciesName", "the target"))],
		"Use either assistant to enter the practice field. The selected Pokemon must participate for the victory to count.",
	], display_name)


func _guide_allocation() -> void:
	var response: Dictionary = await EvTrainingService.get_session()
	var tutorial: Dictionary = response.get("tutorial", {})
	await show_dialogue([
		"The four %s Effort Values are now stored on %s. They do not improve its stats until you assign them." % [_stat_label(str(tutorial.get("stat", ""))), str(tutorial.get("pokemonName", "your Pokemon"))],
		"Open Party, inspect its Summary, choose the EVs tab, and select %s. Allocate all four stored points there." % _stat_label(str(tutorial.get("stat", ""))),
	], display_name)
	get_tree().call_group(
		"ui_overlay",
		"open_ev_training_allocation",
		int(tutorial.get("pokemonId", 0)),
		str(tutorial.get("stat", ""))
	)


func _claim_reward() -> void:
	var result: Dictionary = await InventoryService.claim_npc_item_reward(quest_reward_id)
	if not bool(result.get("success", false)):
		await GameErrorDialogService.show_response(result, "Could not claim Mateo's reward.")
		return
	await show_dialogue(await _resolve_lines(
		quest_reward_received_dialogue_id,
		["Well done. Take this Macho Brace and keep training with a purpose."]
	))
	get_tree().call_group(
		"ui_overlay",
		"add_system_message",
		"EV training unlocked · Received Macho Brace"
	)
	if bool(result.get("claimed", false)):
		SfxManager.play("item_received")


func _show_completed_help() -> void:
	var greeting: Array[String] = [LocalizationManager.text("mentor.mateo.help.greeting")]
	if (
		not quest_reward_completed_dialogue_id.is_empty()
		and quest_reward_completed_dialogue_id != quest_reward_received_dialogue_id
	):
		greeting = await _resolve_lines(quest_reward_completed_dialogue_id, greeting)
	await show_dialogue(greeting)
	while true:
		var topic_id := await _choose_help_topic(
			LocalizationManager.text("mentor.mateo.help.title"),
			LocalizationManager.text("mentor.mateo.help.prompt"),
			[
				{"id": "basics", "label": LocalizationManager.text("mentor.mateo.help.topic.basics")},
				{"id": "earning", "label": LocalizationManager.text("mentor.mateo.help.topic.earning")},
				{"id": "allocating", "label": LocalizationManager.text("mentor.mateo.help.topic.allocating")},
				{"id": "limits", "label": LocalizationManager.text("mentor.mateo.help.topic.limits")},
			]
		)
		if topic_id.is_empty():
			return
		await show_dialogue(_mateo_help_lines(topic_id), display_name)


func _mateo_help_lines(topic_id: String) -> Array[String]:
	var keys: Array[String] = []
	match topic_id:
		"basics":
			keys = ["mentor.mateo.help.basics.1", "mentor.mateo.help.basics.2"]
		"earning":
			keys = ["mentor.mateo.help.earning.1", "mentor.mateo.help.earning.2"]
		"allocating":
			keys = ["mentor.mateo.help.allocating.1", "mentor.mateo.help.allocating.2"]
		"limits":
			keys = ["mentor.mateo.help.limits.1", "mentor.mateo.help.limits.2"]
	var lines: Array[String] = []
	for key: String in keys:
		lines.append(LocalizationManager.text(key))
	return lines


func _choose_help_topic(title: String, prompt: String, topics: Array[Dictionary]) -> String:
	var menu := MENTOR_TOPIC_MENU.new()
	add_child(menu)
	var topic_id: String = await menu.choose_topic(
		title,
		prompt,
		topics,
		LocalizationManager.text("ui.mentor_help.eyebrow"),
		LocalizationManager.text("common.close")
	)
	menu.queue_free()
	return topic_id


func _show_party_prompt(party: Array) -> int:
	_ensure_choice_panel()
	var list := choice_root.get_node("Panel/Margin/Layout/Scroll/List") as VBoxContainer
	for child in list.get_children():
		child.queue_free()
	for candidate_value: Variant in party:
		if candidate_value is not Dictionary:
			continue
		var candidate := candidate_value as Dictionary
		var button := Button.new()
		var is_eligible := bool(candidate.get("eligible", false))
		var species_name := str(candidate.get("speciesName", candidate.get("name", "Pokemon")))
		var training_species_name := str(candidate.get("trainingSpeciesName", species_name))
		var evolution_hint := " → %s" % training_species_name if training_species_name != species_name else ""
		button.text = "%s%s   •   Lv. %d   •   %s" % [str(candidate.get("name", "Pokemon")), evolution_hint, int(candidate.get("level", 1)), _stat_label(str(candidate.get("stat", "")))]
		button.custom_minimum_size = Vector2(0, 46)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_color_override("font_color", Color("#f4f0de"))
		button.add_theme_color_override("font_hover_color", Color("#ffffff"))
		button.add_theme_color_override("font_disabled_color", Color("#8e99a7"))
		button.add_theme_stylebox_override("normal", _choice_button_style(Color("#0b1a2bf5"), Color("#315070")))
		button.add_theme_stylebox_override("hover", _choice_button_style(Color("#14314cf8"), Color("#60d3ff")))
		button.add_theme_stylebox_override("pressed", _choice_button_style(Color("#091521"), Color("#e3bd68")))
		button.add_theme_stylebox_override("disabled", _choice_button_style(Color("#101722d9"), Color("#283b4d")))
		button.disabled = not is_eligible
		button.tooltip_text = "This Pokemon has no room for four more EVs." if button.disabled else "%s is recommended for %s based on %s's final evolution." % [str(candidate.get("name", "This Pokemon")), _stat_label(str(candidate.get("stat", ""))), training_species_name]
		button.pressed.connect(_select_pokemon.bind(int(candidate.get("pokemonId", 0))))
		list.add_child(button)
	var cancel := Button.new()
	cancel.text = LocalizationManager.text("common.cancel")
	cancel.custom_minimum_size = Vector2(0, 42)
	cancel.add_theme_font_size_override("font_size", 15)
	cancel.add_theme_color_override("font_color", Color("#d8e0e8"))
	cancel.add_theme_stylebox_override("normal", _choice_button_style(Color("#121e2cf5"), Color("#496075")))
	cancel.add_theme_stylebox_override("hover", _choice_button_style(Color("#26384af5"), Color("#8fa8bb")))
	cancel.pressed.connect(_select_pokemon.bind(0))
	list.add_child(cancel)
	choice_root.show()
	return await pokemon_selected


func _ensure_choice_panel() -> void:
	if choice_root != null and is_instance_valid(choice_root):
		return
	choice_layer = CanvasLayer.new()
	choice_layer.layer = 90
	add_child(choice_layer)
	choice_root = Control.new()
	choice_root.name = "ChoiceRoot"
	choice_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	choice_root.mouse_filter = Control.MOUSE_FILTER_STOP
	choice_layer.add_child(choice_root)
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#02060bd9")
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	choice_root.add_child(backdrop)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.size = Vector2(560, 400)
	panel.position = -panel.size * 0.5
	panel.add_theme_stylebox_override("panel", _choice_panel_style())
	choice_root.add_child(panel)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 20)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	var title := Label.new()
	title.text = "Choose a Pokémon to train"
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("#f4f0de"))
	layout.add_child(title)
	var description := Label.new()
	description.text = "Mateo will choose the most useful stat for this EV lesson."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 13)
	description.add_theme_color_override("font_color", Color("#afbdca"))
	layout.add_child(description)
	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 4)
	layout.add_child(separator)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 7)
	scroll.add_child(list)
	choice_root.hide()


func _choice_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#081522fa")
	style.border_color = Color("#d4af5d")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color("#000000a8")
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 6)
	return style


func _choice_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _select_pokemon(pokemon_id: int) -> void:
	choice_root.hide()
	pokemon_selected.emit(pokemon_id)


func _resolve_lines(dialogue_id: String, fallback: Array) -> Array[String]:
	return await NpcDialogueService.resolve_lines(dialogue_id, fallback, "EvTrainingExpertMateo")


func _stat_label(stat: String) -> String:
	match stat:
		"hp": return "HP"
		"atk": return "Attack"
		"def": return "Defense"
		"spa": return "Special Attack"
		"spd": return "Special Defense"
		"spe": return "Speed"
	return stat.to_upper()
