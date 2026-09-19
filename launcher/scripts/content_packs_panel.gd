extends AcceptDialog
const Store := preload("res://scripts/content_pack_store.gd")
const DownloadService := preload("res://scripts/resumable_download_service.gd")
var store := Store.new()
var rows: VBoxContainer
var configuration_rows: VBoxContainer
var discover_rows: VBoxContainer
var status: Label
var catalog_status: Label
var picker: FileDialog
var tabs: TabContainer
var translate: Callable
var catalog_request: HTTPRequest
var download_service: ResumableDownloadService
var official_packs: Array[Dictionary] = []
var active_official_pack: Dictionary = {}
var uninstall_dialog: ConfirmationDialog
var pending_uninstall_id := ""


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

	tabs.add_theme_stylebox_override("panel", _style(Color(0.017, 0.027, 0.052, 0.95), Color(0.15, 0.24, 0.38, 0.95), 12, 1))
	tabs.add_theme_stylebox_override("tab_selected", _style(Color(0.27, 0.14, 0.54, 1.0), Color(0.66, 0.42, 1.0, 0.95), 8, 1))
	tabs.add_theme_stylebox_override("tab_unselected", _style(Color(0.055, 0.075, 0.13, 1.0), Color(0.16, 0.22, 0.35, 0.9), 8, 1))
	tabs.add_theme_stylebox_override("tab_hovered", _style(Color(0.14, 0.095, 0.27, 1.0), Color(0.52, 0.30, 0.96, 0.95), 8, 1))
	tabs.add_theme_color_override("font_selected_color", Color(0.98, 0.96, 1.0, 1.0))
	tabs.add_theme_color_override("font_unselected_color", Color(0.65, 0.69, 0.81, 1.0))
	tabs.add_theme_color_override("font_hovered_color", Color(0.94, 0.90, 1.0, 1.0))

	for control in [rows, discover_rows, status, catalog_status]:
		if control == null:
			continue
		control.add_theme_color_override("font_color", Color(0.79, 0.83, 0.93, 1.0))


func setup(translator: Callable, catalog_url: String = "") -> void:
	translate = translator
	# AcceptDialog's built-in title bar is Godot-themed and cannot be styled.
	# Use a borderless window and render the launcher-styled header ourselves.
	borderless = true
	title = ""
	size = Vector2i(740, 520)
	min_size = Vector2i(640, 440)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	layout.custom_minimum_size = Vector2(680, 420)
	add_child(layout)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 34
	layout.add_child(header)
	var heading := Label.new()
	heading.text = translate.call("Mods")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", Color(0.96, 0.93, 1.0, 1.0))
	header.add_child(heading)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = translate.call("Close")
	close_button.custom_minimum_size = Vector2(36, 34)
	close_button.add_theme_font_size_override("font_size", 24)
	_apply_button_style(close_button)
	header.add_child(close_button)
	close_button.pressed.connect(hide)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tabs)
	var discover := ScrollContainer.new()
	discover.name = "Discover"
	discover.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(discover)
	tabs.set_tab_title(0, translate.call("Discover"))
	discover_rows = VBoxContainer.new()
	discover_rows.add_theme_constant_override("separation", 8)
	discover_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	discover.add_child(discover_rows)
	_create_catalog_status()
	var scroll := ScrollContainer.new()
	scroll.name = "Installed"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	tabs.set_tab_title(1, translate.call("Installed"))
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var configure := ScrollContainer.new()
	configure.name = "Customize"
	configure.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(configure)
	tabs.set_tab_title(2, translate.call("Customize"))
	configuration_rows = VBoxContainer.new()
	configuration_rows.add_theme_constant_override("separation", 10)
	configuration_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	configure.add_child(configuration_rows)
	tabs.current_tab = 1
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	layout.add_child(actions)
	var import_button := Button.new()
	import_button.text = translate.call("Import .zip pack")
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
	note.text = translate.call("Import a .zip pack that contains mod.json, or install an official pack from Discover.")
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
	picker.title = translate.call("Choose a mod pack .zip file")
	picker.filters = PackedStringArray(["*.zip ; Mod pack (.zip)"])
	add_child(picker)
	import_button.pressed.connect(func() -> void: picker.popup_centered_ratio(0.75))
	picker.file_selected.connect(_import)
	uninstall_dialog = ConfirmationDialog.new()
	uninstall_dialog.title = translate.call("Uninstall mod")
	uninstall_dialog.ok_button_text = translate.call("Uninstall")
	add_child(uninstall_dialog)
	uninstall_dialog.confirmed.connect(_uninstall_pending)
	catalog_request = HTTPRequest.new()
	add_child(catalog_request)
	catalog_request.request_completed.connect(_on_catalog_request_completed)
	download_service = DownloadService.new()
	add_child(download_service)
	download_service.download_completed.connect(_on_official_pack_downloaded)
	download_service.download_failed.connect(_on_official_pack_download_failed)
	refresh()
	_load_catalog(catalog_url)


static func validate_catalog(candidate: Dictionary) -> String:
	if int(candidate.get("format_version", 0)) != 1:
		return "Unsupported content pack catalog."
	var packs: Variant = candidate.get("packs", [])
	if not packs is Array:
		return "Catalog packs must be an array."
	for pack_value: Variant in packs:
		if not pack_value is Dictionary:
			return "Catalog contains an invalid pack."
		var pack := pack_value as Dictionary
		for field in ["id", "name", "version", "author"]:
			if not pack.get(field) is String or str(pack[field]).strip_edges().is_empty():
				return "Catalog pack is missing " + field + "."
		if not Store.valid_id(str(pack.id)):
			return "Catalog contains an invalid pack ID."
		var download: Variant = pack.get("download", {})
		if not download is Dictionary:
			return "Catalog pack has no download."
		var item := download as Dictionary
		if not bool(DownloadService.parse_http_url(str(item.get("url", ""))).get("valid", false)):
			return "Catalog pack has an invalid download URL."
		if int(item.get("size_bytes", 0)) <= 0 or int(item.get("size_bytes", 0)) > Store.MAX_PACK_BYTES:
			return "Catalog pack has an invalid size."
		var sha256 := str(item.get("sha256", "")).to_lower()
		if sha256.length() != 64 or not sha256.is_valid_hex_number():
			return "Catalog pack has an invalid checksum."
	return ""


func _load_catalog(url: String) -> void:
	var normalized_url := url.strip_edges()
	if normalized_url.is_empty():
		_set_catalog_status(translate.call("The official pack catalog is not available yet. You can already import community packs in Installed."))
		return
	_set_catalog_status(translate.call("Loading official packs..."))
	var error := catalog_request.request(normalized_url, PackedStringArray(["Cache-Control: no-cache"]))
	if error != OK:
		_set_catalog_status(translate.call("Official packs are unavailable. You can still import a local pack."))


func _on_catalog_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_set_catalog_status(translate.call("Official packs are unavailable. You can still import a local pack."))
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		_set_catalog_status(translate.call("Official pack catalog is invalid."))
		return
	var error := validate_catalog(parsed as Dictionary)
	if not error.is_empty():
		_set_catalog_status(error)
		return
	official_packs.clear()
	for pack_value: Variant in (parsed as Dictionary).packs:
		official_packs.append((pack_value as Dictionary).duplicate(true))
	_render_catalog()


func _create_catalog_status(message: String = "") -> void:
	catalog_status = Label.new()
	catalog_status.custom_minimum_size.x = 600
	catalog_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	catalog_status.text = message
	discover_rows.add_child(catalog_status)


func _set_catalog_status(message: String) -> void:
	if not is_instance_valid(catalog_status):
		_create_catalog_status()
	catalog_status.text = message


func _render_catalog() -> void:
	for child in discover_rows.get_children():
		discover_rows.remove_child(child)
		child.queue_free()
	_create_catalog_status()
	var installed: Dictionary = {}
	for pack in store.installed():
		installed[pack.id] = pack
	if official_packs.is_empty():
		_set_catalog_status(translate.call("No official packs are available yet."))
		return
	for pack in official_packs:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style(Color(0.045, 0.07, 0.12, 0.92), Color(0.16, 0.25, 0.39, 0.9), 10, 1))
		discover_rows.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var name := Label.new()
		name.text = "%s · %s" % [pack.name, pack.version]
		name.add_theme_color_override("font_color", Color(0.95, 0.94, 1.0, 1.0))
		name.add_theme_font_size_override("font_size", 17)
		text.add_child(name)
		var description := Label.new()
		description.text = str(pack.get("description", ""))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_color_override("font_color", Color(0.68, 0.73, 0.86, 1.0))
		text.add_child(description)
		var install := Button.new()
		var installed_pack: Dictionary = installed.get(pack.id, {})
		var installed_version := str(installed_pack.get("version", ""))
		install.text = translate.call("Installed") if installed_version == str(pack.version) else (translate.call("Update") if not installed_version.is_empty() else translate.call("Install"))
		install.disabled = installed_version == str(pack.version) or (download_service != null and download_service.is_active())
		_apply_button_style(install, true)
		row.add_child(install)
		install.pressed.connect(func() -> void: _download_official_pack(pack))


func _download_official_pack(pack: Dictionary) -> void:
	if download_service.is_active():
		return
	active_official_pack = pack.duplicate(true)
	var download: Dictionary = pack.download
	_set_catalog_status(translate.call("Downloading {name}...").format({"name": str(pack.name)}))
	var error := download_service.start_download({
		"type": "content_pack",
		"id": str(pack.id),
		"version": str(pack.version),
		"url": str(download.url),
		"sha256": str(download.sha256),
		"size_bytes": int(download.size_bytes),
		"download_dir": "user://content-pack-downloads",
	})
	if error != OK:
		active_official_pack.clear()
		_set_catalog_status(translate.call("Could not start the pack download."))


func _on_official_pack_downloaded(path: String, _summary: Dictionary) -> void:
	var error := store.import_zip(path, true)
	DirAccess.remove_absolute(path)
	refresh()
	active_official_pack.clear()
	_render_catalog()
	if error.is_empty():
		_set_catalog_status(translate.call("Pack installed. Choose it in Customize and restart the game."))
	else:
		_set_catalog_status(translate.call("Could not install pack:") + " " + error)


func _on_official_pack_download_failed(_message: String, _summary: Dictionary) -> void:
	active_official_pack.clear()
	_render_catalog()
	_set_catalog_status(translate.call("Pack download failed. Try again later."))

func refresh() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var packs := store.installed()
	for pack in packs:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style(Color(0.045, 0.07, 0.12, 0.92), Color(0.16, 0.25, 0.39, 0.9), 10, 1))
		rows.add_child(card)
		var details := VBoxContainer.new()
		details.tooltip_text = str(pack.get("description", ""))
		card.add_child(details)
		var name := Label.new()
		name.text = str(pack.name)
		name.add_theme_color_override("font_color", Color(0.92, 0.93, 1.0, 1.0))
		details.add_child(name)
		var metadata := Label.new()
		metadata.text = "%s · %s" % [pack.version, pack.author]
		metadata.add_theme_font_size_override("font_size", 12)
		metadata.add_theme_color_override("font_color", Color(0.59, 0.66, 0.80, 1.0))
		details.add_child(metadata)
		var uninstall := Button.new()
		uninstall.text = translate.call("Uninstall")
		_apply_button_style(uninstall)
		details.add_child(uninstall)
		uninstall.pressed.connect(func() -> void: _confirm_uninstall(str(pack.id), str(pack.name)))
	if packs.is_empty():
		var empty := Label.new()
		empty.text = translate.call("No packs installed. Import a zip or place a pack in the mods folder.")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows.add_child(empty)
	_refresh_configuration(packs)
	status.text = "\n".join(store.errors)


func _confirm_uninstall(pack_id: String, pack_name: String) -> void:
	pending_uninstall_id = pack_id
	uninstall_dialog.dialog_text = translate.call("Remove {name} from this computer? You can install it again later.").format({"name": pack_name})
	uninstall_dialog.popup_centered(Vector2i(460, 170))


func _uninstall_pending() -> void:
	if pending_uninstall_id.is_empty():
		return
	var error := store.uninstall(pending_uninstall_id)
	pending_uninstall_id = ""
	refresh()
	_render_catalog()
	status.text = translate.call("Mod removed.") if error.is_empty() else translate.call("Could not remove mod:") + " " + error


func _refresh_configuration(packs: Array[Dictionary]) -> void:
	for child in configuration_rows.get_children():
		configuration_rows.remove_child(child)
		child.queue_free()
	var selected := store.selected_by_category()
	var categories := {"cries": "Pokémon cries", "battle_sprites": "Battle sprites", "followers": "Follower sprites"}
	for category: String in Store.SELECTABLE_CATEGORIES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		configuration_rows.add_child(row)
		var label := Label.new()
		label.text = translate.call(str(categories[category]))
		label.custom_minimum_size.x = 150
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		var choice := OptionButton.new()
		choice.name = category.capitalize() + "PackChoice"
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.add_item(translate.call("Default"), 0)
		var selected_index := 0
		for pack in packs:
			var assets: Dictionary = pack.get("assets", {})
			var supported := assets.has(category) or (category == "battle_sprites" and assets.has("sprite_collections"))
			if not supported: continue
			choice.add_item(str(pack.name), choice.item_count)
			choice.set_item_metadata(choice.item_count - 1, str(pack.id))
			if str(selected.get(category, "")) == str(pack.id): selected_index = choice.item_count - 1
		choice.select(selected_index)
		_apply_button_style(choice)
		row.add_child(choice)
		var help := Button.new()
		help.text = translate.call("How to make one")
		_apply_button_style(help)
		row.add_child(help)
		var tutorial := Label.new()
		tutorial.text = translate.call(_tutorial_key(category))
		tutorial.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tutorial.add_theme_color_override("font_color", Color(0.66, 0.72, 0.84, 1.0))
		tutorial.visible = false
		configuration_rows.add_child(tutorial)
		help.pressed.connect(func() -> void: tutorial.visible = not tutorial.visible)
		choice.item_selected.connect(func(index: int) -> void:
			var next := store.selected_by_category()
			var pack_id := str(choice.get_item_metadata(index)) if index > 0 else ""
			if pack_id.is_empty(): next.erase(category)
			else: next[category] = pack_id
			_save_selection(next)
		)


func _tutorial_key(category: String) -> String:
	match category:
		"cries": return "Tutorial: Pokémon cries"
		"battle_sprites": return "Tutorial: Battle sprites"
		"followers": return "Tutorial: Follower sprites"
	return ""


func _save_selection(selected: Dictionary) -> void:
	var error := store.save_selected_by_category(selected)
	if error == OK:
		refresh.call_deferred()
	else:
		status.text = translate.call("Could not save pack selection.")

func _import(path: String) -> void:
	var error := store.import_zip(path)
	refresh()
	status.text = translate.call("Pack imported. Choose it in Customize to use it at the next game start.") if error.is_empty() else translate.call("Could not import pack:") + " " + error
