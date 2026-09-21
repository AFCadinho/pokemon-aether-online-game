extends AcceptDialog
const Store = preload("model_pack_store.gd")
var store := Store.new()
var translate: Callable
var picker: FileDialog
var choices: OptionButton
var status: Label
var import_button: Button
var select_button: Button
var refresh_button: Button
var thread: Thread
var operation := ""

func setup(translator: Callable) -> void:
	translate = translator
	title = translate.call("3D Models")
	size = Vector2i(720, 420)
	min_size = Vector2i(600, 360)
	get_ok_button().text = translate.call("Close")
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101827")
	style.border_color = Color("8655ce")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	add_theme_stylebox_override("panel", style)
	var layout := VBoxContainer.new()
	layout.custom_minimum_size = Vector2(640, 330)
	layout.add_theme_constant_override("separation", 16)
	add_child(layout)
	var heading := Label.new()
	heading.text = translate.call("Reviewed Pokémon models")
	heading.add_theme_font_size_override("font_size", 22)
	layout.add_child(heading)
	var hint := Label.new()
	hint.text = translate.call("Import a reviewed model ZIP, then select it for the next game launch. Enable 3D in game Settings. No downloads or changes to saved game settings.")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(550, 65)
	layout.add_child(hint)
	var bar := HBoxContainer.new()
	layout.add_child(bar)
	import_button = _button("Import model ZIP…", bar)
	refresh_button = _button("Refresh", bar)
	var folder := _button("Open model folder", bar)
	folder.pressed.connect(func():
		if DirAccess.make_dir_recursive_absolute(store.root) == OK:
			OS.shell_open(store.root))
	choices = OptionButton.new()
	choices.custom_minimum_size.y = 42
	layout.add_child(choices)
	select_button = _button("Use selected models", layout)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(600, 65)
	layout.add_child(status)
	picker = FileDialog.new()
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.filters = PackedStringArray(["*.zip ; Reviewed 3D model pack"])
	add_child(picker)
	import_button.pressed.connect(func(): picker.popup_centered_ratio(0.8))
	picker.file_selected.connect(func(path: String): start_job("install", path))
	select_button.pressed.connect(func(): start_job("select", str(choices.get_item_metadata(choices.selected))))
	refresh_button.pressed.connect(refresh)
	refresh()
	status.text = translate.call("Installing does not automatically select a pack.")

func _button(label: String, parent: Node) -> Button:
	var button := Button.new()
	button.text = translate.call(label)
	button.custom_minimum_size.y = 38
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("1c2940")
	normal.border_color = Color("4b5e82")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("40305e")
	hover.border_color = Color("aa79f0")
	button.add_theme_stylebox_override("hover", hover)
	parent.add_child(button)
	return button

func refresh() -> void:
	choices.clear()
	choices.add_item(translate.call("Game settings (no launcher override)"))
	choices.set_item_metadata(0, "")
	var selected := store.selected_id()
	for pack in store.installed():
		choices.add_item(translate.call("Reviewed models: %s variants · %s") % [pack.count, str(pack.id).left(12)])
		var index := choices.item_count - 1
		choices.set_item_metadata(index, pack.id)
		if pack.id == selected:
			choices.select(index)

func _busy(value: bool) -> void:
	import_button.disabled = value
	select_button.disabled = value
	refresh_button.disabled = value
	choices.disabled = value
	get_ok_button().disabled = value
	exclusive = value

func start_job(kind: String, value: String) -> void:
	if thread != null: return
	operation = kind
	thread = Thread.new()
	_busy(true)
	status.text = translate.call("Checking model files… Please wait.")
	var error := thread.start(store.import_zip.bind(value) if kind == "install" else store.select.bind(value))
	if error != OK:
		thread = null
		_busy(false)
		status.text = translate.call("Could not start model verification.")

func _process(_delta: float) -> void:
	if thread == null or thread.is_alive(): return
	var result: Dictionary = thread.wait_to_finish()
	thread = null
	_busy(false)
	refresh()
	if not str(result.error).is_empty():
		status.text = translate.call(str(result.error))
	else:
		status.text = translate.call("Model pack installed. Select it to use it." if operation == "install" else "Selection saved for the next game launch.")

func _exit_tree() -> void:
	# Quitting the launcher must not abandon a thread with open staging files.
	if thread != null:
		thread.wait_to_finish()
		thread = null
