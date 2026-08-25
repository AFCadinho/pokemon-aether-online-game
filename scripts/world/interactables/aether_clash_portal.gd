@tool
extends WorldInteractable

class_name AetherClashPortal

signal entry_requested(team_id: String, war_id: String, player: Node2D)
signal portal_state_changed(open: bool)

const PURPLE_PORTAL_TEXTURE := preload("res://assets/world/aether_clash/clash_portal_purple.png")
const RED_PORTAL_TEXTURE := preload("res://assets/world/aether_clash/clash_portal_red.png")
const PURPLE_LIGHT_COLOR := Color("a647ff")
const RED_LIGHT_COLOR := Color("ff3829")

@export_enum("purple", "red") var team_id := "purple":
	set(value):
		team_id = value
		_apply_team_visuals()
@export var active_war_id := ""
@export var entry_open := false:
	set(value):
		if entry_open == value:
			return
		entry_open = value
		_apply_portal_state()
		portal_state_changed.emit(entry_open)
@export_range(0.2, 3.0, 0.1) var pulse_speed := 1.0

@onready var portal_sprite: Sprite2D = get_node_or_null("PortalSprite")
@onready var portal_light: PointLight2D = get_node_or_null("PortalLight")

var _animation_time := 0.0
var _portal_sprite_origin := Vector2.ZERO


func _ready() -> void:
	interactable_kind = "aether_clash_portal"
	requires_facing = false
	blocks_movement = true
	interaction_shape_size = Vector2(104, 104)
	if Engine.is_editor_hint():
		display_name = "%s Clash Portal" % team_id.capitalize()
	else:
		display_name = _text("world.aether_clash.portal.%s.name" % team_id)
	super._ready()
	if portal_sprite != null:
		_portal_sprite_origin = portal_sprite.position
	_apply_team_visuals()
	_apply_portal_state()


func _process(delta: float) -> void:
	_animation_time += delta * pulse_speed
	_animate_portal()
	if not Engine.is_editor_hint():
		await super._process(delta)


func configure_war(war_id: String, open: bool) -> void:
	active_war_id = war_id.strip_edges()
	entry_open = open and not active_war_id.is_empty()
	_apply_portal_state()


func clear_war() -> void:
	active_war_id = ""
	entry_open = false
	_apply_portal_state()


func interact_with_player(player: Node2D) -> void:
	if not entry_open or active_war_id.strip_edges().is_empty():
		await show_dialogue(
			[_text("world.aether_clash.portal.inactive")],
			display_name
		)
		return

	entry_requested.emit(team_id, active_war_id, player)
	for controller: Node in get_tree().get_nodes_in_group("aether_clash_war_controller"):
		if not controller.has_method("request_portal_entry"):
			continue
		var result: Variant = await controller.call(
			"request_portal_entry",
			team_id,
			active_war_id,
			player,
			self
		)
		if result is Dictionary and not bool((result as Dictionary).get("success", false)):
			var error_dialog_service := get_node_or_null("/root/GameErrorDialogService")
			if error_dialog_service != null and error_dialog_service.has_method("show_response"):
				await error_dialog_service.call(
					"show_response",
					result as Dictionary,
					"backend.error.aether_clash_unavailable"
				)
		return

	await show_dialogue(
		[_text("world.aether_clash.portal.unavailable")],
		display_name
	)


func _apply_portal_state() -> void:
	if portal_sprite != null:
		portal_sprite.modulate = Color.WHITE
	if portal_light != null:
		# The portal is visually energized at all times. `entry_open` only
		# represents whether the authoritative war flow currently allows entry.
		portal_light.enabled = true


func _apply_team_visuals() -> void:
	var sprite := portal_sprite
	if sprite == null:
		sprite = get_node_or_null("PortalSprite") as Sprite2D
	if sprite != null:
		sprite.texture = RED_PORTAL_TEXTURE if team_id == "red" else PURPLE_PORTAL_TEXTURE
	var light := portal_light
	if light == null:
		light = get_node_or_null("PortalLight") as PointLight2D
	if light != null:
		light.color = RED_LIGHT_COLOR if team_id == "red" else PURPLE_LIGHT_COLOR


func _animate_portal() -> void:
	if portal_sprite == null:
		return
	var wave := sin(_animation_time * TAU)
	var pulse := 1.0 + wave * 0.022
	portal_sprite.scale = Vector2.ONE * pulse
	portal_sprite.position = _portal_sprite_origin + Vector2(0, wave * 1.25)
	portal_sprite.modulate.a = 0.92 + (wave + 1.0) * 0.04
	if portal_light != null:
		portal_light.energy = 0.68 + (wave + 1.0) * 0.12


func _text(key: String) -> String:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null and localization_manager.has_method("text"):
		return str(localization_manager.call("text", key))
	return key
