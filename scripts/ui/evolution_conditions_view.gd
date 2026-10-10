extends VBoxContainer

const Assets := preload("res://scripts/data/pokemon_assets.gd")

func render(data: Dictionary) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	for value: Variant in data.get("evolutions", []):
		if not value is Dictionary:
			continue
		var entry := value as Dictionary
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("101e2b")
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		style.set_corner_radius_all(8)
		panel.add_theme_stylebox_override("panel", style)
		add_child(panel)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 7)
		panel.add_child(stack)
		var header := HBoxContainer.new()
		stack.add_child(header)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(52, 52)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = Assets.load_home_sprite(str(entry.get("speciesId", "")))
		header.add_child(icon)
		var title := _label(str(entry.get("name", entry.get("speciesId", ""))), Color("69d8e7"))
		title.add_theme_font_size_override("font_size", 18)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(title)
		if not bool(entry.get("gameplaySupported", false)):
			stack.add_child(_label(LocalizationManager.text("ui.evolution_conditions.unsupported")))
			continue
		var rule: Dictionary = entry.get("rule", {})
		for line: String in requirement_lines(entry):
			stack.add_child(_label(line))
		if int(rule.get("min_walk_steps", 0)) > 0:
			var required := int(rule.min_walk_steps)
			var progress := mini(int(data.get("walkSteps", 0)), required)
			stack.add_child(_label(LocalizationManager.text("ui.evolution_conditions.walk_progress", {"steps": progress, "required": required})))
			var bar := ProgressBar.new()
			bar.name = "WalkingProgress"
			bar.max_value = required
			bar.value = progress
			bar.show_percentage = false
			bar.custom_minimum_size.y = 12
			stack.add_child(bar)
			var status_key := "ui.evolution_conditions.walk_active" if bool(data.get("isLead", false)) else "ui.evolution_conditions.walk_paused"
			if progress >= required:
				status_key = "ui.evolution_conditions.met" if bool(entry.get("conditionsMet", false)) else "ui.evolution_conditions.walk_complete"
			stack.add_child(_label(LocalizationManager.text(status_key), Color("9eb3c5")))
		if str(entry.get("itemId", "")) == "" and not rule.has("trade_species") and not (rule.has("min_walk_steps") and bool(entry.get("conditionsMet", false))):
			stack.add_child(_label(LocalizationManager.text("ui.evolution_conditions.met" if bool(entry.get("conditionsMet", false)) else "ui.evolution_conditions.not_met"), Color("9eb3c5")))

static func requirement_lines(entry: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var rule: Dictionary = entry.get("rule", {})
	if rule.has("trade_species"):
		var partner := str(rule.trade_species)
		lines.append(LocalizationManager.text("ui.evolution_conditions.partner_trade", {
			"partner": ContentLocalization.display_name("species", partner, _display_id(partner)),
		}))
	if rule.get("trigger", "") == "shed":
		var target := str(rule.get("evolves_with", "ninjask"))
		lines.append(LocalizationManager.text("ui.evolution_conditions.shed_rule", {
			"pokemon": ContentLocalization.display_name("species", target, _display_id(target)),
		}))
	if rule.has("level"):
		lines.append(LocalizationManager.text("ui.evolution_conditions.level", {"level": int(rule.level)}))
	if rule.has("min_walk_steps"):
		lines.append(LocalizationManager.text("ui.evolution_conditions.walk_rule", {"steps": int(rule.min_walk_steps)}))
	var item := str(entry.get("itemId", ""))
	if item != "":
		lines.append(LocalizationManager.text("ui.evolution_conditions.use_item", {"item": ItemLocalization.display_name(item, _display_id(item))}))
	if rule.has("time_of_day"):
		lines.append(LocalizationManager.text("ui.evolution_conditions.time." + str(rule.time_of_day)))
	for key: String in ["min_happiness", "held_item", "known_move", "known_move_type", "gender", "party_species", "party_type", "needs_overworld_rain", "map_id", "relative_physical_stats"]:
		if rule.has(key):
			# Existing catalog text already describes compound conditions and form rules.
			var condition := str(rule.get("condition", "")).strip_edges()
			if condition != "" and not lines.has(condition):
				lines.append(condition)
			break
	if lines.is_empty():
		lines.append(LocalizationManager.text("ui.evolution_conditions.level_up"))
	return lines

static func _display_id(value: String) -> String:
	return value.replace("-", " ").capitalize()

static func _label(text: String, color := Color("eef8ff")) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 14)
	return label
