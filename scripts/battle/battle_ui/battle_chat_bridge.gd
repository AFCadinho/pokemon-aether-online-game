extends Node
## Presents the existing chat in-place: no second socket/history or send path.
var overlay: CanvasLayer
var host: Control
var panel: Control
var tabs: Control
var entry: LineEdit
var old_layer: int
var root_was_visible := true
var states: Array[Dictionary] = []
var hidden_states: Dictionary = {}
var stopped := false
var log_selected := false
var log_tab: Button
var log_view: RichTextLabel
var last_log := ""
var tab_connections: Array[Dictionary] = []
var primary_tabs: HBoxContainer
var chat_tab: Button
var resize_handle: Button
var calculator_button: Button
var resizing := false
var preferred_height := 420.0
var drag_start_y := 0.0
var drag_start_height := 0.0
var original_panel_style: StyleBox
const ALLOWED := ["ChatPanel", "ChatTabsPanel", "BattleChatLog", "BattleChatPrimaryTabs", "BattleChatResize", "BattleCalculatorButton", "ChatTabsBackground", "ChatContextPopup", "ChatSettingsPopup", "ChatModerationPopup"]

func setup(source: CanvasLayer, screen: Control) -> void:
	overlay = source
	host = screen
	panel = overlay.get_node("Control/ChatPanel")
	original_panel_style = panel.get_theme_stylebox("panel") if panel.has_theme_stylebox_override("panel") else null
	var chat_style := StyleBoxFlat.new()
	chat_style.bg_color = Color("071323a8")
	chat_style.border_color = Color("329bdf88")
	chat_style.set_border_width_all(1)
	chat_style.set_corner_radius_all(6)
	tabs = overlay.get_node("Control/ChatTabsPanel")
	entry = panel.get_node("MarginContainer/VBoxContainer/InputRow/ChatInput") if panel.has_node("MarginContainer/VBoxContainer/InputRow/ChatInput") else overlay.get("chat_input")
	old_layer = overlay.layer
	root_was_visible = overlay.get_node("Control").visible
	var background = overlay.get_node_or_null("Control/ChatTabsBackground")
	if background != null:
		hidden_states[background] = background.visible
	for control in [panel, tabs]:
		states.append({"node":control,"position":control.position,"size":control.size,"scale":control.scale,"modulate":control.modulate,"visible":control.visible,
			"anchors":[control.anchor_left,control.anchor_top,control.anchor_right,control.anchor_bottom]})
	panel.add_theme_stylebox_override("panel",chat_style)
	overlay.set_meta("battle_chat_active",true)
	host.battle.set_meta("battle_chat_bridge",self)
	host.battle.battle_log_rail.hide()
	preferred_height = get_node("/root/SettingsManager").immersive_chat_height
	primary_tabs = HBoxContainer.new()
	primary_tabs.name = "BattleChatPrimaryTabs"
	primary_tabs.add_theme_constant_override("separation",4)
	primary_tabs.z_index = panel.z_index + 2
	overlay.get_node("Control").add_child(primary_tabs)
	log_tab = Button.new()
	log_tab.name = "BattleLogTab"
	log_tab.text = "Battle Log"
	log_tab.toggle_mode = true
	var row := tabs.get_node_or_null("TabRow")
	if row == null:
		row = tabs
	for child in row.get_children():
		if child is Button:
			if log_tab.theme == null:
				log_tab.theme = child.theme
				for style in ["normal","hover","pressed"]:
					log_tab.add_theme_stylebox_override(style,child.get_theme_stylebox(style))
			var callback := func(): select_log(false)
			child.pressed.connect(callback)
			tab_connections.append({"button":child,"callback":callback})
	primary_tabs.add_child(log_tab)
	log_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_tab = Button.new()
	chat_tab.text = "Chat"
	chat_tab.toggle_mode = true
	chat_tab.button_pressed = true
	chat_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	primary_tabs.add_child(chat_tab)
	for button in [log_tab,chat_tab]:
		button.custom_minimum_size.y = 32
		button.add_theme_font_size_override("font_size",16)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("071323f5")
		style.border_color = Color("329bdf")
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		button.add_theme_stylebox_override("normal",style)
		var selected := style.duplicate()
		selected.bg_color = Color("123e60")
		button.add_theme_stylebox_override("pressed",selected)
		button.add_theme_stylebox_override("hover",selected)
	chat_tab.pressed.connect(func(): select_log(false))
	log_tab.pressed.connect(func(): select_log(true))
	resize_handle = Button.new()
	resize_handle.name = "BattleChatResize"
	resize_handle.text = "-----"
	resize_handle.tooltip_text = "Drag to resize chat / battle log"
	resize_handle.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	resize_handle.focus_mode = Control.FOCUS_NONE
	resize_handle.z_index = panel.z_index + 3
	resize_handle.add_theme_font_size_override("font_size",10)
	resize_handle.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	resize_handle.add_theme_stylebox_override("hover",StyleBoxEmpty.new())
	resize_handle.add_theme_stylebox_override("pressed",StyleBoxEmpty.new())
	overlay.get_node("Control").add_child(resize_handle)
	resize_handle.gui_input.connect(_resize_input)
	log_view = RichTextLabel.new()
	log_view.name = "BattleChatLog"
	log_view.bbcode_enabled = true
	log_view.scroll_following = true
	log_view.selection_enabled = true
	log_view.z_index = panel.z_index + 1
	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color("071323a8")
	log_style.border_color = Color("329bdf88")
	log_style.set_border_width_all(1)
	log_style.set_corner_radius_all(6)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		log_style.set_content_margin(side,10)
	log_view.add_theme_stylebox_override("normal",log_style)
	log_view.add_theme_font_size_override("normal_font_size",16)
	overlay.get_node("Control").add_child(log_view)
	process_priority = 100
	calculator_button = Button.new()
	calculator_button.name = "BattleCalculatorButton"
	calculator_button.text = "Damage Calculator"
	calculator_button.add_theme_stylebox_override("normal", log_style.duplicate())
	calculator_button.pressed.connect(func(): host.battle._on_calc_mode_button_pressed())
	overlay.get_node("Control").add_child(calculator_button)
	select_log(true)

func select_log(selected: bool) -> void:
	log_selected = selected
	log_tab.set_pressed_no_signal(selected)
	chat_tab.set_pressed_no_signal(not selected)
	if selected:
		entry.release_focus()
		log_tab.text = "Battle Log"
	_refresh()

func _process(_delta: float) -> void:
	if not stopped:
		_refresh()

func _refresh() -> void:
	if not is_instance_valid(overlay):
		return
	if host.get_node("Cover").visible:
		# The warm-up cover is on the battle canvas; this separate higher
		# canvas must remain hidden until that cover has finished fading.
		overlay.hide()
		return
	overlay.show()
	var layer := host.get_canvas_layer_node()
	overlay.layer = layer.layer + 1 if layer != null else 30
	var root: Control = overlay.get_node("Control")
	root.show()
	for child in root.get_children():
		if child is CanvasItem and str(child.name) not in ALLOWED:
			if not hidden_states.has(child):
				hidden_states[child] = child.visible
			elif child.visible:
				hidden_states[child] = true
			child.hide()
	var screen := root.size
	var width := minf(440, screen.x * 0.23)
	var row := tabs.get_node_or_null("TabRow") as Control
	var natural_width := maxf(420, row.get_combined_minimum_size().x if row != null else tabs.get_combined_minimum_size().x)
	var factor := minf(1.0,width / 420.0)
	var top_limit := screen.y * 0.49
	var height := clampf(preferred_height,220,maxf(220,screen.y - top_limit - 14))
	var header_y := screen.y - height - 14
	var channels_height := 36.0 if not log_selected else 0.0
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size = Vector2(width / factor,(height - 50 - channels_height) / factor)
	panel.scale = Vector2.ONE * factor
	panel.position = Vector2(12,header_y + 50 + channels_height)
	panel.visible = not log_selected
	panel.modulate.a = 1.0 # Only backgrounds are translucent; text remains crisp.
	tabs.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tabs.size.x = natural_width
	tabs.scale = Vector2.ONE * minf(1,width / natural_width)
	tabs.position = Vector2(12,header_y + 50)
	tabs.visible = not log_selected
	primary_tabs.position = Vector2(12,header_y + 14)
	primary_tabs.size = Vector2(width,32)
	resize_handle.position = Vector2(12,header_y)
	resize_handle.size = Vector2(width,12)
	calculator_button.position = Vector2(12,header_y - 36)
	calculator_button.size = Vector2(width,32)
	log_view.position = panel.position
	log_view.size = panel.size
	log_view.scale = panel.scale
	log_view.visible = log_selected
	var content: String = host.battle.battle_log_panel.log_buffer
	if content != last_log:
		last_log = content
		log_view.text = content
		if not log_selected:
			log_tab.text = "Battle Log •"
	host.battle.battle_log_rail.hide()
	var calculator_open: bool = host.battle.calc_drawer.visible
	for control in [panel,tabs,log_view,primary_tabs,resize_handle,calculator_button]:
		if calculator_open:
			control.hide()
	primary_tabs.visible = not calculator_open
	resize_handle.visible = not calculator_open
	calculator_button.visible = not calculator_open
	var background = root.get_node_or_null("ChatTabsBackground")
	if background != null:
		background.hide()

func contains_pointer(point: Vector2) -> bool:
	for control in [panel,tabs,log_view,primary_tabs,resize_handle,calculator_button]:
		if is_instance_valid(control) and control.is_visible_in_tree() and control.get_global_rect().has_point(point):
			return true
	return false

func _resize_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		resizing = true
		drag_start_y = overlay.get_node("Control").get_global_mouse_position().y
		drag_start_height = minf(preferred_height,overlay.get_node("Control").size.y * 0.51 - 14)
		resize_handle.accept_event()

func _input(event: InputEvent) -> void:
	if host.get_node("Cover").visible:
		return
	if resizing and event is InputEventMouseMotion:
		preferred_height = clampf(drag_start_height + drag_start_y - event.position.y,220,800)
		_refresh()
		get_viewport().set_input_as_handled()
		return
	if resizing and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		resizing = false
		get_node("/root/SettingsManager").set_immersive_chat_height(preferred_height)
		get_viewport().set_input_as_handled()
		return
	if not stopped and is_instance_valid(entry) and entry.has_focus() and event is InputEventMouseButton and event.pressed:
		if not panel.get_global_rect().has_point(event.position) and not tabs.get_global_rect().has_point(event.position):
			entry.release_focus()
	if stopped or not is_instance_valid(entry) or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE and entry.has_focus():
		entry.release_focus()
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_ENTER,KEY_KP_ENTER] and not entry.has_focus():
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit or host.get_node("Cover").visible:
			return
		if log_selected:
			select_log(false)
		if entry.is_visible_in_tree() and entry.editable:
			entry.grab_focus()
			get_viewport().set_input_as_handled()

func release() -> void:
	if stopped:
		return
	stopped = true
	if is_instance_valid(panel):
		if original_panel_style != null:
			panel.add_theme_stylebox_override("panel", original_panel_style)
		else:
			panel.remove_theme_stylebox_override("panel")
	set_process_input(false)
	if is_instance_valid(host.battle):
		var typography: Node = host.battle.get_node_or_null("ImmersiveTypography")
		if typography != null:
			typography.restore_chat()
		host.battle.remove_meta("battle_chat_bridge")
	for connection in tab_connections:
		if is_instance_valid(connection.button):
			connection.button.pressed.disconnect(connection.callback)
	if is_instance_valid(log_tab):
		log_tab.get_parent().remove_child(log_tab)
		log_tab.queue_free()
	if is_instance_valid(log_view):
		log_view.queue_free()
	if is_instance_valid(primary_tabs):
		primary_tabs.queue_free()
	if is_instance_valid(resize_handle):
		resize_handle.queue_free()
	if is_instance_valid(calculator_button):
		calculator_button.queue_free()
	if not is_instance_valid(overlay):
		return
	entry.release_focus()
	overlay.remove_meta("battle_chat_active")
	overlay.layer = old_layer
	overlay.get_node("Control").visible = root_was_visible
	for child in hidden_states:
		if is_instance_valid(child):
			child.visible = hidden_states[child]
	for state in states:
		var control: Control = state.node
		control.anchor_left = state.anchors[0]
		control.anchor_top = state.anchors[1]
		control.anchor_right = state.anchors[2]
		control.anchor_bottom = state.anchors[3]
		control.scale = state.scale
		control.position = state.position
		control.size = state.size
		control.modulate = state.modulate
		control.visible = state.visible
	if overlay.has_method("_refresh_coop_party_hud"):
		overlay.call("_refresh_coop_party_hud")

func _exit_tree() -> void:
	release()
