extends Control

const ITEM_ICON_ROOT := "res://assets/items/icons/"

signal dialogue_finished
signal quest_offer_resolved(accepted: bool)

@onready var panel_container: Panel = $PanelContainer
@onready var name_label: Label = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/NPCName
@onready var portrait_panel: Panel = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/PortraitPanel
@onready var npc_sprite: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/PortraitPanel/PortraitMargin/NPCSprite
@onready var text_label: RichTextLabel = $PanelContainer/MarginContainer/HBoxContainer/Panel/MarginContainer/VBoxContainer/RichTextLabel
@onready var quest_offer_content: VBoxContainer = $PanelContainer/MarginContainer/HBoxContainer/Panel/MarginContainer/VBoxContainer/QuestOfferContent
@onready var quest_offer_type_label: Label = $PanelContainer/MarginContainer/HBoxContainer/Panel/MarginContainer/VBoxContainer/QuestOfferContent/QuestTypeLabel
@onready var quest_offer_title_label: Label = $PanelContainer/MarginContainer/HBoxContainer/Panel/MarginContainer/VBoxContainer/QuestOfferContent/QuestTitleLabel
@onready var quest_offer_summary_label: Label = $PanelContainer/MarginContainer/HBoxContainer/Panel/MarginContainer/VBoxContainer/QuestOfferContent/QuestSummaryLabel
@onready var quest_offer_objective_heading: Label = $PanelContainer/MarginContainer/HBoxContainer/Panel/MarginContainer/VBoxContainer/QuestOfferContent/ObjectiveHeading
@onready var quest_offer_objective_label: Label = $PanelContainer/MarginContainer/HBoxContainer/Panel/MarginContainer/VBoxContainer/QuestOfferContent/ObjectiveLabel
@onready var quest_offer_reward_heading: Label = $PanelContainer/MarginContainer/HBoxContainer/Panel/MarginContainer/VBoxContainer/QuestOfferContent/RewardHeading
@onready var quest_offer_reward_icon: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/Panel/MarginContainer/VBoxContainer/QuestOfferContent/RewardCard/RewardMargin/RewardRow/RewardIcon
@onready var quest_offer_reward_label: Label = $PanelContainer/MarginContainer/HBoxContainer/Panel/MarginContainer/VBoxContainer/QuestOfferContent/RewardCard/RewardMargin/RewardRow/RewardLabel
@onready var quest_offer_status_label: Label = $PanelContainer/MarginContainer/HBoxContainer/Panel/MarginContainer/VBoxContainer/QuestOfferStatus
@onready var quest_offer_actions: HBoxContainer = $PanelContainer/MarginContainer/HBoxContainer/Panel/MarginContainer/VBoxContainer/QuestOfferActions
@onready var quest_offer_decline_button: Button = $PanelContainer/MarginContainer/HBoxContainer/Panel/MarginContainer/VBoxContainer/QuestOfferActions/DeclineButton
@onready var quest_offer_accept_button: Button = $PanelContainer/MarginContainer/HBoxContainer/Panel/MarginContainer/VBoxContainer/QuestOfferActions/AcceptButton
@onready var continue_arrow: Label = $PanelContainer/MarginContainer/HBoxContainer/ConitinueArrow

var default_mugshot: Texture2D

var is_open := false
var just_started := false
var quest_offer_open := false
var quest_offer_pending := false
var offered_quest: Dictionary = {}

var lines: Array = []
var current_line_index := 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	default_mugshot = npc_sprite.texture
	quest_offer_decline_button.pressed.connect(_on_quest_offer_declined)
	quest_offer_accept_button.pressed.connect(_on_quest_offer_accepted)
	hide_dialogue()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if not is_open:
		return
	if quest_offer_open:
		return
	
	if just_started:
		just_started = false
		return
		
	if Input.is_action_just_pressed("interact"):
		current_line_index += 1
		
		if current_line_index >= lines.size():
			hide_dialogue()
		else:
			show_current_line()
	
func start_dialogue(new_lines: Array, speaker_name := "", mugshot: Texture2D = null, show_mugshot := true) -> void:
	_reset_quest_offer_view()
	_restore_dialogue_size()
	lines = new_lines
	name_label.text = speaker_name
	name_label.visible = speaker_name != ""
	portrait_panel.visible = show_mugshot
	if show_mugshot:
		npc_sprite.texture = mugshot if mugshot != null else default_mugshot
	else:
		npc_sprite.texture = null
	
	current_line_index = 0
	is_open = true
	just_started = true
	visible = true
	
	GameState.lock_input()
	
	show_current_line()


func start_quest_offer(quest: Dictionary, speaker_name := "", mugshot: Texture2D = null) -> void:
	offered_quest = quest.duplicate(true)
	quest_offer_open = true
	quest_offer_pending = false
	name_label.text = speaker_name
	name_label.visible = not speaker_name.is_empty()
	portrait_panel.visible = true
	npc_sprite.texture = mugshot if mugshot != null else default_mugshot
	_populate_quest_offer(offered_quest)
	text_label.visible = false
	quest_offer_content.visible = true
	quest_offer_decline_button.text = _localized_text("common.decline", "Decline")
	quest_offer_accept_button.text = _localized_text("common.accept", "Accept")
	quest_offer_status_label.visible = false
	quest_offer_actions.visible = true
	continue_arrow.visible = false
	panel_container.offset_top = 36.0
	panel_container.offset_bottom = 374.0
	is_open = true
	just_started = false
	visible = true
	GameState.lock_input()
	quest_offer_accept_button.grab_focus()
	
func show_current_line() -> void:
	text_label.text = str(lines[current_line_index])
		
	
func hide_dialogue() -> void:
	if quest_offer_open:
		_finish_quest_offer(false)
		return
	var was_open := is_open
	
	is_open = false
	just_started = false
	visible = false
	lines = []
	current_line_index = 0
	
	GameState.unlock_input()
	
	if was_open:
		dialogue_finished.emit()


func _on_quest_offer_declined() -> void:
	if not quest_offer_pending:
		_finish_quest_offer(false)


func _on_quest_offer_accepted() -> void:
	if quest_offer_pending:
		return
	quest_offer_pending = true
	quest_offer_accept_button.disabled = true
	quest_offer_decline_button.disabled = true
	quest_offer_status_label.text = _localized_text(
		"ui.quest.offer_accepting",
		"Accepting side quest..."
	)
	quest_offer_status_label.visible = true
	var result: Dictionary = await PlayerGameStateService.accept_side_quest(
		str(offered_quest.get("questId", "")),
		StoryService.get_revision()
	)
	quest_offer_pending = false
	if bool(result.get("success", false)):
		_finish_quest_offer(true)
		return
	quest_offer_accept_button.disabled = false
	quest_offer_decline_button.disabled = false
	quest_offer_status_label.text = _localized_text(
		"ui.quest.offer_error",
		"The side quest could not be accepted. Please try again."
	)
	quest_offer_status_label.visible = true


func _finish_quest_offer(accepted: bool) -> void:
	var was_open := quest_offer_open
	quest_offer_open = false
	quest_offer_pending = false
	is_open = false
	just_started = false
	visible = false
	offered_quest.clear()
	_reset_quest_offer_view()
	_restore_dialogue_size()
	GameState.unlock_input()
	if was_open:
		quest_offer_resolved.emit(accepted)


func _reset_quest_offer_view() -> void:
	text_label.visible = true
	quest_offer_content.visible = false
	quest_offer_actions.visible = false
	quest_offer_status_label.visible = false
	quest_offer_accept_button.disabled = false
	quest_offer_decline_button.disabled = false
	continue_arrow.visible = true


func _restore_dialogue_size() -> void:
	panel_container.offset_top = 92.0
	panel_container.offset_bottom = 262.0


func _populate_quest_offer(quest: Dictionary) -> void:
	var quest_id := str(quest.get("questId", ""))
	quest_offer_type_label.text = _localized_text("ui.quest.side_quest", "Side Quest").to_upper()
	quest_offer_title_label.text = _localized_definition(str(quest.get("titleKey", "")), quest_id)
	quest_offer_summary_label.text = _localized_definition(str(quest.get("summaryKey", "")), "")
	quest_offer_objective_heading.text = _localized_text("ui.quest.objectives", "Objectives").to_upper()
	quest_offer_reward_heading.text = _localized_text("ui.quest.rewards", "Rewards").to_upper()
	var objective := ""
	var steps_value: Variant = quest.get("steps", [])
	if steps_value is Array:
		for step_value: Variant in steps_value as Array:
			if step_value is Dictionary:
				var step := step_value as Dictionary
				objective = _localized_definition(
					str(step.get("objectiveKey", "")),
					str(step.get("stepId", ""))
				)
				break
	quest_offer_objective_label.text = objective
	var rewards_value: Variant = quest.get("rewardPreviews", [])
	quest_offer_reward_label.text = _quest_reward_text(rewards_value)
	quest_offer_reward_icon.texture = _quest_reward_icon(rewards_value)
	quest_offer_reward_icon.visible = quest_offer_reward_icon.texture != null


func _quest_reward_text(rewards_value: Variant) -> String:
	var reward_parts: Array[String] = []
	if rewards_value is Array:
		for reward_value: Variant in rewards_value as Array:
			if reward_value is not Dictionary:
				continue
			var reward := reward_value as Dictionary
			match str(reward.get("type", "")):
				"item":
					var item_id := str(reward.get("itemId", "")).strip_edges()
					if not item_id.is_empty():
						var item_name := ItemLocalization.display_name(
							item_id,
							item_id.replace("-", " ").capitalize()
						)
						var quantity := maxi(int(reward.get("quantity", 1)), 1)
						reward_parts.append("%s  ×%d" % [item_name, quantity])
				"currency":
					var currency := str(reward.get("currency", "")).replace("_", " ").capitalize()
					var amount := maxi(int(reward.get("amount", 1)), 1)
					if not currency.is_empty():
						reward_parts.append("%s  ×%d" % [currency, amount])
	return ", ".join(reward_parts) if not reward_parts.is_empty() else "—"


func _quest_reward_icon(rewards_value: Variant) -> Texture2D:
	if rewards_value is not Array:
		return null
	for reward_value: Variant in rewards_value as Array:
		if reward_value is not Dictionary:
			continue
		var reward := reward_value as Dictionary
		if str(reward.get("type", "")) != "item":
			continue
		var item_id := str(reward.get("itemId", "")).strip_edges()
		if item_id.is_empty():
			continue
		var normalized := item_id.to_upper().replace("-", "").replace("_", "").replace(" ", "")
		for icon_path: String in [
			ITEM_ICON_ROOT + normalized + ".png",
			ITEM_ICON_ROOT + item_id + ".png",
			ITEM_ICON_ROOT + "000.png",
		]:
			if ResourceLoader.exists(icon_path):
				return load(icon_path) as Texture2D
	return null


func _localized_definition(key: String, fallback_id: String) -> String:
	var normalized_key := key.strip_edges()
	if not normalized_key.is_empty() and LocalizationManager.has_key(normalized_key):
		return LocalizationManager.text(normalized_key)
	return fallback_id.replace("_", " ").capitalize()


func _localized_text(key: String, fallback: String) -> String:
	return LocalizationManager.text(key) if LocalizationManager.has_key(key) else fallback
	
