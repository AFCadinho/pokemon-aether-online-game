extends RefCounted

class_name BattleSideConditionPresentation

var player_battle_platform: Control
var enemy_battle_platform: Control
var player_side_effects_panel: Control
var enemy_side_effects_panel: Control

func setup(
	player_platform: Control,
	enemy_platform: Control,
	player_panel: Control,
	enemy_panel: Control
) -> void:
	player_battle_platform = player_platform
	enemy_battle_platform = enemy_platform
	player_side_effects_panel = player_panel
	enemy_side_effects_panel = enemy_panel

func update(player_side_effects: Array, enemy_side_effects: Array, turn: int) -> void:
	_set_battle_platform_side_effects(player_battle_platform, player_side_effects)
	_set_battle_platform_side_effects(enemy_battle_platform, enemy_side_effects)
	_set_side_effects_panel_data(player_side_effects_panel, player_side_effects, turn)
	_set_side_effects_panel_data(enemy_side_effects_panel, enemy_side_effects, turn)

func _set_side_effects_panel_data(panel: Control, side_effects: Array, turn: int) -> void:
	if panel == null:
		return

	if panel.has_method("set_side_effects"):
		panel.call("set_side_effects", side_effects, turn)
	else:
		panel.visible = not side_effects.is_empty()

func _set_battle_platform_side_effects(platform: Control, side_effects: Array) -> void:
	if platform == null:
		return

	if platform.has_method("set_side_effects"):
		platform.call("set_side_effects", side_effects)
		return

	_set_platform_hazard_image_visible(platform, "StickyWebsImage", false)
	_set_platform_hazard_image_visible(platform, "StealthRockImage", false)
	_set_platform_hazard_image_visible(platform, "SpikesImage", false)
	_set_platform_hazard_image_visible(platform, "ToxicSpikesImage", false)

	for effect_value in side_effects:
		if not (effect_value is Dictionary):
			continue

		var effect_data: Dictionary = effect_value as Dictionary
		match str(effect_data.get("effectId", "")):
			"stickyweb", "stickywebs":
				_set_platform_hazard_image_visible(platform, "StickyWebsImage", true)
			"stealthrock":
				_set_platform_hazard_image_visible(platform, "StealthRockImage", true)
			"spikes":
				_set_platform_hazard_image_visible(platform, "SpikesImage", true)
			"toxicspikes":
				_set_platform_hazard_image_visible(platform, "ToxicSpikesImage", true)

func _set_platform_hazard_image_visible(platform: Control, node_name: String, is_visible: bool) -> void:
	var hazard_image := platform.get_node_or_null(node_name) as CanvasItem
	if hazard_image != null:
		hazard_image.visible = is_visible
