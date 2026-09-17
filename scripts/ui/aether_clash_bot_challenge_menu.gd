extends CanvasLayer

signal choice_made(settings: Dictionary)

const CONFIRMATION := preload("res://scenes/interface/aether_confirmation_dialog.tscn")
const TIERS := ["aether-ou", "aether-uu"]
const SPECTATOR_OPTIONS := ["public", "guilds_only"]
const AI_POLICIES := ["ai4", "intermediate", "ai5", "mix_v1"]

var dialog: AetherConfirmationDialog
var bot_count: SpinBox
var tier: OptionButton
var spectators: OptionButton
var difficulty: OptionButton
var reward_attempt: CheckBox
var reward_reset_button: Button
var reward_claimed_today := false
var ai_policies: Array[String] = ["ai4"]
var can_start := false


func choose(options: Dictionary) -> Dictionary:
	build(options)
	return await choice_made


func build(options: Dictionary) -> void:
	layer = 121
	dialog = CONFIRMATION.instantiate() as AetherConfirmationDialog
	add_child(dialog)
	can_start = bool(options.get("available", false)) and bool(options.get("canChallenge", false))
	reward_claimed_today = bool(options.get("rewardClaimedToday", false))
	var message := _t("intro")
	if not bool(options.get("canChallenge", false)):
		message += "\n" + _t("permission")
	elif not bool(options.get("available", false)):
		message += "\n" + _t("unavailable")
	dialog.configure(_t("title"), message, _t("start"), _t("close"))
	bot_count = SpinBox.new()
	bot_count.name = "BotCount"
	bot_count.min_value = 1
	bot_count.max_value = clampi(int(options.get("maxBotCount", 1)), 1, 200)
	bot_count.step = 1
	bot_count.rounded = true
	bot_count.value = mini(10, int(bot_count.max_value))
	_add_field(_t("count"), bot_count)
	dialog.style_spin_box(bot_count)
	tier = OptionButton.new()
	tier.name = "Tier"
	tier.add_item("Aether OU")
	tier.add_item("Aether UU")
	_add_field(_t("format"), tier)
	dialog.style_option_button(tier)
	difficulty = OptionButton.new()
	difficulty.name = "Difficulty"
	ai_policies.clear()
	for policy: String in options.get("aiPolicies", ["ai4"]):
		if AI_POLICIES.has(policy) and not ai_policies.has(policy) and (policy != "mix_v1" or bot_count.max_value >= 3):
			ai_policies.append(policy)
	if ai_policies.is_empty():
		ai_policies.append("ai4")
	for policy: String in ai_policies:
		difficulty.add_item(_t(policy))
	difficulty.item_selected.connect(func(_index: int):
		bot_count.min_value = 3 if ai_policies[difficulty.selected] == "mix_v1" else 1
		if bot_count.value < bot_count.min_value:
			bot_count.value = bot_count.min_value
		_update_reward_choice()
	)
	_add_field(_t("difficulty"), difficulty)
	dialog.style_option_button(difficulty)
	reward_attempt = CheckBox.new()
	reward_attempt.name = "RewardAttempt"
	reward_attempt.text = _t("reward_attempt")
	reward_attempt.tooltip_text = _t("reward_hint")
	reward_attempt.button_pressed = false
	_add_field(_t("reward"), reward_attempt)
	bot_count.value_changed.connect(func(_value: float): _update_reward_choice())
	_update_reward_choice()
	spectators = OptionButton.new()
	spectators.name = "Spectators"
	spectators.add_item(_t("public"))
	spectators.add_item(_t("guilds_only"))
	_add_field(_t("spectators"), spectators)
	dialog.style_option_button(spectators)
	if bool(options.get("rewardResetAvailable", false)):
		reward_reset_button = Button.new()
		reward_reset_button.name = "RewardReset"
		reward_reset_button.text = _t("reset_button")
		reward_reset_button.tooltip_text = _t("reset_hint")
		reward_reset_button.pressed.connect(func(): choice_made.emit({"resetReward": true}))
		dialog.add_custom_control(reward_reset_button)
	dialog.confirm_button.disabled = not can_start
	dialog.confirmed.connect(_confirm)
	dialog.canceled.connect(func(): choice_made.emit({}))
	dialog.popup_centered(Vector2i(560, 500))


func _add_field(label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", AetherConfirmationDialog.COLOR_TEXT)
	row.add_child(label)
	control.custom_minimum_size.x = 240
	row.add_child(control)
	dialog.add_custom_control(row)


func selected_settings() -> Dictionary:
	bot_count.apply()
	if ai_policies[difficulty.selected] == "mix_v1" and bot_count.value < 3:
		bot_count.value = 3
	return {"botCount": int(bot_count.value), "tierId": TIERS[tier.selected], "aiPolicy": ai_policies[difficulty.selected],
		"spectatorAccess": SPECTATOR_OPTIONS[spectators.selected], "rewardAttempt": reward_attempt.button_pressed}


func _update_reward_choice() -> void:
	if reward_attempt == null:
		return
	reward_attempt.disabled = reward_claimed_today or ai_policies[difficulty.selected] != "ai5" or bot_count.value > 20
	if reward_attempt.disabled:
		reward_attempt.button_pressed = false
	reward_attempt.tooltip_text = _t("reward_claimed") if reward_claimed_today else _t("reward_hint")


func _confirm() -> void:
	if not can_start:
		return
	choice_made.emit(selected_settings())


func _t(key: String) -> String:
	return LocalizationManager.text("ui.clash_bot." + key)
