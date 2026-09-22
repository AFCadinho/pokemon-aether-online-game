extends Node
## Typography uses screen-pixel sizes, independent of legacy container transforms.
## Never changes shared font resources, Classic themes, sprites or render targets.
var battle: Control
var font: FontFile
var labels: Array[Control] = []
var scan_due := 0.0
var chat_originals: Dictionary = {}

func _ready() -> void:
	process_priority = 200
	font = load("res://assets/fonts/DejaVuSans.ttf").duplicate()
	font.multichannel_signed_distance_field = true
	font.fallbacks = [load("res://assets/fonts/NotoSansCJKsc-Regular.otf")]
	_scan(battle)

func _scan(node: Node) -> void:
	if node is SubViewport or node is Node3D:
		return
	if node is Label or node is RichTextLabel or node is BaseButton or node is LineEdit or node is ProgressBar:
		if node not in labels:
			labels.append(node)
	for child in node.get_children():
		_scan(child)

func _target(control: Control) -> int:
	var path := str(battle.get_path_to(control))
	if control.name == "PartySwitchLabel":
		return 16
	if "StatStage" in path:
		return 12
	if "CalcPanel" in path:
		return 14
	if "PartyGrid" in path and not "Hover" in path:
		return 12 if control is ProgressBar else 13
	if "Hover" in path:
		return 18 if "NameLabel" in path else 14
	if "CurrentAction" in path:
		return 18
	if "MovesGrid" in path:
		return 18 if "Name" in control.name or "MoveLabel" == control.name else 14
	if "HudPanel" in path:
		return 14
	if "SideFieldEffects" in path or "Timer" in path:
		return 14
	return 16

func _process(delta: float) -> void:
	for key in ["PartyHoverCard","PokemonHoverCard","MoveHoverCard"]:
		var card := battle.get_node_or_null("%"+key) as Control
		if card != null:
			var parent_scale := (card.get_parent() as Control).get_screen_transform().y.length()
			card.scale = Vector2.ONE / maxf(0.1,parent_scale)
	scan_due -= delta
	if scan_due <= 0:
		labels = labels.filter(func(control): return is_instance_valid(control))
		_scan(battle) # Picks up generated Bag rows, badges and popups.
		scan_due = 0.2
	for control in labels:
		if is_instance_valid(control) and control.is_inside_tree():
			apply_text(control,font,_target(control))
	if battle.has_meta("battle_chat_bridge"):
		var bridge = battle.get_meta("battle_chat_bridge")
		_apply_chat(bridge.panel)
		apply_text(bridge.log_view,font,16)
		apply_text(bridge.log_tab,font,16)
		apply_text(bridge.chat_tab,font,16)
		apply_text(bridge.calculator_button,font,16)

func _apply_chat(node: Node) -> void:
	if node is Label or node is RichTextLabel or node is BaseButton or node is LineEdit:
		if not chat_originals.has(node):
			var previous := {}
			for key in (["normal_font","bold_font","italics_font","bold_italics_font","mono_font"] if node is RichTextLabel else ["font"]):
				previous[key] = node.get_theme_font(key) if node.has_theme_font_override(key) else null
			for key in (["normal_font_size","bold_font_size","italics_font_size","bold_italics_font_size","mono_font_size"] if node is RichTextLabel else ["font_size"]):
				previous[key] = node.get_theme_font_size(key) if node.has_theme_font_size_override(key) else null
			chat_originals[node] = previous
		apply_text(node,font,16)
	for child in node.get_children():
		_apply_chat(child)

func restore_chat() -> void:
	for control in chat_originals:
		if not is_instance_valid(control):
			continue
		for key in chat_originals[control]:
			var value = chat_originals[control][key]
			if key.ends_with("size"):
				if value == null:
					control.remove_theme_font_size_override(key)
				else:
					control.add_theme_font_size_override(key,value)
			else:
				if value == null:
					control.remove_theme_font_override(key)
				else:
					control.add_theme_font_override(key,value)
	chat_originals.clear()

func _exit_tree() -> void:
	restore_chat()

static func apply_text(control: Control, face: Font, pixels: int) -> void:
	var transform := control.get_screen_transform()
	var scale_y := maxf(0.1,transform.y.length())
	var font_size := maxi(8,roundi(pixels / scale_y))
	var sizes := ["normal_font_size","bold_font_size","italics_font_size","bold_italics_font_size","mono_font_size"] if control is RichTextLabel else ["font_size"]
	var fonts := ["normal_font","bold_font","italics_font","bold_italics_font","mono_font"] if control is RichTextLabel else ["font"]
	for key in sizes:
		if control.get_theme_font_size(key) != font_size:
			control.add_theme_font_size_override(key,font_size)
	for key in fonts:
		if control.get_theme_font(key) != face:
			control.add_theme_font_override(key,face)
