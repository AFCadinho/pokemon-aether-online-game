extends AcceptDialog
const Store := preload("res://scripts/content_pack_store.gd")
var store := Store.new()
var rows: VBoxContainer
var status: Label
var picker: FileDialog
var tabs: TabContainer
var translate: Callable

func setup(translator: Callable) -> void:
	translate = translator
	title = translate.call("Mods")
	size = Vector2i(740, 520)
	var layout := VBoxContainer.new()
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
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	tabs.current_tab = 1
	var actions := HBoxContainer.new()
	layout.add_child(actions)
	var import_button := Button.new()
	import_button.text = translate.call("Import pack")
	actions.add_child(import_button)
	var folder_button := Button.new()
	folder_button.text = translate.call("Open mods folder")
	actions.add_child(folder_button)
	var refresh_button := Button.new()
	refresh_button.text = translate.call("Refresh")
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
		var row := HBoxContainer.new()
		rows.add_child(row)
		var toggle := CheckBox.new()
		toggle.text = "%s · %s · %s" % [pack.name, pack.version, pack.author]
		toggle.clip_text = true
		toggle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		toggle.tooltip_text = str(pack.get("description", ""))
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle.button_pressed = pack.id in enabled
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
