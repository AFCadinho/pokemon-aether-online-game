extends Node
## Keeps an active input above the native keyboard without changing its focus,
## text or caret. Attach to a freely positioned Control (not a Container child).

signal layout_changed

const MARGIN_PIXELS := 16.0

var surface: Control
var inputs: Array[LineEdit] = []
var _shift := Vector2.ZERO


func _process(_delta: float) -> void:
	var window_fit := get_node_or_null("/root/WindowFit")
	if window_fit == null or not window_fit.call("is_touch_ui"):
		return
	var keyboard_height := DisplayServer.virtual_keyboard_get_height() if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) else 0
	var window_bottom := float(DisplayServer.window_get_position().y + DisplayServer.window_get_size().y)
	if OS.has_feature("web"):
		var obscured := float(JavaScriptBridge.eval("window.visualViewport ? Math.max(0, window.innerHeight - visualViewport.height - visualViewport.offsetTop) : 0", true))
		var css_height := float(JavaScriptBridge.eval("window.innerHeight", true))
		keyboard_height = obscured * float(DisplayServer.window_get_size().y) / maxf(css_height, 1.0)
	update_layout(keyboard_height, window_bottom)


func update_layout(keyboard_height: float, window_bottom: float) -> void:
	if not is_instance_valid(surface):
		return
	# Remove our own translation before measuring. This also preserves changes
	# made by anchors or the chat resize controls while the keyboard is open.
	surface.position -= _shift
	var previous_shift := _shift
	_shift = Vector2.ZERO
	if keyboard_height > 0.0 and surface.is_visible_in_tree():
		for input: LineEdit in inputs:
			if not is_instance_valid(input) or not input.has_focus() or not input.is_visible_in_tree():
				continue
			# get_screen_transform includes CanvasLayer and canvas_items stretch:
			# the keyboard height is in physical screen pixels, not UI units.
			var input_rect := input.get_screen_transform() * Rect2(Vector2.ZERO, input.size)
			var pixels_up := required_shift(input_rect, window_bottom - keyboard_height)
			var screen_transform := surface.get_screen_transform()
			var parent_transform := screen_transform * surface.get_transform().affine_inverse()
			_shift = parent_transform.affine_inverse().basis_xform(Vector2(0.0, -pixels_up))
			break
	surface.position += _shift
	if not _shift.is_equal_approx(previous_shift):
		layout_changed.emit()


static func required_shift(input_rect: Rect2, keyboard_top: float) -> float:
	# Keep the whole field visible where possible, even on small landscape
	# screens. If the keyboard leaves less space than a field, keep its top.
	var bottom_overlap := maxf(0.0, input_rect.end.y + MARGIN_PIXELS - keyboard_top)
	var top_limit := maxf(0.0, input_rect.position.y - MARGIN_PIXELS)
	return minf(bottom_overlap, top_limit)
