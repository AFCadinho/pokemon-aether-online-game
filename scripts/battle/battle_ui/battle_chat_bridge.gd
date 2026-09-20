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
const ALLOWED := ["ChatPanel", "ChatTabsPanel", "BattleChatLog", "ChatTabsBackground", "ChatContextPopup", "ChatSettingsPopup", "ChatModerationPopup"]

func setup(source: CanvasLayer, screen: Control) -> void:
	overlay = source
	host = screen
	panel = overlay.get_node("Control/ChatPanel")
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
	overlay.set_meta("battle_chat_active",true)
	host.battle.set_meta("battle_chat_bridge",self)
	host.battle.battle_log_rail.hide()
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
	row.add_child(log_tab)
	log_tab.pressed.connect(func(): select_log(true))
	log_view = RichTextLabel.new()
	log_view.name = "BattleChatLog"
	log_view.bbcode_enabled = true
	log_view.scroll_following = true
	log_view.selection_enabled = true
	log_view.z_index = panel.z_index + 1
	log_view.add_theme_stylebox_override("normal",panel.get_theme_stylebox("panel"))
	log_view.add_theme_font_size_override("normal_font_size",16)
	overlay.get_node("Control").add_child(log_view)
	process_priority = 100
	_refresh()

func select_log(selected: bool) -> void:
	log_selected = selected
	log_tab.set_pressed_no_signal(selected)
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
	var factor := width / natural_width
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size = Vector2(natural_width, minf(340, screen.y * 0.38 / factor))
	panel.scale = Vector2.ONE * factor
	panel.position = Vector2(12, screen.y - panel.size.y * factor - 14)
	panel.visible = not log_selected
	panel.modulate.a = 1.0 if entry.has_focus() else 0.88
	tabs.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tabs.size.x = natural_width
	tabs.scale = panel.scale
	tabs.position = panel.position - Vector2(0,tabs.size.y * factor + 5)
	tabs.show()
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
	var background = root.get_node_or_null("ChatTabsBackground")
	if background != null:
		background.hide()

func _input(event: InputEvent) -> void:
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
	set_process_input(false)
	if is_instance_valid(host.battle):
		host.battle.remove_meta("battle_chat_bridge")
	for connection in tab_connections:
		if is_instance_valid(connection.button):
			connection.button.pressed.disconnect(connection.callback)
	if is_instance_valid(log_tab):
		log_tab.get_parent().remove_child(log_tab)
		log_tab.queue_free()
	if is_instance_valid(log_view):
		log_view.queue_free()
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

func _exit_tree() -> void:
	release()
