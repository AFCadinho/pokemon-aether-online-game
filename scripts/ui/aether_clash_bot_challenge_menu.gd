extends CanvasLayer

signal choice_made(settings: Dictionary)

const CONFIRMATION := preload("res://scenes/interface/aether_confirmation_dialog.tscn")
const TIERS := ["aether-ou", "aether-uu"]
const SPECTATOR_OPTIONS := ["public", "guilds_only"]

var dialog: AetherConfirmationDialog
var bot_count: SpinBox
var tier: OptionButton
var spectators: OptionButton
var can_start := false


func choose(options: Dictionary) -> Dictionary:
	build(options)
	return await choice_made


func build(options: Dictionary) -> void:
	layer = 121
	dialog = CONFIRMATION.instantiate() as AetherConfirmationDialog
	add_child(dialog)
	can_start = bool(options.get("available", false)) and bool(options.get("canChallenge", false))
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
	spectators = OptionButton.new()
	spectators.name = "Spectators"
	spectators.add_item(_t("public"))
	spectators.add_item(_t("guilds_only"))
	_add_field(_t("spectators"), spectators)
	dialog.style_option_button(spectators)
	dialog.confirm_button.disabled = not can_start
	dialog.confirmed.connect(_confirm)
	dialog.canceled.connect(func(): choice_made.emit({}))
	dialog.popup_centered(Vector2i(560, 440))


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
	return {"botCount": int(bot_count.value), "tierId": TIERS[tier.selected],
		"spectatorAccess": SPECTATOR_OPTIONS[spectators.selected]}


func _confirm() -> void:
	if not can_start:
		return
	choice_made.emit(selected_settings())


func _t(key: String) -> String:
	return LocalizationManager.text("ui.clash_bot." + key)
