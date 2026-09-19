extends AcceptDialog
const Store := preload("res://scripts/content_pack_store.gd")
var store := Store.new()
var rows: VBoxContainer
var status: Label
var picker: FileDialog
var tabs: TabContainer
var translate: Callable


func _style(color: Color, border: Color = Color(0, 0, 0, 0), radius: int = 8, width: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


func _apply_button_style(button: Button, primary: bool = false) -> void:
	var normal := Color(0.42, 0.20, 0.82, 1.0) if primary else Color(0.075, 0.10, 0.17, 1.0)
	var hover := Color(0.55, 0.27, 0.98, 1.0) if primary else Color(0.14, 0.10, 0.27, 1.0)
	var border := Color(0.68, 0.42, 1.0, 0.9) if primary else Color(0.24, 0.32, 0.48, 0.9)
	button.add_theme_stylebox_override("normal", _style(normal, border, 8, 1))
	button.add_theme_stylebox_override("hover", _style(hover, Color(0.68, 0.42, 1.0, 1.0), 8, 1))
	button.add_theme_stylebox_override("pressed", _style(Color(0.08, 0.055, 0.16, 1.0), Color(0.76, 0.52, 1.0, 1.0), 8, 1))
	button.add_theme_stylebox_override("disabled", _style(Color(0.055, 0.07, 0.12, 0.72), Color(0.16, 0.21, 0.33, 0.7), 8, 1))
	button.add_theme_color_override("font_color", Color(0.94, 0.94, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.48, 0.58, 1.0))


func _apply_style() -> void:
	add_theme_stylebox_override("panel", _style(Color(0.025, 0.04, 0.078, 0.99), Color(0.41, 0.25, 0.76, 0.95), 16, 1))
	add_theme_color_override("title_color", Color(0.96, 0.93, 1.0, 1.0))
	add_theme_font_size_override("title_font_size", 20)

	tabs.add_theme_stylebox_override("panel", _style(Color(0.017, 0.027, 0.052, 0.95), Color(0.15, 0.24, 0.38, 0.95), 12, 1))
	tabs.add_theme_stylebox_override("tab_selected", _style(Color(0.27, 0.14, 0.54, 1.0), Color(0.66, 0.42, 1.0, 0.95), 8, 1))
	tabs.add_theme_stylebox_override("tab_unselected", _style(Color(0.055, 0.075, 0.13, 1.0), Color(0.16, 0.22, 0.35, 0.9), 8, 1))
	tabs.add_theme_stylebox_override("tab_hovered", _style(Color(0.14, 0.095, 0.27, 1.0), Color(0.52, 0.30, 0.96, 0.95), 8, 1))
	tabs.add_theme_color_override("font_selected_color", Color(0.98, 0.96, 1.0, 1.0))
	tabs.add_theme_color_override("font_unselected_color", Color(0.65, 0.69, 0.81, 1.0))
	tabs.add_theme_color_override("font_hovered_color", Color(0.94, 0.90, 1.0, 1.0))

	for control in [rows, status]:
		control.add_theme_color_override("font_color", Color(0.79, 0.83, 0.93, 1.0))

func setup(translator: Callable) -> void:
	translate = translator
	title = translate.call("Mods")
	size = Vector2i(740, 520)
	min_size = Vector2i(640, 440)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	layout.custom_minimum_size = Vector2(680, 420)
	add_child(layout)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tabs)
	var discover := VBoxContainer.new()
	discover.name = "Discover"
	tabs.add_child(discover)
	tabs.set_tab_title(0, translate.call("Discover"))
	var explanation := Label.new()
	explanation.text = translate.call("The official pack catalog is not available yet. You can already import community packs in Installed.")
	explanation.custom_minimum_size.x = 600
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	discover.add_child(explanation)
	var scroll := ScrollContainer.new()
	scroll.name = "Installed"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	tabs.set_tab_title(1, translate.call("Installed"))
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	tabs.current_tab = 1
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	layout.add_child(actions)
	var import_button := Button.new()
	import_button.text = translate.call("Import pack")
	_apply_button_style(import_button, true)
	actions.add_child(import_button)
	var folder_button := Button.new()
	folder_button.text = translate.call("Open mods folder")
	_apply_button_style(folder_button)
	actions.add_child(folder_button)
	var refresh_button := Button.new()
	refresh_button.text = translate.call("Refresh")
	_apply_button_style(refresh_button)
	actions.add_child(refresh_button)
	refresh_button.pressed.connect(refresh)
	folder_button.pressed.connect(func() -> void:
		if DirAccess.make_dir_recursive_absolute(store.root) == OK:
			OS.shell_open(store.root)
	)
	var note := Label.new()
	note.text = translate.call("Changes apply at the next game start. The first enabled pack has priority.")
	note.custom_minimum_size.x = 600
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(note)
	status = Label.new()
	status.custom_minimum_size.x = 600
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(status)
	_apply_style()
	picker = FileDialog.new()
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.filters = PackedStringArray(["*.zip ; Mod pack"])
	add_child(picker)
	import_button.pressed.connect(func() -> void: picker.popup_centered_ratio(0.75))
	picker.file_selected.connect(_import)
	refresh()

func refresh() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var enabled := store.enabled_ids()
	var packs := store.installed()
	# Active packs appear in their actual priority order.
	packs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left := enabled.find(a.id)
		var right := enabled.find(b.id)
		return (left if left >= 0 else 100000) < (right if right >= 0 else 100000)
	)
	for pack in packs:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style(Color(0.045, 0.07, 0.12, 0.92), Color(0.16, 0.25, 0.39, 0.9), 10, 1))
		rows.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		var toggle := CheckBox.new()
		toggle.text = "%s · %s · %s" % [pack.name, pack.version, pack.author]
		toggle.clip_text = true
		toggle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		toggle.tooltip_text = str(pack.get("description", ""))
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle.button_pressed = pack.id in enabled
		toggle.add_theme_color_override("font_color", Color(0.92, 0.93, 1.0, 1.0))
		toggle.add_theme_color_override("font_hover_color", Color.WHITE)
		row.add_child(toggle)
		toggle.toggled.connect(func(active: bool) -> void:
			var ids := store.enabled_ids()
			ids.erase(pack.id)
			if active:
				ids.append(pack.id)
			_save(ids)
		)
		var priority := Button.new()
		priority.text = translate.call("Move up")
		_apply_button_style(priority)
		priority.disabled = enabled.find(pack.id) <= 0
		row.add_child(priority)
		priority.pressed.connect(func() -> void:
			var ids := store.enabled_ids()
			var index := ids.find(pack.id)
			if index > 0:
				ids[index] = ids[index - 1]
				ids[index - 1] = pack.id
				_save(ids)
		)
	if packs.is_empty():
		var empty := Label.new()
		empty.text = translate.call("No packs installed. Import a zip or place a pack in the mods folder.")
		empty.custom_minimum_size.x = 600
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows.add_child(empty)
	status.text = "\n".join(store.errors)

func _save(ids: Array[String]) -> void:
	var error := store.save_enabled(ids)
	if error == OK:
		refresh.call_deferred()
	else:
		status.text = translate.call("Could not save pack selection.")

func _import(path: String) -> void:
	var error := store.import_zip(path)
	refresh()
	status.text = translate.call("Pack imported. Enable it to use it on the next game start.") if error.is_empty() else translate.call("Could not import pack:") + " " + error
