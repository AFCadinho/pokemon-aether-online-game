extends CanvasLayer

var room: Node2D
var service: Node
var button: Button
var data: Dictionary = {}
var polling := false
var menu: CanvasLayer
var seen: Array[int] = []

func _ready() -> void:
	service = get_node("/root/GuildService")
	layer = 56
	var surface := Control.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(surface)
	button = Button.new()
	surface.add_child(button)
	# Requests belong below the right-hand actions, away from the party HUD.
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -336
	button.offset_right = -88
	button.offset_top = 96
	button.offset_bottom = 136
	button.custom_minimum_size = Vector2(248, 40)
	button.add_theme_font_size_override("font_size", 14)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.visible = false
	var skin := preload("res://scripts/ui/guild_base_room_directory.gd").new()
	button.theme = skin._theme()
	button.add_theme_stylebox_override("normal", skin._style(Color("#142237"), Color("#f6cf72")))
	button.add_theme_stylebox_override("hover", skin._style(Color("#203550"), Color("#f6cf72")))
	skin.free()
	button.pressed.connect(_open)
	var timer := Timer.new()
	timer.wait_time = 5
	timer.autostart = true
	timer.timeout.connect(_poll)
	add_child(timer)
	_poll.call_deferred()

func _poll() -> void:
	if polling or not AuthService.is_authenticated() or GameState.current_map != room or room.guild_id <= 0:
		return
	var membership: Dictionary = service.current_membership
	if int(membership.get("guildId", 0)) > 0 and int(membership.guildId) != room.guild_id:
		button.hide()
		return
	polling = true
	var result: Dictionary = await service.base_visit_requests(room.guild_id)
	polling = false
	if not is_inside_tree() or GameState.current_map != room:
		return
	if not bool(result.get("success", false)):
		button.hide()
		return
	data = result.state
	var incoming: Array = data.get("requests", [])
	# Permanent access settings live at the manager's counter. The HUD only
	# needs attention while there are actual requests to answer.
	button.visible = not incoming.is_empty()
	button.text = LocalizationManager.text("ui.guild_base.visits.badge", {"count": incoming.size()})
	for request: Dictionary in incoming:
		if not seen.has(int(request.userId)):
			get_tree().call_group("ui_overlay", "add_system_message", LocalizationManager.text("ui.guild_base.visits.notification", {"name": str(request.name)}))
	seen.clear()
	for request: Dictionary in incoming:
		seen.append(int(request.userId))

func _open() -> void:
	if is_instance_valid(menu) or GameState.is_overworld_input_locked():
		return
	menu = preload("res://scripts/ui/guild_base_visit_menu.gd").new()
	add_child(menu)
	menu.open(service, data, "", room.guild_id)
	await menu.resolved
	menu = null
	_poll.call_deferred()
