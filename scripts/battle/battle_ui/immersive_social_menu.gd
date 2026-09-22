extends Node
## Compact battle entry point for the existing Friends and Guild windows.
const FriendlistPopupScene: PackedScene = preload("res://scenes/interface/friendlist_popup.tscn")
const GuildPopupScene: PackedScene = preload("res://scenes/interface/guild_popup.tscn")

var battle: Control
var button: Button
var menu: PanelContainer
var popups: Dictionary = {}

func _ready() -> void:
	var stage: Control = battle.get_node("%BattleStage")
	button = Button.new()
	button.name = "BattleSocialButton"
	button.text = "☰"
	button.tooltip_text = "Friends & Guild"
	button.custom_minimum_size = Vector2(28, 28)
	button.z_index = 92
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", _button_style(Color("0b2034f5"), Color("62d7ff")))
	button.add_theme_stylebox_override("hover", _button_style(Color("164461fa"), Color("93e5ff")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("071323fa"), Color("329bdf")))
	stage.add_child(button)
	button.pressed.connect(_toggle_menu)
	menu = PanelContainer.new()
	menu.name = "BattleSocialMenu"
	menu.z_index = 91
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	menu.add_theme_stylebox_override("panel", _menu_style())
	stage.add_child(menu)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	menu.add_child(margin)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	margin.add_child(actions)
	actions.add_child(_action("Friends", "res://assets/ui/friendlist.svg", _open_friends))
	actions.add_child(_action("Guild", "res://assets/ui/guild.svg", _open_guild))
	menu.hide()

func _process(_delta: float) -> void:
	if not is_instance_valid(button):
		return
	var stage: Control = battle.get_node("%BattleStage")
	var portrait := battle.battle_stage.get_node_or_null("TrainerPortrait0") as Control
	if portrait == null:
		button.hide()
		menu.hide()
		return
	button.visible = portrait.visible
	# Its right edge meets the field-indicator lane instead of covering it.
	button.position = portrait.position + Vector2(portrait.size.x - 16, -8)
	if menu.visible:
		var target_x := button.position.x + button.size.x - menu.size.x
		menu.position = Vector2(
			clampf(target_x, 6.0, stage.size.x - menu.size.x - 6.0),
			button.position.y + button.size.y + 6.0
		)

func _toggle_menu() -> void:
	menu.visible = not menu.visible

func _action(label: String, icon_path: String, callback: Callable) -> Button:
	var action := Button.new()
	action.name = "Battle%sAction" % label
	action.text = label
	action.tooltip_text = label
	action.custom_minimum_size = Vector2(154, 36)
	action.alignment = HORIZONTAL_ALIGNMENT_LEFT
	action.add_theme_font_size_override("font_size", 15)
	action.icon = load(icon_path) as Texture2D
	action.expand_icon = true
	action.add_theme_constant_override("icon_max_width", 20)
	action.add_theme_stylebox_override("normal", _button_style(Color("0b1a2bf2"), Color("315070")))
	action.add_theme_stylebox_override("hover", _button_style(Color("143b55f5"), Color("62d7ff")))
	action.pressed.connect(callback)
	return action

func _open_friends() -> void:
	menu.hide()
	_open_popup("friends", FriendlistPopupScene.instantiate())

func _open_guild() -> void:
	menu.hide()
	_open_popup("guild", GuildPopupScene.instantiate())

func _open_popup(id: String, popup: Control) -> void:
	var existing: Control = popups.get(id) as Control
	if is_instance_valid(existing):
		existing.move_to_front()
		return
	var host := battle.get_parent().get_parent() as Control
	if host == null:
		return
	host.add_child(popup)
	popups[id] = popup
	popup.z_index = 200
	popup.call("open")
	if popup.has_signal("closed"):
		popup.closed.connect(func():
			popups.erase(id)
			popup.queue_free())

func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 10
	style.content_margin_right = 10
	return style

func _menu_style() -> StyleBoxFlat:
	var style := _button_style(Color("061222f5"), Color("329bdf"))
	style.set_border_width_all(2)
	style.shadow_color = Color("02081199")
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style
