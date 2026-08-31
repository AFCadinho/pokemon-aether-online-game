extends Control

const ITEM_ICON_ROOT := "res://assets/items/icons/"
const TRAINER_CARD_TEXTURE_ROOT := "res://assets/sprites/trainer_cards/"
const MOVE_TYPE_INDEX_PATH := "res://data/move_type_index.json"
const SYSTEM_SPEAKER_NAME := "system"
const SYSTEM_MUGSHOT := preload("res://assets/sprites/mugshots/aether_system_core.png")

static var reward_move_type_index: Dictionary = {}
static var reward_move_type_index_loaded := false

signal dialogue_finished
signal quest_offer_resolved(accepted: bool)

@onready var panel_container: Panel = $PanelContainer
@onready var quest_offer_close_button: Button = $PanelContainer/QuestOfferCloseButton
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
@onready var quest_offer_reward_entries: HFlowContainer = $PanelContainer/MarginContainer/HBoxContainer/Panel/MarginContainer/VBoxContainer/QuestOfferContent/RewardCard/RewardMargin/RewardEntries
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
var input_state_before_open: Dictionary = {}
var has_captured_input_state := false

var lines: Array = []
var current_line_index := 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	default_mugshot = npc_sprite.texture
	quest_offer_decline_button.pressed.connect(_on_quest_offer_declined)
	quest_offer_accept_button.pressed.connect(_on_quest_offer_accepted)
	quest_offer_close_button.pressed.connect(hide_dialogue)
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
		_advance_dialogue()


func _input(event: InputEvent) -> void:
	if not is_open or quest_offer_open or just_started:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_advance_dialogue()
			get_viewport().set_input_as_handled()


func _advance_dialogue() -> void:
	current_line_index += 1
	if current_line_index >= lines.size():
		hide_dialogue()
	else:
		show_current_line()
	
func start_dialogue(new_lines: Array, speaker_name := "", mugshot: Texture2D = null, show_mugshot := true) -> void:
	_capture_input_state_before_open()
	_reset_quest_offer_view()
	_restore_dialogue_size()
	lines = new_lines
	name_label.text = speaker_name
	name_label.visible = speaker_name != ""
	portrait_panel.visible = show_mugshot
	if show_mugshot:
		_set_portrait_texture(_resolve_mugshot(speaker_name, mugshot))
	else:
		_set_portrait_texture(null)
	
	current_line_index = 0
	is_open = true
	just_started = true
	visible = true
	
	GameState.lock_input()
	
	show_current_line()


func start_quest_offer(quest: Dictionary, speaker_name := "", mugshot: Texture2D = null) -> void:
	_capture_input_state_before_open()
	offered_quest = quest.duplicate(true)
	quest_offer_open = true
	quest_offer_pending = false
	name_label.text = speaker_name
	name_label.visible = not speaker_name.is_empty()
	portrait_panel.visible = true
	_set_portrait_texture(_resolve_mugshot(speaker_name, mugshot))
	_populate_quest_offer(offered_quest)
	text_label.visible = false
	quest_offer_content.visible = true
	quest_offer_decline_button.text = _localized_text("common.decline", "Decline")
	quest_offer_accept_button.text = _localized_text("common.accept", "Accept")
	quest_offer_status_label.visible = false
	quest_offer_actions.visible = true
	quest_offer_close_button.visible = true
	continue_arrow.visible = false
	panel_container.offset_top = 36.0
	panel_container.offset_bottom = 374.0
	is_open = true
	just_started = false
	visible = true
	GameState.lock_input()
	quest_offer_accept_button.grab_focus()


func _set_portrait_texture(texture: Texture2D) -> void:
	npc_sprite.texture = texture
	var is_trainer_card := texture != null and texture.resource_path.begins_with(TRAINER_CARD_TEXTURE_ROOT)
	var is_system_mugshot := texture == SYSTEM_MUGSHOT
	if is_trainer_card or is_system_mugshot:
		npc_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		npc_sprite.texture_filter = (
			CanvasItem.TEXTURE_FILTER_NEAREST
			if is_trainer_card
			else CanvasItem.TEXTURE_FILTER_LINEAR
		)
	else:
		npc_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		npc_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _resolve_mugshot(speaker_name: String, mugshot: Texture2D) -> Texture2D:
	if mugshot != null:
		return mugshot
	if speaker_name.strip_edges().to_lower() == SYSTEM_SPEAKER_NAME:
		return SYSTEM_MUGSHOT
	return default_mugshot
	
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
	
	if was_open:
		_restore_input_state_after_close()
	
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
	quest_offer_close_button.disabled = true
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
	quest_offer_close_button.disabled = false
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
	if was_open:
		_restore_input_state_after_close()
	if was_open:
		quest_offer_resolved.emit(accepted)


func _capture_input_state_before_open() -> void:
	if has_captured_input_state:
		return
	input_state_before_open = {
		"input": bool(GameState.input_locked),
		"overworld": bool(GameState.overworld_input_locked),
		"ui": bool(GameState.ui_input_locked),
	}
	has_captured_input_state = true


func _restore_input_state_after_close() -> void:
	var previous_state := input_state_before_open.duplicate()
	input_state_before_open.clear()
	has_captured_input_state = false
	GameState.unlock_input()
	if bool(previous_state.get("input", false)):
		GameState.lock_input()
		return
	if bool(previous_state.get("overworld", false)):
		GameState.lock_overworld_input()
	if bool(previous_state.get("ui", false)):
		GameState.lock_ui_input()


func _reset_quest_offer_view() -> void:
	text_label.visible = true
	quest_offer_content.visible = false
	quest_offer_actions.visible = false
	quest_offer_close_button.visible = false
	quest_offer_status_label.visible = false
	quest_offer_accept_button.disabled = false
	quest_offer_decline_button.disabled = false
	quest_offer_close_button.disabled = false
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
	_populate_quest_reward_entries(rewards_value)


func _populate_quest_reward_entries(rewards_value: Variant) -> void:
	for child: Node in quest_offer_reward_entries.get_children():
		quest_offer_reward_entries.remove_child(child)
		child.queue_free()
	var added_count := 0
	if rewards_value is Array:
		for reward_value: Variant in rewards_value as Array:
			if reward_value is not Dictionary:
				continue
			var reward := reward_value as Dictionary
			var reward_text := _quest_reward_text([reward])
			if reward_text == "—":
				continue
			quest_offer_reward_entries.add_child(_create_quest_reward_entry(reward, reward_text))
			added_count += 1
	if added_count == 0:
		quest_offer_reward_entries.add_child(_create_quest_reward_label("—"))


func _create_quest_reward_entry(reward: Dictionary, reward_text: String) -> HBoxContainer:
	var entry := HBoxContainer.new()
	entry.add_theme_constant_override("separation", 5)
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if str(reward.get("type", "")) == "item":
		var item_id := str(reward.get("itemId", "")).strip_edges()
		var icon_texture := _quest_reward_item_icon(item_id)
		if icon_texture != null:
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(28, 28)
			icon.texture = icon_texture
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			entry.add_child(icon)
	entry.add_child(_create_quest_reward_label(reward_text))
	return entry


func _create_quest_reward_label(reward_text: String) -> Label:
	var label := Label.new()
	label.text = reward_text
	label.add_theme_color_override("font_color", Color(1.0, 0.87, 0.48, 1.0))
	label.add_theme_font_size_override("font_size", 16)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


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
					var amount := maxi(int(reward.get("amount", 1)), 1)
					var currency_id := str(reward.get("currency", "")).strip_edges().to_lower()
					if currency_id == "money":
						reward_parts.append("₽%d" % amount)
					elif not currency_id.is_empty():
						reward_parts.append("%s  ×%d" % [currency_id.replace("_", " ").capitalize(), amount])
				"skill_experience":
					var skill_id := str(reward.get("skillId", "")).strip_edges().to_lower()
					var experience := maxi(int(reward.get("experience", 1)), 1)
					if not skill_id.is_empty():
						var skill_key := "ui.skills.%s.name" % skill_id
						var skill_name := _localized_text(skill_key, skill_id.capitalize())
						reward_parts.append("%s  +%d XP" % [skill_name, experience])
	return ", ".join(reward_parts) if not reward_parts.is_empty() else "—"


func _quest_reward_item_icon(item_id: String) -> Texture2D:
	if item_id.is_empty():
		return null
	var normalized := item_id.to_upper().replace("-", "").replace("_", "").replace(" ", "")
	var icon_paths: Array[String] = [
		ITEM_ICON_ROOT + normalized + ".png",
		ITEM_ICON_ROOT + item_id + ".png",
	]
	var machine_icon_path := _quest_reward_machine_icon_path(item_id)
	if not machine_icon_path.is_empty():
		icon_paths.append(machine_icon_path)
	for icon_path: String in icon_paths:
		if ResourceLoader.exists(icon_path):
			return load(icon_path) as Texture2D
	var fallback_path := ITEM_ICON_ROOT + "000.png"
	return load(fallback_path) as Texture2D if ResourceLoader.exists(fallback_path) else null


func _quest_reward_machine_icon_path(item_id: String) -> String:
	var normalized_id := item_id.strip_edges().to_lower().replace("_", "-").replace(" ", "-")
	var machine_kind := ""
	if normalized_id.begins_with("tm-"):
		machine_kind = "tm"
	elif normalized_id.begins_with("hm-"):
		machine_kind = "hm"
	else:
		return ""
	var move_id := normalized_id.trim_prefix("%s-" % machine_kind)
	_ensure_reward_move_type_index_loaded()
	var move_type := str(reward_move_type_index.get(move_id, "")).strip_edges().to_upper()
	if move_type.is_empty():
		return ""
	var icon_prefix := "machine_tr_" if machine_kind == "hm" else "machine_"
	return ITEM_ICON_ROOT + icon_prefix + move_type + ".png"


func _ensure_reward_move_type_index_loaded() -> void:
	if reward_move_type_index_loaded:
		return
	reward_move_type_index_loaded = true
	reward_move_type_index.clear()
	if not FileAccess.file_exists(MOVE_TYPE_INDEX_PATH):
		return
	var parsed_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(MOVE_TYPE_INDEX_PATH))
	if parsed_value is not Dictionary:
		return
	for move_key_value: Variant in (parsed_value as Dictionary).keys():
		var move_key := str(move_key_value).strip_edges().to_lower().replace("_", "-").replace(" ", "-")
		var move_type := str((parsed_value as Dictionary).get(move_key_value, "")).strip_edges().to_lower()
		if not move_key.is_empty() and not move_type.is_empty():
			reward_move_type_index[move_key] = move_type


func _localized_definition(key: String, fallback_id: String) -> String:
	var normalized_key := key.strip_edges()
	if not normalized_key.is_empty() and LocalizationManager.has_key(normalized_key):
		return LocalizationManager.text(normalized_key)
	return fallback_id.replace("_", " ").capitalize()


func _localized_text(key: String, fallback: String) -> String:
	return LocalizationManager.text(key) if LocalizationManager.has_key(key) else fallback
	
