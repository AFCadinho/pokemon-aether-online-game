class_name DaycarePopup
extends PanelContainer

signal closed
const STATS: Array[String] = ["hp", "atk", "def", "spa", "spd", "spe"]
var pokemon_select: OptionButton
var exp_check: CheckBox
var ev_check: CheckBox
var level_input: SpinBox
var ev_inputs: Dictionary = {}
var ev_grid: GridContainer
var current_label: Label
var quote_label: Label
var status_label: Label
var preview_button: Button
var confirm_button: Button
var close_button: Button
var refresh_button: Button
var retry_button: Button
var job_container: VBoxContainer
var tabs: TabContainer
var confirmation: AetherConfirmationDialog
var entries: Array = []
var jobs: Array = []
var job_views: Array = []
var quote: Dictionary = {}
var daycare_cap := 5
var busy := false
var generation := 0
var clock_ticks := 0

func _t(key: String, values: Dictionary = {}) -> String:
	return LocalizationManager.text("ui.daycare." + key, values)

func _label(text_value: String, parent: Node) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_OFF if parent is HBoxContainer or parent is GridContainer else TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER if parent is HBoxContainer or parent is GridContainer else Control.SIZE_FILL
	parent.add_child(label)
	return label

func _button(text_value: String, parent: Node, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#081522")
	style.border_color = Color("#397b9c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	add_theme_stylebox_override("panel", style)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	add_child(layout)
	var title := _label(_t("title"), layout)
	title.add_theme_font_size_override("font_size", 26)
	_label(_t("explanation"), layout)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tabs)
	var training_scroll := ScrollContainer.new()
	training_scroll.name = _t("new_training")
	training_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(training_scroll)
	var training := VBoxContainer.new()
	training.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	training.add_theme_constant_override("separation", 10)
	training_scroll.add_child(training)
	pokemon_select = OptionButton.new()
	pokemon_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pokemon_select.clip_text = true
	pokemon_select.item_selected.connect(_pokemon_changed)
	training.add_child(pokemon_select)
	current_label = _label("", training)
	var level_row := HBoxContainer.new()
	training.add_child(level_row)
	exp_check = CheckBox.new()
	exp_check.text = _t("exp_training")
	exp_check.toggled.connect(_targets_changed)
	level_row.add_child(exp_check)
	_label(_t("target_level"), level_row)
	level_input = SpinBox.new()
	level_input.min_value = 1
	level_input.max_value = 100
	level_input.step = 1
	level_input.custom_minimum_size.x = 88
	level_input.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_input.value_changed.connect(_targets_changed)
	level_row.add_child(level_input)
	ev_check = CheckBox.new()
	ev_check.text = _t("ev_training")
	ev_check.toggled.connect(_targets_changed)
	training.add_child(ev_check)
	var grid := GridContainer.new()
	ev_grid = grid
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	training.add_child(grid)
	for stat: String in STATS:
		_label(stat.to_upper(), grid)
		var input := SpinBox.new()
		input.min_value = 0
		input.max_value = 252
		input.step = 1
		input.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		input.custom_minimum_size.x = 76
		input.value_changed.connect(_targets_changed)
		grid.add_child(input)
		ev_inputs[stat] = input
	_label(_t("ev_hint"), training)
	quote_label = _label("", training)
	var jobs_scroll := ScrollContainer.new()
	jobs_scroll.name = _t("in_training")
	jobs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(jobs_scroll)
	job_container = VBoxContainer.new()
	job_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	job_container.add_theme_constant_override("separation", 12)
	jobs_scroll.add_child(job_container)
	status_label = _label("", layout)
	var footer := HFlowContainer.new()
	layout.add_child(footer)
	preview_button = _button(_t("preview"), footer, _preview)
	confirm_button = _button(_t("deposit"), footer, _ask_confirm)
	refresh_button = _button(_t("refresh"), footer, _load_state)
	retry_button = _button(_t("retry"), footer, _retry)
	close_button = _button(LocalizationManager.text("common.close"), footer, close_popup)
	confirmation = preload("res://scenes/interface/aether_confirmation_dialog.tscn").instantiate() as AetherConfirmationDialog
	add_child(confirmation)
	confirmation.confirmed.connect(_confirm)
	confirmation.style_option_button(pokemon_select)
	confirmation.style_spin_box(level_input)
	confirmation.style_checkbox(exp_check)
	confirmation.style_checkbox(ev_check)
	for stat: String in STATS:
		confirmation.style_spin_box(ev_inputs[stat] as SpinBox)
	tabs.tab_changed.connect(_tab_changed)
	var timer := Timer.new()
	timer.wait_time = 1
	timer.timeout.connect(_tick)
	add_child(timer)
	timer.start()
	get_viewport().size_changed.connect(_fit_window)
	minimum_size_changed.connect(_queue_fit)
	_fit_window()
	_queue_fit()
	_set_busy(false)

func _tab_changed(index: int) -> void:
	preview_button.visible = index == 0
	confirm_button.visible = index == 0
	_queue_fit()

func _queue_fit() -> void:
	_fit_window.call_deferred()

func _fit_window() -> void:
	var screen := get_viewport_rect().size
	size = Vector2(minf(760, screen.x - 32), minf(680, screen.y - 32))
	position = (screen - size) * 0.5
	if ev_grid != null:
		ev_grid.columns = 4 if screen.x < 640 else 6

func open_daycare() -> void:
	visible = true
	generation += 1
	quote.clear()
	await _load_state()

func close_popup() -> void:
	if busy:
		return
	generation += 1
	confirmation.hide_dialog()
	visible = false
	closed.emit()

func _set_busy(value: bool) -> void:
	busy = value
	var pending := not DaycareService.pending_request.is_empty()
	pokemon_select.disabled = value or pending or entries.is_empty()
	var current_level := int(entries[pokemon_select.selected].get("pokemon", {}).get("level", 1)) if not entries.is_empty() else 100
	exp_check.disabled = value or pending or entries.is_empty() or current_level >= daycare_cap
	ev_check.disabled = value or pending or entries.is_empty()
	level_input.editable = not value and not pending and exp_check.button_pressed and not entries.is_empty()
	for stat: String in STATS:
		(ev_inputs[stat] as SpinBox).editable = not value and not pending and ev_check.button_pressed and not entries.is_empty()
	preview_button.disabled = value or pending or entries.is_empty() or jobs.size() >= 6 or not (exp_check.button_pressed or ev_check.button_pressed)
	confirm_button.disabled = value or pending or quote.is_empty()
	close_button.disabled = value
	refresh_button.disabled = value
	retry_button.visible = pending
	retry_button.disabled = value
	_tick()

func _load_state() -> void:
	if busy:
		return
	_set_busy(true)
	status_label.text = _t("loading")
	var current := generation
	var response: Dictionary = await DaycareService.state()
	if current != generation:
		return
	if bool(response.get("success", false)):
		_apply_state(response.get("body", {}))
	else:
		status_label.text = str(response.get("error", ""))
	_set_busy(false)

func _apply_state(data: Dictionary) -> void:
	entries = data.get("pokemon", [])
	jobs = data.get("jobs", [])
	daycare_cap = int(data.get("daycareLevelCap", 5))
	clock_ticks = Time.get_ticks_msec()
	pokemon_select.clear()
	for entry: Dictionary in entries:
		var p: Dictionary = entry.get("pokemon", {})
		var location: Dictionary = entry.get("location", {})
		var place := _t("party_slot", {"slot": int(location.get("partySlot", 0)) + 1}) if str(location.get("type", "")) == "party" else _t("box_slot", {"box": int(location.get("boxIndex", 0)) + 1, "slot": int(location.get("slotIndex", 0)) + 1})
		pokemon_select.add_item("%s · Lv.%s · %s" % [_name(p), p.get("level", 1), place])
	if entries.is_empty():
		pokemon_select.add_item(_t("no_pokemon"))
	quote.clear()
	quote_label.text = ""
	_pokemon_changed(0)
	_build_jobs()
	status_label.text = _t("state", {"count": jobs.size(), "money": data.get("money", 0), "cap": daycare_cap})
	if not DaycareService.pending_request.is_empty():
		status_label.text = _t("pending")

func _name(pokemon: Dictionary) -> String:
	var nickname: Variant = pokemon.get("nickname")
	return str(nickname) if nickname is String and not str(nickname).is_empty() else str(pokemon.get("displaySpecies", pokemon.get("species", "Pokémon")))

func _pokemon_changed(_index: int) -> void:
	quote.clear()
	quote_label.text = ""
	if entries.is_empty():
		current_label.text = _t("no_pokemon")
		return
	var p: Dictionary = entries[pokemon_select.selected].get("pokemon", {})
	var level := int(p.get("level", 1))
	level_input.max_value = max(daycare_cap, level)
	level_input.min_value = level
	level_input.set_value_no_signal(mini(level + 1, int(level_input.max_value)))
	exp_check.set_pressed_no_signal(level < daycare_cap)
	ev_check.set_pressed_no_signal(false)
	var current_evs: Dictionary = p.get("evs", {})
	var stored_evs: Dictionary = p.get("storedEvs", p.get("stored_evs", {}))
	var stored_text: Array[String] = []
	for stat: String in STATS:
		var input := ev_inputs[stat] as SpinBox
		input.min_value = int(current_evs.get(stat, 0))
		input.set_value_no_signal(input.min_value)
		stored_text.append("%s %s" % [stat.to_upper(), stored_evs.get(stat, 0)])
	current_label.text = _t("current", {"level": level, "experience": p.get("experience", 0), "stored": " · ".join(stored_text)})
	_set_busy(busy)

func _targets_changed(_value: Variant) -> void:
	quote.clear()
	quote_label.text = ""
	_set_busy(busy)

func _selection() -> Dictionary:
	if entries.is_empty():
		return {}
	var p: Dictionary = entries[pokemon_select.selected].get("pokemon", {})
	var selection := {"pokemonId": int(p.get("ownedPokemonId", p.get("pokemonId", 0)))}
	if exp_check.button_pressed:
		selection["targetLevel"] = int(level_input.value)
	if ev_check.button_pressed:
		var evs: Dictionary = {}
		for stat: String in STATS:
			evs[stat] = int((ev_inputs[stat] as SpinBox).value)
		selection["targetEvs"] = evs
	return selection

func _preview() -> void:
	if busy or entries.is_empty():
		return
	if ev_check.button_pressed:
		var total := 0
		for stat: String in STATS:
			total += int((ev_inputs[stat] as SpinBox).value)
		if total > 510:
			status_label.text = _t("ev_total_error")
			return
	_set_busy(true)
	var current := generation
	var response: Dictionary = await DaycareService.preview(_selection())
	if current != generation:
		return
	if bool(response.get("success", false)):
		_show_quote(response.get("body", {}))
	else:
		status_label.text = str(response.get("error", ""))
	_set_busy(false)

func _show_quote(data: Dictionary) -> void:
	quote = data
	quote_label.text = _t("quote", {"experience": data.get("requiredExperience", 0), "evs": data.get("requiredEvs", 0), "price": data.get("price", 0), "time": _duration(int(data.get("durationSeconds", 0)))})
	quote_label.text += "\n" + _t("service_times", {"exp": _duration(int(data.get("expDurationSeconds", 0))), "ev": _duration(int(data.get("evDurationSeconds", 0)))})
	var target_evs: Array[String] = []
	for stat: String in STATS:
		target_evs.append("%s %s" % [stat.to_upper(), data.get("targetEvs", {}).get(stat, 0)])
	quote_label.text += "\n" + _t("targets", {"level": data.get("targetLevel", 1), "evs": " · ".join(target_evs)})
	status_label.text = _t("review")

func _ask_confirm() -> void:
	if busy or quote.is_empty():
		return
	confirmation.configure(_t("title"), _t("confirmation", {"price": quote.get("price", 0), "time": _duration(int(quote.get("durationSeconds", 0)))}), _t("deposit"), LocalizationManager.text("common.cancel"))
	confirmation.popup_centered()

func _confirm() -> void:
	if busy or quote.is_empty():
		return
	confirmation.hide_dialog()
	_set_busy(true)
	var response: Dictionary = await DaycareService.confirm(str(quote.get("previewId", "")), quote)
	await _after_write(response, false)

func _pickup(job_id: String) -> void:
	if busy or not DaycareService.pending_request.is_empty():
		return
	_set_busy(true)
	var response: Dictionary = await DaycareService.pickup(job_id)
	await _after_write(response, true)

func _retry() -> void:
	if busy:
		return
	var was_pickup := str(DaycareService.pending_request.get("kind", "")) == "pickup"
	_set_busy(true)
	var response: Dictionary = await DaycareService.retry()
	await _after_write(response, was_pickup)

func _after_write(response: Dictionary, pickup: bool) -> void:
	_set_busy(false)
	if bool(response.get("success", false)):
		await _load_state()
		status_label.text = _t("picked_up") if pickup else _t("deposited")
		if not pickup:
			tabs.current_tab = 1
		else:
			var scene := get_tree().current_scene
			var overlay := scene.get_node_or_null("UIOverlay") if scene != null else null
			if overlay != null and overlay.has_method("queue_reward_move_learn_candidates"):
				overlay.call("queue_reward_move_learn_candidates", response.get("body", {}).get("reward", {}))
	else:
		if DaycareService.pending_request.is_empty():
			await _load_state()
			status_label.text = str(response.get("error", ""))
		else:
			status_label.text = _t("pending")
	_set_busy(false)

func _build_jobs() -> void:
	for node in job_container.get_children():
		job_container.remove_child(node)
		node.queue_free()
	job_views.clear()
	for job: Dictionary in jobs:
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 5)
		job_container.add_child(card)
		var p: Dictionary = job.get("pokemon", {})
		var plan: Dictionary = job.get("plan", {})
		_label(_t("job_title", {"place": int(job.get("bed", 0)) + 1, "pokemon": _name(p), "level": plan.get("targetLevel", 1)}), card)
		var goal: Array[String] = []
		if bool(plan.get("expSelected", false)):
			goal.append(_t("exp_goal", {"level": plan.get("targetLevel", 1)}))
		if bool(plan.get("evSelected", false)):
			var spread: Array[String] = []
			for stat: String in STATS:
				spread.append("%s %s" % [stat.to_upper(), plan.get("targetEvs", {}).get(stat, 0)])
			goal.append("EV: " + " · ".join(spread))
		_label("\n".join(goal), card)
		var countdown := _label("", card)
		var progress := ProgressBar.new()
		progress.max_value = maxi(int(plan.get("durationSeconds", 0)), 1)
		card.add_child(progress)
		var pickup := _button(_t("pickup"), card, _pickup.bind(str(job.get("id", ""))))
		job_views.append({"job": job, "countdown": countdown, "progress": progress, "pickup": pickup})
	if jobs.is_empty():
		_label(_t("no_jobs"), job_container)
	_tick()

func _tick() -> void:
	if not visible:
		return
	var elapsed := maxi(0, int((Time.get_ticks_msec() - clock_ticks) / 1000))
	for view: Dictionary in job_views:
		var job: Dictionary = view.get("job", {})
		var remaining := maxi(0, int(job.get("remainingSeconds", 0)) - elapsed)
		(view.get("countdown") as Label).text = _t("ready") if remaining == 0 else _t("remaining", {"time": _duration(remaining)})
		var duration := int(job.get("plan", {}).get("durationSeconds", 0))
		var progress := view.get("progress") as ProgressBar
		progress.value = progress.max_value if remaining == 0 else maxi(0, duration - remaining)
		(view.get("pickup") as Button).disabled = busy or remaining > 0 or not DaycareService.pending_request.is_empty()

func _duration(seconds: int) -> String:
	return "%02d:%02d:%02d" % [int(seconds / 3600), int((seconds % 3600) / 60), seconds % 60]
