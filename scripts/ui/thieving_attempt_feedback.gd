extends CanvasLayer

const ICON := preload("res://assets/ui/thieving.svg")
const ATTEMPT_DURATION := 0.55
const RESULT_DURATION := 0.9
const PANEL_SIZE := Vector2(196, 82)

var phase := "attempt"
var elapsed := 0.0
var target: WeakRef
var panel: PanelContainer
var title: Label
var detail: Label
var meter: ProgressBar


func _ready() -> void:
	layer = 60
	panel = PanelContainer.new()
	panel.name = "ThievingAttemptPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = PANEL_SIZE
	panel.size = PANEL_SIZE
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color("#171426f5")
	surface.border_color = Color("#9975c6")
	surface.set_border_width_all(1)
	surface.set_corner_radius_all(14)
	surface.set_content_margin_all(10)
	surface.shadow_color = Color(0.01, 0.01, 0.025, 0.45)
	surface.shadow_size = 3
	panel.add_theme_stylebox_override("panel", surface)
	add_child(panel)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 4)
	panel.add_child(rows)
	var heading := HBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_constant_override("separation", 8)
	rows.add_child(heading)
	var icon := TextureRect.new()
	icon.texture = ICON
	icon.custom_minimum_size = Vector2(26, 26)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(icon)
	title = Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color("#f2e7ff"))
	heading.add_child(title)
	meter = ProgressBar.new()
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.custom_minimum_size = Vector2(0, 8)
	meter.show_percentage = false
	meter.max_value = 100
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#080c16")
	track.set_corner_radius_all(4)
	meter.add_theme_stylebox_override("background", track)
	_set_meter_color(Color("#bf91ed"))
	rows.add_child(meter)
	detail = Label.new()
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_theme_font_size_override("font_size", 12)
	detail.add_theme_color_override("font_color", Color("#c0b9d0"))
	rows.add_child(detail)
	panel.visible = false


func begin(npc: Node2D) -> void:
	target = weakref(npc)
	phase = "attempt"
	elapsed = 0.0
	title.text = _text("ui.thieving.feedback.attempt")
	detail.text = _text("ui.thieving.feedback.reaching")
	panel.visible = true
	_update_position(npc)


func finish(result: Dictionary) -> void:
	elapsed = 0.0
	meter.modulate.a = 1.0
	var outcome := str(result.get("outcome", ""))
	if bool(result.get("success", false)) and outcome == "success":
		phase = "success"
		title.text = _text("ui.thieving.feedback.success")
		detail.text = _text("ui.thieving.feedback.reward", {
			"amount": maxi(int(result.get("rewardMoney", 0)), 0),
			"experience": maxi(int(result.get("experienceAwarded", 0)), 0),
		})
		_set_meter_color(Color("#73dfa1"))
		meter.value = 100
	elif bool(result.get("success", false)) and outcome == "caught":
		phase = "caught"
		title.text = _text("ui.thieving.feedback.caught")
		detail.text = _text("ui.thieving.feedback.detected")
		_set_meter_color(Color("#ff817e"))
		meter.value = 100
	else:
		phase = "error"
		title.text = _text("ui.thieving.feedback.error")
		detail.text = _text("ui.thieving.feedback.retry")
		_set_meter_color(Color("#a4a6b8"))


func _process(delta: float) -> void:
	if target == null or not panel.visible:
		return
	var npc := target.get_ref() as Node2D
	if not is_instance_valid(npc) or not npc.is_inside_tree():
		queue_free()
		return
	_update_position(npc)
	elapsed += delta
	if phase == "attempt":
		# This is an action animation, never a fabricated success chance.
		var progress := clampf(elapsed / ATTEMPT_DURATION, 0.0, 1.0)
		meter.value = 85.0 * (1.0 - pow(1.0 - progress, 2.0))
		if progress >= 1.0:
			phase = "pending"
			title.text = _text("ui.thieving.feedback.pending")
			detail.text = _text("ui.thieving.feedback.waiting")
	elif phase == "pending":
		meter.modulate.a = 0.8 + 0.2 * sin(elapsed * 4.0)
	elif elapsed >= RESULT_DURATION:
		queue_free()


func _update_position(npc: Node2D) -> void:
	var nameplate_top := npc.get_global_transform_with_canvas() * Vector2(0, -80)
	var desired := nameplate_top - Vector2(panel.size.x * 0.5, panel.size.y + 10)
	var upper := (get_viewport().get_visible_rect().size - panel.size - Vector2(8, 8)).max(Vector2(8, 8))
	panel.position = desired.clamp(Vector2(8, 8), upper).round()


func _set_meter_color(color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	meter.add_theme_stylebox_override("fill", fill)


func _text(key: String, parameters: Dictionary = {}) -> String:
	return str(get_node("/root/LocalizationManager").call("text", key, parameters))
