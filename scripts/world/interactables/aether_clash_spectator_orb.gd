@tool
extends WorldInteractable

class_name AetherClashSpectatorOrb

@export_range(0.2, 3.0, 0.1) var pulse_speed := 0.85
@export_range(-256, 256, 1) var sort_z_offset := 0

@onready var orb_sprite: Sprite2D = $OrbSprite
@onready var orb_light: PointLight2D = $OrbLight

var animation_time := 0.0
var sprite_origin := Vector2.ZERO


func _ready() -> void:
	z_as_relative = false
	z_index = clampi(floori(global_position.y) + sort_z_offset, -4096, 4096)
	interactable_kind = "aether_clash_spectator_orb"
	blocks_movement = true
	requires_facing = false
	interaction_shape_size = Vector2(96, 112)
	display_name = _text(
		"world.aether_clash.spectator_orb.name",
		"Aether Spectator Orb"
	)
	super._ready()
	sprite_origin = orb_sprite.position
	queue_redraw()


func _process(delta: float) -> void:
	animation_time += delta * pulse_speed
	var wave := sin(animation_time * TAU)
	orb_sprite.position = sprite_origin + Vector2(0.0, wave * 2.0)
	orb_sprite.scale = Vector2.ONE * (1.12 + wave * 0.04)
	orb_light.energy = 0.72 + (wave + 1.0) * 0.14
	if not Engine.is_editor_hint():
		await super._process(delta)


func interact_with_player(player: Node2D) -> void:
	for controller: Node in get_tree().get_nodes_in_group("aether_clash_duel_controller"):
		if not controller.has_method("request_spectator_orb"):
			continue
		var result: Variant = await controller.call("request_spectator_orb", player, self)
		if result is Dictionary and not bool((result as Dictionary).get("success", false)):
			var message := str((result as Dictionary).get(
				"error",
				_text(
					"ui.aether_clash.spectator.unavailable",
					"The Aether view is unavailable right now."
				)
			))
			await show_dialogue([message], display_name)
		return
	await show_dialogue([
		_text(
			"ui.aether_clash.spectator.unavailable",
			"The Aether view is unavailable right now."
		)
	], display_name)


func _draw() -> void:
	_draw_oval(Vector2(0, 11), Vector2(25, 11), Color(0.01, 0.03, 0.07, 0.72))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-23, 8), Vector2(23, 8), Vector2(17, 28), Vector2(-17, 28),
	]), Color("13243c"))
	draw_polyline(PackedVector2Array([
		Vector2(-23, 8), Vector2(23, 8), Vector2(17, 28), Vector2(-17, 28), Vector2(-23, 8),
	]), Color("64d7f0"), 2.0, true)


func _draw_oval(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)


func _text(key: String, fallback: String) -> String:
	var manager := get_node_or_null("/root/LocalizationManager")
	if manager != null and manager.has_method("text"):
		var translated := str(manager.call("text", key))
		if translated != key:
			return translated
	return fallback
