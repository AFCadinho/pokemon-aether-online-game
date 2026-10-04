extends PanelContainer
signal download_requested(kind: String)
signal pause_requested
signal resume_requested
signal automatic_updates_changed(kind: String, enabled: bool)

var summaries := {}
var buttons := {}
var automatic := {}
var progress: ProgressBar
var message: Label
var pause: Button
var resume: Button

func _ready() -> void:
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)
	var title := _label("Downloads", 26)
	layout.add_child(title)
	layout.add_child(_label("Download Pokémon assets before playing. Existing files are skipped.", 16))
	for kind: String in ["3d", "2d"]:
		var card := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("142238")
		style.set_corner_radius_all(10)
		style.set_content_margin_all(14)
		card.add_theme_stylebox_override("panel", style)
		layout.add_child(card)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 10)
		card.add_child(body)
		body.add_child(_label("3D models" if kind == "3d" else "2D sprites", 21))
		body.add_child(_label("Normal, shiny and approved alternate forms." if kind == "3d" else "Normal and shiny artwork, animated sprites and pixel sprites.", 15))
		var summary := _label("Checking download catalog…", 16)
		body.add_child(summary)
		summaries[kind] = summary
		var button := Button.new()
		button.text = _text("Download all 3D models" if kind == "3d" else "Download all 2D sprites")
		button.disabled = true
		button.pressed.connect(func(): download_requested.emit(kind))
		body.add_child(button)
		buttons[kind] = button
		var checkbox := CheckBox.new()
		checkbox.text = _text("Keep these assets up to date")
		checkbox.toggled.connect(func(enabled: bool): automatic_updates_changed.emit(kind, enabled))
		body.add_child(checkbox)
		automatic[kind] = checkbox
	progress = ProgressBar.new()
	progress.show_percentage = false
	layout.add_child(progress)
	message = _label("Choose a download above. You can pause and resume later.", 16)
	layout.add_child(message)
	var controls := HBoxContainer.new()
	layout.add_child(controls)
	pause = Button.new()
	pause.text = _text("Pause")
	pause.disabled = true
	pause.pressed.connect(func(): pause_requested.emit())
	controls.add_child(pause)
	resume = Button.new()
	resume.text = _text("Resume")
	resume.disabled = true
	resume.pressed.connect(func(): resume_requested.emit())
	controls.add_child(resume)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

func _label(key: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = _text(key)
	label.set_meta("bulk_text_key", key)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _text(key: String, values := {}) -> String:
	return get_node("/root/LauncherLocalization").text(key, values)

func refresh_locale() -> void:
	for label: Node in find_children("*", "Label", true, false):
		if label.has_meta("bulk_text_key"):
			label.text = _text(label.get_meta("bulk_text_key"))
	for kind: String in buttons:
		buttons[kind].text = _text("Download all 3D models" if kind == "3d" else "Download all 2D sprites")
		automatic[kind].text = _text("Keep these assets up to date")
	pause.text = _text("Pause")
	resume.text = _text("Resume")
